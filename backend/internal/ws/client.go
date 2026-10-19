package ws

import (
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096
)

// Client represents a single active WebSocket session.
type Client struct {
	hub             *Hub
	conn            *websocket.Conn
	send            chan []byte
	userID          string
	username        string
	faction         string
	logger          *slog.Logger
	subscribedCells map[string]bool
	lastPresence    time.Time
	mu              sync.RWMutex
}

// HasSubscribedCell checks if this client is subscribed to any of the candidate cells.
func (c *Client) HasSubscribedCell(cells []string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if len(c.subscribedCells) == 0 {
		return false
	}
	for _, cell := range cells {
		if c.subscribedCells[cell] {
			return true
		}
	}
	return false
}

// readPump pumps inbound messages from the websocket connection to the hub.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		_ = c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				c.logger.Warn("websocket read error", "error", err, "user_id", c.userID)
			}
			break
		}

		var inbound InboundMessage
		if err := json.Unmarshal(message, &inbound); err != nil {
			c.logger.Debug("malformed inbound ws payload", "error", err)
			continue
		}

		switch inbound.Type {
		case TypeHeartbeat:
			// Refresh read deadline
			_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))

		case TypeViewportSubscribe:
			c.mu.Lock()
			c.subscribedCells = make(map[string]bool, len(inbound.Cells))
			for _, cell := range inbound.Cells {
				c.subscribedCells[cell] = true
			}
			c.mu.Unlock()
			c.logger.Debug("client subscribed to viewport cells", "user_id", c.userID, "count", len(inbound.Cells))

		case TypePresenceUpdate:
			// Server-side per-connection rate limit: at most 1 update / 2 s
			now := time.Now()
			c.mu.Lock()
			if !c.lastPresence.IsZero() && now.Sub(c.lastPresence) < 2*time.Second {
				c.mu.Unlock()
				c.logger.Debug("presence update dropped due to rate limit (1 update / 2s)", "user_id", c.userID)
				continue
			}
			c.lastPresence = now
			c.mu.Unlock()

			// Dispatch targeted presence through Hub
			c.hub.DispatchPresence(c.userID, c.username, c.faction, inbound.Latitude, inbound.Longitude)
		}
	}
}

// writePump pumps outbound messages from the hub to the websocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
