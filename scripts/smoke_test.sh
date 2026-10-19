#!/usr/bin/env bash
# ==============================================================================
# Territory Runner Backend Smoke Test Script (POSIX/Bash)
# Validates /healthz, /readyz, authenticated API access, and WebSocket connectivity.
#
# Usage:
#   ./scripts/smoke_test.sh [BASE_URL] [AUTH_USER] [BEARER_TOKEN]
# ==============================================================================

set -euo pipefail

BASE_URL="${1:-${BASE_URL:-http://localhost:8080}}"
AUTH_USER="${2:-${AUTH_USER:-smoke_tester}}"
BEARER_TOKEN="${3:-${BEARER_TOKEN:-}}"

PASSED=0
FAILED=0

pass() {
    echo -e "  \033[32m[PASS]\033[0m $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "  \033[31m[FAIL]\033[0m $1: $2"
    FAILED=$((FAILED + 1))
}

echo "=================================================="
echo "Territory Runner Smoke Test: $BASE_URL"
echo "=================================================="

# 1. Healthz Check
HEALTHZ_RESP=$(curl -sS --max-time 5 "$BASE_URL/healthz" || echo "FAILED")
if echo "$HEALTHZ_RESP" | grep -q '"status":"ok"'; then
    pass "/healthz returned status=ok"
else
    fail "/healthz check failed" "$HEALTHZ_RESP"
fi

# 2. Readyz Check
READYZ_RESP=$(curl -sS --max-time 5 "$BASE_URL/readyz" || echo "FAILED")
if echo "$READYZ_RESP" | grep -q '"status":"ready"'; then
    pass "/readyz returned status=ready (DB/Store connected)"
else
    fail "/readyz check failed" "$READYZ_RESP"
fi

# 3. Authenticated Settings Request
AUTH_HEADERS=()
SETTINGS_URL="$BASE_URL/v1/me/settings"
if [ -n "$BEARER_TOKEN" ]; then
    AUTH_HEADERS=(-H "Authorization: Bearer $BEARER_TOKEN")
else
    AUTH_HEADERS=(-H "X-Dev-User: $AUTH_USER")
    SETTINGS_URL="$BASE_URL/v1/me/settings?dev_user=$AUTH_USER"
fi

SETTINGS_RESP=$(curl -sS --max-time 5 "${AUTH_HEADERS[@]}" "$SETTINGS_URL" || echo "FAILED")
if echo "$SETTINGS_RESP" | grep -q 'live_visibility'; then
    pass "Authenticated GET /v1/me/settings succeeded"
else
    fail "Authenticated GET /v1/me/settings failed" "$SETTINGS_RESP"
fi

# 4. WebSocket Upgrade Handshake
WS_SCHEME="ws"
if [[ "$BASE_URL" == https* ]]; then
    WS_SCHEME="wss"
fi
HOST_PART=$(echo "$BASE_URL" | sed -E 's|^https?://||')
WS_URL="$WS_SCHEME://$HOST_PART/v1/ws?dev_user=$AUTH_USER"

# Verify HTTP 101 Switching Protocols response on WebSocket handshake request
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --include \
    --no-buffer \
    --header "Connection: Upgrade" \
    --header "Upgrade: websocket" \
    --header "Host: $HOST_PART" \
    --header "Origin: http://localhost" \
    --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
    --header "Sec-WebSocket-Version: 13" \
    "$BASE_URL/v1/ws?dev_user=$AUTH_USER" || echo "000")

if [ "$HTTP_STATUS" = "101" ]; then
    pass "WebSocket handshake returned HTTP 101 Switching Protocols"
else
    fail "WebSocket handshake failed with HTTP status" "$HTTP_STATUS"
fi

echo "--------------------------------------------------"
echo "Summary: $PASSED Passed, $FAILED Failed"
echo "=================================================="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
