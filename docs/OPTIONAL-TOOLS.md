# Optional Tools & Skills

This document catalogs optional tools and skills you can add to your Clawdbot deployment.

## Multi-LLM Strategy

**Why:** Running Opus for everything is expensive. Route tasks to appropriate models.

### Recommended Configuration

```json
{
  "agents": {
    "main": {
      "model": "anthropic/claude-sonnet-4",
      "overrides": {
        "coding": "anthropic/claude-opus-4-5",
        "research": "google/gemini-2.5-pro",
        "chat": "anthropic/claude-sonnet-4"
      }
    }
  }
}
```

### Model Recommendations

| Use Case | Model | Why |
|----------|-------|-----|
| Quick chat | Sonnet | Fast, cheap |
| Complex coding | Opus | Best reasoning |
| Deep research | Gemini Pro | Large context |
| Back-and-forth | Kimi | Good value |

## Social Media Integration

### Typefully Skill
Manage social media drafts, scheduling, and publishing.

```bash
clawdhub install typefully
```

Features:
- Draft posts
- Schedule content
- Add media
- Cross-platform publishing

### ICP Listener Agent
Monitor where your audience speaks and extract insights.

**Build Your Own:**
1. Monitor Reddit, Twitter, YouTube comments
2. Extract pain points, questions, objections
3. Feed into content strategy

See: `skills/icp-listener/` template

## Memory Enhancement

### Supermemory Plugin
Cloud-based long-term memory with automatic recall.

```bash
clawdbot plugins install @supermemory/openclaw-supermemory
```

Features:
- Auto-recall relevant context before every turn
- Auto-capture conversations for long-term storage
- User profile extraction
- Semantic search across all history

**Requires:** Supermemory Pro subscription

### QMD (Quick Markdown Search)
95% token savings via semantic search.

```bash
bun add -g qmd
qmd index memory skills workspace
```

## Semantic Memory in Hooks

**Advanced:** Include semantic memory in PreToolUse hooks (not just UserPromptSubmit).

This means before every tool call, relevant memories are injected, improving tool usage accuracy.

Implementation in `clawdbot.json`:
```json
{
  "hooks": {
    "preToolUse": {
      "injectMemory": true
    }
  }
}
```

## Visual Analysis

### Playground Skill
Interactive visual analysis with 6 templates.

```bash
clawdhub install playground
```

Templates:
- Code Map
- Concept Map
- Data Explorer
- Design Playground
- Diff Review
- Document Critique

## Agent Monitoring

### Crabwalk
Real-time ReactFlow dashboard for watching agents work.

Features:
- Subagent hierarchical tracking
- Parent→child relationships
- Collapsible sidebar groups
- Follow mode for live tracking

## Team of Rivals Architecture

For high-stakes tasks, use adversarial review:

```
Planner → Writer → Critic (veto authority) → User
```

Key principles:
1. Critics can reject and trigger retry
2. Pre-declare acceptance criteria before execution
3. Use different models for writer vs critic
4. Multiple layers with misaligned failure modes

See: `memory/research/team-of-rivals-paper.md`
