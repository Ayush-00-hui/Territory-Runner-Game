# Territory Runner Error Code Catalogue

This document defines the standard error response envelope, HTTP status mapping, error codes, and client remediation strategies for the Territory Runner platform.

---

## 1. Standard Error Envelope

All API endpoints return JSON error payloads formatted with a unified envelope. Every error includes a machine-readable `error` code, human-readable `detail`, and a unique `request_id` correlated with server-side structured logs and client Crashlytics traces.

```json
{
  "error": "ANOMALY_REJECTED",
  "detail": "Instantaneous human speed ceiling exceeded: 38.4 km/h > 25.0 km/h",
  "request_id": "c1f7a40b-481f-4279-9943-261ec08d1354"
}
```

Clients parse `request_id` and attach it to local logs and bug reports.

---

## 2. Error Catalogue

| Error Code | HTTP Status | Trigger Condition | Client Remediation |
| :--- | :--- | :--- | :--- |
| `UNAUTHORIZED` | 401 Unauthorized | Missing, expired, or malformed Firebase JWT token / WebSocket auth param. | Refresh Firebase ID token and retry; if refresh fails, prompt re-authentication. |
| `INVALID_JSON` | 400 Bad Request | Request body contains malformed JSON syntax or type mismatches. | Validate payload serialization before transmission. |
| `PAYLOAD_TOO_LARGE` | 413 Payload Too Large | Request body exceeds maximum allowed size (2 MB). | Downsample dense GPS tracks using Ramer-Douglas-Peucker before upload. |
| `MISSING_KEY` | 400 Bad Request | Idempotency key omitted on `/v1/runs` submission. | Provide a UUIDv4 idempotency key generated at run initiation. |
| `INVALID_ACTIVITY_TYPE` | 400 Bad Request | Activity type is not one of `running`, `walking`, or `cycling`. | Select a valid activity type from the enumeration. |
| `INSUFFICIENT_POINTS` | 400 Bad Request | GPS track contains fewer than 3 coordinates. | Ensure run recording captures at least 3 points before attempting to finish. |
| `TOO_MANY_POINTS` | 400 Bad Request | GPS track exceeds system limit (20,000 points). | Segment extended ultramarathon runs or apply trajectory decimation. |
| `INVALID_DURATION` | 400 Bad Request | Duration is negative or exceeds 86,400 seconds (24 hours). | Validate stopwatch clock against monotonic timestamps. |
| `NON_MONOTONIC_TIMESTAMPS`| 400 Bad Request | Telemetry contains out-of-order or rewind timestamps. | Discard timestamp jumps from clock sync changes before sync. |
| `ANOMALY_REJECTED` | 422 Unprocessable | Anticheat rules tripped (speed > 25 km/h, teleport jump > 50m/s, mock location provider). | Flag to runner that transport speeds or mock GPS cannot be claimed for territory. |
| `INVALID_LOOP` | 400 Bad Request | Polygon perimeter self-intersects or fails planar enclosure. | Notify runner that loop crossed itself; preserve path for continued running. |
| `MAX_ZONES_EXCEEDED` | 400 Bad Request | User attempts to store more than 5 privacy exclusion zones. | Prompt runner to delete or adjust an existing privacy zone. |
| `INVALID_RADIUS` | 400 Bad Request | Privacy zone radius is not between 50m and 2,000m. | Constrain slider to valid 50m–2000m range in UI. |
| `INVALID_COORDINATES` | 400 Bad Request | Latitude not in [-90, 90] or longitude not in [-180, 180]. | Discard out-of-bounds GPS coordinate fixes. |
| `INVALID_TOKEN` | 400 Bad Request | FCM device push token is empty or blank. | Re-fetch FCM token from native messaging service. |
| `RATE_LIMIT_EXCEEDED` | 429 Too Many Requests | Token bucket rate limit exhausted. | Read `Retry-After` response header and queue background retry with backoff. |
| `WS_DISABLED` | 503 Service Unavailable | Real-time WebSocket hub is disabled on server instance. | Fallback to HTTP polling for rival presence and leaderboard. |
| `TRANSACTION_FAILED` | 500 Internal Error | PostGIS polygon clipping or spatial transaction conflict. | Keep run in local `SyncQueue` and retry with exponential jitter. |
| `INTERNAL_ERROR` | 500 Internal Error | Unexpected database or backend execution fault. | Report `request_id` to runner UI; preserve local offline state. |

---

## 3. Client Offline & Recovery Guarantees

1. **Transient Network or Server Errors (5xx, 429, timeouts):**
   - The Flutter client's `SyncQueue` enqueues the serialized run and retries automatically using exponential backoff with jitter.
   - Run coordinates and claimed areas remain safely preserved in Hive local storage.
2. **Permanent Client Errors (400, 422):**
   - The error is logged via `AppLogger.error` with `request_id`.
   - The run status is marked as unprocessable; runner is notified without freezing or crashing the UI.
