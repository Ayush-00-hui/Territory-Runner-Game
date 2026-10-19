<#
.SYNOPSIS
    Territory Runner Backend Smoke Test Script
    Validates /healthz, /readyz, authenticated API access, and WebSocket connectivity.

.PARAMETER BaseUrl
    Base URL of the target server (e.g. "http://localhost:8080").

.PARAMETER AuthUser
    User ID to use for dev authentication (default: "smoke_tester").

.PARAMETER BearerToken
    Optional JWT bearer token for production authentication.
#>

param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$AuthUser = "smoke_tester",
    [string]$BearerToken = ""
)

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Write-Pass($msg) {
    Write-Host "  [PASS] $msg" -ForegroundColor Green
    $script:passed++
}

function Write-Fail($msg, $err) {
    Write-Host "  [FAIL] $($msg): $err" -ForegroundColor Red
    $script:failed++
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Territory Runner Smoke Test: $BaseUrl" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Healthz Check
try {
    $resp = Invoke-RestMethod -Uri "$BaseUrl/healthz" -Method Get -TimeoutSec 5
    if ($resp.status -eq "ok") {
        Write-Pass "/healthz returned status=ok"
    } else {
        Write-Fail "/healthz unexpected response" ($resp | ConvertTo-Json -Compress)
    }
} catch {
    Write-Fail "/healthz endpoint unreachable" $_.Exception.Message
}

# 2. Readyz Check
try {
    $resp = Invoke-RestMethod -Uri "$BaseUrl/readyz" -Method Get -TimeoutSec 5
    if ($resp.status -eq "ready") {
        Write-Pass "/readyz returned status=ready (DB/Store connected)"
    } else {
        Write-Fail "/readyz unexpected response" ($resp | ConvertTo-Json -Compress)
    }
} catch {
    Write-Fail "/readyz endpoint unreachable" $_.Exception.Message
}

# 3. Authenticated Settings Request
try {
    $headers = @{}
    $settingsUrl = "$BaseUrl/v1/me/settings"
    if ($BearerToken -ne "") {
        $headers["Authorization"] = "Bearer $BearerToken"
    } else {
        $headers["X-Dev-User"] = $AuthUser
        $settingsUrl = "$BaseUrl/v1/me/settings?dev_user=$AuthUser"
    }

    $resp = Invoke-RestMethod -Uri $settingsUrl -Method Get -Headers $headers -TimeoutSec 5
    if ($null -ne $resp.live_visibility) {
        Write-Pass "Authenticated GET /v1/me/settings succeeded (live_visibility=$($resp.live_visibility))"
    } else {
        Write-Fail "Authenticated /v1/me/settings missing live_visibility" ($resp | ConvertTo-Json -Compress)
    }
} catch {
    Write-Fail "Authenticated GET /v1/me/settings failed" $_.Exception.Message
}

# 4. Real-Time WebSocket Handshake
try {
    $wsScheme = if ($BaseUrl.StartsWith("https")) { "wss" } else { "ws" }
    $hostPart = $BaseUrl -replace "^https?://", ""
    
    $wsUriStr = "$($wsScheme)://$($hostPart)/v1/ws?dev_user=$($AuthUser)"
    $ws = [System.Net.WebSockets.ClientWebSocket]::new()
    
    if ($BearerToken -ne "") {
        $wsUriStr = "$($wsScheme)://$($hostPart)/v1/ws"
        $ws.Options.AddSubProtocol("bearer")
        $ws.Options.SetRequestHeader("Authorization", "Bearer $BearerToken")
    }

    $uri = [Uri]::new($wsUriStr)
    $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
    
    $connectTask = $ws.ConnectAsync($uri, $cts.Token)
    $connectTask.Wait()

    if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        Write-Pass "WebSocket handshake connected successfully ($($ws.State))"

        # Send test viewport subscription packet
        $subscribeJson = '{"type":"viewport_subscribe","cells":["9q8yyk"]}'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($subscribeJson)
        $segment = [ArraySegment[byte]]::new($bytes)
        $sendTask = $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token)
        $sendTask.Wait()
        Write-Pass "Sent viewport_subscribe message over WebSocket"

        $closeTask = $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "smoke_complete", [System.Threading.CancellationToken]::None)
        $closeTask.Wait()
    } else {
        Write-Fail "WebSocket connected but state not Open" $ws.State
    }
    $ws.Dispose()
} catch {
    Write-Fail "WebSocket handshake failed" $_.Exception.Message
}

Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "Summary: $passed Passed, $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
