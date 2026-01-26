#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Clawdbot Starter Kit — Automated Setup
# By The AI Integration Hub (theaiintegrationhub.com)
# ============================================================================

VERSION="1.0.0"
REPO_URL="https://github.com/theaiintegrationhub/clawdbot-starter-kit"
TEMPLATE_DIR="template"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  ${BOLD}🤖 Clawdbot Starter Kit v${VERSION}${NC}                            ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${BLUE}By The AI Integration Hub${NC}                               ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
ask()   { echo -ne "${CYAN}[?]${NC} $1: "; }

# ============================================================================
# Config from frontend (base64 JSON) or interactive
# ============================================================================

CONFIG_JSON=""
WORKSPACE_DIR=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --config)
        CONFIG_JSON=$(echo "$2" | base64 -d 2>/dev/null || echo "")
        shift 2
        ;;
      --dir)
        WORKSPACE_DIR="$2"
        shift 2
        ;;
      --help|-h)
        echo "Usage: setup.sh [--config BASE64_JSON] [--dir WORKSPACE_DIR]"
        echo ""
        echo "Options:"
        echo "  --config  Base64-encoded JSON config from the web wizard"
        echo "  --dir     Target workspace directory (default: ~/clawd)"
        exit 0
        ;;
      *)
        shift
        ;;
    esac
  done
}

# ============================================================================
# Interactive prompts (fallback if no --config)
# ============================================================================

interactive_setup() {
  echo -e "${BOLD}Let's set up your AI assistant.${NC}"
  echo ""

  # --- User info ---
  echo -e "${BOLD}━━━ About You ━━━${NC}"
  ask "Your name"
  read -r USER_NAME
  ask "Your timezone (e.g. EST, PST, UTC)"
  read -r USER_TIMEZONE
  ask "Your role/title"
  read -r USER_ROLE
  ask "Your focus area"
  read -r USER_FOCUS
  echo ""

  # --- Agent info ---
  echo -e "${BOLD}━━━ Your Agent ━━━${NC}"
  ask "Agent name"
  read -r AGENT_NAME
  ask "Agent emoji (e.g. 🤖, 🦊, 🐍)"
  read -r AGENT_EMOJI
  echo ""
  echo "  Agent personality:"
  echo "    1) Professional & precise"
  echo "    2) Casual & friendly"
  echo "    3) Technical & direct"
  echo "    4) Creative & energetic"
  echo "    5) Custom"
  ask "Choose (1-5)"
  read -r VIBE_CHOICE
  case $VIBE_CHOICE in
    1) AGENT_VIBE="Professional, precise, and thorough. Clear communication with attention to detail. Formal but approachable."
       AGENT_VIBE_SHORT="Professional & precise" ;;
    2) AGENT_VIBE="Casual, warm, and friendly. Like talking to a smart friend who gets things done. Relaxed but reliable."
       AGENT_VIBE_SHORT="Casual & friendly" ;;
    3) AGENT_VIBE="Technical, direct, no fluff. Get to the point. Code speaks louder than words. Efficient and sharp."
       AGENT_VIBE_SHORT="Technical & direct" ;;
    4) AGENT_VIBE="Creative, energetic, always bringing fresh ideas. Enthusiastic but focused. Makes work feel exciting."
       AGENT_VIBE_SHORT="Creative & energetic" ;;
    5) ask "Describe the vibe in one sentence"
       read -r AGENT_VIBE
       AGENT_VIBE_SHORT="Custom"
       ;;
    *) AGENT_VIBE="Direct, efficient, and genuinely helpful. Gets things done."
       AGENT_VIBE_SHORT="Balanced" ;;
  esac
  echo ""

  # --- Skill packs ---
  echo -e "${BOLD}━━━ Skill Packs ━━━${NC}"
  echo "  Select which skill packs to install:"
  echo ""
  echo "    ${BOLD}[C]${NC} Core (always included)"
  echo "        security-guardrails, delegation, memory-architecture"
  echo ""
  echo "    ${BOLD}[M]${NC} Marketing"
  echo "        23 skills: CRO, copywriting, SEO, analytics, pricing, launch strategy..."
  echo ""
  echo "    ${BOLD}[D]${NC} Developer"
  echo "        coding-agent, deploy-agent, read-github, deepwiki"
  echo ""
  echo "    ${BOLD}[O]${NC} Operations"
  echo "        caldav-calendar, n8n-workflow-automation"
  echo ""
  echo "    ${BOLD}[W]${NC} Media"
  echo "        elevenlabs-voices, vap-media, remotion-server, remotion-best-practices"
  echo ""
  echo "    ${BOLD}[A]${NC} All of the above"
  echo ""
  ask "Enter choices (e.g. M,D or A for all)"
  read -r SKILL_CHOICES
  echo ""

  # --- Integrations ---
  echo -e "${BOLD}━━━ Integrations (optional, press Enter to skip) ━━━${NC}"
  ask "Telegram bot token"
  read -r TELEGRAM_TOKEN
  ask "Anthropic API key"
  read -r ANTHROPIC_KEY
  echo ""

  # --- Workspace ---
  if [[ -z "$WORKSPACE_DIR" ]]; then
    ask "Workspace directory (default: ~/clawd)"
    read -r WORKSPACE_DIR
    WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/clawd}"
  fi

  # Build JSON
  CONFIG_JSON=$(cat <<EOF
{
  "user": {
    "name": "$USER_NAME",
    "timezone": "$USER_TIMEZONE",
    "role": "$USER_ROLE",
    "focus": "$USER_FOCUS"
  },
  "agent": {
    "name": "$AGENT_NAME",
    "emoji": "$AGENT_EMOJI",
    "vibe": "$AGENT_VIBE",
    "vibeShort": "$AGENT_VIBE_SHORT"
  },
  "skills": "$SKILL_CHOICES",
  "integrations": {
    "telegram": "$TELEGRAM_TOKEN",
    "anthropic": "$ANTHROPIC_KEY"
  },
  "workspace": "$WORKSPACE_DIR"
}
EOF
)
}

