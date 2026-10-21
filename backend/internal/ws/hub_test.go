package ws_test

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
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
	// Configure test hub with a tiny outbound buffer (2 slots) so saturation is fast, deterministic,
	// and independent of host OS kernel TCP loopback buffer sizes.
	hub, _, wsURL := setupTestHub(t, ws.WithOutboundBufferSize(2))

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

	// Target slow client with rapid messages to saturate its 2-slot outbound buffer.
	// Since slow client never drains, it must be dropped as a slow consumer,
	// while responsive client Alpha remains connected and unblocked.
	for i := 0; i < 50; i++ {
		hub.SendToUser("runner_slow", map[string]string{"type": "flood"})
	}

	// Slow client should have been dropped, responsive client Alpha remains connected
	assert.Eventually(t, func() bool {
		return hub.ActiveClientCount() == 1
	}, 2*time.Second, 20*time.Millisecond, "slow client must be dropped when outbound buffer is full")
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

	// Attacker and victim are friends so victim receives attacker_id
	hub.SetFriendsCache("attacker_02", []string{"victim_01"})

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

func TestWebSocket_FriendsDeadlockOnCacheMiss(t *testing.T) {
	memStore := store.NewMemoryStore()
	ctx := context.Background()

	// 1. Create two users and make them friends in the store
	u1 := &store.User{ID: "usr_sender", Username: "Sender", Faction: "Cyber Vanguard"}
	u2 := &store.User{ID: "usr_receiver", Username: "Receiver", Faction: "Cyber Vanguard"}
	require.NoError(t, memStore.UpsertUser(ctx, u1))
	require.NoError(t, memStore.UpsertUser(ctx, u2))

	req, err := memStore.SendFriendRequest(ctx, u1.ID, u2.ID)
	require.NoError(t, err)
	_, err = memStore.RespondFriendRequest(ctx, req.ID, u2.ID, "accept")
	require.NoError(t, err)

	// 2. Setup Hub with store and NO pre-populated friend cache (empty cache)
	hub, _, wsURL := setupTestHub(t, ws.WithStore(memStore))
	hub.UpdateUserVisibility(u1.ID, "friends")

	// 3. Connect both users via WebSocket
	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u1.ID, nil)
	require.NoError(t, err)
	defer c1.Close()

	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u2.ID, nil)
	require.NoError(t, err)
	defer c2.Close()

	time.Sleep(50 * time.Millisecond)

	// 4. Send presence update from c1, expect c2 to receive it within 3s timeout
	done := make(chan error, 1)
	go func() {
		_ = c2.SetReadDeadline(time.Now().Add(3 * time.Second))
		_, msgBytes, err := c2.ReadMessage()
		if err != nil {
			done <- err
			return
		}
		var presence ws.PresenceMessage
		if err := json.Unmarshal(msgBytes, &presence); err != nil {
			done <- err
			return
		}
		done <- nil
	}()

	err = c1.WriteJSON(ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.501,
		Longitude: -0.121,
	})
	require.NoError(t, err)

	select {
	case err := <-done:
		require.NoError(t, err)
	case <-time.After(3 * time.Second):
		t.Fatal("DEADLOCK DETECTED: DispatchPresence froze on cache miss")
	}
}

