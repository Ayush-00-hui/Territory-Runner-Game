# Privacy Policy & Geodata Architecture

**Territory Runner** is a real-world GPS territory-conquest running game. Because geospatial tracking involves sensitive location data (such as residential or workplace origins), this document outlines how runner data is collected, processed, sanitized, synchronized, and deleted.

---

## 1. Data Collected & Purpose

| Data Category | Specific Fields | Primary Purpose | Storage Location |
| :--- | :--- | :--- | :--- |
| **Account Identity** | User ID, display name, avatar URL, auth provider tokens | Authentication and multiplayer profile attribution | PostgreSQL `users` table |
| **Real-Time GPS Coordinates** | Latitude, longitude, altitude, accuracy, timestamp, speed | Live run tracking, anti-cheat validation, pacing metrics | Ephemeral in-memory (device) & WebSocket broadcast |
| **Territory Polygons** | GeoJSON Polygon coordinates, bounded area ($m^2$), capture timestamp, owner ID | Core gameplay mechanics: claim, hold, contest, and display sovereign zones | PostgreSQL `territories` table (PostGIS geometry) |
| **Privacy Zones** | Center latitude/longitude, radius (50m–2000m), name, enabled state | Redaction of sensitive zones (e.g. home, office) from tracks and presence | Local `SharedPreferences` + PostgreSQL `privacy_zones` table |
| **Tactical Safety Data** | Emergency contact name, SMS number, SOS distress events | Emergency dialing and SMS dispatch via device intents | Device-local `SharedPreferences` only (never sent to server) |

---

## 2. Server-Enforced Privacy Zones

In addition to client-side redaction, the backend enforces privacy zones as an authoritative security layer:

1. **Storage Limits**:
   - Each runner may register up to **5 privacy zones** (`maxZones = 5`).
   - Radius constraints: **50 meters minimum** to **2,000 meters maximum** (`minRadius = 50.0`, `maxRadius = 2000.0`).
   - Enforced by server validation at `PUT /v1/me/privacy-zones` and database constraints (`radius_meters BETWEEN 50 AND 2000`).

2. **Presence Suppression (WebSockets)**:
   - When a runner moves within their registered privacy zone, real-time WebSocket presence updates (`TypePresenceUpdate`) are **completely dropped at the server hub** before broadcasting to nearby runners.
   - Competitors and rivals on the live map cannot see another runner's location or movement while inside their designated privacy bubble.

3. **GPS Track & Export Masking**:
   - GPS breadcrumbs falling within an active privacy zone radius ($d \le R$) are omitted from GPX 1.1 and GeoJSON path exports.
   - First and last segments of runs originating or terminating inside privacy zones are truncated to prevent triangulating a runner's residence or workplace.

---

## 3. Public Territory State vs. Private Paths

A fundamental architectural distinction exists between **territory polygons** and **GPS path tracks**:

- **Territory Polygons are Public**:
  - Territory polygons represent contested, sovereign game space on the public map.
  - Hiding territory polygons inside privacy zones would create invisible, unattackable ghost zones that break the multiplayer game loop.
  - Therefore, territory geometries remain visible to all players.
- **GPS Breadcrumb Tracks are Redacted**:
  - The exact route, pace, heart rate, timestamps, and street-level path taken to capture that territory are stripped of coordinates within privacy zones.
  - Runners can contest territories near their homes without exposing their exact address or daily running routine.

---

## 4. Offline-First Synchronization

- Privacy zones are cached locally in device storage (`SharedPreferences`) for immediate offline protection.
- When an authenticated session is established, changes sync with `GET /v1/me/privacy-zones` and `PUT /v1/me/privacy-zones`.
- If the network or backend is unreachable, the client operates gracefully using cached local zones, preventing tracking leakage during network drops.

---

## 5. Tactical SOS & Safety Features

- **No Remote Telemetry for SOS Contacts**: Emergency contact numbers and SOS SMS messages are stored strictly on the local device.
- **Native OS Intent Dispatch**: Emergency calls (911/112) and SOS SMS dispatches use native `url_launcher` intents (`tel:` and `sms:`). The Territory Runner backend does not store or process emergency contact information.
- **Audible Siren**: Operates entirely offline on the client audio hardware.

---

## 6. Account Deletion & Data Portability (GDPR / CCPA)

1. **Data Portability**:
   - Users can export all captured territories and run tracks in standard **GPX 1.1** (with `<type>running</type>`) and RFC 7946 **GeoJSON** formats via `ExportService`.
   - Export dialogues allow optional or mandatory privacy redaction before exporting.
2. **Account Deletion**:
   - Users can request complete account deletion.
   - Deletion cascades across `users`, `privacy_zones`, `friendships`, `duels`, and reassigns or removes associated game assets in compliance with privacy regulations.
