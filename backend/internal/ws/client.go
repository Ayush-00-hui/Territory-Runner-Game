package ws

import (
	"encoding/json"
	"log/slog"
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
	hub      *Hub
	conn     *websocket.Conn
	send     chan []byte
	userID   string
	username string
	faction  string
	logger   *slog.Logger
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

		case TypePresenceUpdate:
			// Enforce server-side privacy zones: never broadcast runner presence while user is inside a zone
			if c.hub.IsPointInUserPrivacyZone(c.userID, inbound.Latitude, inbound.Longitude) {
				c.logger.Debug("runner presence suppressed due to privacy zone", "user_id", c.userID, "lat", inbound.Latitude, "lng", inbound.Longitude)
				continue
			}

			// Broadcast runner kinematic position to peers
			presence := PresenceMessage{
				Type:      TypeRunnerPresence,
				UserID:    c.userID,
				Username:  c.username,
				Faction:   c.faction,
				Latitude:  inbound.Latitude,
				Longitude: inbound.Longitude,
				Speed:     inbound.Speed,
				Heading:   inbound.Heading,
				UpdatedAt: time.Now().UTC().Format(time.RFC3339),
			}
			c.hub.BroadcastJSON(presence)
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
