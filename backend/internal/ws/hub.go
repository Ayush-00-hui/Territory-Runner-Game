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
	"golang.org/x/sync/singleflight"
)

// Option configures Hub parameters.
type Option func(*Hub)

// DefaultFriendsCacheTTL defines the cache duration for user friend sets (PROPOSED: 60s).
const DefaultFriendsCacheTTL = 60 * time.Second

// DefaultRecentRecipientsTTL defines the TTL for tracking recent presence recipients (PROPOSED: 60s).
const DefaultRecentRecipientsTTL = 60 * time.Second

// WithFriendsCacheTTL sets the TTL for cached friendships.
func WithFriendsCacheTTL(ttl time.Duration) Option {
	return func(h *Hub) {
		if ttl > 0 {
			h.friendsCacheTTL = ttl
		}
	}
}

// WithRecentRecipientsTTL sets the TTL for tracking recent presence recipients.
func WithRecentRecipientsTTL(ttl time.Duration) Option {
	return func(h *Hub) {
		if ttl > 0 {
			h.recentRecipientsTTL = ttl
		}
	}
}

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

type friendsCacheEntry struct {
	friends   map[string]bool
	expiresAt time.Time
}

// Hub manages active WebSocket runner connections and fans out targeted real-time updates.
type Hub struct {
	clients             map[*Client]bool
	userClients         map[string]map[*Client]bool
	userPrivacyZones    map[string][]geo.PrivacyZoneEvaluator
	userVisibility      map[string]string // "off" | "friends" | "nearby"
	friendsCache        map[string]*friendsCacheEntry
	friendsMu           sync.RWMutex
	friendsSF           singleflight.Group
	friendsCacheTTL     time.Duration
	recentRecipients    map[string]map[string]time.Time // senderID -> recipientUserID -> expiresAt
	recentRecipientsMu  sync.RWMutex
	recentRecipientsTTL time.Duration
	broadcast           chan []byte
	register            chan *Client
	unregister          chan *Client
	mu                  sync.RWMutex
	logger              *slog.Logger
	stop                chan struct{}
	upgrader            websocket.Upgrader
	store               store.Store
	presenceDelay       time.Duration
	maxConnsPerUser     int
	outboundBufferSize  int
}

