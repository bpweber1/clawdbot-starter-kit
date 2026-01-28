#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Clawdbot Starter Kit — Automated Setup
# By The AI Integration Hub (theaiintegrationhub.com)
# ============================================================================

VERSION="1.1.0"
REPO_URL="https://github.com/bpweber1/clawdbot-starter-kit"
TEMPLATE_DIR="template"
LOG_FILE="/tmp/clawdbot-setup-$(date +%Y%m%d-%H%M%S).log"
FAILED_SKILLS=()
SETUP_STEP=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_TMP_DIR=""

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
  echo -e "${CYAN}║${NC}  ${BOLD}Clawdbot Starter Kit v${VERSION}${NC}                              ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ${BLUE}By The AI Integration Hub${NC}                               ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "  Log file: $LOG_FILE"
  echo ""
}

log()   { echo -e "${GREEN}[✓]${NC} $1"; echo "[$(date +%H:%M:%S)] OK: $1" >> "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; echo "[$(date +%H:%M:%S)] WARN: $1" >> "$LOG_FILE"; }
err()   { echo -e "${RED}[✗]${NC} $1"; echo "[$(date +%H:%M:%S)] ERR: $1" >> "$LOG_FILE"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; echo "[$(date +%H:%M:%S)] INFO: $1" >> "$LOG_FILE"; }
ask()   { echo -ne "${CYAN}[?]${NC} $1: "; }

# Error handler for resume capability
on_error() {
  err "Setup failed at step: $SETUP_STEP"
  err "Check log: $LOG_FILE"
  echo ""
  echo -e "  ${BOLD}To resume, re-run the same command.${NC}"
  echo -e "  Already-completed steps will be skipped."
  echo ""
}
trap on_error ERR

# ============================================================================
# Cross-platform base64 decode
# ============================================================================

b64decode() {
  # macOS uses -D, Linux uses -d, both support --decode
  if base64 --decode <<< "$1" 2>/dev/null; then
    return
  elif base64 -d <<< "$1" 2>/dev/null; then
    return
  elif base64 -D <<< "$1" 2>/dev/null; then
    return
  else
    echo ""
    return 1
  fi
}

# ============================================================================
# Detect OS
# ============================================================================

detect_os() {
  local uname_out
  uname_out="$(uname -s)"
  case "$uname_out" in
    Linux*)   OS_TYPE="linux" ;;
    Darwin*)  OS_TYPE="mac" ;;
    CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
    *)        OS_TYPE="linux" ;;
  esac
  echo "[$(date +%H:%M:%S)] OS detected: $OS_TYPE ($uname_out)" >> "$LOG_FILE"
}

# ============================================================================
# Config from frontend (base64 JSON) or interactive
# ============================================================================

CONFIG_JSON=""
WORKSPACE_DIR=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --config)
        CONFIG_JSON=$(b64decode "$2" 2>/dev/null || echo "")
        if [[ -z "$CONFIG_JSON" ]]; then
          err "Failed to decode config. Check the base64 string."
          exit 1
        fi
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
  echo "    ${BOLD}[M]${NC} Marketing (23 skills)"
  echo "    ${BOLD}[D]${NC} Developer (5 skills)"
  echo "    ${BOLD}[O]${NC} Operations (2 skills)"
  echo "    ${BOLD}[W]${NC} Media (5 skills)"
  echo "    ${BOLD}[R]${NC} Research (3 skills) — QMD, last30days, Crabwalk"
  echo "    ${BOLD}[V]${NC} Voice (1 skill) — PersonaPlex full-duplex AI"
  echo "    ${BOLD}[A]${NC} All of the above"
  echo ""
  ask "Enter choices (e.g. M,D or A for all)"
  read -r SKILL_CHOICES
  echo ""

  # --- Integrations ---
  echo -e "${BOLD}━━━ Integrations (optional, press Enter to skip) ━━━${NC}"
  ask "Telegram bot token"
  read -r TELEGRAM_TOKEN
  echo ""
  echo "  Authentication mode:"
  echo "    1) Anthropic API Key"
  echo "    2) Claude Max session token"
  ask "Choose (1-2)"
  read -r AUTH_CHOICE
  if [[ "$AUTH_CHOICE" == "2" ]]; then
    ask "Claude Max session token"
    read -r CLAUDE_MAX_TOKEN
    ANTHROPIC_KEY=""
  else
    ask "Anthropic API key"
    read -r ANTHROPIC_KEY
    CLAUDE_MAX_TOKEN=""
  fi
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
    "anthropic": "$ANTHROPIC_KEY",
    "claudeMax": "$CLAUDE_MAX_TOKEN"
  },
  "workspace": "$WORKSPACE_DIR"
}
EOF
)
}