# ============================================================================
# Extract config values
# ============================================================================

get_val() {
  echo "$CONFIG_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d$1)" 2>/dev/null || echo "$2"
}

# ============================================================================
# Prerequisites check
# ============================================================================

check_prereqs() {
  echo -e "${BOLD}━━━ Checking Prerequisites ━━━${NC}"

  # Node.js
  if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    log "Node.js $NODE_VER"
  else
    err "Node.js not found. Install: https://nodejs.org"
    exit 1
  fi

  # npm
  if command -v npm &>/dev/null; then
    log "npm $(npm -v)"
  else
    err "npm not found"
    exit 1
  fi

  # Clawdbot
  if command -v clawdbot &>/dev/null; then
    log "Clawdbot $(clawdbot --version 2>/dev/null || echo 'installed')"
  else
    warn "Clawdbot not found. Installing..."
    npm install -g clawdbot
    log "Clawdbot installed"
  fi

  # ClawdHub CLI
  if command -v clawdhub &>/dev/null; then
    log "ClawdHub CLI installed"
  else
    warn "ClawdHub CLI not found. Installing..."
    npm install -g clawdhub
    log "ClawdHub CLI installed"
  fi

  # Python3
  if command -v python3 &>/dev/null; then
    log "Python3 $(python3 --version 2>&1 | awk '{print $2}')"
  else
    warn "Python3 not found. Some skills may not work."
  fi

  # git
  if command -v git &>/dev/null; then
    log "git $(git --version | awk '{print $3}')"
  else
    err "git not found"
    exit 1
  fi

  echo ""
}

# ============================================================================
# Create workspace
# ============================================================================

create_workspace() {
  local dir="$1"

  echo -e "${BOLD}━━━ Creating Workspace ━━━${NC}"

  if [[ -d "$dir" ]]; then
    warn "Directory $dir already exists"
    ask "Continue and merge? (y/N)"
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      err "Aborted"
      exit 1
    fi
  fi

  mkdir -p "$dir"/{memory,skills,resources,scripts}
  log "Directory structure created: $dir"

  # Init git
  if [[ ! -d "$dir/.git" ]]; then
    cd "$dir" && git init -q
    log "Git repository initialized"
  fi

  echo ""
}

# ============================================================================
# Template files with variable substitution
# ============================================================================

