package ws

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/gorilla/websocket"
)

// Option configures Hub parameters.
type Option func(*Hub)

// WithAllowedOrigins configures origin validation for WebSocket handshakes.
func WithAllowedOrigins(allowedOrigins []string) Option {
	return func(h *Hub) {
		h.upgrader.CheckOrigin = func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			if origin == "" {
				return true
			}
			for _, allowed := range allowedOrigins {
				if allowed == "*" || allowed == origin {
					return true
				}
			}
			return false
		}
	}
}

// WithStore sets the backing store for fetching friend relationships and settings.
func WithStore(s store.Store) Option {
	return func(h *Hub) {
		h.store = s
	}
}

// WithPresenceDelay configures the delay applied before delivering coarsened presence updates.
func WithPresenceDelay(d time.Duration) Option {
	return func(h *Hub) {
		h.presenceDelay = d
	}
}

// WithMaxConnsPerUser sets the maximum allowed concurrent WebSocket sessions per user.
func WithMaxConnsPerUser(max int) Option {
	return func(h *Hub) {
		if max > 0 {
			h.maxConnsPerUser = max
		}
	}
}

// WithOutboundBufferSize sets the per-client outbound channel buffer size.
func WithOutboundBufferSize(size int) Option {
	return func(h *Hub) {
		if size > 0 {
			h.outboundBufferSize = size
		}
	}
}

// Hub manages active WebSocket runner connections and fans out targeted real-time updates.
type Hub struct {
	clients          map[*Client]bool
	userClients      map[string]map[*Client]bool
	userPrivacyZones map[string][]geo.PrivacyZoneEvaluator
	userVisibility   map[string]string // "off" | "friends" | "nearby"
	friendsCache     map[string]map[string]bool
	broadcast        chan []byte
	register         chan *Client
	unregister       chan *Client
	mu               sync.RWMutex
	logger           *slog.Logger
	stop             chan struct{}
	upgrader         websocket.Upgrader
	store            store.Store
	presenceDelay    time.Duration
	maxConnsPerUser  int
	outboundBufferSize int
}

// NewHub initializes a new real-time WebSocket hub.
func NewHub(logger *slog.Logger, opts ...Option) *Hub {
	if logger == nil {
		logger = slog.Default()
	}
	h := &Hub{
		clients:          make(map[*Client]bool),
		userClients:      make(map[string]map[*Client]bool),
		userPrivacyZones: make(map[string][]geo.PrivacyZoneEvaluator),
		userVisibility:   make(map[string]string),
		friendsCache:     make(map[string]map[string]bool),
		broadcast:        make(chan []byte, 256),
		register:         make(chan *Client),
		unregister:       make(chan *Client),
		logger:           logger,
		stop:             make(chan struct{}),
		presenceDelay:    5 * time.Second, // Default 5s privacy delay
		maxConnsPerUser:  3,               // Max 3 connections per user
		outboundBufferSize: 128,           // Default 128-slot outbound buffer per client
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			Subprotocols:    []string{"bearer"},
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}
	for _, opt := range opts {
		opt(h)
	}
	return h
}