# ============================================================================
# Extract config values (with nested key support)
# ============================================================================

get_val() {
  echo "$CONFIG_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    keys = $1
    val = d
    for k in keys:
        val = val[k]
    print(val)
except:
    print('$2')
" 2>/dev/null || echo "$2"
}

# ============================================================================
# Prerequisites check
# ============================================================================

check_prereqs() {
  SETUP_STEP="prerequisites"
  echo -e "${BOLD}━━━ Checking Prerequisites ━━━${NC}"

  detect_os
  log "Operating system: $OS_TYPE"

  # Node.js
  if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    log "Node.js $NODE_VER"
    # Check minimum version (18+)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if [[ "$NODE_MAJOR" -lt 18 ]]; then
      warn "Node.js 18+ recommended. You have $NODE_VER"
    fi
  else
    err "Node.js not found."
    if [[ "$OS_TYPE" == "mac" ]]; then
      echo "    Install: brew install node"
    else
      echo "    Install: https://nodejs.org or: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs"
    fi
    exit 1
  fi

  # npm
  if command -v npm &>/dev/null; then
    log "npm $(npm -v)"
  else
    err "npm not found"
    exit 1
  fi

  # git
  if command -v git &>/dev/null; then
    log "git $(git --version | awk '{print $3}')"
  else
    err "git not found"
    if [[ "$OS_TYPE" == "mac" ]]; then
      echo "    Install: xcode-select --install"
    else
      echo "    Install: sudo apt-get install -y git"
    fi
    exit 1
  fi

  # Python3 (needed for config parsing)
  if command -v python3 &>/dev/null; then
    log "Python3 $(python3 --version 2>&1 | awk '{print $2}')"
  else
    err "Python3 not found (required for config parsing)"
    if [[ "$OS_TYPE" == "mac" ]]; then
      echo "    Install: brew install python3"
    else
      echo "    Install: sudo apt-get install -y python3"
    fi
    exit 1
  fi

  # Clawdbot
  if command -v clawdbot &>/dev/null; then
    log "Clawdbot $(clawdbot --version 2>/dev/null || echo 'installed')"
  else
    warn "Clawdbot not found. Installing..."
    npm install -g clawdbot 2>> "$LOG_FILE"
    if command -v clawdbot &>/dev/null; then
      log "Clawdbot installed"
    else
      err "Failed to install Clawdbot. Check npm permissions."
      echo "    Try: sudo npm install -g clawdbot"
      exit 1
    fi
  fi

  # ClawdHub CLI (optional — we have fallback)
  if command -v clawdhub &>/dev/null; then
    log "ClawdHub CLI installed"
  else
    info "ClawdHub CLI not found. Installing..."
    npm install -g clawdhub 2>> "$LOG_FILE" || warn "ClawdHub CLI install failed (will use git fallback for skills)"
  fi

  echo ""
}

# ============================================================================
# Create workspace
# ============================================================================

