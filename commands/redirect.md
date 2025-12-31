---
description: "Redirect AoT Loop - Interrupt and modify direction without stopping"
argument-hint: "[modification instructions (optional)]"
allowed-tools: ["Read", "Edit", "AskUserQuestion", "KillShell", "Task"]
---

# Redirect Command

Immediately interrupt the running AoT Loop and continue after modifying direction.

## Responsibility

- Immediately interrupt running Worker
- Accept user instructions and interactively specify modification details
- Update state file
- Restart coordinator and proceed to next iteration

## Operation Flow

### Step 1: Interrupt Running Worker

```bash
# Set redirect_requested flag
control:
  redirect_requested: true
```

Terminate running sub agents (Worker, Probe, Verifier) via KillShell.
Results are discarded and not reflected in Bindings.

### Step 2: Present Current State

Display current state to user:

```
## Current State (Iteration [N])

**Objective**:
- Goal: [goal]
- Base case: [base_case.type]: [base_case.value]
- Background: [background_intent]

**Work Graph**:
- Pending: [count] atoms
- In Progress: [count] atoms
- Resolved: [count] atoms

**Recent Activity**:
- Last resolved: [atom description]
- Current focus: [in_progress atom]

**Issues** (if any):
- Stall count: [stall_count]
- Last failure: [if applicable]
```

### Step 3: Accept User Instructions

If no argument, confirm with AskUserQuestion:

```
What would you like to modify?

1. Change objective (goal, base_case, deliverables)
2. Adjust Work Graph (add/remove atoms, force OR selection)
3. Change constraints (iteration limit, parallel limit)
4. Override Bindings (re-do a resolved atom)
5. Other (describe your modification)
```

### Step 4: Specify Modification Details

Based on user instructions, interactively confirm details:

- Ask questions about unclear points
- Specify modification details
- Identify modification scope

### Step 5: Update State File

Update state according to modification type:

| Modification Type | Target | Trail Impact |
|----------|------|----------------|
| **Alignment change** | goal, base_case, background_intent, deliverables | Clear Trail |
| **Constraint change** | constraints (iteration limit, parallel limit, etc.) | Preserve Trail |
| **DAG addition** | Add new Atom | Append to Trail |
| **DAG deletion** | Delete unresolved Atom | Append to Trail |
| **Force OR selection** | Force specify OR branch choice | Append to Trail |
| **Bindings modification** | Overwrite resolved summary | Clear only affected scope |

### Step 6: Record in corrections

```yaml
corrections:
  - timestamp: "2025-01-15T10:30:00Z"
    type: dag_adjustment       # or objective_change, constraint_change, bindings_override
    description: "Changed auth method from JWT to Session"
    trail_cleared: false       # true for alignment change
```

### Step 7: Restart coordinator

```yaml
control:
  redirect_requested: false    # Reset flag
  # iteration is managed by SubagentStop hook, don't change
```

Restart coordinator agent via Task tool:

```
Tool: Task
Parameters:
  subagent_type: "ralph-wiggum-aot:aot-coordinator"
  description: "AoT Loop redirect resume"
  prompt: |
    Redirect complete. Resume AoT Loop.

    Changes applied: [modification summary]

    Read .claude/aot-loop-state.md and continue execution.
```

**Note**: Reset redirect_requested before spawning coordinator.

## Modification Type Details

### Alignment change (objective_change)

Changes to goal, base_case, background_intent, deliverables.

**Impact**:
- Clear Trail (past selection history becomes invalid)
- Essentially a restart

### DAG adjustment (dag_adjustment)

Add, delete Atoms, force OR selection.

**Atom addition**:
```yaml
atoms:
  - id: A[N+1]
    description: "[new task]"
    status: pending
    depends_on: [...]
```

**Atom deletion**:
- Can only delete unresolved Atoms
- Cannot delete resolved Atoms (Bindings depend on them)

**Force OR selection**:
```yaml
or_groups:
  auth_method:
    selected: A4_session    # Forced by user
```

### Constraint change (constraint_change)

```yaml
constraints:
  max_iterations: 30        # Increase limit
  max_stall_count: 5        # Increase stall tolerance
```

### Bindings modification (bindings_override)

Overwrite resolved Atom summary.

**Impact**:
- Reset affected Atom to pending
- Reset dependent Atoms to pending (cascade)
- Partial redo

## Completion Message

```
Redirect complete.

Changes applied:
- [modification summary]

Correction recorded in state file.
Resuming loop at iteration [N+1].

The coordinator will now continue with the modified objective.
```

## Error Cases

### Loop not running

```
No active AoT Loop to redirect.

To start a loop, run:
  /align-goal [your requirements]
  /enter-recursion
```

### Conflicting change

```
Warning: The requested change creates a conflict.

Issue: [specific conflict description]

Options:
1. Resolve conflict by [proposal]
2. Cancel redirect
3. Force change (may cause issues)

What would you like to do?
```
