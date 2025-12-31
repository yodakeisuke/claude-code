---
description: "Explain AoT Loop plugin commands and usage"
---

# AoT Loop Plugin Help

Please explain the following to the user:

## What is AoT Loop?

AoT (Atom of Thoughts) is an autonomous development loop that decomposes complex goals into a DAG (Directed Acyclic Graph) of atomic tasks:

- **Atoms**: Smallest units of work
- **Dependencies**: AND/OR relationships between tasks
- **Convergence**: Loop stops when base_case is satisfied
- **Backtracking**: OR branches allow alternative approaches on failure

## Available Commands

### /align-goal [requirements]

Interactive goal alignment - establish objective before starting the loop.

**Usage:**
```
/align-goal "Build a REST API with auth and tests"
```

**Process:**
1. Discuss requirements interactively
2. Define background intent, deliverables, completion criteria
3. Generate initial Work Graph (DAG of Atoms)
4. Save to `.claude/aot-loop-state.md`

---

### /enter-recursion

Start the autonomous loop after goal alignment.

**Usage:**
```
/enter-recursion
```

**Prerequisites:**
- Must run `/align-goal` first
- State file must exist with valid objective

**Process:**
1. Validates alignment (goal, base_case, atoms exist)
2. Spawns coordinator agent
3. Loop runs until base_case satisfied or stopped

---

### /exit-recursion [reason]

Manually stop the loop (state preserved for later resumption).

**Usage:**
```
/exit-recursion
/exit-recursion "Need to review approach"
```

**Process:**
1. Sets `stop_requested = true`
2. Records stop reason
3. Preserves all state (can resume with `/enter-recursion`)

---

### /redirect [instructions]

Interrupt the loop and modify direction without stopping.

**Usage:**
```
/redirect
/redirect "Change auth from JWT to sessions"
```

**Process:**
1. Interrupts running workers
2. Shows current state
3. Accepts modification instructions
4. Updates state and continues loop

---

## Key Concepts

### Base Case

The completion criteria that can be externally verified:

```yaml
base_case:
  type: command
  value: "npm test"
```

When the base case passes, the loop completes successfully.

### Work Graph (DAG)

Tasks are decomposed into Atoms with dependencies:

```
A1: Create User model
 └─ A2: Implement auth (depends on A1)
     ├─ A3: Password hashing (depends on A1)
     └─ A4: JWT tokens (depends on A1)
```

### Convergence Guarantees

- **Stopping**: Base case satisfaction, manual stop, or iteration limit
- **Progress**: DAG must shrink (fewer pending Atoms) each iteration
- **Stall detection**: If no progress after N iterations, strategy changes

### Backtracking (OR Branches)

When an approach fails:

```yaml
or_groups:
  auth_method:
    choices: [jwt_auth, session_auth]
    selected: jwt_auth  # If this fails, try session_auth
```

---

## Example Workflow

```bash
# Step 1: Align on the goal
/align-goal "Build a TODO API with CRUD, validation, and tests"

# Step 2: Review the generated Work Graph
# (Claude will show the DAG of Atoms)

# Step 3: Start autonomous execution
/enter-recursion

# The loop runs autonomously:
# - Executes Atoms in dependency order
# - Verifies progress each iteration
# - Backtracking on failures
# - Completes when all tests pass
```

---

## When to Use AoT Loop

**Good for:**
- Complex multi-step tasks requiring decomposition
- Tasks with verifiable completion criteria (tests, commands)
- Work that may need alternative approaches
- Long-running autonomous development

**Not good for:**
- Simple one-shot operations
- Tasks requiring human judgment at each step
- Unclear or subjective success criteria

---

## Sub-Agents

| Agent | Role |
|-------|------|
| **Coordinator** | Manages iteration, spawns sub-agents |
| **Probe** | Investigates feasibility (read-only) |
| **Worker** | Executes Atom tasks |
| **Verifier** | Checks base_case completion |
