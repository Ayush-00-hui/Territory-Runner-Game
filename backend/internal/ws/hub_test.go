package ws_test

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestHub(t *testing.T, opts ...ws.Option) (*ws.Hub, *httptest.Server, string) {
	// By default in tests, set presence delay to 0 for instant deterministic testing
	defaultOpts := []ws.Option{
		ws.WithPresenceDelay(0),
	}
	allOpts := append(defaultOpts, opts...)
	hub := ws.NewHub(slog.Default(), allOpts...)
	go hub.Run()
	t.Cleanup(func() {
		hub.Stop()
	})

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := r.URL.Query().Get("uid")
		hub.ServeWS(w, r, uid, "Runner_"+uid, "Cyber Vanguard")
	}))
	t.Cleanup(func() {
		server.Close()
	})

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")
	return hub, server, wsURL
}

func TestWebSocket_SubprotocolEchoed(t *testing.T) {
	_, _, wsURL := setupTestHub(t)

	dialer := websocket.Dialer{
		Subprotocols: []string{"bearer", "dummy-jwt-token"},
	}

	conn, resp, err := dialer.Dial(wsURL+"?uid=runner_proto", nil)
	require.NoError(t, err)
	defer conn.Close()

	assert.Equal(t, http.StatusSwitchingProtocols, resp.StatusCode)
	assert.Equal(t, "bearer", resp.Header.Get("Sec-Websocket-Protocol"), "server must echo negotiated subprotocol")
}

func TestWebSocket_OffSendsNothing(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	// Sender Alpha (visibility defaults to "off")
	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer c1.Close()

	// Receiver Beta
	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta", nil)
	require.NoError(t, err)
	defer c2.Close()

	time.Sleep(50 * time.Millisecond)

	// Receiver Beta subscribes to all cells
	cell := geo.GeohashPrecision6(51.501, -0.121)
	err = c2.WriteJSON(ws.InboundMessage{
		Type:  ws.TypeViewportSubscribe,
		Cells: []string{cell},
	})
	require.NoError(t, err)
	time.Sleep(50 * time.Millisecond)

	// Verify sender visibility is explicitly "off"
	assert.Equal(t, "off", hub.GetUserVisibility("runner_alpha"))

	// Sender Alpha sends presence update
	err = c1.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.501,
		Longitude: -0.121,
	})
	require.NoError(t, err)

	// Receiver Beta should NOT receive any message (read timeout)
	_ = c2.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, _, err = c2.ReadMessage()
	assert.Error(t, err, "off visibility must send nothing to peers")
}

func TestWebSocket_FriendsOnly(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	// Configure sender Alpha with friends-only visibility
	hub.UpdateUserVisibility("runner_alpha", "friends")
	// Beta is a friend, Gamma is a stranger
	hub.SetFriendsCache("runner_alpha", []string{"runner_beta"})

	cAlpha, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer cAlpha.Close()

	cBeta, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta", nil)
	require.NoError(t, err)
	defer cBeta.Close()

	cGamma, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_gamma", nil)
	require.NoError(t, err)
	defer cGamma.Close()

	time.Sleep(50 * time.Millisecond)

	// Alpha sends presence update
	err = cAlpha.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.501,
		Longitude: -0.121,
	})
	require.NoError(t, err)

	// Friend Beta MUST receive Alpha's coarsened presence
	_ = cBeta.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, msgBytes, err := cBeta.ReadMessage()
	require.NoError(t, err)

	var presence ws.PresenceMessage
	err = json.Unmarshal(msgBytes, &presence)
	require.NoError(t, err)
	assert.Equal(t, ws.TypeRunnerPresence, presence.Type)
	assert.Equal(t, "runner_alpha", presence.UserID)

	// Stranger Gamma MUST NOT receive anything
	_ = cGamma.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, _, err = cGamma.ReadMessage()
	assert.Error(t, err, "stranger must not receive friends-only presence update")
}

