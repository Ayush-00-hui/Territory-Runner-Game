package notify

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
)

// Notifier defines push alert dispatch capabilities.
type Notifier interface {
	SendTerritoryAlert(ctx context.Context, deviceToken, territoryID, rivalName string, areaLost float64) error
	SendTerritoryAlertToUser(ctx context.Context, userID, territoryID, rivalName string, areaLost float64) error
}

// ServiceAccountKey matches standard Google Service Account JSON.
type ServiceAccountKey struct {
	Type         string `json:"type"`
	ProjectID    string `json:"project_id"`
	PrivateKeyID string `json:"private_key_id"`
	PrivateKey   string `json:"private_key"`
	ClientEmail  string `json:"client_email"`
	TokenURI     string `json:"token_uri"`
}

// FCMNotification represents the display notification payload in FCM HTTP v1.
type FCMNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

// AndroidConfig represents Android-specific delivery settings.
type AndroidConfig struct {
	Priority     string              `json:"priority"`
	Notification AndroidNotification `json:"notification"`
}

// AndroidNotification represents Android system notification channel parameters.
type AndroidNotification struct {
	ChannelID string `json:"channel_id"`
	Sound     string `json:"sound"`
}

// APNSConfig represents Apple APNS specific delivery headers.
type APNSConfig struct {
	Headers map[string]string `json:"headers"`
	Payload APNSPayload       `json:"payload"`
}

// APNSPayload encapsulates the APNS aps dictionary.
type APNSPayload struct {
	Aps ApsBody `json:"aps"`
}

// ApsBody specifies APNS sound and alert behavior.
type ApsBody struct {
	Sound string `json:"sound"`
}

// MessagePayload is the root object under "message" in FCM HTTP v1.
type MessagePayload struct {
	Token        string            `json:"token"`
	Notification *FCMNotification  `json:"notification,omitempty"`
	Data         map[string]string `json:"data,omitempty"`
	Android      *AndroidConfig    `json:"android,omitempty"`
	APNS         *APNSConfig       `json:"apns,omitempty"`
}

// FCMMessage wraps MessagePayload per FCM v1 specification.
type FCMMessage struct {
	Message MessagePayload `json:"message"`
}

// FCMClient implements modern FCM HTTP v1 using OAuth2 Service Account JWT tokens.
type FCMClient struct {
	store       store.Store
	logger      *slog.Logger
	httpClient  *http.Client
	projectID   string
	clientEmail string
	tokenURI    string
	fcmBaseURL  string
	parsedKey   *rsa.PrivateKey
	enabled     bool

	mu          sync.Mutex
	accessToken string
	tokenExpiry time.Time
}

// Option configures FCMClient.
type Option func(*FCMClient)

// WithHTTPClient injects a custom HTTP client for tests or custom timeouts.
func WithHTTPClient(client *http.Client) Option {
	return func(c *FCMClient) {
		if client != nil {
			c.httpClient = client
		}
	}
}

// WithTokenURI overrides the token exchange URL (useful for mocking Google OAuth in hermetic tests).
func WithTokenURI(uri string) Option {
	return func(c *FCMClient) {
		if uri != "" {
			c.tokenURI = uri
		}
	}
}

// WithFCMBaseURL overrides the FCM v1 endpoint base URL (useful for mocking FCM in tests).
func WithFCMBaseURL(url string) Option {
	return func(c *FCMClient) {
		if url != "" {
			c.fcmBaseURL = url
		}
	}
}

// NewFCMClient initializes an FCM HTTP v1 client from environment credentials or provided credentials.
// Gracefully degrades if credentials are not configured.
func NewFCMClient(dataStore store.Store, logger *slog.Logger, opts ...Option) *FCMClient {
	if logger == nil {
		logger = slog.Default()
	}

	client := &FCMClient{
		store:      dataStore,
		logger:     logger,
		httpClient: &http.Client{Timeout: 10 * time.Second},
		tokenURI:   "https://oauth2.googleapis.com/token",
		fcmBaseURL: "https://fcm.googleapis.com",
		enabled:    false,
	}

	for _, opt := range opts {
		opt(client)
	}

	credsData := loadServiceAccountBytes()
	if len(credsData) == 0 {
		logger.Warn("FCM service account credentials not configured; push notifications disabled (graceful fallback)")
		return client
	}

	var saKey ServiceAccountKey
	if err := json.Unmarshal(credsData, &saKey); err != nil {
		logger.Warn("failed to parse FCM service account JSON; push notifications disabled", "error", err)
		return client
	}

	key, err := parseRSAPrivateKey(saKey.PrivateKey)
	if err != nil {
		logger.Warn("failed to parse RSA private key from FCM service account; push notifications disabled", "error", err)
		return client
	}

	client.projectID = saKey.ProjectID
	client.clientEmail = saKey.ClientEmail
	if saKey.TokenURI != "" && client.tokenURI == "https://oauth2.googleapis.com/token" {
		client.tokenURI = saKey.TokenURI
	}
	client.parsedKey = key
	client.enabled = true

	logger.Info("FCM HTTP v1 push notifier initialized", "project_id", client.projectID, "client_email", client.clientEmail)
	return client
}