func TestWebSocket_FriendsDelivery_AddAndRemoveFriendDynamics(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	u1 := &store.User{ID: "usr_dyn1", Username: "DynSender", Faction: "Cyber Vanguard"}
	u2 := &store.User{ID: "usr_dyn2", Username: "DynReceiver", Faction: "Cyber Vanguard"}
	require.NoError(t, memStore.UpsertUser(ctx, u1))
	require.NoError(t, memStore.UpsertUser(ctx, u2))

	hub, _, wsURL := setupTestHub(t, ws.WithStore(memStore), ws.WithPresenceDelay(0))
	hub.UpdateUserVisibility(u1.ID, "friends")

	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u1.ID, nil)
	require.NoError(t, err)
	defer c1.Close()

	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u2.ID, nil)
	require.NoError(t, err)
	defer c2.Close()

	time.Sleep(50 * time.Millisecond)

	received := make(chan ws.PresenceMessage, 10)
	go func() {
		for {
			_, msgBytes, err := c2.ReadMessage()
			if err != nil {
				return
			}
			var p ws.PresenceMessage
			if err := json.Unmarshal(msgBytes, &p); err == nil {
				received <- p
			}
		}
	}()

	// Step 1: Not friends initially -> c2 should NOT receive update
	hub.DispatchPresence(u1.ID, "DynSender", "Cyber Vanguard", 51.501, -0.121)

	select {
	case msg := <-received:
		t.Fatalf("unexpected presence received before friendship established: %+v", msg)
	case <-time.After(150 * time.Millisecond):
		// Expected: nothing received
	}

	// Step 2: Add friend -> delivery starts immediately without hub restart
	req, err := memStore.SendFriendRequest(ctx, u1.ID, u2.ID)
	require.NoError(t, err)
	f, err := memStore.RespondFriendRequest(ctx, req.ID, u2.ID, "accept")
	require.NoError(t, err)
	hub.InvalidateFriends(f.RequesterID, f.AddresseeID)

	hub.DispatchPresence(u1.ID, "DynSender", "Cyber Vanguard", 51.502, -0.122)

	select {
	case msg := <-received:
		assert.Equal(t, u1.ID, msg.UserID)
	case <-time.After(2 * time.Second):
		t.Fatal("expected presence after friend request accepted, timed out")
	}

	// Step 3: Remove friend -> delivery stops immediately
	require.NoError(t, memStore.RemoveFriend(ctx, u1.ID, u2.ID))
	hub.InvalidateFriends(u1.ID, u2.ID)

	hub.DispatchPresence(u1.ID, "DynSender", "Cyber Vanguard", 51.503, -0.123)

	select {
	case msg := <-received:
		t.Fatalf("unexpected presence received after friend removal: %+v", msg)
	case <-time.After(150 * time.Millisecond):
		// Expected: nothing received
	}
}

func TestWebSocket_FriendsDelivery_ConcurrentStress(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// Seed 10 users in memory
	for i := 0; i < 10; i++ {
		uid := fmt.Sprintf("stress_user_%d", i)
		_ = memStore.UpsertUser(ctx, &store.User{ID: uid, Username: uid, Faction: "Vanguard"})
	}

	// Make pairs mutual friends
	for i := 0; i < 9; i++ {
		req, err := memStore.SendFriendRequest(ctx, fmt.Sprintf("stress_user_%d", i), fmt.Sprintf("stress_user_%d", i+1))
		if err == nil {
			_, _ = memStore.RespondFriendRequest(ctx, req.ID, fmt.Sprintf("stress_user_%d", i+1), "accept")
		}
	}

	hub, _, _ := setupTestHub(t, ws.WithStore(memStore), ws.WithPresenceDelay(0))
	for i := 0; i < 10; i++ {
		hub.UpdateUserVisibility(fmt.Sprintf("stress_user_%d", i), "friends")
	}

	const workers = 16
	const iterations = 50
	var wg sync.WaitGroup
	wg.Add(workers)

	for w := 0; w < workers; w++ {
		go func(workerID int) {
			defer wg.Done()
			senderID := fmt.Sprintf("stress_user_%d", workerID%10)
			for j := 0; j < iterations; j++ {
				hub.DispatchPresence(senderID, senderID, "Vanguard", 51.500+float64(j)*0.0001, -0.120+float64(workerID)*0.0001)
				if j%10 == 0 {
					hub.InvalidateFriends(senderID)
				}
			}
		}(w)
	}

	wg.Wait()
}

func TestWebSocket_RunnerLeft_RespectsVisibilityOff(t *testing.T) {
	_, _, wsURL := setupTestHub(t)

	// Alpha connects with default visibility "off"
	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha_off", nil)
	require.NoError(t, err)

	// Beta connects and listens
	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta_listen", nil)
	require.NoError(t, err)
	defer c2.Close()

	time.Sleep(50 * time.Millisecond)

	// Alpha disconnects
	c1.Close()

	// Beta should NOT receive runner_left for an "off" user
	_ = c2.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, msg, err := c2.ReadMessage()
	assert.Error(t, err, "expected no runner_left delivered when leaving user visibility is off, but got: %s", string(msg))
}

