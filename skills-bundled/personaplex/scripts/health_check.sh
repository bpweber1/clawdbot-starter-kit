#!/usr/bin/env bash
# health_check.sh — Check if a PersonaPlex server is running and healthy.
#
# Usage:
#   ./health_check.sh [SERVER_URL]
#   ./health_check.sh https://myserver:8998
#   ./health_check.sh --local
#   ./health_check.sh --json
#
# Returns exit code 0 if healthy, 1 if unhealthy.

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
SERVER_URL="${1:-https://localhost:8998}"
JSON_OUTPUT=false
LOCAL_CHECK=false
TIMEOUT=10

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Parse Args ──────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --json)       JSON_OUTPUT=true ;;
        --local)      LOCAL_CHECK=true; SERVER_URL="https://localhost:8998" ;;
        --timeout=*)  TIMEOUT="${arg#*=}" ;;
        --help|-h)
            echo "Usage: $(basename "$0") [SERVER_URL] [--json] [--local] [--timeout=N]"
            echo ""
            echo "Check PersonaPlex server health status."
            echo ""
            echo "Arguments:"
            echo "  SERVER_URL          Server URL (default: https://localhost:8998)"
            echo "  --json              Output results as JSON"
            echo "  --local             Check localhost and include GPU info"
            echo "  --timeout=N         Connection timeout in seconds (default: 10)"
            echo "  --help              Show this help"
            echo ""
            echo "Examples:"
            echo "  ./health_check.sh https://myserver:8998"
            echo "  ./health_check.sh --local --json"
            echo "  ./health_check.sh https://gpu-instance:8998 --timeout=30"
            exit 0
            ;;
        https://*|http://*)  SERVER_URL="$arg" ;;
    esac
done

# ─── Check Functions ─────────────────────────────────────────────────────────

check_http() {
    local url="$1"
    local status_code
    local response_time

    # Use curl with timing, allow self-signed certs
    local start_time
    start_time=$(date +%s%N 2>/dev/null || date +%s)

    status_code=$(curl -sk -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --connect-timeout "$TIMEOUT" \
        "$url" 2>/dev/null) || status_code="000"

    local end_time
    end_time=$(date +%s%N 2>/dev/null || date +%s)

    # Calculate response time in ms
    if [[ "$start_time" =~ ^[0-9]{10,}$ ]]; then
        response_time=$(( (end_time - start_time) / 1000000 ))
    else
        response_time=$(( (end_time - start_time) * 1000 ))
    fi

    echo "$status_code|$response_time"
}

check_websocket() {
    local ws_url="$1"

    # Try WebSocket connection with timeout
    if command -v websocat &>/dev/null; then
        # Use websocat if available
        echo "test" | timeout "$TIMEOUT" websocat -1 -k "$ws_url" &>/dev/null
        return $?
    elif command -v python3 &>/dev/null; then
        # Fallback to Python
        python3 -c "
import asyncio, ssl, sys
try:
    import websockets
except ImportError:
    sys.exit(2)

async def check():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        async with websockets.connect('$ws_url', ssl=ctx, open_timeout=$TIMEOUT):
            pass
        return True
    except Exception:
        return False

result = asyncio.run(check())
sys.exit(0 if result else 1)
" 2>/dev/null
        return $?
    else
        # Can't check WebSocket
        return 2
    fi
}

get_gpu_info() {
    if ! command -v nvidia-smi &>/dev/null; then
        echo "unavailable"
        return
    fi

    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu \
        --format=csv,noheader,nounits 2>/dev/null || echo "error"
}

get_process_info() {
    # Check if moshi.server is running
    local pid
    pid=$(pgrep -f "moshi.server" 2>/dev/null | head -1) || true

    if [[ -n "$pid" ]]; then
        local uptime_raw
        uptime_raw=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ') || true
        echo "$pid|$uptime_raw"
    else
        echo ""
    fi
}

# ─── Main Health Check ──────────────────────────────────────────────────────