create_workspace() {
  local dir="$1"
  SETUP_STEP="workspace"

  echo -e "${BOLD}━━━ Creating Workspace ━━━${NC}"

  if [[ -d "$dir" && -f "$dir/AGENTS.md" ]]; then
    warn "Workspace already exists at $dir"
    ask "Continue and update? Existing files will be preserved. (y/N)"
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
  SETUP_STEP="templates"

  echo -e "${BOLD}━━━ Installing Template Files ━━━${NC}"

  local user_name=$(get_val "['user','name']" "User")
  local user_tz=$(get_val "['user','timezone']" "UTC")
  local user_role=$(get_val "['user','role']" "Professional")
  local user_focus=$(get_val "['user','focus']" "Getting things done")
  local user_style=$(get_val "['user','style']" "Efficient and focused.")
  local agent_name=$(get_val "['agent','name']" "Assistant")
  local agent_emoji=$(get_val "['agent','emoji']" "🤖")
  local agent_vibe=$(get_val "['agent','vibe']" "Direct, efficient, and genuinely helpful.")
  local agent_vibe_short=$(get_val "['agent','vibeShort']" "Balanced")

  # Download kit from repo (always fresh — includes templates + bundled skills)
  local tmp_dir
  tmp_dir=$(mktemp -d)
  info "Downloading starter kit..."
  if git clone --depth 1 "$REPO_URL" "$tmp_dir/kit" 2>> "$LOG_FILE"; then
    log "Starter kit downloaded"
  else
    err "Failed to download starter kit from $REPO_URL"
    exit 1
  fi
  local tmpl_dir="$tmp_dir/kit/template"
  # Export for bundled skill access
  KIT_TMP_DIR="$tmp_dir/kit"
  export KIT_TMP_DIR

  for file in AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md MEMORY.md SECURITY.md HEARTBEAT.md; do
    if [[ -f "$tmpl_dir/$file" ]]; then
      # Skip if file already exists (preserve user edits on re-run)
      if [[ -f "$dir/$file" ]]; then
        warn "$file already exists — skipping (preserving your edits)"
        continue
      fi
      sed \
        -e "s|{{USER_NAME}}|$user_name|g" \
        -e "s|{{USER_TIMEZONE}}|$user_tz|g" \
        -e "s|{{USER_ROLE}}|$user_role|g" \
        -e "s|{{USER_FOCUS}}|$user_focus|g" \
        -e "s|{{USER_WORKING_STYLE}}|$user_style|g" \
        -e "s|{{AGENT_NAME}}|$agent_name|g" \
        -e "s|{{AGENT_EMOJI}}|$agent_emoji|g" \
        -e "s|{{AGENT_VIBE}}|$agent_vibe|g" \
        -e "s|{{AGENT_VIBE_SHORT}}|$agent_vibe_short|g" \
        -e "s|{{SETUP_DATE}}|$setup_date|g" \
        -e "s|{{SKILL_PACKS}}|$skill_packs_label|g" \
        -e "s|{{INSTALLED_SKILLS_TABLE}}|*(Skills installed by setup)*|g" \
        "$tmpl_dir/$file" > "$dir/$file"
      log "$file"
    fi
  done

  echo ""
}

# ============================================================================
# Install skills (with ClawdHub fallback to git)
# ============================================================================

install_skill() {
  local skill_name="$1"
  local target_dir="$2"

  # Check if bundled in starter kit first (local install)
  local bundled_dir="$SCRIPT_DIR/../skills-bundled/$skill_name"
  
  if [[ -d "$bundled_dir" ]]; then
    cp -r "$bundled_dir" "$target_dir/$skill_name"
    log "$skill_name (bundled)"
    return 0
  fi

  # Check if bundled in downloaded kit
  if [[ -n "${KIT_TMP_DIR:-}" && -d "$KIT_TMP_DIR/skills-bundled/$skill_name" ]]; then
    cp -r "$KIT_TMP_DIR/skills-bundled/$skill_name" "$target_dir/$skill_name"
    log "$skill_name (bundled)"
    return 0
  fi

  # Try ClawdHub (with timeout)
  if command -v clawdhub &>/dev/null; then
    if timeout 30 clawdhub install "$skill_name" --dir "$target_dir" 2>> "$LOG_FILE"; then
      log "$skill_name"
      return 0
    fi
  fi

  # Fallback: try direct git clone from ClawdHub
  local skill_url="https://github.com/clawdbot/skill-$skill_name"
  if git clone --depth 1 "$skill_url" "$target_dir/$skill_name" 2>> "$LOG_FILE"; then
    rm -rf "$target_dir/$skill_name/.git"
    log "$skill_name (via git)"
    return 0
  fi

  # All methods failed
  warn "Failed to install: $skill_name (install manually later)"
  FAILED_SKILLS+=("$skill_name")
  return 0  # Don't abort on skill failure
}