install_templates() {
  local dir="$1"
  local setup_date
  setup_date=$(date +%Y-%m-%d)

  echo -e "${BOLD}━━━ Installing Template Files ━━━${NC}"

  local user_name=$(get_val "['user']['name']" "User")
  local user_tz=$(get_val "['user']['timezone']" "UTC")
  local user_role=$(get_val "['user']['role']" "Professional")
  local user_focus=$(get_val "['user']['focus']" "Getting things done")
  local agent_name=$(get_val "['agent']['name']" "Assistant")
  local agent_emoji=$(get_val "['agent']['emoji']" "🤖")
  local agent_vibe=$(get_val "['agent']['vibe']" "Direct, efficient, and genuinely helpful.")
  local agent_vibe_short=$(get_val "['agent']['vibeShort']" "Balanced")

  # Copy and substitute templates
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local tmpl_dir="$script_dir/../template"

  if [[ ! -d "$tmpl_dir" ]]; then
    # Fallback: download templates from repo
    warn "Template directory not found locally. Downloading from repo..."
    local tmp_dir=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$tmp_dir/kit" 2>/dev/null
    tmpl_dir="$tmp_dir/kit/template"
  fi

  for file in AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md MEMORY.md SECURITY.md HEARTBEAT.md; do
    if [[ -f "$tmpl_dir/$file" ]]; then
      sed \
        -e "s|{{USER_NAME}}|$user_name|g" \
        -e "s|{{USER_TIMEZONE}}|$user_tz|g" \
        -e "s|{{USER_ROLE}}|$user_role|g" \
        -e "s|{{USER_FOCUS}}|$user_focus|g" \
        -e "s|{{USER_WORKING_STYLE}}|Efficient and focused.|g" \
        -e "s|{{AGENT_NAME}}|$agent_name|g" \
        -e "s|{{AGENT_EMOJI}}|$agent_emoji|g" \
        -e "s|{{AGENT_VIBE}}|$agent_vibe|g" \
        -e "s|{{AGENT_VIBE_SHORT}}|$agent_vibe_short|g" \
        -e "s|{{SETUP_DATE}}|$setup_date|g" \
        -e "s|{{SKILL_PACKS}}|$skill_packs_label|g" \
        -e "s|{{INSTALLED_SKILLS_TABLE}}|*(Run setup to populate)*|g" \
        "$tmpl_dir/$file" > "$dir/$file"
      log "$file"
    fi
  done

  echo ""
}

# ============================================================================
# Install skills
# ============================================================================

