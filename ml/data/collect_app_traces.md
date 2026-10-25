# Field Collection Guide: Real-World App GPS Traces

This guide provides instructions for our 3 team members to record and export real-world GPS movement traces using the Territory Runner mobile app. These traces supplement the academic GeoLife dataset with current smartphone telemetry (Android / iOS GPS chips, urban multipath reflections, and realistic sensor noise).

---

## 1. Collection Quotas & Distribution

Each team member is assigned a quota across athletic and vehicular modalities:

| Team Member | Athletic Sessions (Walk / Run / Cycle) | Vehicular Sessions (Bus / Auto / Car) | Total Target |
| :--- | :---: | :---: | :---: |
| **Member 1 (Ayush)** | 7+ (3 runs, 2 walks, 2 cycles) | 4+ (1 bus, 2 auto-rickshaw, 1 car) | **11+** |
| **Member 2** | 7+ (3 runs, 2 walks, 2 cycles) | 3+ (1 bus, 1 auto-rickshaw, 1 car) | **10+** |
| **Member 3** | 7+ (3 runs, 2 walks, 2 cycles) | 4+ (2 bus, 1 auto-rickshaw, 1 car) | **11+** |
| **Total Target** | **21+ Athletic Sessions** | **11+ Vehicular Sessions** | **32+ Sessions** |

### Session Duration Requirements:
- **Athletic Sessions**: Minimum 10 minutes (ideally 15–30 minutes) outdoors.
- **Vehicular Sessions**: Minimum 8 minutes in active transit (stop-and-go traffic, arterial roads, or highways).

---

## 2. Device Pre-Flight Settings

To ensure uncorrupted GPS telemetry:
1. **Location Permissions**: Set to **"Allow all the time"** with **"Use precise location"** enabled.
2. **Battery Optimization**: Set the Territory Runner app to **"Unrestricted"** (prevents Android / iOS background execution throttling).
3. **Mock Locations**: Verify Android Developer Options **"Select mock location app"** is set to **None**.
4. **Physical Environment**: Record in diverse environments (open parks, suburban neighborhoods, and dense high-rise urban canyons).

---

## 3. In-App Debug Export Instructions

We have built a dedicated **ML Debug Trace Exporter** into the app:

1. Open **Territory Runner** on your device.
2. Start your activity (e.g. Run, Walk, Ride).
3. Complete your route and press **Finish Run**.
4. On the summary / history share card or in **Profile > Settings > Developer / ML Data Collection**:
   - Tap **"Export ML Debug Trace"**.
   - Select the true transportation mode:
     - `walk`
     - `run`
     - `cycle`
     - `bus`
     - `auto` (auto-rickshaw)
     - `car`
   - Tap **"Export & Share"**.
5. Save or AirDrop/Google Drive the generated JSON file into your local workstation at:
   ```
   ml/data/app_traces/
   ```

---

## 4. Telemetry JSON File Schema

The app exports session traces matching this structure:

```json
{
  "version": "1.0",
  "session_id": "member1_20261026_073000_run",
  "user_id": "member1",
  "transport_mode": "run",
  "recorded_at": "2026-10-26T07:30:00Z",
  "duration_seconds": 920,
  "distance_meters": 2450.5,
  "device_model": "Pixel 8 Pro",
  "os_version": "Android 14",
  "points": [
    {
      "latitude": 28.5451234,
      "longitude": 77.1923456,
      "altitude": 218.4,
      "accuracy": 3.8,
      "speed_mps": 2.74,
      "timestamp_ms": 1792955400000
    },
    {
      "latitude": 28.5451980,
      "longitude": 77.1924102,
      "altitude": 218.6,
      "accuracy": 4.1,
      "speed_mps": 2.81,
      "timestamp_ms": 1792955401000
    }
  ],
  "motion_windows": [
    {
      "start_time_iso": "2026-10-26T07:30:00.000Z",
      "duration_sec": 10.0,
      "cadence_spm": 164.2,
      "motion_energy": 1.48,
      "cadence_confidence": 0.88
    },
    {
      "start_time_iso": "2026-10-26T07:30:10.000Z",
      "duration_sec": 10.0,
      "cadence_spm": 166.0,
      "motion_energy": 1.52,
      "cadence_confidence": 0.91
    }
  ]
}
```

---

## 5. Integrating Collected Traces into the Pipeline

Whenever any `.json` files are placed into `ml/data/app_traces/`, the training pipeline automatically picks them up during the next data preparation run:

```bash
python ml/data/prepare_geolife.py
```

The script parses each `.json` file, maps the mode to `{legit_walk_run, legit_cycle, vehicle}`, and appends the labeled breadcrumbs to the master dataset for cross-validation.
