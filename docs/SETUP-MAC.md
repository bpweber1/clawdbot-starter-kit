# Clawdbot Setup Guide for macOS

Step-by-step instructions to deploy Clawdbot on a Mac.

---

## Prerequisites

- macOS 10.15 (Catalina) or newer
- Admin access to the Mac
- ~2GB free disk space
- Internet connection

---

## Step 1: Install Homebrew (if not installed)

Open **Terminal** (Applications → Utilities → Terminal) and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts. After installation, run the commands it suggests to add brew to your PATH.

Verify it works:
```bash
brew --version
```

---

## Step 2: Install Node.js

```bash
brew install node@22
```

Add to PATH (if needed):
```bash
echo 'export PATH="/opt/homebrew/opt/node@22/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:
```bash
node --version   # Should show v22.x.x
npm --version    # Should show 10.x.x
```

---

## Step 3: Install Clawdbot

```bash
npm install -g clawdbot
```

Verify:
```bash
clawdbot --version
```

---

## Step 4: Create Workspace Directory

```bash
mkdir -p ~/clawd
cd ~/clawd
```

---

## Step 5: Run the Starter Kit Wizard

Open the wizard in your browser:
```
https://clawdbot-starter-kit.vercel.app/
```

**Complete the 5 steps:**

### Step 1: AI Provider
- Select **Anthropic** (recommended)
- Get your API key from: https://console.anthropic.com/settings/keys
- Paste the key (starts with `sk-ant-`)

### Step 2: Channels
- **Telegram** (recommended for personal use):
  1. Open Telegram, search for `@BotFather`
  2. Send `/newbot`
  3. Choose a name (e.g., "Brad's Assistant")
  4. Choose a username (must end in `bot`, e.g., `brads_helper_bot`)
  5. Copy the token BotFather gives you
  6. Paste it in the wizard

### Step 3: Skill Packs
- **[C] Core** - Always include (security, delegation, memory)
- **[R] Research** - Optional (search tools, trend research)
- Select what you want by typing the letters (e.g., `CR` for Core + Research)

### Step 4: Preferences
- Set timezone (e.g., `America/New_York`)
- Choose thinking mode (default is fine)
- Adjust heartbeat interval if desired (default 30 min)

### Step 5: Deploy
- Select **macOS**
- Copy the generated command

---

## Step 6: Run the Install Command

Paste the command from Step 5 into Terminal. It will look something like:

```bash
curl -fsSL https://clawdbot-starter-kit.vercel.app/install.sh | bash -s -- \
  --provider anthropic \
  --api-key "sk-ant-xxxxx" \
  --channel telegram \
  --telegram-token "123456:ABC-xxxxx" \
  --skills "C" \
  --timezone "America/New_York" \
  --workspace ~/clawd
```

This will:
- Download and configure Clawdbot
- Set up the workspace with template files
- Install selected skills
- Create the configuration

---

## Step 7: Start Clawdbot

```bash
cd ~/clawd
clawdbot start
```

You should see output like:
```
[clawdbot] Gateway starting...
[clawdbot] Telegram bot connected
[clawdbot] Ready
```

---

## Step 8: Test It

1. Open Telegram
2. Search for your bot's username
3. Send `/start` or just say "Hello"
4. The bot should respond

---

## Step 9: Keep It Running (Optional)

To keep Clawdbot running after you close Terminal:

### Option A: Background with nohup
```bash
cd ~/clawd
nohup clawdbot start > clawdbot.log 2>&1 &
```

### Option B: Create a Launch Agent (auto-start on login)

```bash
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.clawdbot.agent.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawdbot.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/clawdbot</string>
        <string>start</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/clawd</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/clawd/clawdbot.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/clawd/clawdbot-error.log</string>
</dict>
</plist>
EOF
```

Replace `YOUR_USERNAME` with the actual username, then:
```bash
launchctl load ~/Library/LaunchAgents/com.clawdbot.agent.plist
```

---

## Troubleshooting

### "command not found: clawdbot"
```bash
# Check if npm global bin is in PATH
npm config get prefix
# Add to PATH if needed:
echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### "Error: ANTHROPIC_API_KEY not set"
```bash
# Check config
cat ~/.clawdbot/clawdbot.json | grep -A2 "anthropic"
```

### Telegram bot not responding
1. Make sure you started a chat with the bot first
2. Check the bot token is correct
3. Check logs: `clawdbot status` or `cat ~/clawd/clawdbot.log`

### Port already in use
```bash
# Find what's using port 18789
lsof -i :18789
# Kill it or change port in config
```

---

## Useful Commands

```bash
clawdbot start          # Start the gateway
clawdbot stop           # Stop the gateway
clawdbot status         # Check status
clawdbot restart        # Restart
clawdbot config         # View config location
```

---

## Next Steps

Once running:
1. Chat with your bot to set up its personality (SOUL.md)
2. Tell it about yourself (USER.md)
3. Start giving it tasks

The bot will create memory files as you interact with it.

---

*Questions? https://discord.com/invite/clawd*
