#!/usr/bin/env bash
# setup_server.sh — Deploy PersonaPlex on a GPU instance
# Usage: ./setup_server.sh --provider runpod --gpu-type A100 [--region us-east-1] [--cpu-offload] [--port 8998]
#
# Providers: runpod, lambda, aws, local
# Installs dependencies, clones repo, launches server with SSL.

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
PROVIDER="local"
GPU_TYPE="A100"
REGION="us-east-1"
PORT=8998
CPU_OFFLOAD=""
INSTALL_DIR="${PERSONAPLEX_DIR:-$HOME/personaplex}"
LOG_FILE="/tmp/personaplex-setup.log"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[PersonaPlex]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }

# ─── Usage ───────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy PersonaPlex full-duplex speech-to-speech server on a GPU instance.

Options:
  --provider TYPE     Cloud provider: runpod, lambda, aws, local (default: local)
  --gpu-type TYPE     GPU type: A100, H100, A10G (default: A100)
  --region REGION     Cloud region for AWS (default: us-east-1)
  --port PORT         Server port (default: 8998)
  --cpu-offload       Enable CPU offload for limited VRAM GPUs
  --install-dir DIR   Installation directory (default: ~/personaplex)
  --help              Show this help message

Environment:
  HF_TOKEN            HuggingFace token (required, must accept model license first)
  PERSONAPLEX_DIR     Override installation directory

Examples:
  # Local deployment
  ./setup_server.sh --provider local

  # RunPod with A100
  ./setup_server.sh --provider runpod --gpu-type A100

  # AWS with CPU offload
  ./setup_server.sh --provider aws --gpu-type A10G --region us-west-2 --cpu-offload

  # Lambda Labs
  ./setup_server.sh --provider lambda --gpu-type A100
EOF
    exit 0
}

# ─── Parse Args ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --provider)     PROVIDER="$2"; shift 2 ;;
        --gpu-type)     GPU_TYPE="$2"; shift 2 ;;
        --region)       REGION="$2"; shift 2 ;;
        --port)         PORT="$2"; shift 2 ;;
        --cpu-offload)  CPU_OFFLOAD="--cpu-offload"; shift ;;
        --install-dir)  INSTALL_DIR="$2"; shift 2 ;;
        --help|-h)      usage ;;
        *)              error "Unknown option: $1"; usage ;;
    esac
done

# ─── Validation ──────────────────────────────────────────────────────────────
if [[ -z "${HF_TOKEN:-}" ]]; then
    error "HF_TOKEN environment variable is required."
    echo "  1. Accept the model license at: https://huggingface.co/nvidia/personaplex-7b-v1"
    echo "  2. Set your token: export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx"
    exit 1
fi

# ─── Provider-Specific Setup ────────────────────────────────────────────────
setup_provider() {
    case "$PROVIDER" in
        runpod)
            log "Setting up for RunPod ($GPU_TYPE)..."
            info "Recommended pod config:"
            info "  - Template: RunPod PyTorch 2.x"
            info "  - GPU: $GPU_TYPE 80GB"
            info "  - Container Disk: 50GB+"
            info "  - Volume: 100GB (for model cache)"
            info ""
            info "For RunPod Serverless, use this template:"
            info "  - Docker Image: nvidia/cuda:12.4.0-devel-ubuntu22.04"
            info "  - Handler: Custom (see docs)"
            info "  - GPU: $GPU_TYPE"
            ;;
        lambda)
            log "Setting up for Lambda Labs ($GPU_TYPE)..."
            info "Recommended instance:"
            info "  - GPU: 1x $GPU_TYPE (gpu_1x_${GPU_TYPE,,})"
            info "  - Region: auto-selected by availability"
            info "  - Storage: 200GB+"
            ;;
        aws)
            log "Setting up for AWS ($GPU_TYPE, $REGION)..."
            local instance_type
            case "$GPU_TYPE" in
                A100)  instance_type="p4d.24xlarge" ;;
                H100)  instance_type="p5.48xlarge" ;;
                A10G)  instance_type="g5.xlarge" ;;
                *)     instance_type="p4d.24xlarge" ;;
            esac
            info "Recommended instance: $instance_type"
            info "  - Region: $REGION"
            info "  - AMI: Deep Learning AMI (Ubuntu 22.04)"
            info "  - Storage: 200GB gp3"
            if [[ "$GPU_TYPE" == "A10G" ]]; then
                warn "A10G has 24GB VRAM — enabling --cpu-offload automatically"
                CPU_OFFLOAD="--cpu-offload"
            fi
            ;;
        local)
            log "Setting up for local deployment..."
            ;;
        *)
            error "Unknown provider: $PROVIDER"
            error "Supported: runpod, lambda, aws, local"
            exit 1
            ;;
    esac
}

