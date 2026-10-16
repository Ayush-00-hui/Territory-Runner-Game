package ws

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Permissive CORS for mobile clients & emulators
		return true
	},
}

// Hub manages active WebSocket runner connections and fans out live broadcasts.
type Hub struct {
	clients     map[*Client]bool
	userClients map[string]map[*Client]bool
	broadcast   chan []byte
	register    chan *Client
	unregister  chan *Client
	mu          sync.RWMutex
	logger      *slog.Logger
	stop        chan struct{}
}

// NewHub initializes a new real-time WebSocket hub.
func NewHub(logger *slog.Logger) *Hub {
	if logger == nil {
		logger = slog.Default()
	}
	return &Hub{
		clients:     make(map[*Client]bool),
		userClients: make(map[string]map[*Client]bool),
		broadcast:   make(chan []byte, 256),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		logger:      logger,
		stop:        make(chan struct{}),
	}
}

// Run executes the central event coordination loop.
func (h *Hub) Run() {
	for {
		select {
		case <-h.stop:
			h.mu.Lock()
			for client := range h.clients {
				close(client.send)
				delete(h.clients, client)
			}
			h.mu.Unlock()
			return

		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			if _, exists := h.userClients[client.userID]; !exists {
				h.userClients[client.userID] = make(map[*Client]bool)
			}
			h.userClients[client.userID][client] = true
			h.mu.Unlock()
			h.logger.Debug("client connected to ws hub", "user_id", client.userID, "total_clients", len(h.clients))

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)

				if userMap, exists := h.userClients[client.userID]; exists {
					delete(userMap, client)
					if len(userMap) == 0 {
						delete(h.userClients, client.userID)
					}
				}
				h.mu.Unlock()

				// Inform peers that this runner left
				leftMsg, _ := json.Marshal(RunnerLeftMessage{
					Type:   TypeRunnerLeft,
					UserID: client.userID,
				})
				h.Broadcast(leftMsg)
				h.logger.Debug("client disconnected from ws hub", "user_id", client.userID)
			} else {
				h.mu.Unlock()
			}

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// Broadcast queues a raw byte slice message to all connected clients.
func (h *Hub) Broadcast(msg []byte) {
	select {
	case h.broadcast <- msg:
	default:
		h.logger.Warn("ws broadcast buffer full; dropped message")
	}
}

// BroadcastJSON serializes an object to JSON and fans out to all connected runners.
func (h *Hub) BroadcastJSON(v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		h.logger.Error("failed to serialize ws broadcast", "error", err)
		return
	}
	h.Broadcast(data)
}

// SendToUser dispatches a targeted message to all active sessions of a specific user.
func (h *Hub) SendToUser(userID string, v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		h.logger.Error("failed to marshal user alert", "error", err)
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	userMap, exists := h.userClients[userID]
	if !exists || len(userMap) == 0 {
		return
	}

	for client := range userMap {
		select {
		case client.send <- data:
		default:
			h.logger.Warn("user client buffer full; dropped alert", "user_id", userID)
		}
	}
}

// BroadcastConquest broadcasts both targeted victim alerts and general milestone notifications.
func (h *Hub) BroadcastConquest(attackerID, attackerName string, areaClaimed float64, victimUserIDs []string) {
	nowStr := time.Now().UTC().Format(time.RFC3339)

	// 1. Send targeted high-priority tactical warning to each victim
	for _, victimID := range victimUserIDs {
		if victimID == attackerID || victimID == "" {
			continue
		}
		alert := TerritoryAlertMessage{
			Type:           TypeTerritoryUnderAttack,
			Event:          "territory_under_attack",
			AttackerID:     attackerID,
			AttackerName:   attackerName,
			AreaClaimedSqm: areaClaimed,
			VictimUserID:   victimID,
			Message:        fmt.Sprintf("⚠️ ALERT: Territory under attack! Rival %s captured %.0f m²!", attackerName, areaClaimed),
			Timestamp:      nowStr,
		}
		h.SendToUser(victimID, alert)
	}

	// 2. Broadcast newsfeed conquest event to all active runners
	broadcastMsg := ConquestBroadcastMessage{
		Type:           TypeConquestBroadcast,
		Event:          "territory_claimed",
		AttackerID:     attackerID,
		AttackerName:   attackerName,
		AreaClaimedSqm: areaClaimed,
		Message:        fmt.Sprintf("%s conquered %.0f m² of territory!", attackerName, areaClaimed),
		Timestamp:      nowStr,
	}
	h.BroadcastJSON(broadcastMsg)
}

// ActiveClientCount returns the number of currently connected WebSocket runners.
func (h *Hub) ActiveClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// Stop gracefully shuts down the hub.
func (h *Hub) Stop() {
	close(h.stop)
}

// ServeWS upgrades the HTTP connection to a full-duplex WebSocket session.
func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request, userID, username, faction string) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.logger.Error("failed to upgrade websocket connection", "error", err)
		return
	}

	client := &Client{
		hub:      h,
		conn:     conn,
		send:     make(chan []byte, 128),
		userID:   userID,
		username: username,
		faction:  faction,
		logger:   h.logger,
	}

	h.register <- client

	go client.writePump()
	go client.readPump()
}
