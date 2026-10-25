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
| **Motion Window Summaries** | 10s aggregate step cadence (`cadence_spm`), motion energy (`motion_energy`), confidence (`cadence_confidence`) | Anti-cheat physical locomotor validation (detecting vehicular stillness) | Ephemeral in-memory (device) & PostgreSQL `runs` payload |
| **Tactical Safety Data** | Emergency contact name, SMS number, SOS distress events | Emergency dialing and SMS dispatch via device intents | Device-local `SharedPreferences` only (never sent to server) |

---

## 2. Server-Enforced Privacy Zones

In addition to client-side redaction, the backend enforces privacy zones as an authoritative security layer:

1. **Storage Limits**:
   - Each runner may register up to **5 privacy zones** (`maxZones = 5`).
   - Radius constraints: **50 meters minimum** to **2,000 meters maximum** (`minRadius = 50.0`, `maxRadius = 2000.0`).
   - Enforced by server validation at `PUT /v1/me/privacy-zones` and database constraints (`radius_meters BETWEEN 50 AND 2000`).

2. **Presence Suppression (WebSockets)**:
   - When a runner moves within their registered privacy zone, real-time WebSocket presence updates (`TypePresenceUpdate`) are **completely dropped at the client and server hub** before broadcasting.
   - Dual-ended enforcement: Presence is suppressed if either the sender or recipient is within an active privacy exclusion zone.
   - Competitors and rivals on the live map cannot see another runner's location or movement while inside their designated privacy bubble.

3. **GPS Track & Export Masking**:
   - GPS breadcrumbs falling within an active privacy zone radius ($d \le R$) are omitted from GPX 1.1 and GeoJSON path exports.
   - First and last segments of runs originating or terminating inside privacy zones are truncated to prevent triangulating a runner's residence or workplace.

---

## 3. Real-Time Presence & Live Location Visibility (Phase 1 Hardening)

To adhere to privacy-by-default and prevent stalking or pace profiling during active runs:

1. **Default Visibility (`off`)**:
   - `live_visibility` defaults strictly to `'off'` on account creation (`000010_add_user_settings.up.sql`).
   - Unless a runner explicitly opts in via **Profile > Live Location Visibility**, zero outbound presence messages are broadcast to the network.
   - Configurable modes:
     - `off`: Live position is never broadcast or delivered to anyone.
     - `friends`: Delivered strictly to mutual accepted friends.
     - `nearby`: Delivered to nearby runners within the same spatial geohash cell or 8 adjacent perimeter cells.

2. **Kinematic Stripping, Delay & Spatial Coarsening**:
   - **25m Grid Snapping**: Coordinates broadcast to nearby runners are snapped to a 25-meter grid center (`SnapToGrid25m`), preventing street-level triangulation.
   - **5-Second Delay**: Presence broadcasts are held in a 5-second buffer before dispatch (`presenceDelay = 5s`).
   - **Kinematic Redaction**: Speed, cadence, and heading are entirely stripped and omitted from public presence broadcasts.

3. **Spatial Geohash Cell Targeting**:
   - Uses standard base32 **Geohash precision 6** (~1.2 km x 0.6 km) with 8 adjacent neighbor cells.
   - Clients declare visible map bounds via lightweight `viewport_subscribe` packets (`{"type": "viewport_subscribe", "cells": [...]}`).
   - Presence packets are delivered exclusively to clients subscribed to overlapping cells, scaling $O(K)$ with local cell density rather than $O(N^2)$ global fanout, with a hard delivery cap of 200 recipients per packet.

4. **Transport Security & Anti-Leak Controls**:
   - **No Query Parameter Credentials**: In production mode (`AUTH_MODE != "dev"`), tokens or user IDs in query strings (`?token=`, `?user_id=`, `?dev_user=`) are strictly rejected (HTTP 401).
   - **Standard Subprotocol Auth**: Clients negotiate authentication via `Sec-WebSocket-Protocol: bearer, <id_token>` or `Authorization: Bearer <token>`, preventing token leakage in HTTP access logs and proxy caches.
   - **Connection Capping & Rate Limiting**: Capped at **3 concurrent WebSocket connections** per user (HTTP 429) and throttled to **at most 1 presence update per 2 seconds** per client socket.
   - **Slow Consumer Isolation**: Saturated client channels drop packets gracefully without blocking other concurrent runners.

---

## 4. Public Territory State vs. Private Paths

A fundamental architectural distinction exists between **territory polygons** and **GPS path tracks**:

- **Territory Polygons are Public**:
  - Territory polygons represent contested, sovereign game space on the public map.
  - Hiding territory polygons inside privacy zones would create invisible, unattackable ghost zones that break the multiplayer game loop.
  - Therefore, territory geometries remain visible to all players.
- **GPS Breadcrumb Tracks are Redacted**:
  - The exact route, pace, heart rate, timestamps, and street-level path taken to capture that territory are stripped of coordinates within privacy zones.
  - Runners can contest territories near their homes without exposing their exact address or daily running routine.

---

## 5. Offline-First Synchronization

- Privacy zones are cached locally in device storage (`SharedPreferences`) for immediate offline protection.
- When an authenticated session is established, changes sync with `GET /v1/me/privacy-zones` and `PUT /v1/me/privacy-zones`.
- If the network or backend is unreachable, the client operates gracefully using cached local zones, preventing tracking leakage during network drops.

---

## 6. Tactical SOS & Safety Features

