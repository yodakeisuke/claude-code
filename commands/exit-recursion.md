---
description: "Stop AoT Loop - Manually stop the autonomous iteration loop"
argument-hint: "[reason for stopping (optional)]"
allowed-tools: ["Read", "Edit"]
---

# Exit Recursion Command

Manually stop the running AoT Loop.

## Responsibility

- Issue a stop request to the running agent loop
- Record the stop reason in state
- Stop while preserving state (Work Graph, Bindings, Trail are not lost)

## Operation Steps

### Step 1: Check State File

Load `.claude/aot-loop-state.md` and verify current state.

### Step 2: Set stop_requested

```yaml
# Before
control:
  status: running
  stop_requested: false
  stop_reason: null

# After
control:
  status: running           # Changed to stopped by Hook
  stop_requested: true
  stop_reason: "[reason specified in argument, or 'Manual stop requested']"
```

### Step 3: Confirmation Message

```
Stop request registered.

Current state:
  - Iteration: [iteration]
  - Pending atoms: [count]
  - Resolved atoms: [count]

The loop will stop at the end of the current iteration.
State is preserved in .claude/aot-loop-state.md

To resume later, run: /enter-recursion
To start fresh, run: /align-goal
```

## Recording Stop Reason

If argument provided, record as stop reason:

```bash
/exit-recursion "Needs user review before continuing"
```

If no argument, use default reason:

```yaml
stop_reason: "Manual stop requested"
```

## State Preservation

The following are preserved after stop:

- `objective`: Alignment info
- `atoms`: Work Graph (including in-progress state)
- `bindings`: Resolved Atom summaries
- `trail`: OR selection history
- `corrections`: Redirect history

This allows resumption later with `/enter-recursion`.

## Error Cases

### Loop not running

```
No active AoT Loop found.

Current status: [pending / stopped / completed]

To start a new loop, run:
  /align-goal [your requirements]
  /enter-recursion
```

### State file doesn't exist

```
No state file found at .claude/aot-loop-state.md

To start a new AoT Loop, run:
  /align-goal [your requirements]
```

## Relationship with base_case

- `stop_requested` is independent of base_case
- Can stop even without reaching base_case
- Stop reason is treated as "interruption" not "success"

## Hook Coordination

When SubagentStop hook detects `stop_requested = true`:

1. Complete current iteration
2. Change `control.status` to `stopped`
3. End loop

```json
{
  "decision": "approve",
  "reason": "Manual stop requested"
}
```