// IsEnabled returns true if FCM has valid service account credentials loaded.
func (c *FCMClient) IsEnabled() bool {
	return c.enabled
}

// BuildAlertPayload constructs the standardized FCM HTTP v1 payload for a territory attack alert.
func BuildAlertPayload(deviceToken, territoryID, rivalName string, areaLost float64) FCMMessage {
	return FCMMessage{
		Message: MessagePayload{
			Token: deviceToken,
			Notification: &FCMNotification{
				Title: "Territory alert",
				Body:  fmt.Sprintf("Rival %s claimed %.0f m² from your territory.", rivalName, areaLost),
			},
			Data: map[string]string{
				"type":          "territory_carved",
				"territory_id":  territoryID,
				"rival_name":    rivalName,
				"area_lost_sqm": fmt.Sprintf("%.1f", areaLost),
			},
			Android: &AndroidConfig{
				Priority: "high",
				Notification: AndroidNotification{
					ChannelID: "territory_alerts",
					Sound:     "default",
				},
			},
			APNS: &APNSConfig{
				Headers: map[string]string{
					"apns-priority": "10",
				},
				Payload: APNSPayload{
					Aps: ApsBody{
						Sound: "default",
					},
				},
			},
		},
	}
}

// SendTerritoryAlert dispatches an FCM v1 push notification to an individual device token.
func (c *FCMClient) SendTerritoryAlert(ctx context.Context, deviceToken, territoryID, rivalName string, areaLost float64) error {
	if !c.enabled {
		return nil
	}
	if deviceToken == "" {
		return errors.New("cannot send alert: device token is empty")
	}

	token, err := c.getAccessToken(ctx)
	if err != nil {
		return fmt.Errorf("failed to obtain OAuth2 token for FCM: %w", err)
	}

	payload := BuildAlertPayload(deviceToken, territoryID, rivalName, areaLost)
	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to serialize FCM payload: %w", err)
	}

	baseURL := c.fcmBaseURL
	if baseURL == "" {
		baseURL = "https://fcm.googleapis.com"
	}
	endpoint := fmt.Sprintf("%s/v1/projects/%s/messages:send", baseURL, c.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}

	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("FCM HTTP request error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("FCM server rejected push (status %d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// SendTerritoryAlertToUser retrieves all registered device tokens for the user and sends push alerts.
func (c *FCMClient) SendTerritoryAlertToUser(ctx context.Context, userID, territoryID, rivalName string, areaLost float64) error {
	if !c.enabled || c.store == nil {
		return nil
	}

	logger := c.logger
	if logger == nil {
		logger = slog.Default()
	}

	tokens, err := c.store.GetDeviceTokens(ctx, userID)
	if err != nil {
		return fmt.Errorf("error querying device tokens for %s: %w", err, err)
	}
	if len(tokens) == 0 {
		logger.Debug("no device tokens registered for victim runner", "user_id", userID)
		return nil
	}

	var errs []string
	for _, tok := range tokens {
		if sendErr := c.SendTerritoryAlert(ctx, tok, territoryID, rivalName, areaLost); sendErr != nil {
			logger.Warn("failed to deliver push to device token", "user_id", userID, "error", sendErr)
			errs = append(errs, sendErr.Error())
		}
	}

	if len(errs) > 0 && len(errs) == len(tokens) {
		return fmt.Errorf("all %d device pushes failed: %s", len(tokens), strings.Join(errs, "; "))
	}
	return nil
}

// getAccessToken returns a valid cached OAuth2 bearer token or generates a fresh one.
func (c *FCMClient) getAccessToken(ctx context.Context) (string, error) {
	c.mu.Lock()
	if c.accessToken != "" && time.Now().Before(c.tokenExpiry.Add(-60*time.Second)) {
		token := c.accessToken
		c.mu.Unlock()
		return token, nil
	}
	c.mu.Unlock()

	return c.refreshAccessToken(ctx)
}

func (c *FCMClient) refreshAccessToken(ctx context.Context) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Double-check under write lock
	if c.accessToken != "" && time.Now().Before(c.tokenExpiry.Add(-60*time.Second)) {
		return c.accessToken, nil
	}

	assertion, err := c.createJWTOAuthAssertion()
	if err != nil {
		return "", fmt.Errorf("failed to create JWT assertion: %w", err)
	}

	form := url.Values{}
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	form.Set("assertion", assertion)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.tokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to execute oauth token request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("oauth token endpoint returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode oauth response: %w", err)
	}

	c.accessToken = tokenResp.AccessToken
	expiresIn := tokenResp.ExpiresIn
	if expiresIn <= 0 {
		expiresIn = 3600
	}
	c.tokenExpiry = time.Now().Add(time.Duration(expiresIn) * time.Second)

	return c.accessToken, nil
}

