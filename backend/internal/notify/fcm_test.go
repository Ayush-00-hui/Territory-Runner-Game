package notify

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func generateTestRSAKeyPEM(t *testing.T) string {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	require.NoError(t, err)

	der := x509.MarshalPKCS1PrivateKey(key)
	block := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: der,
	}
	return string(pem.EncodeToMemory(block))
}

func TestBuildAlertPayload(t *testing.T) {
	payload := BuildAlertPayload("fcm_token_12345", "poly_territory_99", "ShadowStriker", 1850.5)

	assert.Equal(t, "fcm_token_12345", payload.Message.Token)
	assert.Equal(t, "TERRITORY UNDER ATTACK!", payload.Message.Notification.Title)
	assert.Contains(t, payload.Message.Notification.Body, "ShadowStriker")
	assert.Contains(t, payload.Message.Notification.Body, "1850")

	require.NotNil(t, payload.Message.Data)
	assert.Equal(t, "territory_carved", payload.Message.Data["type"])
	assert.Equal(t, "poly_territory_99", payload.Message.Data["territory_id"])
	assert.Equal(t, "ShadowStriker", payload.Message.Data["rival_name"])
	assert.Equal(t, "1850.5", payload.Message.Data["area_lost_sqm"])

	require.NotNil(t, payload.Message.Android)
	assert.Equal(t, "high", payload.Message.Android.Priority)
	assert.Equal(t, "territory_alerts", payload.Message.Android.Notification.ChannelID)

	require.NotNil(t, payload.Message.APNS)
	assert.Equal(t, "10", payload.Message.APNS.Headers["apns-priority"])
}

func TestFCMClientGracefulDegradeWhenNoCredentials(t *testing.T) {
	memStore := store.NewMemoryStore()
	client := NewFCMClient(memStore, nil)

	assert.False(t, client.IsEnabled())

	// Sending alert with disabled client should not error or crash
	err := client.SendTerritoryAlert(context.Background(), "token", "poly_1", "rival", 500.0)
	assert.NoError(t, err)

	err = client.SendTerritoryAlertToUser(context.Background(), "user_1", "poly_1", "rival", 500.0)
	assert.NoError(t, err)
}

func TestFCMOAuth2TokenRefreshAndSend(t *testing.T) {
	privKeyPEM := generateTestRSAKeyPEM(t)
	parsedPrivKey, err := parseRSAPrivateKey(privKeyPEM)
	require.NoError(t, err)

	tokenRequestCount := 0
	fcmRequestCount := 0

	// Mock Google OAuth & FCM v1 HTTP Server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/token" {
			tokenRequestCount++
			assert.Equal(t, "application/x-www-form-urlencoded", r.Header.Get("Content-Type"))
			_ = r.ParseForm()
			assert.Equal(t, "urn:ietf:params:oauth:grant-type:jwt-bearer", r.Form.Get("grant_type"))
			assert.NotEmpty(t, r.Form.Get("assertion"))

			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"access_token": "ya29.mock_oauth2_access_token_abc",
				"token_type":   "Bearer",
				"expires_in":   3600,
			})
			return
		}

		if r.URL.Path == "/v1/projects/test-territory-project/messages:send" {
			fcmRequestCount++
			assert.Equal(t, "Bearer ya29.mock_oauth2_access_token_abc", r.Header.Get("Authorization"))
			assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

			var msg FCMMessage
			err := json.NewDecoder(r.Body).Decode(&msg)
			assert.NoError(t, err)
			assert.Equal(t, "test_device_token_xyz", msg.Message.Token)

			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte(`{"name": "projects/test-territory-project/messages/1234567890"}`))
			return
		}

		http.NotFound(w, r)
	}))
	defer server.Close()

	memStore := store.NewMemoryStore()
	client := &FCMClient{
		store:       memStore,
		httpClient:  server.Client(),
		projectID:   "test-territory-project",
		clientEmail: "service-acc@test-territory-project.iam.gserviceaccount.com",
		tokenURI:    server.URL + "/token",
		fcmBaseURL:  server.URL,
		parsedKey:   parsedPrivKey,
		enabled:     true,
	}

	// 1. Send first alert — should request OAuth2 token once and send message
	err = client.SendTerritoryAlert(context.Background(), "test_device_token_xyz", "poly_001", "ViperRunner", 420.0)
	assert.NoError(t, err)
	assert.Equal(t, 1, tokenRequestCount)
	assert.Equal(t, 1, fcmRequestCount)

	// 2. Send second alert immediately — token is cached, should NOT request token again
	err = client.SendTerritoryAlert(context.Background(), "test_device_token_xyz", "poly_002", "ViperRunner", 120.0)
	assert.NoError(t, err)
	assert.Equal(t, 1, tokenRequestCount, "OAuth token should be reused from TTL cache")
	assert.Equal(t, 2, fcmRequestCount)
}

func TestFCMUserFanoutDelivery(t *testing.T) {
	memStore := store.NewMemoryStore()
	ctx := context.Background()

	victimUID := "user_victim_88"
	_ = memStore.SaveDeviceToken(ctx, victimUID, "token_phone_1")
	_ = memStore.SaveDeviceToken(ctx, victimUID, "token_tablet_2")

	deliveredTokens := make([]string, 0)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/token" {
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"access_token": "ya29.mock_token",
				"expires_in":   3600,
			})
			return
		}
		if r.URL.Path == "/v1/projects/test-project/messages:send" {
			var msg FCMMessage
			_ = json.NewDecoder(r.Body).Decode(&msg)
			deliveredTokens = append(deliveredTokens, msg.Message.Token)
			w.WriteHeader(http.StatusOK)
			return
		}
		http.NotFound(w, r)
	}))
	defer server.Close()

	privKeyPEM := generateTestRSAKeyPEM(t)
	parsedKey, err := parseRSAPrivateKey(privKeyPEM)
	require.NoError(t, err)

	client := &FCMClient{
		store:       memStore,
		httpClient:  server.Client(),
		projectID:   "test-project",
		clientEmail: "sa@test-project.iam.gserviceaccount.com",
		tokenURI:    server.URL + "/token",
		fcmBaseURL:  server.URL,
		parsedKey:   parsedKey,
		enabled:     true,
	}

	err = client.SendTerritoryAlertToUser(ctx, victimUID, "poly_victim", "RivalSpeedster", 950.0)
	assert.NoError(t, err)

	assert.ElementsMatch(t, []string{"token_phone_1", "token_tablet_2"}, deliveredTokens)
}

func TestMockNotifierRecordsDispatchedAlerts(t *testing.T) {
	mock := NewMockNotifier()
	ctx := context.Background()

	err := mock.SendTerritoryAlert(ctx, "dev_token_1", "poly_12", "Rival_A", 300.0)
	require.NoError(t, err)

	err = mock.SendTerritoryAlertToUser(ctx, "user_45", "poly_45", "Rival_B", 750.0)
	require.NoError(t, err)

	assert.Equal(t, 2, mock.TotalAlerts())
	assert.Equal(t, "dev_token_1", mock.SentAlerts[0].DeviceToken)
	assert.Equal(t, 300.0, mock.SentAlerts[0].AreaLost)
	assert.Equal(t, "user_45", mock.SentAlerts[1].UserID)
	assert.Equal(t, 750.0, mock.SentAlerts[1].AreaLost)
}