# ─── Install System Dependencies ────────────────────────────────────────────
install_deps() {
    log "Installing system dependencies..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq libopus-dev git python3-pip curl jq 2>&1 | tail -5
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y opus-devel git python3-pip curl jq 2>&1 | tail -5
    elif command -v brew &>/dev/null; then
        brew install opus git curl jq 2>/dev/null || true
    else
        warn "Could not detect package manager. Please install libopus-dev manually."
    fi

    log "System dependencies installed."
}

# ─── Clone and Install PersonaPlex ───────────────────────────────────────────
install_personaplex() {
    log "Installing PersonaPlex to $INSTALL_DIR..."

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "Repository exists, pulling latest..."
        cd "$INSTALL_DIR"
        git pull --ff-only 2>/dev/null || warn "Could not pull latest (may have local changes)"
    else
        git clone https://github.com/NVIDIA/personaplex.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    # Install Python package
    log "Installing moshi package..."
    pip install moshi/. 2>&1 | tail -5

    # Install accelerate if CPU offload is requested
    if [[ -n "$CPU_OFFLOAD" ]]; then
        log "Installing accelerate for CPU offload..."
        pip install accelerate 2>&1 | tail -3
    fi

    # Blackwell GPU check
    if command -v nvidia-smi &>/dev/null; then
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
        if echo "$gpu_name" | grep -qi "b200\|b100"; then
            warn "Blackwell GPU detected ($gpu_name). Installing compatible PyTorch..."
            pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
        fi
        info "Detected GPU: $gpu_name"
    else
        warn "nvidia-smi not found — GPU may not be available"
    fi

    log "PersonaPlex installed successfully."
}

# ─── Launch Server ───────────────────────────────────────────────────────────
launch_server() {
    cd "$INSTALL_DIR"

    log "Launching PersonaPlex server..."
    info "  Port: $PORT"
    info "  CPU Offload: ${CPU_OFFLOAD:-disabled}"
    info "  Provider: $PROVIDER"
    info "  GPU Type: $GPU_TYPE"

    # Create SSL directory
    SSL_DIR=$(mktemp -d)
    info "  SSL Certs: $SSL_DIR"

    # Detect access URL
    local access_ip
    if [[ "$PROVIDER" == "local" ]]; then
        access_ip="localhost"
    else
        access_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "localhost")
    fi

    echo ""
    log "═══════════════════════════════════════════════════════════════"
    log "  PersonaPlex Server Starting"
    log "  Access WebUI at: https://${access_ip}:${PORT}"
    log "  WebSocket URL:   wss://${access_ip}:${PORT}/ws"
    log "═══════════════════════════════════════════════════════════════"
    echo ""

    # Save connection info
    cat > /tmp/personaplex-server.json <<CONNEOF
{
    "provider": "$PROVIDER",
    "gpu_type": "$GPU_TYPE",
    "url": "https://${access_ip}:${PORT}",
    "ws_url": "wss://${access_ip}:${PORT}/ws",
    "webui": "https://${access_ip}:${PORT}",
    "ssl_dir": "$SSL_DIR",
    "cpu_offload": $([ -n "$CPU_OFFLOAD" ] && echo "true" || echo "false"),
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
CONNEOF
    info "Connection info saved to /tmp/personaplex-server.json"

    # Launch
    export HF_TOKEN
    exec python -m moshi.server --ssl "$SSL_DIR" $CPU_OFFLOAD
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
    echo ""
    log "PersonaPlex Server Setup"
    log "Provider: $PROVIDER | GPU: $GPU_TYPE | Region: $REGION"
    echo ""

    setup_provider
    install_deps
    install_personaplex
    launch_server
}

main "$@"