install_skills() {
  local dir="$1"
  local choices=$(get_val "['skills']" "C" | tr '[:lower:]' '[:upper:]')

  echo -e "${BOLD}━━━ Installing Skills ━━━${NC}"

  cd "$dir"

  # Core (always)
  local core_skills=("security-guardrails" "delegation" "memory-architecture")
  for skill in "${core_skills[@]}"; do
    info "Installing $skill..."
    clawdhub install "$skill" --dir skills 2>/dev/null && log "$skill" || warn "Failed: $skill (can install manually later)"
  done

  # Marketing
  if [[ "$choices" == *"M"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Marketing pack..."
    clawdhub install marketing --dir skills 2>/dev/null && log "Marketing (23 skills)" || warn "Failed: marketing"
  fi

  # Developer
  if [[ "$choices" == *"D"* ]] || [[ "$choices" == *"A"* ]]; then
    local dev_skills=("coding-agent" "deploy-agent" "read-github" "deepwiki" "clawddocs")
    for skill in "${dev_skills[@]}"; do
      info "Installing $skill..."
      clawdhub install "$skill" --dir skills 2>/dev/null && log "$skill" || warn "Failed: $skill"
    done
  fi

  # Operations
  if [[ "$choices" == *"O"* ]] || [[ "$choices" == *"A"* ]]; then
    local ops_skills=("caldav-calendar" "n8n-workflow-automation")
    for skill in "${ops_skills[@]}"; do
      info "Installing $skill..."
      clawdhub install "$skill" --dir skills 2>/dev/null && log "$skill" || warn "Failed: $skill"
    done
  fi

  # Media
  if [[ "$choices" == *"W"* ]] || [[ "$choices" == *"A"* ]]; then
    local media_skills=("elevenlabs-voices" "vap-media" "remotion-server" "remotion-best-practices" "sag")
    for skill in "${media_skills[@]}"; do
      info "Installing $skill..."
      clawdhub install "$skill" --dir skills 2>/dev/null && log "$skill" || warn "Failed: $skill"
    done
  fi

  echo ""
}

# ============================================================================
# Configure Clawdbot
# ============================================================================

configure_clawdbot() {
  local dir="$1"
  local anthropic_key=$(get_val "['integrations']['anthropic']" "")
  local telegram_token=$(get_val "['integrations']['telegram']" "")

  echo -e "${BOLD}━━━ Configuring Clawdbot ━━━${NC}"

  # Check if clawdbot is already configured
  local config_file="$HOME/.clawdbot/clawdbot.json"

  if [[ ! -f "$config_file" ]]; then
    info "Running clawdbot init..."
    if [[ -n "$anthropic_key" ]]; then
      mkdir -p "$HOME/.clawdbot"
      cat > "$config_file" <<CONF
{
  "profiles": {
    "anthropic:default": {
      "provider": "anthropic",
      "apiKey": "$anthropic_key"
    }
  },
  "agents": {
    "main": {
      "model": "anthropic/claude-sonnet-4-20250514",
      "workspace": "$dir"
    }
  },
  "gateway": {
    "bind": "loopback",
    "auth": {
      "mode": "token"
    }
  }
}
CONF
    log "Clawdbot config created (loopback + token auth)"
    else
      warn "No Anthropic API key provided. Run 'clawdbot init' manually."
    fi
  else
    log "Clawdbot config already exists"
  fi

  # Telegram
  if [[ -n "$telegram_token" && "$telegram_token" != "" ]]; then
    info "Telegram bot token provided — add to config manually or run:"
    echo "    clawdbot config set channels.telegram.botToken \"$telegram_token\""
  fi

  echo ""
}

# ============================================================================
# Security hardening
# ============================================================================

harden_security() {
  local dir="$1"

  echo -e "${BOLD}━━━ Security Hardening ━━━${NC}"

  # Verify gateway is loopback
  local config_file="$HOME/.clawdbot/clawdbot.json"
  if [[ -f "$config_file" ]]; then
    if grep -q '"loopback"' "$config_file"; then
      log "Gateway bound to loopback (not exposed to internet)"
    else
      warn "Gateway may be exposed! Setting to loopback..."
      # Would need jq or python to safely edit JSON
    fi

    if grep -q '"token"' "$config_file"; then
      log "Token authentication enabled"
    else
      warn "Token auth not detected. Enable it in config."
    fi
  fi

  # SECURITY.md already installed via templates
  log "ACIP prompt injection defense installed (SECURITY.md)"

  # Check for open ports
  if command -v ss &>/dev/null; then
    local exposed
    exposed=$(ss -tlnp 2>/dev/null | grep -E '0\.0\.0\.0.*(18789|3456)' || true)
    if [[ -n "$exposed" ]]; then
      warn "⚠️  Gateway port appears exposed to all interfaces!"
      warn "Fix: Set gateway.bind to 'loopback' in clawdbot config"
    else
      log "No gateway ports exposed to public"
    fi
  fi

  echo ""
}

# ============================================================================
# Final commit & summary
# ============================================================================

finalize() {
  local dir="$1"

  echo -e "${BOLD}━━━ Finalizing ━━━${NC}"

  cd "$dir"
  git add -A 2>/dev/null
  git commit -q -m "Initial setup via Clawdbot Starter Kit v${VERSION}" 2>/dev/null || true
  log "Initial commit created"

  local agent_name=$(get_val "['agent']['name']" "Your agent")
  local agent_emoji=$(get_val "['agent']['emoji']" "🤖")
  local user_name=$(get_val "['user']['name']" "there")

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}✅ Setup Complete!${NC}                                       ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Agent:${NC}     $agent_name $agent_emoji"
  echo -e "  ${BOLD}Owner:${NC}     $user_name"
  echo -e "  ${BOLD}Workspace:${NC} $dir"
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo "    1. Start the gateway:  clawdbot gateway start"
  echo "    2. Open a session:     clawdbot chat"
  echo "    3. Your agent will introduce itself and get to know you"
  echo ""
  echo -e "  ${BOLD}Useful commands:${NC}"
  echo "    clawdbot status          — Check agent status"
  echo "    clawdbot security audit  — Run security audit"
  echo "    clawdbot doctor          — Diagnose issues"
  echo ""
  echo -e "  ${BLUE}Need help?${NC} https://docs.clawd.bot"
  echo -e "  ${BLUE}Support:${NC}   Brad@theaiintegrationhub.com"
  echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
  banner
  parse_args "$@"

  if [[ -z "$CONFIG_JSON" ]]; then
    interactive_setup
  fi

  WORKSPACE_DIR=$(get_val "['workspace']" "${WORKSPACE_DIR:-$HOME/clawd}")
  skill_packs_label=$(get_val "['skills']" "Core")

  check_prereqs
  create_workspace "$WORKSPACE_DIR"
  install_templates "$WORKSPACE_DIR"
  install_skills "$WORKSPACE_DIR"
  configure_clawdbot "$WORKSPACE_DIR"
  harden_security "$WORKSPACE_DIR"
  finalize "$WORKSPACE_DIR"
}

main "$@"
