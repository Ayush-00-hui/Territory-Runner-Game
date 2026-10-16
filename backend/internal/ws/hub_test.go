package ws_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestWebSocketHubPresenceAndBroadcast(t *testing.T) {
	hub := ws.NewHub(nil)
	go hub.Run()
	defer hub.Stop()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := r.URL.Query().Get("uid")
		hub.ServeWS(w, r, uid, "Runner_"+uid, "Cyber Vanguard")
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	// Connect Client 1 (Runner Alpha)
	c1, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_alpha", nil)
	require.NoError(t, err)
	defer c1.Close()

	// Connect Client 2 (Runner Beta)
	c2, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=runner_beta", nil)
	require.NoError(t, err)
	defer c2.Close()

	time.Sleep(50 * time.Millisecond)
	assert.Equal(t, 2, hub.ActiveClientCount())

	// Runner Alpha sends presence update
	presenceUpdate := ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.501,
		Longitude: -0.121,
		Speed:     3.2,
		Heading:   90.0,
	}
	err = c1.WriteJSON(presenceUpdate)
	require.NoError(t, err)

	// Runner Beta should receive Runner Alpha's presence broadcast
	_ = c2.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, msgBytes, err := c2.ReadMessage()
	require.NoError(t, err)

	var presence ws.PresenceMessage
	err = json.Unmarshal(msgBytes, &presence)
	require.NoError(t, err)
	assert.Equal(t, ws.TypeRunnerPresence, presence.Type)
	assert.Equal(t, "runner_alpha", presence.UserID)
	assert.Equal(t, 51.501, presence.Latitude)
}

func TestWebSocketTargetedTerritoryCarvedAlert(t *testing.T) {
	hub := ws.NewHub(nil)
	go hub.Run()
	defer hub.Stop()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := r.URL.Query().Get("uid")
		hub.ServeWS(w, r, uid, "Runner_"+uid, "Cyber Vanguard")
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	// Victim connects
	victimClient, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=victim_01", nil)
	require.NoError(t, err)
	defer victimClient.Close()

	time.Sleep(50 * time.Millisecond)

	// Attacker captures territory that slices into victim_01
	hub.BroadcastConquest("attacker_02", "ShadowRunner", 3500.0, []string{"victim_01"})

	// Victim must receive targeted territory alert
	_ = victimClient.SetReadDeadline(time.Now().Add(2 * time.Second))
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