func TestWebSocket_NearbyCellDeliveryAndNonNeighbourExclusion(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	// Alpha enables "nearby" visibility
	hub.UpdateUserVisibility("runner_alpha", "nearby")

	cAlpha, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer cAlpha.Close()

	// Beta is nearby (subscribes to Alpha's cell)
	cBeta, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta", nil)
	require.NoError(t, err)
	defer cBeta.Close()

	// Gamma is distant (subscribes to a non-neighboring cell in New York)
	cGamma, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_gamma", nil)
	require.NoError(t, err)
	defer cGamma.Close()

	time.Sleep(50 * time.Millisecond)

	alphaLat, alphaLng := 51.501, -0.121 // London
	alphaCell := geo.GeohashPrecision6(alphaLat, alphaLng)

	// Beta subscribes to Alpha's cell
	err = cBeta.WriteJSON(ws.InboundMessage{
		Type:  ws.TypeViewportSubscribe,
		Cells: []string{alphaCell},
	})
	require.NoError(t, err)

	// Gamma subscribes to a distant cell in Tokyo
	tokyoCell := geo.GeohashPrecision6(35.6762, 139.6503)
	err = cGamma.WriteJSON(ws.InboundMessage{
		Type:  ws.TypeViewportSubscribe,
		Cells: []string{tokyoCell},
	})
	require.NoError(t, err)

	time.Sleep(50 * time.Millisecond)

	// Alpha sends presence in London
	err = cAlpha.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  alphaLat,
		Longitude: alphaLng,
	})
	require.NoError(t, err)

	// Beta (nearby subscriber) MUST receive
	_ = cBeta.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, msgBytes, err := cBeta.ReadMessage()
	require.NoError(t, err)

	var presence ws.PresenceMessage
	err = json.Unmarshal(msgBytes, &presence)
	require.NoError(t, err)
	assert.Equal(t, "runner_alpha", presence.UserID)

	// Gamma (distant subscriber) MUST NOT receive
	_ = cGamma.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, _, err = cGamma.ReadMessage()
	assert.Error(t, err, "non-neighboring cell subscriber must not receive nearby presence")
}

func TestWebSocket_PrivacyZoneSuppression(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	hub.UpdateUserVisibility("runner_alpha", "nearby")
	hub.UpdateUserPrivacyZones("runner_alpha", []geo.PrivacyZoneEvaluator{
		{
			Latitude:     51.501,
			Longitude:    -0.121,
			RadiusMeters: 200.0,
			IsEnabled:    true,
		},
	})

	cAlpha, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer cAlpha.Close()

	cBeta, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta", nil)
	require.NoError(t, err)
	defer cBeta.Close()

	time.Sleep(50 * time.Millisecond)

	// Beta subscribes to cells in the area
	cellInside := geo.GeohashPrecision6(51.501, -0.121)
	cellOutside := geo.GeohashPrecision6(51.520, -0.121)
	err = cBeta.WriteJSON(ws.InboundMessage{
		Type:  ws.TypeViewportSubscribe,
		Cells: []string{cellInside, cellOutside},
	})
	require.NoError(t, err)
	time.Sleep(50 * time.Millisecond)

	// Pump incoming messages from Beta to a channel
	betaReceived := make(chan []byte, 10)
	go func() {
		for {
			_, msg, err := cBeta.ReadMessage()
			if err != nil {
				return
			}
			betaReceived <- msg
		}
	}()

	// 1. Alpha sends presence INSIDE privacy zone -> suppressed
	err = cAlpha.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.501,
		Longitude: -0.121,
	})
	require.NoError(t, err)

	select {
	case msg := <-betaReceived:
		t.Fatalf("presence inside privacy zone must be suppressed, got: %s", string(msg))
	case <-time.After(200 * time.Millisecond):
		// Correctly suppressed!
	}

	// 2. Alpha sends presence OUTSIDE privacy zone (~2km away) -> delivered
	time.Sleep(2100 * time.Millisecond) // wait for rate limiter
	err = cAlpha.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.520,
		Longitude: -0.121,
	})
	require.NoError(t, err)

	select {
	case msgBytes := <-betaReceived:
		var presence ws.PresenceMessage
		err = json.Unmarshal(msgBytes, &presence)
		require.NoError(t, err)
		assert.Equal(t, "runner_alpha", presence.UserID)
		assert.Equal(t, ws.TypeRunnerPresence, presence.Type)
	case <-time.After(1 * time.Second):
		t.Fatal("timed out waiting for outside-zone presence message")
	}
}