// Run executes the central event coordination loop.
func (h *Hub) Run() {
	for {
		select {
		case <-h.stop:
			h.mu.Lock()
			for client := range h.clients {
				client.Close()
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
				client.Close()

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
			clientsSnapshot := make([]*Client, 0, len(h.clients))
			for client := range h.clients {
				clientsSnapshot = append(clientsSnapshot, client)
			}
			h.mu.RUnlock()

			for _, client := range clientsSnapshot {
				h.deliverToClient(client, message)
			}
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
	userMap, exists := h.userClients[userID]
	if !exists || len(userMap) == 0 {
		h.mu.RUnlock()
		return
	}
	targetClients := make([]*Client, 0, len(userMap))
	for client := range userMap {
		targetClients = append(targetClients, client)
	}
	h.mu.RUnlock()

	for _, client := range targetClients {
		h.deliverToClient(client, data)
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

	// 2. Broadcast conquest event to all active runners
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

// UpdateUserPrivacyZones caches or updates active privacy zones for a runner.
func (h *Hub) UpdateUserPrivacyZones(userID string, zones []geo.PrivacyZoneEvaluator) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(zones) == 0 {
		delete(h.userPrivacyZones, userID)
		return
	}
	h.userPrivacyZones[userID] = zones
}

// IsPointInUserPrivacyZone evaluates whether (lat, lng) lies inside any of the user's active privacy zones.
func (h *Hub) IsPointInUserPrivacyZone(userID string, lat, lng float64) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	zones, exists := h.userPrivacyZones[userID]
	if !exists || len(zones) == 0 {
		return false
	}
	return geo.IsPointInAnyZone(lat, lng, zones)
}

// UpdateUserVisibility updates cached presence visibility for a runner ("off" | "friends" | "nearby").
func (h *Hub) UpdateUserVisibility(userID, visibility string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if visibility == "" {
		visibility = "off"
	}
	h.userVisibility[userID] = visibility
}

// GetUserVisibility returns the current presence visibility for a user, defaulting to "off".
func (h *Hub) GetUserVisibility(userID string) string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	if vis, ok := h.userVisibility[userID]; ok && vis != "" {
		return vis
	}
	return "off"
}

// SetFriendsCache sets the mutual friends list for a user (used in testing or synced from store).
func (h *Hub) SetFriendsCache(userID string, friendIDs []string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	m := make(map[string]bool, len(friendIDs))
	for _, id := range friendIDs {
		m[id] = true
	}
	h.friendsCache[userID] = m
}

// areUsersFriends checks if userA and userB are mutual friends.
func (h *Hub) areUsersFriends(userA, userB string) bool {
	h.mu.RLock()
	if cache, ok := h.friendsCache[userA]; ok {
		isFriend := cache[userB]
		h.mu.RUnlock()
		return isFriend
	}
	h.mu.RUnlock()

	if h.store != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		friends, err := h.store.GetFriends(ctx, userA)
		if err == nil {
			friendMap := make(map[string]bool, len(friends))
			for _, f := range friends {
				friendMap[f.ID] = true
			}
			h.mu.Lock()
			h.friendsCache[userA] = friendMap
			h.mu.Unlock()
			return friendMap[userB]
		}
	}
	return false
}

// DispatchPresence processes inbound presence with consent enforcement, coordinate coarsening,
// spatial cell / friends targeting, privacy zone suppression, and delivery delay.
func (h *Hub) DispatchPresence(senderID, username, faction string, rawLat, rawLng float64) {
	// 1. Check sender's privacy zone (defense-in-depth)
	if h.IsPointInUserPrivacyZone(senderID, rawLat, rawLng) {
		h.logger.Debug("presence suppressed: coordinate inside sender privacy zone", "user_id", senderID)
		return
	}

	// 2. Check sender's live_visibility setting (defaults to "off")
	visibility := h.GetUserVisibility(senderID)
	if visibility == "off" || visibility == "" {
		// "off" sends nothing to anyone
		return
	}

	// 3. Coarsen coordinates: snap to ~25 m spatial grid and strip heading/speed
	coarsenedLat, coarsenedLng := geo.SnapToGrid(rawLat, rawLng, 25.0)

	// 4. Select candidate recipients based on visibility mode
	h.mu.RLock()
	var candidateRecipients []*Client

	if visibility == "friends" {
		for client := range h.clients {
			if client.userID == senderID {
				continue
			}
			if h.areUsersFriends(senderID, client.userID) {
				candidateRecipients = append(candidateRecipients, client)
			}
		}
	} else if visibility == "nearby" {
		cell := geo.GeohashPrecision6(coarsenedLat, coarsenedLng)
		neighbors := geo.GeohashNeighbors(cell)
		allCells := append(neighbors, cell)

		for client := range h.clients {
			if client.userID == senderID {
				continue
			}
			if client.HasSubscribedCell(allCells) {
				candidateRecipients = append(candidateRecipients, client)
			}
		}
	}
	h.mu.RUnlock()

	// 5. Filter delivery path: check both sender's and recipient's privacy zones
	var filteredRecipients []*Client
	for _, client := range candidateRecipients {
		// Recipient privacy zone check
		if h.IsPointInUserPrivacyZone(client.userID, coarsenedLat, coarsenedLng) {
			continue
		}
		// Sender privacy zone check on coarsened coordinates
		if h.IsPointInUserPrivacyZone(senderID, coarsenedLat, coarsenedLng) {
			continue
		}
		filteredRecipients = append(filteredRecipients, client)
	}

	// 6. Cap recipients per update (at most 200)
	if len(filteredRecipients) > 200 {
		filteredRecipients = filteredRecipients[:200]
	}

	if len(filteredRecipients) == 0 {
		return
	}

	// 7. Construct coarsened presence payload (no speed, no heading)
	presence := PresenceMessage{
		Type:      TypeRunnerPresence,
		UserID:    senderID,
		Username:  username,
		Faction:   faction,
		Latitude:  coarsenedLat,
		Longitude: coarsenedLng,
		UpdatedAt: time.Now().UTC().Format(time.RFC3339),
	}
	data, err := json.Marshal(presence)
	if err != nil {
		h.logger.Error("failed to serialize targeted presence message", "error", err)
		return
	}

	// 8. Deliver after short privacy delay (default 5 s)
	deliver := func() {
		for _, client := range filteredRecipients {
			h.deliverToClient(client, data)
		}
	}

	if h.presenceDelay <= 0 {
		deliver()
	} else {
		time.AfterFunc(h.presenceDelay, deliver)
	}
}

// deliverToClient sends a message to a client or drops slow consumers without blocking others.
func (h *Hub) deliverToClient(client *Client, data []byte) {
	if client.IsClosed() {
		return
	}

	if !client.TrySend(data) {
		if !client.IsClosed() {
			// Slow consumer: client's outbound channel is full. Drop client without blocking others.
			h.logger.Warn("slow consumer detected; dropping client", "user_id", client.userID)
			h.dropSlowClient(client)
		}
	}
}

// dropSlowClient terminates and removes a slow client from active maps.
func (h *Hub) dropSlowClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.clients[client]; ok {
		delete(h.clients, client)
		client.Close()

		if userMap, exists := h.userClients[client.userID]; exists {
			delete(userMap, client)
			if len(userMap) == 0 {
				delete(h.userClients, client.userID)
			}
		}
	}
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

// ServeWS upgrades the HTTP connection to a full-duplex WebSocket session with connection capping.
func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request, userID, username, faction string) {
	// Enforce maximum concurrent connections per user (max 3)
	h.mu.RLock()
	conns := len(h.userClients[userID])
	h.mu.RUnlock()

	if conns >= h.maxConnsPerUser {
		h.logger.Warn("max concurrent websocket connections exceeded", "user_id", userID, "count", conns)
		http.Error(w, `{"error":"too_many_connections","detail":"maximum concurrent websocket connections exceeded"}`, http.StatusTooManyRequests)
		return
	}

	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.logger.Error("failed to upgrade websocket connection", "error", err)
		return
	}

	bufSize := h.outboundBufferSize
	if bufSize <= 0 {
		bufSize = 128
	}

	client := &Client{
		hub:             h,
		conn:            conn,
		send:            make(chan []byte, bufSize),
		userID:          userID,
		username:        username,
		faction:         faction,
		logger:          h.logger,
		subscribedCells: make(map[string]bool),
	}

	h.register <- client

	go client.writePump()
	go client.readPump()
}
