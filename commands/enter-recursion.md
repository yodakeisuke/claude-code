---
description: "Start AoT Loop - Begin autonomous iteration after goal alignment"
argument-hint: ""
allowed-tools: ["Read", "Edit", "Task"]
---

# Enter Recursion Command

Start the autonomous iteration loop based on the aligned Objective.

## Preconditions (Gate)

Verify the following before starting the loop:

1. **State file exists**: `.claude/aot-loop-state.md` exists
2. **Alignment complete**: The following are set in objective section
   - `goal`
   - `base_case` (type and value)
   - `background_intent`
   - `deliverables`
   - `definition_of_done`
3. **Initial DAG exists**: At least one Atom in `atoms`
4. **Not yet executed**: `control.status` is `pending`

## Gate Verification Steps

1. Load state file
2. Verify existence of each field
3. Display error message and exit if any are missing

**Error example**:

```
Error: Cannot start AoT Loop

Missing required fields:
  - objective.base_case.value is empty
  - atoms is empty (no initial tasks)

Please run /align-goal first to complete goal alignment.
```

## Loop Start Steps

After gate verification passes:

1. Update `control.status` to `running`
2. Set `control.iteration` to 1
3. Spawn coordinator agent

```yaml
# Before
control:
  status: pending
  iteration: 0

# After
control:
  status: running
  iteration: 1
```

## Coordinator Agent Spawn

Spawn coordinator agent using Task tool.

**Important**: Use `ralph-wiggum-aot:aot-coordinator` for `subagent_type`.

```
Tool: Task
Parameters:
  subagent_type: "ralph-wiggum-aot:aot-coordinator"
  description: "AoT Loop iteration 1"
  prompt: |
    AoT Loop iteration 1 started.

    Read the state file at .claude/aot-loop-state.md and:
    1. Analyze the Work Graph (atoms)
    2. Identify executable Atoms (dependencies resolved)
    3. Decide: Probe, Worker, or Verifier
    4. Execute and update state

    Reference skills: state-contract, aot-dag, convergence, parallel-exec
```

**Fallback**: If custom agents are not available, use `general-purpose` and include coordinator.md content in the prompt.

## Start Message

```
AoT Loop started (iteration 1)

Objective: [goal summary]
Base case: [base_case.type]: [base_case.value]
Initial atoms: [atom count]

The coordinator agent will now analyze the Work Graph and begin execution.
To stop the loop manually, run: /exit-recursion
To modify direction, run: /redirect
```

## Resume Behavior

### When status = running

```
Warning: AoT Loop is already running (iteration 5)

Options:
1. Continue current loop (do nothing)
2. Force restart from iteration 1
3. Stop the loop (/exit-recursion)

What would you like to do?
```

### When status = stopped

Resume from stopped state. iteration continues (not reset).

```yaml
# Before
control:
  status: stopped
  iteration: 5
  stop_requested: false
  stop_reason: "Manual stop requested"

# After
control:
  status: running
  iteration: 5          # Continue (not reset)
  stop_requested: false
  stop_reason: null     # Clear
```

### When status = completed

Re-execution from completed state. Treat as new loop.

```
AoT Loop has already completed successfully.

Options:
1. Start fresh with /align-goal
2. Force restart from iteration 1 (reset status to running)

What would you like to do?
```

## Error Handling

| Situation | Response |
|------|------|
| No state file | Guide to `/align-goal` |
| Alignment incomplete | Display missing fields |
| atoms is empty | Guide to add initial tasks |
| status is stopped/completed | Confirm resume or guide to `/align-goal` |
