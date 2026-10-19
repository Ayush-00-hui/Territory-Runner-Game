package auth_test

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type tokenBuilder struct {
	privKey   *rsa.PrivateKey
	kid       string
	projectID string
	subject   string
	issuer    string
	audience  string
	expiresAt int64
	issuedAt  int64
}

func newTokenBuilder(privKey *rsa.PrivateKey, kid, projectID, subject string) *tokenBuilder {
	now := time.Now().Unix()
	return &tokenBuilder{
		privKey:   privKey,
		kid:       kid,
		projectID: projectID,
		subject:   subject,
		issuer:    "https://securetoken.google.com/" + projectID,
		audience:  projectID,
		expiresAt: now + 3600,
		issuedAt:  now,
	}
}

func (b *tokenBuilder) build() (string, error) {
	header := map[string]string{
		"alg": "RS256",
		"kid": b.kid,
		"typ": "JWT",
	}
	headerJSON, err := json.Marshal(header)
	if err != nil {
		return "", err
	}
	headerB64 := base64.RawURLEncoding.EncodeToString(headerJSON)

	payload := map[string]interface{}{
		"iss": b.issuer,
		"aud": b.audience,
		"sub": b.subject,
		"exp": b.expiresAt,
		"iat": b.issuedAt,
	}
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	payloadB64 := base64.RawURLEncoding.EncodeToString(payloadJSON)

	signedContent := headerB64 + "." + payloadB64
	hasher := sha256.New()
	hasher.Write([]byte(signedContent))
	digest := hasher.Sum(nil)

	sig, err := rsa.SignPKCS1v15(rand.Reader, b.privKey, crypto.SHA256, digest)
	if err != nil {
		return "", err
	}
	sigB64 := base64.RawURLEncoding.EncodeToString(sig)

	return fmt.Sprintf("%s.%s", signedContent, sigB64), nil
}

func setupTestAuth(t *testing.T) (*auth.Authenticator, *rsa.PrivateKey, string, string) {
	privKey, err := rsa.GenerateKey(rand.Reader, 2048)
	require.NoError(t, err)

	kid := "test-key-id-123"
	projectID := "territory-runner-prod-99"

	staticKeys := map[string]*rsa.PublicKey{
		kid: &privKey.PublicKey,
	}
	keyProvider := auth.NewStaticKeyProvider(staticKeys)

	cfg := &config.Config{
		AuthMode:          "firebase",
		Env:               "production",
		FirebaseProjectID: projectID,
	}

	authenticator := auth.NewAuthenticator(cfg, auth.WithKeyProvider(keyProvider))
	return authenticator, privKey, kid, projectID
}

func TestVerifyToken_Valid(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "user_runner_alpha")
	tokenStr, err := builder.build()
	require.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)

	uid, err := authenticator.AuthenticateRequest(req)
	require.NoError(t, err)
	assert.Equal(t, "user_runner_alpha", uid)
}

func TestVerifyToken_Expired(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "user_runner_expired")
	builder.expiresAt = time.Now().Unix() - 100 // expired 100s ago
	builder.issuedAt = time.Now().Unix() - 500
	tokenStr, err := builder.build()
	require.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)

	uid, err := authenticator.AuthenticateRequest(req)
	assert.ErrorIs(t, err, auth.ErrTokenExpired)
	assert.Empty(t, uid)
}

func TestVerifyToken_WrongAudience(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "user_runner_wrong_aud")
	builder.audience = "some-malicious-app-id"
	tokenStr, err := builder.build()
	require.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)

	uid, err := authenticator.AuthenticateRequest(req)
	assert.ErrorIs(t, err, auth.ErrInvalidAudience)
	assert.Empty(t, uid)
}

func TestVerifyToken_WrongIssuer(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "user_runner_wrong_iss")
	builder.issuer = "https://securetoken.google.com/rogue-project"
	tokenStr, err := builder.build()
	require.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	req.Header.Set("Authorization", "Bearer "+tokenStr)

	uid, err := authenticator.AuthenticateRequest(req)
	assert.ErrorIs(t, err, auth.ErrInvalidIssuer)
	assert.Empty(t, uid)
}

func TestVerifyToken_TamperedSignature(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "user_runner_tampered")
	tokenStr, err := builder.build()
	require.NoError(t, err)

	// Tamper with the token body
	tamperedToken := tokenStr[:len(tokenStr)-4] + "AAAA"

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	req.Header.Set("Authorization", "Bearer "+tamperedToken)

	uid, err := authenticator.AuthenticateRequest(req)
	assert.Error(t, err)
	assert.Empty(t, uid)
}

func TestVerifyToken_MissingToken(t *testing.T) {
	authenticator, _, _, _ := setupTestAuth(t)

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	uid, err := authenticator.AuthenticateRequest(req)
	assert.ErrorIs(t, err, auth.ErrUnauthorized)
	assert.Empty(t, uid)
}

func TestVerifyToken_SecWebSocketProtocolHeader(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "ws_runner_token")
	tokenStr, err := builder.build()
	require.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/v1/ws", nil)
	req.Header.Set("Sec-WebSocket-Protocol", "bearer, "+tokenStr)

	uid, err := authenticator.AuthenticateRequest(req)
	require.NoError(t, err)
	assert.Equal(t, "ws_runner_token", uid)
}

func TestDevAuthMode_AcceptsDevHeaders(t *testing.T) {
	cfg := &config.Config{
		AuthMode: "dev",
		Env:      "development",
	}
	authenticator := auth.NewAuthenticator(cfg)

	req := httptest.NewRequest(http.MethodGet, "/v1/runs", nil)
	req.Header.Set("X-Dev-User", "local_developer")

	uid, err := authenticator.AuthenticateRequest(req)
	require.NoError(t, err)
	assert.Equal(t, "local_developer", uid)
}

func TestVerifyToken_QueryTokenRejectedInProd(t *testing.T) {
	authenticator, privKey, kid, projectID := setupTestAuth(t)

	builder := newTokenBuilder(privKey, kid, projectID, "user_runner_query")
	tokenStr, err := builder.build()
	require.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/v1/ws?token="+tokenStr, nil)
	uid, err := authenticator.AuthenticateRequest(req)
	assert.ErrorIs(t, err, auth.ErrUnauthorized)
	assert.Empty(t, uid)
}

func TestDevAuthMode_AcceptsDevUserQueryParam(t *testing.T) {
	cfg := &config.Config{
		AuthMode: "dev",
		Env:      "development",
	}
	authenticator := auth.NewAuthenticator(cfg)

	req := httptest.NewRequest(http.MethodGet, "/v1/ws?dev_user=query_developer", nil)
	uid, err := authenticator.AuthenticateRequest(req)
	require.NoError(t, err)
	assert.Equal(t, "query_developer", uid)

	req2 := httptest.NewRequest(http.MethodGet, "/v1/ws?user_id=uid_developer", nil)
	uid2, err := authenticator.AuthenticateRequest(req2)
	require.NoError(t, err)
	assert.Equal(t, "uid_developer", uid2)
}

