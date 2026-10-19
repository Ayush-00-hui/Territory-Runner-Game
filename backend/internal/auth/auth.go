package auth

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
)

type contextKey string

const (
	userIDKey contextKey = "user_id"
)

var (
	// ErrUnauthorized is returned when credentials are missing or invalid.
	ErrUnauthorized = errors.New("unauthorized: missing or invalid credentials")
	// ErrTokenExpired is returned when a JWT has expired.
	ErrTokenExpired = errors.New("unauthorized: token has expired")
	// ErrInvalidIssuer is returned when a JWT issuer does not match Firebase project ID.
	ErrInvalidIssuer = errors.New("unauthorized: invalid token issuer")
	// ErrInvalidAudience is returned when a JWT audience does not match Firebase project ID.
	ErrInvalidAudience = errors.New("unauthorized: invalid token audience")
	// ErrInvalidSignature is returned when a JWT signature verification fails.
	ErrInvalidSignature = errors.New("unauthorized: invalid token signature")
	// ErrMissingSubject is returned when a JWT sub claim is empty.
	ErrMissingSubject = errors.New("unauthorized: missing token subject")

	maxAgeRegex = regexp.MustCompile(`max-age=(\d+)`)
)

// KeyProvider supplies public RSA keys for JWT verification.
type KeyProvider interface {
	GetPublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error)
}

// GoogleKeyProvider fetches and caches Google's public x509 certificates.
type GoogleKeyProvider struct {
	client     *http.Client
	keysURL    string
	mu         sync.RWMutex
	keys       map[string]*rsa.PublicKey
	expiryTime time.Time
}

// NewGoogleKeyProvider creates a GoogleKeyProvider targeting Google's public x509 cert endpoint.
func NewGoogleKeyProvider() *GoogleKeyProvider {
	return &GoogleKeyProvider{
		client:  &http.Client{Timeout: 10 * time.Second},
		keysURL: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com",
		keys:    make(map[string]*rsa.PublicKey),
	}
}

// GetPublicKey retrieves the RSA public key corresponding to kid from cache or Google's API.
func (p *GoogleKeyProvider) GetPublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	p.mu.RLock()
	if time.Now().Before(p.expiryTime) && p.keys[kid] != nil {
		k := p.keys[kid]
		p.mu.RUnlock()
		return k, nil
	}
	p.mu.RUnlock()

	p.mu.Lock()
	defer p.mu.Unlock()

	// Double-check after acquiring write lock
	if time.Now().Before(p.expiryTime) && p.keys[kid] != nil {
		return p.keys[kid], nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.keysURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create public key request: %w", err)
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch public keys: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code fetching public keys: %d", resp.StatusCode)
	}

	var certMap map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&certMap); err != nil {
		return nil, fmt.Errorf("failed to decode public key certs: %w", err)
	}

	// Parse Cache-Control header max-age
	ttl := 6 * time.Hour
	cacheControl := resp.Header.Get("Cache-Control")
	if match := maxAgeRegex.FindStringSubmatch(cacheControl); len(match) > 1 {
		if sec, err := strconv.Atoi(match[1]); err == nil && sec > 0 {
			ttl = time.Duration(sec) * time.Second
		}
	}

	newKeys := make(map[string]*rsa.PublicKey)
	for k, certPEM := range certMap {
		block, _ := pem.Decode([]byte(certPEM))
		if block == nil {
			continue
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			continue
		}
		if rsaPub, ok := cert.PublicKey.(*rsa.PublicKey); ok {
			newKeys[k] = rsaPub
		}
	}

	p.keys = newKeys
	p.expiryTime = time.Now().Add(ttl)

	key, ok := p.keys[kid]
	if !ok {
		return nil, fmt.Errorf("public key with kid %q not found", kid)
	}
	return key, nil
}

// StaticKeyProvider supplies fixed public keys for unit testing.
type StaticKeyProvider struct {
	keys map[string]*rsa.PublicKey
}

// NewStaticKeyProvider creates a StaticKeyProvider with predetermined RSA public keys.
func NewStaticKeyProvider(keys map[string]*rsa.PublicKey) *StaticKeyProvider {
	return &StaticKeyProvider{keys: keys}
}

// GetPublicKey returns the key matching kid from the static map.
func (s *StaticKeyProvider) GetPublicKey(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	k, ok := s.keys[kid]
	if !ok {
		return nil, fmt.Errorf("public key with kid %q not found", kid)
	}
	return k, nil
}

// Authenticator handles token verification and user identity extraction.
type Authenticator struct {
	cfg         *config.Config
	keyProvider KeyProvider
}

// Option configures Authenticator options.
type Option func(*Authenticator)

// WithKeyProvider overrides the public key provider (useful for unit testing).
func WithKeyProvider(kp KeyProvider) Option {
	return func(a *Authenticator) {
		a.keyProvider = kp
	}
}

// NewAuthenticator creates an Authenticator instance.
func NewAuthenticator(cfg *config.Config, opts ...Option) *Authenticator {
	a := &Authenticator{
		cfg:         cfg,
		keyProvider: NewGoogleKeyProvider(),
	}
	for _, opt := range opts {
		opt(a)
	}
	return a
}

type jwtHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
	Typ string `json:"typ"`
}

// FirebaseClaims contains verified claims from a Google/Firebase ID token.
type FirebaseClaims struct {
	Issuer    string `json:"iss"`
	Audience  string `json:"aud"`
	Subject   string `json:"sub"`
	ExpiresAt int64  `json:"exp"`
	IssuedAt  int64  `json:"iat"`
	AuthTime  int64  `json:"auth_time,omitempty"`
}

// VerifyFirebaseToken validates an RS256 JWT against Firebase project constraints and Google public keys.
func (a *Authenticator) VerifyFirebaseToken(ctx context.Context, tokenString string) (*FirebaseClaims, error) {
	parts := strings.Split(tokenString, ".")
	if len(parts) != 3 {
		return nil, ErrUnauthorized
	}

	// 1. Decode and validate header
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, ErrUnauthorized
	}

	var header jwtHeader
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return nil, ErrUnauthorized
	}

	if header.Alg != "RS256" {
		return nil, errors.New("unauthorized: unsupported token algorithm, expected RS256")
	}
	if header.Kid == "" {
		return nil, errors.New("unauthorized: missing kid in token header")
	}

	// 2. Fetch RSA public key for this kid
	pubKey, err := a.keyProvider.GetPublicKey(ctx, header.Kid)
	if err != nil {
		return nil, ErrUnauthorized
	}

	// 3. Verify RS256 signature
	sigBytes, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, ErrUnauthorized
	}

	signedContent := parts[0] + "." + parts[1]
	hasher := sha256.New()
	hasher.Write([]byte(signedContent))
	digest := hasher.Sum(nil)

	if err := rsa.VerifyPKCS1v15(pubKey, crypto.SHA256, digest, sigBytes); err != nil {
		return nil, ErrInvalidSignature
	}

	// 4. Decode payload and validate claims
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, ErrUnauthorized
	}

	var claims FirebaseClaims
	if err := json.Unmarshal(payloadBytes, &claims); err != nil {
		return nil, ErrUnauthorized
	}

	if claims.Subject == "" {
		return nil, ErrMissingSubject
	}

	expectedIssuer := "https://securetoken.google.com/" + a.cfg.FirebaseProjectID
	if claims.Issuer != expectedIssuer {
		return nil, ErrInvalidIssuer
	}

	if claims.Audience != a.cfg.FirebaseProjectID {
		return nil, ErrInvalidAudience
	}

	now := time.Now().Unix()
	if claims.ExpiresAt <= now {
		return nil, ErrTokenExpired
	}

	// Allow up to 60 seconds of clock skew for iat
	if claims.IssuedAt > now+60 {
		return nil, errors.New("unauthorized: token issued in the future")
	}

	return &claims, nil
}

// AuthenticateRequest extracts and verifies the runner identity.
func (a *Authenticator) AuthenticateRequest(r *http.Request) (string, error) {
	if a.cfg.AuthMode == "dev" {
		devUser := r.Header.Get("X-Dev-User")
		if devUser == "" {
			devUser = r.URL.Query().Get("dev_user")
		}
		if devUser == "" {
			devUser = r.URL.Query().Get("user_id")
		}
		if devUser == "" {
			devUser = r.URL.Query().Get("token")
		}
		if devUser != "" {
			return devUser, nil
		}
		return "dev_runner_local", nil
	}

	// Production / Firebase authentication mode:
	// Only accept Authorization header or Sec-WebSocket-Protocol header.
	// Query parameters are rejected to prevent token leakage in HTTP access logs and proxy caches.
	token := ""
	authHeader := r.Header.Get("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token = strings.TrimPrefix(authHeader, "Bearer ")
	} else if wsProto := r.Header.Get("Sec-WebSocket-Protocol"); wsProto != "" {
		// Support Sec-WebSocket-Protocol for WebSocket clients (e.g. "bearer, <token>")
		parts := strings.Split(wsProto, ",")
		for i, p := range parts {
			trimmed := strings.TrimSpace(p)
			if strings.EqualFold(trimmed, "bearer") && i+1 < len(parts) {
				token = strings.TrimSpace(parts[i+1])
				break
			}
		}
		if token == "" && len(parts) == 1 {
			token = strings.TrimSpace(parts[0])
		}
	}

	if token == "" {
		return "", ErrUnauthorized
	}

	claims, err := a.VerifyFirebaseToken(r.Context(), token)
	if err != nil {
		return "", err
	}

	return claims.Subject, nil
}

// Middleware injects verified runner identity into request context.
func (a *Authenticator) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, err := a.AuthenticateRequest(r)
		if err != nil {
			http.Error(w, `{"error":"unauthorized","detail":"missing or invalid authentication credentials"}`, http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), userIDKey, uid)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// GetUserID extracts the authenticated user ID from context.
func GetUserID(ctx context.Context) string {
	if val, ok := ctx.Value(userIDKey).(string); ok {
		return val
	}
	return ""
}
