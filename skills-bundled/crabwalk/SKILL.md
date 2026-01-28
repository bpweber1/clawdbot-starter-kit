# 🦀 Crabwalk — Real-time Clawdbot Monitor

Live dashboard to watch your AI agents work in real-time. ReactFlow node graph showing sessions, tool calls, and response chains.

## Installation

### Docker (Recommended)

```bash
docker run -d -p 3000:3000 \
  -e CLAWDBOT_API_TOKEN=your-token \
  -e CLAWDBOT_URL=ws://host.docker.internal:18789 \
  ghcr.io/luccast/crabwalk:latest
```

### From Source

```bash
git clone https://github.com/luccast/crabwalk.git
cd crabwalk
npm install
CLAWDBOT_API_TOKEN=your-token npm run dev
```

Open http://localhost:3000/monitor

## Get Gateway Token

```bash
# Find in clawdbot config
jq '.gateway.auth.token' ~/.clawdbot/clawdbot.json
```

## Features

- Live activity graph (ReactFlow)
- Multi-platform monitoring (WhatsApp, Telegram, Discord, Slack)
- Real-time WebSocket streaming
- Expand nodes to inspect tool args/payloads
- Filter by platform, search by recipient

## More Info

- GitHub: https://github.com/luccast/crabwalk
- Author: @luccasveg