install_skills() {
  local dir="$1"
  local choices=$(get_val "['skills']" "C" | tr '[:lower:]' '[:upper:]')
  SETUP_STEP="skills"

  echo -e "${BOLD}━━━ Installing Skills ━━━${NC}"

  local skills_dir="$dir/skills"
  mkdir -p "$skills_dir"

  # Core (always)
  info "Installing Core skills..."
  for skill in security-guardrails delegation memory-architecture; do
    if [[ -d "$skills_dir/$skill" ]]; then
      log "$skill (already installed)"
    else
      install_skill "$skill" "$skills_dir"
    fi
  done

  # Marketing
  if [[ "$choices" == *"M"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Marketing pack..."
    if [[ -d "$skills_dir/marketing" ]]; then
      log "Marketing (already installed)"
    else
      install_skill "marketing" "$skills_dir"
    fi
  fi

  # Developer
  if [[ "$choices" == *"D"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Developer pack..."
    for skill in coding-agent deploy-agent read-github deepwiki clawddocs; do
      if [[ -d "$skills_dir/$skill" ]]; then
        log "$skill (already installed)"
      else
        install_skill "$skill" "$skills_dir"
      fi
    done
  fi

  # Operations
  if [[ "$choices" == *"O"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Operations pack..."
    for skill in caldav-calendar n8n-workflow-automation; do
      if [[ -d "$skills_dir/$skill" ]]; then
        log "$skill (already installed)"
      else
        install_skill "$skill" "$skills_dir"
      fi
    done
  fi

  # Media
  if [[ "$choices" == *"W"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Media pack..."
    for skill in elevenlabs-voices vap-media remotion-server remotion-best-practices sag; do
      if [[ -d "$skills_dir/$skill" ]]; then
        log "$skill (already installed)"
      else
        install_skill "$skill" "$skills_dir"
      fi
    done
  fi

  # Research
  if [[ "$choices" == *"R"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Research pack..."
    for skill in qmd last30days crabwalk; do
      if [[ -d "$skills_dir/$skill" ]]; then
        log "$skill (already installed)"
      else
        install_skill "$skill" "$skills_dir"
      fi
    done
  fi

  # Voice
  if [[ "$choices" == *"V"* ]] || [[ "$choices" == *"A"* ]]; then
    info "Installing Voice pack..."
    for skill in personaplex; do
      if [[ -d "$skills_dir/$skill" ]]; then
        log "$skill (already installed)"
      else
        install_skill "$skill" "$skills_dir"
      fi
    done
  fi

  if [[ ${#FAILED_SKILLS[@]} -gt 0 ]]; then
    warn "${#FAILED_SKILLS[@]} skill(s) failed to install: ${FAILED_SKILLS[*]}"
    warn "Install them manually later with: clawdhub install <skill-name>"
  fi

  # Cleanup downloaded kit
  if [[ -n "${KIT_TMP_DIR:-}" && -d "${KIT_TMP_DIR%/*}" ]]; then
    rm -rf "${KIT_TMP_DIR%/*}"
  fi

  echo ""
}

# ============================================================================
# Configure Clawdbot (supports API key, Claude Max, and additional keys)
# ============================================================================

configure_clawdbot() {
  local dir="$1"
  SETUP_STEP="configure"

  local anthropic_key=$(get_val "['integrations','anthropic']" "")
  local claude_max=$(get_val "['integrations','claudeMax']" "")
  local telegram_token=$(get_val "['integrations','telegram']" "")
  local openai_key=$(get_val "['integrations','openai']" "")
  local elevenlabs_key=$(get_val "['integrations','elevenlabs']" "")
  local brave_key=$(get_val "['integrations','brave']" "")

  echo -e "${BOLD}━━━ Configuring Clawdbot ━━━${NC}"

  local config_dir="$HOME/.clawdbot"
  local config_file="$config_dir/clawdbot.json"

  if [[ -f "$config_file" ]]; then
    log "Clawdbot config already exists — preserving"
    # Still add telegram if provided
    if [[ -n "$telegram_token" ]]; then
      info "To add Telegram, run:"
      echo "    clawdbot config set channels.telegram.botToken \"$telegram_token\""
    fi
    echo ""
    return
  fi

  mkdir -p "$config_dir"

  # Determine auth config
  local auth_block=""
  if [[ -n "$anthropic_key" ]]; then
    auth_block=$(cat <<AUTHEOF
    "anthropic:default": {
      "provider": "anthropic",
      "apiKey": "$anthropic_key"
    }
AUTHEOF
)
    log "Auth: Anthropic API Key configured"
  elif [[ -n "$claude_max" ]]; then
    auth_block=$(cat <<AUTHEOF
    "anthropic:default": {
      "provider": "anthropic",
      "sessionKey": "$claude_max"
    }
AUTHEOF
)
    log "Auth: Claude Max token configured"
  else
    warn "No authentication configured. You'll need to set this up manually."
    warn "Run: clawdbot init"
    echo ""
    return
  fi

  # Build Telegram channel config
  local telegram_block=""
  if [[ -n "$telegram_token" ]]; then
    telegram_block=$(cat <<TELEOF
  "channels": {
    "telegram": {
      "botToken": "$telegram_token"
    }
  },
TELEOF
)
    log "Telegram bot configured"
  fi

  # Write config
  cat > "$config_file" <<CONF
{
  "profiles": {
$auth_block
  },
  "agents": {
    "defaults": {
      "compaction": {
        "memoryFlush": {
          "enabled": true
        }
      },
      "memorySearch": {
        "experimental": {
          "sessionMemory": true
        },
        "sources": ["memory", "sessions"]
      }
    },
    "main": {
      "model": "anthropic/claude-sonnet-4-20250514",
      "workspace": "$dir"
    }
  },
  $telegram_block
  "gateway": {
    "bind": "loopback",
    "auth": {
      "mode": "token"
    }
  }
}
CONF

  log "Clawdbot config created (loopback + token auth)"

  # Store additional API keys in workspace config
  local keys_dir="$dir/.config"
  mkdir -p "$keys_dir"

  if [[ -n "$openai_key" ]]; then
    echo "OPENAI_API_KEY=$openai_key" > "$keys_dir/openai.env"
    chmod 600 "$keys_dir/openai.env"
    log "OpenAI API key stored"
  fi

  if [[ -n "$elevenlabs_key" ]]; then
    echo "ELEVENLABS_API_KEY=$elevenlabs_key" > "$keys_dir/elevenlabs.env"
    chmod 600 "$keys_dir/elevenlabs.env"
    log "ElevenLabs API key stored"
  fi

  if [[ -n "$brave_key" ]]; then
    echo "BRAVE_API_KEY=$brave_key" > "$keys_dir/brave.env"
    chmod 600 "$keys_dir/brave.env"
    log "Brave Search API key stored"
  fi

  # Add .config to gitignore
  if [[ -f "$dir/.gitignore" ]]; then
    grep -q '.config/' "$dir/.gitignore" || echo '.config/' >> "$dir/.gitignore"
  else
    echo '.config/' > "$dir/.gitignore"
  fi

  echo ""
}

# ============================================================================
# Security hardening
# ============================================================================

harden_security() {
  local dir="$1"
  SETUP_STEP="security"

  echo -e "${BOLD}━━━ Security Hardening ━━━${NC}"

  local config_file="$HOME/.clawdbot/clawdbot.json"
  if [[ -f "$config_file" ]]; then
    if grep -q '"loopback"' "$config_file"; then
      log "Gateway bound to loopback (not exposed to internet)"
    else
      warn "Gateway may be exposed. Setting bind to loopback recommended."
    fi

    if grep -q '"token"' "$config_file"; then
      log "Token authentication enabled"
    else
      warn "Token auth not detected. Enable it in config."
    fi
  fi

  # SECURITY.md already installed via templates
  if [[ -f "$dir/SECURITY.md" ]]; then
    log "Security policy installed (SECURITY.md)"
  fi

  # Verify no sensitive files in git
  if [[ -f "$dir/.gitignore" ]]; then
    log ".gitignore configured"
  fi

  # Check file permissions on config
  if [[ -d "$dir/.config" ]]; then
    chmod 700 "$dir/.config"
    log "API key directory permissions secured (700)"
  fi

  # Check for open ports (Linux only)
  if command -v ss &>/dev/null; then
    local exposed
    exposed=$(ss -tlnp 2>/dev/null | grep -E '0\.0\.0\.0.*(18789|3456)' || true)
    if [[ -n "$exposed" ]]; then
      warn "Gateway port appears exposed to all interfaces!"
    else
      log "No gateway ports exposed to public"
    fi
  fi

  echo ""
}

# ============================================================================
# Smoke test — verify the installation actually works
# ============================================================================

smoke_test() {
  local dir="$1"
  SETUP_STEP="smoke-test"

  echo -e "${BOLD}━━━ Running Smoke Test ━━━${NC}"

  local passed=0
  local failed=0

  # Test 1: Workspace files exist
  if [[ -f "$dir/AGENTS.md" && -f "$dir/SOUL.md" && -f "$dir/USER.md" ]]; then
    log "Workspace files: OK"
     passed=$((passed + 1))
  else
    err "Workspace files: MISSING"
     failed=$((failed + 1))
  fi

  # Test 2: Skills directory has content
  local skill_count
  skill_count=$(find "$dir/skills" -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [[ "$skill_count" -gt 1 ]]; then
    log "Skills installed: $((skill_count - 1)) skill(s)"
     passed=$((passed + 1))
  else
    warn "Skills directory is empty"
     failed=$((failed + 1))
  fi

  # Test 3: Clawdbot binary works
  if clawdbot --version &>/dev/null; then
    log "Clawdbot binary: OK"
     passed=$((passed + 1))
  else
    err "Clawdbot binary: FAILED"
     failed=$((failed + 1))
  fi

  # Test 4: Config file exists
  if [[ -f "$HOME/.clawdbot/clawdbot.json" ]]; then
    log "Clawdbot config: OK"
     passed=$((passed + 1))
  else
    warn "Clawdbot config: NOT FOUND (run 'clawdbot init')"
     failed=$((failed + 1))
  fi

  # Test 5: Template variables replaced (no {{}} remaining)
  local unreplaced
  unreplaced=$(grep -r '{{' "$dir"/*.md 2>/dev/null | grep -v node_modules || true)
  if [[ -z "$unreplaced" ]]; then
    log "Template substitution: OK"
     passed=$((passed + 1))
  else
    warn "Some template variables not replaced:"
    echo "$unreplaced" | head -5
     failed=$((failed + 1))
  fi

  echo ""
  if [[ "$failed" -eq 0 ]]; then
    log "All $passed tests passed!"
  else
    warn "$passed passed, $failed failed"
  fi

  echo ""
}

# ============================================================================
# Final commit & summary
# ============================================================================

finalize() {
  local dir="$1"
  SETUP_STEP="finalize"

  echo -e "${BOLD}━━━ Finalizing ━━━${NC}"

  cd "$dir"
  git add -A 2>/dev/null
  git commit -q -m "Initial setup via Clawdbot Starter Kit v${VERSION}" 2>/dev/null || true
  log "Initial commit created"

  local agent_name=$(get_val "['agent','name']" "Your agent")
  local agent_emoji=$(get_val "['agent','emoji']" "🤖")
  local user_name=$(get_val "['user','name']" "there")

  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}Setup Complete!${NC}                                          ${GREEN}║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Agent:${NC}     $agent_name $agent_emoji"
  echo -e "  ${BOLD}Owner:${NC}     $user_name"
  echo -e "  ${BOLD}Workspace:${NC} $dir"
  echo -e "  ${BOLD}Log:${NC}       $LOG_FILE"
  echo ""

  if [[ ${#FAILED_SKILLS[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}Failed skills:${NC} ${FAILED_SKILLS[*]}"
    echo -e "  Install later: clawdhub install <skill-name>"
    echo ""
  fi

  echo -e "  ${BOLD}Next steps:${NC}"
  echo "    1. Start the gateway:  clawdbot gateway start"
  echo "    2. Open a session:     clawdbot chat"
  echo "    3. Your agent will introduce itself and get to know you"
  echo ""
  echo -e "  ${BOLD}Useful commands:${NC}"
  echo "    clawdbot status          — Check agent status"
  echo "    clawdbot doctor          — Diagnose issues"
  echo "    clawdbot gateway restart — Restart the agent"
  echo ""
  echo -e "  ${BLUE}Need help?${NC}  https://docs.clawd.bot"
  echo -e "  ${BLUE}Community:${NC}  https://discord.com/invite/clawd"
  echo -e "  ${BLUE}Support:${NC}    hello@theaiintegrationhub.com"
  echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
  # Start logging
  echo "Clawdbot Starter Kit v${VERSION} — $(date)" > "$LOG_FILE"
  echo "Args: $*" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"

  banner
  parse_args "$@"

  if [[ -z "$CONFIG_JSON" ]]; then
    interactive_setup
  fi

  WORKSPACE_DIR=$(get_val "['workspace']" "${WORKSPACE_DIR:-$HOME/clawd}")
  # Expand ~ to home directory
  WORKSPACE_DIR="${WORKSPACE_DIR/#\~/$HOME}"
  skill_packs_label=$(get_val "['skills']" "Core")

  check_prereqs
  create_workspace "$WORKSPACE_DIR"
  install_templates "$WORKSPACE_DIR"
  install_skills "$WORKSPACE_DIR"
  configure_clawdbot "$WORKSPACE_DIR"
  harden_security "$WORKSPACE_DIR"
  smoke_test "$WORKSPACE_DIR"
  finalize "$WORKSPACE_DIR"
}

main "$@"