func TestWebSocket_RunnerLeft_OnlyDeliveredToEligibleRecipients(t *testing.T) {
	memStore := store.NewMemoryStore()
	ctx := context.Background()

	u1 := &store.User{ID: "usr_alice", Username: "Alice", Faction: "Vanguard"}
	u2 := &store.User{ID: "usr_bob", Username: "Bob", Faction: "Vanguard"}
	u3 := &store.User{ID: "usr_stranger", Username: "Stranger", Faction: "Vanguard"}
	require.NoError(t, memStore.UpsertUser(ctx, u1))
	require.NoError(t, memStore.UpsertUser(ctx, u2))
	require.NoError(t, memStore.UpsertUser(ctx, u3))

	// Alice and Bob are friends; Stranger is not
	req, err := memStore.SendFriendRequest(ctx, u1.ID, u2.ID)
	require.NoError(t, err)
	_, err = memStore.RespondFriendRequest(ctx, req.ID, u2.ID, "accept")
	require.NoError(t, err)

	hub, _, wsURL := setupTestHub(t, ws.WithStore(memStore))
	hub.UpdateUserVisibility(u1.ID, "friends")

	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u1.ID, nil)
	require.NoError(t, err)
	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u2.ID, nil)
	require.NoError(t, err)
	defer c2.Close()
	c3, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+u3.ID, nil)
	require.NoError(t, err)
	defer c3.Close()

	time.Sleep(50 * time.Millisecond)

	// Alice leaves
	c1.Close()

	// Bob (friend) should receive runner_left
	_ = c2.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, bMsg, err := c2.ReadMessage()
	require.NoError(t, err, "friend should receive runner_left")
	var leftMsg ws.RunnerLeftMessage
	err = json.Unmarshal(bMsg, &leftMsg)
	require.NoError(t, err)
	assert.Equal(t, ws.TypeRunnerLeft, leftMsg.Type)
	assert.Equal(t, u1.ID, leftMsg.UserID)

	// Stranger should NOT receive runner_left
	_ = c3.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, sMsg, err := c3.ReadMessage()
	assert.Error(t, err, "stranger should not receive runner_left, but got: %s", string(sMsg))
}

func TestWebSocket_ConquestBroadcast_OnlyVictimsAndFriends(t *testing.T) {
	memStore := store.NewMemoryStore()
	ctx := context.Background()

	attacker := &store.User{ID: "atk_01", Username: "Attacker", Faction: "Vanguard"}
	victim := &store.User{ID: "vic_01", Username: "Victim", Faction: "Vanguard"}
	friend := &store.User{ID: "fri_01", Username: "Friend", Faction: "Vanguard"}
	stranger := &store.User{ID: "str_01", Username: "Stranger", Faction: "Vanguard"}
	require.NoError(t, memStore.UpsertUser(ctx, attacker))
	require.NoError(t, memStore.UpsertUser(ctx, victim))
	require.NoError(t, memStore.UpsertUser(ctx, friend))
	require.NoError(t, memStore.UpsertUser(ctx, stranger))

	// Attacker and Friend are mutual friends
	req, err := memStore.SendFriendRequest(ctx, attacker.ID, friend.ID)
	require.NoError(t, err)
	_, err = memStore.RespondFriendRequest(ctx, req.ID, friend.ID, "accept")
	require.NoError(t, err)

	hub, _, wsURL := setupTestHub(t, ws.WithStore(memStore))

	cVictim, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+victim.ID, nil)
	require.NoError(t, err)
	defer cVictim.Close()

	cFriend, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+friend.ID, nil)
	require.NoError(t, err)
	defer cFriend.Close()

	cStranger, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid="+stranger.ID, nil)
	require.NoError(t, err)
	defer cStranger.Close()

	time.Sleep(50 * time.Millisecond)

	// Attacker conquers territory claiming from victim
	hub.BroadcastConquest(attacker.ID, attacker.Username, 1500.0, []string{victim.ID})

	// 1. Friend should receive conquest announcement with AttackerID included
	_ = cFriend.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, friBytes, err := cFriend.ReadMessage()
	require.NoError(t, err)
	var friMsg ws.ConquestBroadcastMessage
	require.NoError(t, json.Unmarshal(friBytes, &friMsg))
	assert.Equal(t, attacker.ID, friMsg.AttackerID, "friend must see attacker ID")

	// 2. Victim should receive targeted alert; since victim is non-friend, attacker_id should NOT be exposed
	_ = cVictim.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	_, vicBytes, err := cVictim.ReadMessage()
	require.NoError(t, err)
	var vicAlert ws.TerritoryAlertMessage
	require.NoError(t, json.Unmarshal(vicBytes, &vicAlert))
	assert.Empty(t, vicAlert.AttackerID, "non-friend victim must not receive attacker_id")

	// 3. Stranger should receive NOTHING (not a victim, not a friend)
	_ = cStranger.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	_, strBytes, err := cStranger.ReadMessage()
	assert.Error(t, err, "stranger should not receive conquest event, but received: %s", string(strBytes))
}