// NewHub initializes a new real-time WebSocket hub.
func NewHub(logger *slog.Logger, opts ...Option) *Hub {
	if logger == nil {
		logger = slog.Default()
	}
	h := &Hub{
		clients:             make(map[*Client]bool),
		userClients:         make(map[string]map[*Client]bool),
		userPrivacyZones:   make(map[string][]geo.PrivacyZoneEvaluator),
		userVisibility:     make(map[string]string),
		friendsCache:       make(map[string]*friendsCacheEntry),
		friendsCacheTTL:    DefaultFriendsCacheTTL,
		recentRecipients:    make(map[string]map[string]time.Time),
		recentRecipientsTTL: DefaultRecentRecipientsTTL,
		broadcast:          make(chan []byte, 256),
		register:           make(chan *Client),
		unregister:         make(chan *Client),
		logger:             logger,
		stop:               make(chan struct{}),
		presenceDelay:      5 * time.Second, // Default 5s privacy delay
		maxConnsPerUser:    3,               // Max 3 connections per user
		outboundBufferSize: 128,             // Default 128-slot outbound buffer per client
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
			totalClients := len(h.clients)
			h.mu.Unlock()
			h.logger.Debug("client connected to ws hub", "user_id", client.userID, "total_clients", totalClients)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				client.Close()

				completelyLeft := false
				if userMap, exists := h.userClients[client.userID]; exists {
					delete(userMap, client)
					if len(userMap) == 0 {
						delete(h.userClients, client.userID)
						completelyLeft = true
					}
				}
				h.mu.Unlock()

				if completelyLeft {
					h.dispatchRunnerLeft(client.userID)
				}
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

// BroadcastConquest broadcasts targeted victim alerts and conquest announcements
// to victims and the attacker's friends only (never global).
// AttackerID is never included in anything sent to non-friends.
func (h *Hub) BroadcastConquest(attackerID, attackerName string, areaClaimed float64, victimUserIDs []string) {
	nowStr := time.Now().UTC().Format(time.RFC3339)

	// Resolve attacker's friends once
	attackerFriends := h.getSenderFriends(attackerID)

	victimSet := make(map[string]bool)
	for _, vid := range victimUserIDs {
		if vid != "" && vid != attackerID {
			victimSet[vid] = true
		}
	}

	// 1. Send targeted high-priority tactical warning to each victim
	for victimID := range victimSet {
		isFriend := attackerFriends != nil && attackerFriends[victimID]
		reportedAttackerID := ""
		if isFriend {
			reportedAttackerID = attackerID
		}

		alert := TerritoryAlertMessage{
			Type:           TypeTerritoryUnderAttack,
			Event:          "territory_under_attack",
			AttackerID:     reportedAttackerID,
			AttackerName:   attackerName,
			AreaClaimedSqm: areaClaimed,
			VictimUserID:   victimID,
			Message:        fmt.Sprintf("⚠️ ALERT: Territory under attack! Rival %s captured %.0f m²!", attackerName, areaClaimed),
			Timestamp:      nowStr,
		}
		h.SendToUser(victimID, alert)
	}

	// 2. Deliver conquest event to attacker's friends only (with AttackerID)
	if attackerFriends != nil {
		friendMsg := ConquestBroadcastMessage{
			Type:           TypeConquestBroadcast,
			Event:          "territory_claimed",
			AttackerID:     attackerID,
			AttackerName:   attackerName,
			AreaClaimedSqm: areaClaimed,
			Message:        fmt.Sprintf("%s conquered %.0f m² of territory!", attackerName, areaClaimed),
			Timestamp:      nowStr,
		}

		for friendID := range attackerFriends {
			// If friend was also a victim, they already received TerritoryAlertMessage
			if !victimSet[friendID] && friendID != attackerID {
				h.SendToUser(friendID, friendMsg)
			}
		}
	}
}

// recordRecentRecipients logs recipients who received presence from senderID with TTL.
func (h *Hub) recordRecentRecipients(senderID string, recipientUserIDs []string) {
	if len(recipientUserIDs) == 0 {
		return
	}
	h.recentRecipientsMu.Lock()
	defer h.recentRecipientsMu.Unlock()

	recips, exists := h.recentRecipients[senderID]
	if !exists {
		recips = make(map[string]time.Time)
		h.recentRecipients[senderID] = recips
	}
	expiry := time.Now().Add(h.recentRecipientsTTL)
	for _, rid := range recipientUserIDs {
		if rid != senderID && rid != "" {
			recips[rid] = expiry
		}
	}
}

// getRecentRecipients returns currently unexpired recipients for a given sender.
func (h *Hub) getRecentRecipients(senderID string) map[string]bool {
	h.recentRecipientsMu.Lock()
	defer h.recentRecipientsMu.Unlock()

	recips, exists := h.recentRecipients[senderID]
	if !exists {
		return nil
	}
	now := time.Now()
	res := make(map[string]bool)
	for uid, expiry := range recips {
		if now.Before(expiry) {
			res[uid] = true
		} else {
			delete(recips, uid)
		}
	}
	if len(recips) == 0 {
		delete(h.recentRecipients, senderID)
	}
	return res
}

// dispatchRunnerLeft sends runner_left only to recipients who could have seen that runner
// (friends or recent presence recipients/cell subscribers) and never when visibility is "off".
func (h *Hub) dispatchRunnerLeft(userID string) {
	visibility := h.GetUserVisibility(userID)
	if visibility == "off" || visibility == "" {
		return
	}

	eligibleUserIDs := make(map[string]bool)
	if visibility == "friends" {
		friends := h.getSenderFriends(userID)
		for fID := range friends {
			eligibleUserIDs[fID] = true
		}
	} else if visibility == "nearby" {
		recents := h.getRecentRecipients(userID)
		for rID := range recents {
			eligibleUserIDs[rID] = true
		}
		friends := h.getSenderFriends(userID)
		for fID := range friends {
			eligibleUserIDs[fID] = true
		}
	}

	if len(eligibleUserIDs) == 0 {
		return
	}

	leftMsg, err := json.Marshal(RunnerLeftMessage{
		Type:   TypeRunnerLeft,
		UserID: userID,
	})
	if err != nil {
		h.logger.Error("failed to serialize runner_left message", "error", err)
		return
	}

	h.mu.RLock()
	var targetClients []*Client
	for targetUID := range eligibleUserIDs {
		if targetUID == userID {
			continue
		}
		if clients, ok := h.userClients[targetUID]; ok {
			for c := range clients {
				targetClients = append(targetClients, c)
			}
		}
	}
	h.mu.RUnlock()

	for _, c := range targetClients {
		h.deliverToClient(c, leftMsg)
	}
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

// InvalidateFriends removes cached friend sets for the specified users.
// If no user IDs are passed, it clears the entire friends cache.
func (h *Hub) InvalidateFriends(userIDs ...string) {
	h.friendsMu.Lock()
	defer h.friendsMu.Unlock()
	if len(userIDs) == 0 {
		h.friendsCache = make(map[string]*friendsCacheEntry)
		return
	}
	for _, id := range userIDs {
		delete(h.friendsCache, id)
		h.friendsSF.Forget(id)
	}
}

// SetFriendsCache sets the mutual friends list for a user (used in testing or explicit synchronization).
func (h *Hub) SetFriendsCache(userID string, friendIDs []string) {
	h.friendsMu.Lock()
	defer h.friendsMu.Unlock()
	m := make(map[string]bool, len(friendIDs))
	for _, id := range friendIDs {
		m[id] = true
	}
	h.friendsCache[userID] = &friendsCacheEntry{
		friends:   m,
		expiresAt: time.Now().Add(h.friendsCacheTTL),
	}
}

// getSenderFriends returns the friend ID set for the given user, resolving from cache or store.
func (h *Hub) getSenderFriends(userID string) map[string]bool {
	h.friendsMu.RLock()
	entry, ok := h.friendsCache[userID]
	if ok && time.Now().Before(entry.expiresAt) {
		res := entry.friends
		h.friendsMu.RUnlock()
		return res
	}
	h.friendsMu.RUnlock()

	if h.store == nil {
		return nil
	}

	v, err, _ := h.friendsSF.Do(userID, func() (interface{}, error) {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		friends, err := h.store.GetFriends(ctx, userID)
		if err != nil {
			return nil, err
		}
		friendMap := make(map[string]bool, len(friends))
		for _, f := range friends {
			friendMap[f.ID] = true
		}
		h.friendsMu.Lock()
		h.friendsCache[userID] = &friendsCacheEntry{
			friends:   friendMap,
			expiresAt: time.Now().Add(h.friendsCacheTTL),
		}
		h.friendsMu.Unlock()
		return friendMap, nil
	})
	if err != nil || v == nil {
		return nil
	}
	return v.(map[string]bool)
}

// areUsersFriends checks if userA and userB are mutual friends.
func (h *Hub) areUsersFriends(userA, userB string) bool {
	friends := h.getSenderFriends(userA)
	if friends == nil {
		return false
	}
	return friends[userB]
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

	// 4. Select candidate recipients based on visibility mode:
	// Snapshot clients under RLock and release it BEFORE friendship resolution or store I/O.
	h.mu.RLock()
	clientSnapshots := make([]*Client, 0, len(h.clients))
	for client := range h.clients {
		if client.userID != senderID {
			clientSnapshots = append(clientSnapshots, client)
		}
	}
	h.mu.RUnlock()

	var candidateRecipients []*Client

	if visibility == "friends" {
		// Resolve the sender's friend set ONCE per dispatch (not per client).
		friends := h.getSenderFriends(senderID)
		if len(friends) > 0 {
			for _, client := range clientSnapshots {
				if friends[client.userID] {
					candidateRecipients = append(candidateRecipients, client)
				}
			}
		}
	} else if visibility == "nearby" {
		cell := geo.GeohashPrecision6(coarsenedLat, coarsenedLng)
		neighbors := geo.GeohashNeighbors(cell)
		allCells := append(neighbors, cell)

		for _, client := range clientSnapshots {
			if client.HasSubscribedCell(allCells) {
				candidateRecipients = append(candidateRecipients, client)
			}
		}
	}

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

	// Record recent recipients for targeted runner_left delivery
	recipIDs := make([]string, 0, len(filteredRecipients))
	for _, client := range filteredRecipients {
		recipIDs = append(recipIDs, client.userID)
	}
	h.recordRecentRecipients(senderID, recipIDs)

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