func (c *FCMClient) createJWTOAuthAssertion() (string, error) {
	headerJSON := `{"alg":"RS256","typ":"JWT"}`
	headerB64 := base64.RawURLEncoding.EncodeToString([]byte(headerJSON))

	now := time.Now().UTC()
	claims := map[string]interface{}{
		"iss":   c.clientEmail,
		"sub":   c.clientEmail,
		"aud":   c.tokenURI,
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}

	claimsBytes, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	claimsB64 := base64.RawURLEncoding.EncodeToString(claimsBytes)

	signingInput := headerB64 + "." + claimsB64
	hashed := sha256.Sum256([]byte(signingInput))

	signature, err := rsa.SignPKCS1v15(rand.Reader, c.parsedKey, crypto.SHA256, hashed[:])
	if err != nil {
		return "", fmt.Errorf("failed to sign JWT assertion: %w", err)
	}
	signatureB64 := base64.RawURLEncoding.EncodeToString(signature)

	return signingInput + "." + signatureB64, nil
}

func parseRSAPrivateKey(pemStr string) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, errors.New("failed to parse PEM block containing private key")
	}

	if key, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if rsaKey, ok := key.(*rsa.PrivateKey); ok {
			return rsaKey, nil
		}
		return nil, errors.New("PKCS#8 key is not an RSA private key")
	}

	if key, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		return key, nil
	}

	return nil, errors.New("failed to parse RSA private key (tried PKCS#8 and PKCS#1)")
}

func loadServiceAccountBytes() []byte {
	// 1. Check FIREBASE_SERVICE_ACCOUNT_JSON (file path or inline json)
	if val := os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON"); val != "" {
		trimmed := strings.TrimSpace(val)
		if strings.HasPrefix(trimmed, "{") {
			return []byte(trimmed)
		}
		if data, err := os.ReadFile(val); err == nil {
			return data
		}
	}

	// 2. Check GOOGLE_APPLICATION_CREDENTIALS
	if val := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"); val != "" {
		if data, err := os.ReadFile(val); err == nil {
			return data
		}
	}

	return nil
}

// MockNotifier provides an in-memory recording notifier for tests.
type MockNotifier struct {
	mu         sync.Mutex
	SentAlerts []SentAlertRecord
}

// SentAlertRecord captures a dispatched push notification for test assertions.
type SentAlertRecord struct {
	DeviceToken string
	UserID      string
	TerritoryID string
	RivalName   string
	AreaLost    float64
}

// NewMockNotifier creates a test mock notifier.
func NewMockNotifier() *MockNotifier {
	return &MockNotifier{
		SentAlerts: make([]SentAlertRecord, 0),
	}
}

func (m *MockNotifier) SendTerritoryAlert(ctx context.Context, deviceToken, territoryID, rivalName string, areaLost float64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.SentAlerts = append(m.SentAlerts, SentAlertRecord{
		DeviceToken: deviceToken,
		TerritoryID: territoryID,
		RivalName:   rivalName,
		AreaLost:    areaLost,
	})
	return nil
}

func (m *MockNotifier) SendTerritoryAlertToUser(ctx context.Context, userID, territoryID, rivalName string, areaLost float64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.SentAlerts = append(m.SentAlerts, SentAlertRecord{
		UserID:      userID,
		TerritoryID: territoryID,
		RivalName:   rivalName,
		AreaLost:    areaLost,
	})
	return nil
}

// TotalAlerts returns the count of dispatched alerts recorded in the mock.
func (m *MockNotifier) TotalAlerts() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.SentAlerts)
}