run_health_check() {
    local overall_status="healthy"
    local http_status="unknown"
    local http_code="000"
    local http_latency_ms=0
    local ws_status="unknown"
    local gpu_name=""
    local gpu_mem_used=""
    local gpu_mem_total=""
    local gpu_util=""
    local gpu_temp=""
    local process_pid=""
    local process_uptime=""
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # 1. HTTP check
    local http_result
    http_result=$(check_http "$SERVER_URL")
    http_code=$(echo "$http_result" | cut -d'|' -f1)
    http_latency_ms=$(echo "$http_result" | cut -d'|' -f2)

    if [[ "$http_code" =~ ^[23] ]]; then
        http_status="ok"
    elif [[ "$http_code" == "000" ]]; then
        http_status="unreachable"
        overall_status="unhealthy"
    else
        http_status="error"
        overall_status="degraded"
    fi

    # 2. WebSocket check
    local ws_url
    ws_url=$(echo "$SERVER_URL" | sed 's|^https://|wss://|; s|^http://|ws://|')
    ws_url="${ws_url}/ws"

    if check_websocket "$ws_url"; then
        ws_status="ok"
    elif [[ $? -eq 2 ]]; then
        ws_status="skipped"
    else
        ws_status="failed"
        if [[ "$overall_status" == "healthy" ]]; then
            overall_status="degraded"
        fi
    fi

    # 3. GPU info (local only)
    if [[ "$LOCAL_CHECK" == "true" ]] || [[ "$SERVER_URL" == *"localhost"* ]]; then
        local gpu_info
        gpu_info=$(get_gpu_info)
        if [[ "$gpu_info" != "unavailable" ]] && [[ "$gpu_info" != "error" ]]; then
            gpu_name=$(echo "$gpu_info" | cut -d',' -f1 | tr -d ' ')
            gpu_mem_used=$(echo "$gpu_info" | cut -d',' -f2 | tr -d ' ')
            gpu_mem_total=$(echo "$gpu_info" | cut -d',' -f3 | tr -d ' ')
            gpu_util=$(echo "$gpu_info" | cut -d',' -f4 | tr -d ' ')
            gpu_temp=$(echo "$gpu_info" | cut -d',' -f5 | tr -d ' ')
        fi

        # 4. Process info
        local proc_info
        proc_info=$(get_process_info)
        if [[ -n "$proc_info" ]]; then
            process_pid=$(echo "$proc_info" | cut -d'|' -f1)
            process_uptime=$(echo "$proc_info" | cut -d'|' -f2)
        else
            if [[ "$overall_status" == "healthy" ]]; then
                overall_status="unhealthy"
            fi
        fi
    fi

    # ─── Output ──────────────────────────────────────────────────────────
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        cat <<JSONEOF
{
    "status": "$overall_status",
    "timestamp": "$timestamp",
    "server_url": "$SERVER_URL",
    "checks": {
        "http": {
            "status": "$http_status",
            "status_code": $http_code,
            "latency_ms": $http_latency_ms
        },
        "websocket": {
            "status": "$ws_status",
            "url": "$ws_url"
        }$(if [[ -n "$gpu_name" ]]; then cat <<GPU
,
        "gpu": {
            "name": "$gpu_name",
            "memory_used_mb": ${gpu_mem_used:-0},
            "memory_total_mb": ${gpu_mem_total:-0},
            "utilization_pct": ${gpu_util:-0},
            "temperature_c": ${gpu_temp:-0}
        }
GPU
fi)$(if [[ -n "$process_pid" ]]; then cat <<PROC
,
        "process": {
            "pid": $process_pid,
            "uptime": "$process_uptime"
        }
PROC
fi)
    }
}
JSONEOF
    else
        echo ""
        if [[ "$overall_status" == "healthy" ]]; then
            echo -e "${GREEN}✓ PersonaPlex Server: HEALTHY${NC}"
        elif [[ "$overall_status" == "degraded" ]]; then
            echo -e "${YELLOW}⚠ PersonaPlex Server: DEGRADED${NC}"
        else
            echo -e "${RED}✗ PersonaPlex Server: UNHEALTHY${NC}"
        fi
        echo -e "  ${BLUE}URL:${NC}       $SERVER_URL"
        echo -e "  ${BLUE}Time:${NC}      $timestamp"
        echo ""
        echo "  Checks:"

        # HTTP
        if [[ "$http_status" == "ok" ]]; then
            echo -e "    ${GREEN}✓${NC} HTTP:      $http_code (${http_latency_ms}ms)"
        else
            echo -e "    ${RED}✗${NC} HTTP:      $http_code ($http_status)"
        fi

        # WebSocket
        if [[ "$ws_status" == "ok" ]]; then
            echo -e "    ${GREEN}✓${NC} WebSocket: connected"
        elif [[ "$ws_status" == "skipped" ]]; then
            echo -e "    ${YELLOW}—${NC} WebSocket: skipped (no client available)"
        else
            echo -e "    ${RED}✗${NC} WebSocket: $ws_status"
        fi

        # GPU
        if [[ -n "$gpu_name" ]]; then
            echo -e "    ${GREEN}✓${NC} GPU:       $gpu_name (${gpu_mem_used}/${gpu_mem_total} MB, ${gpu_util}% util, ${gpu_temp}°C)"
        fi

        # Process
        if [[ -n "$process_pid" ]]; then
            echo -e "    ${GREEN}✓${NC} Process:   PID $process_pid (uptime: $process_uptime)"
        elif [[ "$LOCAL_CHECK" == "true" ]]; then
            echo -e "    ${RED}✗${NC} Process:   moshi.server not found"
        fi

        echo ""
    fi

    # Return appropriate exit code
    case "$overall_status" in
        healthy)  return 0 ;;
        degraded) return 0 ;;  # Still return 0 for degraded (server is reachable)
        *)        return 1 ;;
    esac
}

run_health_check
