# Local Server & Spare-Laptop Recipe

This document provides a field-tested blueprint for running the **Territory Runner** backend locally on a developer machine or a spare laptop for live outdoor demonstrations, field tests, and campus playtests.

---

## 1. The Spare-Laptop Architecture

When demonstrating or field-testing Territory Runner without cloud infrastructure, a standard laptop acts as the authoritative multi-tenant game server.

```
                    ┌────────────────────────────────────────────────────────┐
                    │               SPARE LAPTOP (Authoritative Host)         │
                    │                                                        │
                    │   ┌────────────────────────────────────────────────┐   │
                    │   │ Docker / Local Go Server (Port 8080)            │   │
                    │   │   - REST API & Anti-Cheat Engine               │   │
                    │   │   - Real-Time WebSocket Hub (Presence/Alerts)   │   │
                    │   │   - PostgreSQL 16 + PostGIS 3.4 (Port 5432)    │   │
                    │   └──────────────────────┬─────────────────────────┘   │
                    │                          │                             │
                    │   Local Wi-Fi / Hotspot Interface (e.g. 192.168.43.50) │
                    └──────────────────────────▲─────────────────────────────┘
                                               │
                       Local Wi-Fi Network (LAN) / Phone Hotspot
                                               │
             ┌─────────────────────────────────┴─────────────────────────────────┐
             │                                                                   │
   ┌─────────▼───────────────┐                                         ┌─────────▼───────────────┐
   │ RUNNER A (Mobile Device)│                                         │ RUNNER B (Mobile Device)│
   │ Flutter Client (Debug)  │                                         │ Flutter Client (Debug)  │
   │ API: http://192.168.43.50:8080                                    │ API: http://192.168.43.50:8080
   └─────────────────────────┘                                         └─────────────────────────┘
```

---

## 2. Laptop Setup & Power Configuration

To ensure uninterrupted backend service while walking, cycling, or running outdoors:

1. **Power & Sleep Settings (Windows / macOS / Linux)**:
   - **Lid Close Action**: Configure OS to **"Do nothing"** when the lid is closed (Control Panel > Power Options > Choose what closing the lid does).
   - **Sleep & Hibernate**: Disable sleep on battery and plugged-in mode (`Never sleep`).
   - **Wi-Fi Power Saving**: Disable Wi-Fi adapter power-saving mode (prevent adapter from sleeping when idle).
2. **Backpack Transport**:
   - If carrying the laptop in a backpack during tests, ensure adequate ventilation around side air vents and monitor battery state.

---

## 3. Network Configuration & Wi-Fi Hotspot

### Method A: Mobile Hotspot (Field / Outdoor Testing)
1. Enable **Personal Hotspot** on one mobile device (or a dedicated portable 4G/5G puck).
2. Connect the laptop to the mobile hotspot Wi-Fi.
3. Open a terminal on the laptop and find its local IP:
   - **Windows**: `ipconfig` (look for *IPv4 Address* under Wireless LAN adapter, e.g. `192.168.43.50`).
   - **Linux / macOS**: `ip addr` or `ifconfig` (look for `wlan0` / `en0` IP).
4. Connect all runner client phones to the **same** hotspot Wi-Fi network.
5. Verify mutual reachability: ping the laptop IP from Termux or an app on the phone.

### Method B: Static LAN IP / Home Router
If testing indoors, assign a fixed DHCP reservation to the laptop's MAC address in your router settings (e.g., `192.168.1.100`).

---

## 4. Running the Backend Stack

### Option 1: Docker Compose (Recommended)
```powershell
cd backend
docker compose up -d
```
- Starts PostGIS 16 container and Go backend container.
- Embedded migrations automatically apply on boot (`RUN_MIGRATIONS=true`).
- Backend binds to `0.0.0.0:8080`.

### Option 2: Bare-Metal Go (With In-Memory Fallback or Local Postgres)
If Docker Desktop is inactive:
```powershell
cd backend
go run ./cmd/server
```
- In development mode (`ENV=development`, `AUTH_MODE=dev`), if PostgreSQL is unreachable, the server automatically boots with the hermetic in-memory spatial store.