func TestWebSocket_RateLimit(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	hub.UpdateUserVisibility("runner_alpha", "nearby")

	cAlpha, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer cAlpha.Close()

	cBeta, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta", nil)
	require.NoError(t, err)
	defer cBeta.Close()

	time.Sleep(50 * time.Millisecond)

	cell := geo.GeohashPrecision6(51.520, -0.121)
	_ = cBeta.WriteJSON(ws.InboundMessage{
		Type:  ws.TypeViewportSubscribe,
		Cells: []string{cell},
	})
	time.Sleep(50 * time.Millisecond)

	// Rapidly send two presence updates from Alpha
	_ = cAlpha.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.520,
		Longitude: -0.121,
	})
	_ = cAlpha.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.521,
		Longitude: -0.121,
	})

	// Beta receives the first one
	_ = cBeta.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, _, err = cBeta.ReadMessage()
	require.NoError(t, err)

	// Second rapid update within 2s MUST have been dropped by rate limiter
	_ = cBeta.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, _, err = cBeta.ReadMessage()
	assert.Error(t, err, "second rapid presence update within 2s should be dropped")
}

func TestWebSocket_SlowClientDropped(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	hub.UpdateUserVisibility("runner_alpha", "nearby")

	cAlpha, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer cAlpha.Close()

	// Drain messages for Alpha so Alpha remains active and responsive
	go func() {
		for {
			if _, _, err := cAlpha.ReadMessage(); err != nil {
				return
			}
		}
	}()

	// Slow Client
	cSlow, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_slow", nil)
	require.NoError(t, err)
	defer cSlow.Close()

	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, 2, hub.ActiveClientCount())

	// Target slow client with rapid messages to saturate its 128-slot outbound buffer.
	// Since slow client never drains, it must be dropped as a slow consumer,
	// while responsive client Alpha remains connected and unblocked.
	for i := 0; i < 150; i++ {
		hub.SendToUser("runner_slow", []byte(`{"type":"targeted_flood"}`))
	}

	time.Sleep(50 * time.Millisecond)

	// Slow client should have been dropped, responsive client Alpha remains connected
	assert.Equal(t, 1, hub.ActiveClientCount(), "slow client must be dropped when outbound buffer is full")
}

func TestWebSocket_MaxConnectionsPerUser(t *testing.T) {
	_, _, wsURL := setupTestHub(t, ws.WithMaxConnsPerUser(3))

	// Connect 3 times as user_multi
	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=user_multi", nil)
	require.NoError(t, err)
	defer c1.Close()

	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=user_multi", nil)
	require.NoError(t, err)
	defer c2.Close()

	c3, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=user_multi", nil)
	require.NoError(t, err)
	defer c3.Close()

	time.Sleep(50 * time.Millisecond)

	// 4th connection attempt MUST be rejected with HTTP 429
	_, resp, err := websocket.DefaultDialer.Dial(wsURL+"?uid=user_multi", nil)
	assert.Error(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)
}

func TestWebSocketTargetedTerritoryCarvedAlert(t *testing.T) {
	hub, _, wsURL := setupTestHub(t)

	// Victim connects
	victimClient, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=victim_01", nil)
	require.NoError(t, err)
	defer victimClient.Close()

	time.Sleep(50 * time.Millisecond)

	// Attacker captures territory that slices into victim_01
	hub.BroadcastConquest("attacker_02", "ShadowRunner", 3500.0, []string{"victim_01"})

	// Victim must receive targeted territory alert
	_ = victimClient.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, msgBytes, err := victimClient.ReadMessage()
	require.NoError(t, err)

	var alert ws.TerritoryAlertMessage
	err = json.Unmarshal(msgBytes, &alert)
	require.NoError(t, err)

	assert.Equal(t, ws.TypeTerritoryUnderAttack, alert.Type)
	assert.Equal(t, "territory_under_attack", alert.Event)
	assert.Equal(t, "attacker_02", alert.AttackerID)
	assert.Equal(t, 3500.0, alert.AreaClaimedSqm)
	assert.Contains(t, alert.Message, "ShadowRunner")
	assert.Contains(t, alert.Message, "3500 m²")
}
