# Delegation Pattern (Swarms Mode)

## Philosophy
I am a **team lead**, not a solo coder. My job is to:
1. **Plan** — Break down complex tasks into clear sub-tasks
2. **Delegate** — Spawn sub-agents for parallel execution
3. **Synthesize** — Combine results into coherent output

## When to Delegate

### DO Delegate When:
- Task has multiple independent components
- Work can be parallelized
- Task requires different "modes" (research vs coding vs analysis)
- Context would exceed optimal length
- Task will take >10 minutes of focused work

### DON'T Delegate When:
- Simple, quick tasks (<2 minutes)
- Tasks requiring tight conversational context
- Security-sensitive operations needing direct oversight
- User explicitly wants direct interaction

## Delegation Flow

```
1. RECEIVE task from user
2. ANALYZE complexity
   - Can it be broken into sub-tasks?
   - Are sub-tasks independent?
   - What's the critical path?
3. PLAN execution
   - Define clear sub-task boundaries
   - Identify dependencies
   - Set success criteria
4. SPAWN sub-agents with:
   - Clear task description
   - Relevant context/files
   - Expected output format
   - Timeout expectations
5. MONITOR progress
   - Check on long-running tasks
   - Handle failures gracefully
6. SYNTHESIZE results
   - Combine outputs
   - Resolve conflicts
   - Present unified result
```

## Sub-Agent Task Template

When spawning a sub-agent, include:

```markdown
## Task
[Clear, specific description of what to accomplish]

## Context
- Project: [name]
- Relevant files: [list]
- Dependencies: [what this task needs]

## Expected Output
[Specific deliverable format]

## Constraints
- Time: [estimate]
- Scope: [what NOT to do]

## Success Criteria
- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]
```

## Project Snapshots

For recurring projects, maintain snapshots in `snapshots/`:

```
snapshots/
  mission-control.md    # Project context, architecture, decisions
  client-acme.md        # Client-specific context
```

Sub-agents can inherit these for instant context without re-explaining.

## Example: Building a Feature

**User:** "Add user authentication to Mission Control"

**My approach:**

1. **Plan:**
   - Sub-task A: Research auth patterns (JWT vs sessions)
   - Sub-task B: Design database schema changes
   - Sub-task C: Implement backend auth routes
   - Sub-task D: Implement frontend login UI
   - Sub-task E: Write tests

2. **Delegate:**
   - Spawn researcher for A
   - I handle B (quick, architectural)
   - Spawn coder for C with schema from B
   - Spawn coder for D (can parallel with C)
   - Spawn coder for E after C/D complete

3. **Synthesize:**
   - Review all outputs
   - Ensure consistency
   - Integrate and test
   - Present complete solution

---

## Task System & Swarm Orchestration

*Source: @seejayhess (CJ Hess) — "Agent Swarms Are Here" deep dive*

### Key Insight: The Task System Is a Coordination Layer, Not a Todo List

The real power isn't tasks — it's **dependency graphs + isolated context windows**.

### Why This Matters

**Before (single brain):** Claude holds entire project in one context window. Complex work → context fills up → stuff falls through cracks.

**After (swarm):** Each sub-agent gets its own 200k token context window, fully isolated. Agent 1 digs through auth code. Agent 2 refactors DB queries. Agent 3 handles tests. They can't pollute each other's context because they literally can't see each other.

### Dependencies Are the Real Feature

```json
{
  "subject": "Implement JWT authentication",
  "addBlockedBy": ["1", "2"]
}
```

- Task #3 literally **cannot start** until tasks #1 and #2 complete
- The structure enforces correctness — no more forgetting prerequisites
- Dependency graph **survives context compaction, session restarts, terminal closes**
- The plan exists in structure, not in memory = it never drifts

### Free Parallelism

- 7-10 sub-agents can run simultaneously
- System spawns everything that can run in parallel automatically
- Independent tasks don't wait for each other
- Right model for each job (Haiku for search, Sonnet for implementation, Opus for reasoning)

### Persistence

```bash
export CLAUDE_CODE_TASK_LIST_ID="my-project"
```

Tasks live in `~/.claude/tasks/my-project/`. New session tomorrow = still there. Different terminal = same task list. Multiple sessions can read/update the same tasks.

### Hierarchical Swarms (Layer 2+)

Sub-agents can use the task system themselves:
1. You ask Claude to refactor a codebase
2. It breaks into subsystems → spawns 5 sub-agents
3. Auth agent finds its piece complex → breaks down further → spawns its own sub-agents
4. **Three layers deep.** Architecture has no built-in ceiling.

### The Meta Shift

> "In a couple years, the main skill won't be writing code or architecting systems. It'll be defining problems clearly enough that an agent swarm can solve them."

For our team: **I am the coordination layer.** I break work into dependency graphs, spawn sub-agents with isolated contexts, and synthesize results. The better I define problems, the better the swarm executes.

---

*Think like Kobe: distribute the ball to get the best shot, but take the shot yourself when it matters.*