---

## 5. Client Configuration & Android Cleartext HTTP

### Cleartext HTTP Policy
Android 9+ (API level 28+) disables unencrypted HTTP by default.
- In **Debug Builds**: `android/app/src/debug/AndroidManifest.xml` explicitly sets `android:usesCleartextTraffic="true"`, allowing local LAN HTTP communication (`http://192.168.x.x:8080`).
- In **Release Builds**: `android/app/src/main/AndroidManifest.xml` enforces HTTPS-only for production security.

### Launching the Client with Custom Backend URL
Pass `--dart-define=API_BASE_URL` at compile/run time:
```powershell
# Running on physical Android device connected via USB or Wi-Fi adb:
flutter run --dart-define=API_BASE_URL=http://192.168.43.50:8080

# Building debug APK for sideloading onto runner phones:
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.43.50:8080
```

---

## 6. Remote Tunneling Options & Trade-Offs

When runners and the host cannot share a local Wi-Fi network, reverse tunneling allows external mobile devices over cellular 4G/5G to access the laptop server.

| Tunnel Solution | Command | Pros | Cons / Trade-Offs |
| :--- | :--- | :--- | :--- |
| **Local Wi-Fi / Hotspot (Direct)** | *No tool needed* | **Lowest latency (~2–5 ms)**, 100% offline, zero cloud dependency. | Devices must be in Wi-Fi range of hotspot. |
| **Cloudflare Tunnel (`cloudflared`)** | `cloudflared tunnel --url http://localhost:8080` | Free, trusted HTTPS certificate, stable WebSocket support, no open ports. | Adds edge round-trip latency (~30–60 ms); requires Cloudflare account for named domain. |
| **ngrok** | `ngrok http 8080` | Extremely fast 1-line setup, instant HTTPS endpoint. | Free tier assigns ephemeral URL that changes on every restart; rate limits on free tunnels. |
| **Tailscale** | `tailscale up` | Zero public internet exposure, end-to-end encrypted WireGuard mesh, static IP. | Every runner phone must install Tailscale client and join the tailnet. |

---

## 7. Automated Smoke Testing

Validate that the local server is completely operational before beginning a trial:

### On Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke_test.ps1 -BaseUrl http://localhost:8080
```

### On Linux / macOS (Bash):
```bash
./scripts/smoke_test.sh http://localhost:8080
```

The smoke test verifies:
1. `GET /healthz`: HTTP 200 OK.
2. `GET /readyz`: HTTP 200 OK (database/store liveness).
3. `GET /v1/me/settings`: Authenticated user preference retrieval.
4. `GET /v1/ws`: WebSocket handshake upgrade (HTTP 101) and viewport subscription message dispatch.

---

## 8. Demo-Day Checklist (10 Points)

Before demonstrating Territory Runner to examiners, peers, or users:

- [ ] **1. Laptop Battery**: Laptop charged to 100%; power adapter and portable power bank packed.
- [ ] **2. OS Sleep Disabled**: Confirmed laptop will not sleep when lid is closed.
- [ ] **3. Backend Running**: Go backend running on port 8080; terminal visible or logs piped.
- [ ] **4. Database Migrations**: All 10 SQL migrations applied and verified clean.
- [ ] **5. Hotspot Active**: Phone or mobile hotspot active with 2.4/5GHz Wi-Fi broadcast.
- [ ] **6. IP Address Verified**: Laptop LAN IP checked (`ipconfig` / `ifconfig`) and confirmed reachable.
- [ ] **7. Smoke Test Green**: Ran `scripts/smoke_test.ps1` with 4/4 passing checks.
- [ ] **8. Client App Installed**: Debug APK built with `--dart-define=API_BASE_URL=http://<IP>:8080` installed on test phones.
- [ ] **9. GPS Fixed**: Phones held outdoors until high-accuracy GPS lock is acquired.
- [ ] **10. Backup Created**: Ran `scripts/backup_db.sh` to capture baseline territory state.
