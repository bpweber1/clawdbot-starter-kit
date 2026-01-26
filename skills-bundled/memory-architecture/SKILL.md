# Memory Architecture

## Overview
Dual-memory system for persistent learning across sessions.

## Memory Types

### Short-Term Memory (Session Context)
- **Location:** In-context conversation
- **Duration:** Current session only
- **Purpose:** Working memory for immediate tasks
- **Managed by:** Clawdbot automatically

### Long-Term Memory (Persistent)
- **Location:** `memory/` directory + `MEMORY.md`
- **Duration:** Persists across sessions
- **Purpose:** Accumulated knowledge, preferences, lessons
- **Managed by:** Me (Kobe)

## File Structure

```
memory/
├── YYYY-MM-DD.md      # Daily logs (episodic memory)
├── heartbeat-state.json # Heartbeat tracking
└── [topic].md         # Topic-specific notes

MEMORY.md              # Curated long-term memory (semantic)
snapshots/             # Project-specific context
USER.md                # Human preferences & context
TOOLS.md               # Environment-specific notes
```

## Memory Categories

### Episodic Memory (What happened)
Daily files capture:
- Conversations and decisions
- Tasks completed
- Lessons learned
- Errors and fixes

### Semantic Memory (What I know)
MEMORY.md captures:
- User preferences
- Recurring patterns
- Best practices discovered
- Important relationships

### Procedural Memory (How to do things)
Skills capture:
- Task-specific instructions
- Tool usage patterns
- Workflow templates

## Memory Maintenance

### Daily (During Heartbeats)
- Check if today's memory file exists
- Log significant events
- Update heartbeat-state.json

### Weekly
- Review daily files
- Extract patterns to MEMORY.md
- Prune outdated information

### Per-Project
- Update relevant snapshot
- Capture architectural decisions
- Note client preferences

## Memory Retrieval

### Before Starting Work
1. Read MEMORY.md (main session only)
2. Read recent daily files (2-3 days)
3. Read relevant project snapshot
4. Check USER.md for preferences

### During Work
- Update daily file with significant events
- Note decisions and rationale
- Capture any errors for future reference

### After Completing Work
- Commit memory updates
- Update snapshots if project-relevant
- Note any new patterns

## Example: Learning a Preference

**Session 1:**
```
Brad: "Use 2-space indentation"
→ Log to daily file
→ Update MEMORY.md: "Code style: 2-space indent"
```

**Session 2:**
```
→ Read MEMORY.md at start
→ Apply 2-space indentation automatically
```

## Anti-Patterns

❌ Don't store sensitive data (passwords, keys) in memory files
❌ Don't log every trivial interaction
❌ Don't let memory files grow unbounded
❌ Don't forget to commit memory updates

---

*Memory is what makes continuity possible. Use it wisely.*