- **No Remote Telemetry for SOS Contacts**: Emergency contact numbers and SOS SMS messages are stored strictly on the local device.
- **Native OS Intent Dispatch**: Emergency calls (911/112) and SOS SMS dispatches use native `url_launcher` intents (`tel:` and `sms:`). The Territory Runner backend does not store or process emergency contact information.
- **Audible Siren**: Operates entirely offline on the client audio hardware.

---

## 7. Account Deletion & Data Portability (GDPR / CCPA)

1. **Data Portability**:
   - Users can export all captured territories and run tracks in standard **GPX 1.1** (with `<type>running</type>`) and RFC 7946 **GeoJSON** formats via `ExportService`.
   - Export dialogues allow optional or mandatory privacy redaction before exporting.
2. **Account Deletion**:
   - Users can request complete account deletion.
   - Deletion cascades across `users`, `privacy_zones`, `friendships`, `duels`, and reassigns or removes associated game assets in compliance with privacy regulations.

---

## 8. Map Tile Requests & Local Caching Privacy

1. **Third-Party Tile Requests**:
   - To render base maps, the client makes HTTPS GET requests for image tiles ($z/x/y$) to the configured tile provider (OpenStreetMap or Mapbox).
   - Tile requests include standard coordinate indices and the application's identifying User-Agent (`com.territoryrunner.app/1.0.0 (https://github.com/Ayush-00-hui/Territory-Runner-Game)`).
   - **Zero User Telemetry**: No user identifier, authentication token, runner name, or GPS breadcrumb track is ever attached to map tile network requests.
2. **Local Tile Caching**:
   - Downloaded map tiles are stored on device in an app-private cache directory.
   - Tiles remain cached locally for a minimum of 7 days before conditional revalidation (`If-Modified-Since`), minimizing network requests.
   - Runners can purge all cached map tiles at any time from **Profile > Data & Offline > Map cache & storage > Purge Offline Map Cache**.

---

## 9. Motion Sensor & Accelerometer Privacy (Cadence & Energy Validation)

To ensure fair multiplayer conquest without intrusive surveillance, Territory Runner uses on-device accelerometer kinematics to validate authentic athletic movement and detect vehicular spoofing.

### 1. Zero Raw Sensor Telemetry Policy
- **Strictly On-Device Processing**: The mobile app samples the device accelerometer ($a_x, a_y, a_z$) at ~25 Hz (~40 ms intervals) solely while a run is actively recorded.
- **NEVER Uploaded or Persisted**: Raw tri-axial acceleration waveforms, micro-vibration time series, and sensor timestamps are **never transmitted over the network, written to persistent storage, or shared with third parties**.
- **Immediate In-Memory Purging**: Raw accelerometer samples are stored exclusively in an ephemeral circular buffer in device RAM. As soon as a 10-second window completes and aggregate summary features are calculated, the raw sample buffer is explicitly cleared (`_currentSamples.clear()`).

### 2. Exactly What Is Derived & Sent
At the boundary of each 10-second tumbling window, only three coarse statistical scalars are derived and included as optional fields in the run completion payload (`POST /v1/runs`):

| Derived Field | Data Type | Computation Method | Purpose |
| :--- | :---: | :--- | :--- |
| `cadence_spm` | `float64` | Step cadence in steps per minute (SPM), derived via peak counting within the physiological human running band (1.0–3.5 Hz / 60–210 SPM) with dynamic noise rejection and a 0.285s refractory filter. | Confirms rhythmic human footfalls (typical run: 150–185 SPM; walk: 100–130 SPM; car: <15 SPM). |
| `motion_energy` | `float64` | Mean square acceleration magnitude ($\frac{1}{N}\sum a_i^2$) in $\text{m}^2/\text{s}^4$, measuring physical impact intensity. | Distinguishes high-impact running footsteps ($>1.0\,\text{m}^2/\text{s}^4$) from low-vibration vehicle cabins ($<0.25\,\text{m}^2/\text{s}^4$). |
| `cadence_confidence` | `float64` | Normalized score in $[0.0, 1.0]$ measuring step rhythm regularity based on the coefficient of variation (CV) of inter-peak intervals. | Measures step periodicity to reject irregular non-locomotor shaking. |

Each 10-second window also includes:
- `start_time_iso` / `start_time_ms`: ISO-8601 timestamp aligning the 10-second window with the corresponding GPS breadcrumb span.
- `duration_sec`: Nominal duration of the window (default: 10.0 seconds).

### 3. Side-Channel & Spyware Defense Guarantees
1. **No Eavesdropping or Keystroke Inference**: High-frequency accelerometer data can theoretically leak keystrokes or speech vibrations if sampled continuously. Territory Runner prevents this side-channel by:
   - Sampling exclusively during an active workout session started by the user.
   - Restricting sampling to ~25 Hz (well below acoustic or high-frequency keystroke bands).
   - Never uploading time-series waveforms.
2. **Mathematical Irreversibility**: A 10-second window aggregates approximately 250 individual 3D acceleration vectors into two aggregate numbers (cadence SPM and motion energy). It is mathematically impossible to reconstruct device orientation, hand tremors, user gestures, or physical environments from these window scalars.
3. **Graceful Degradation & Backward Compatibility**: If motion sensor permissions are unavailable or hardware sensors fail, the `motion_windows` field is simply omitted (`null` / empty). The backend detector falls back gracefully to pure spatial GPS kinematics, ensuring full backward compatibility.

