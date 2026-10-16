package ws

// MessageType defines the real-time event category.
type MessageType string

const (
	// Client -> Server
	TypePresenceUpdate MessageType = "presence_update"
	TypeHeartbeat      MessageType = "heartbeat"

	// Server -> Client
	TypeRunnerPresence       MessageType = "runner_presence"
	TypeRunnerLeft           MessageType = "runner_left"
	TypeTerritoryAlert       MessageType = "territory_alert"
	TypeTerritoryUnderAttack MessageType = "territory_under_attack"
	TypeConquestBroadcast    MessageType = "conquest_broadcast"
)

// InboundMessage represents a client packet sent over WebSocket.
type InboundMessage struct {
	Type      MessageType `json:"type"`
	Latitude  float64     `json:"latitude,omitempty"`
	Longitude float64     `json:"longitude,omitempty"`
	Speed     float64     `json:"speed,omitempty"`
	Heading   float64     `json:"heading,omitempty"`
}

// PresenceMessage broadcasts live runner kinematics to nearby/active peers.
type PresenceMessage struct {
	Type      MessageType `json:"type"`
	UserID    string      `json:"user_id"`
	Username  string      `json:"username"`
	Faction   string      `json:"faction"`
	Latitude  float64     `json:"latitude"`
	Longitude float64     `json:"longitude"`
	Speed     float64     `json:"speed"`
	Heading   float64     `json:"heading"`
	UpdatedAt string      `json:"updated_at"`
}

// RunnerLeftMessage informs peers that a runner has disconnected or gone offline.
type RunnerLeftMessage struct {
	Type   MessageType `json:"type"`
	UserID string      `json:"user_id"`
}

// TerritoryAlertMessage sends an instant tactical warning to an attacked player.
type TerritoryAlertMessage struct {
	Type           MessageType `json:"type"`
	Event          string      `json:"event"`
	AttackerID     string      `json:"attacker_id"`
	AttackerName   string      `json:"attacker_name"`
	AreaClaimedSqm float64     `json:"area_claimed_sqm"`
	VictimUserID   string      `json:"victim_user_id,omitempty"`
	Message        string      `json:"message"`
	Timestamp      string      `json:"timestamp"`
}

// ConquestBroadcastMessage sends a global milestone feed update to all connected runners.
type ConquestBroadcastMessage struct {
	Type           MessageType `json:"type"`
	Event          string      `json:"event"`
	AttackerID     string      `json:"attacker_id"`
	AttackerName   string      `json:"attacker_name"`
	AreaClaimedSqm float64     `json:"area_claimed_sqm"`
	Message        string      `json:"message"`
	Timestamp      string      `json:"timestamp"`
}
