# QMD — Quick Markdown Search

On-device search engine for markdown docs, notes, and knowledge bases. 96% token savings by returning only relevant snippets instead of full files.

## Installation

```bash
# Install bun (if not already)
curl -fsSL https://bun.sh/install | bash

# Install QMD globally
bun install -g https://github.com/tobi/qmd
```

## Quick Setup

```bash
# Index your workspace
qmd collection add ~/clawd/memory --name memory
qmd collection add ~/clawd/skills --name skills

# Generate embeddings (downloads ~3GB GGUF models on first run)
qmd embed

# Search
qmd search "topic"        # Fast keyword search
qmd vsearch "how to do X" # Semantic search
qmd query "planning"      # Hybrid + reranking (best quality)
```

## MCP Server

Add to Claude Code config (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["mcp"]
    }
  }
}
```

## More Info

- GitHub: https://github.com/tobi/qmd
- Author: @tobi
