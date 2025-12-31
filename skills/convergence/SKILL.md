---
description: "This skill should be used when evaluating loop progress, detecting stalls, deciding whether to continue or stop iteration, or switching strategies when the DAG is not shrinking. Use it in the coordinator agent to determine next actions based on convergence metrics."
---

# Convergence

Guarantee loop convergence, detect stalls, and switch strategies.

## Core Principles

### Halting (Base Case)

Express completion criteria as **externally verifiable**.

| Verification Method | Example | Machine Evaluable |
|----------|-----|:----------:|
| Test success | `npm test` exit code = 0 | Yes |
| Artifact exists | `./dist/bundle.js` exists | Yes |
| Verification command | `curl -s localhost:3000/health` | Yes |
| Agent judgment | "Auth API operates normally" | No (confirmation required) |

**base_case satisfied → immediate stop**

### Convergence (Monotonic Decrease)

The essence of progress is that the "problem (unresolved Atoms)" **gets smaller** each iteration.

```
Iteration 1: |unresolved Atoms| = 5
Iteration 2: |unresolved Atoms| = 4  → Progress
Iteration 3: |unresolved Atoms| = 4  → Stalled! stall_count++
Iteration 4: |unresolved Atoms| = 3  → Progress recovered, stall_count = 0
```

## Progress Evaluation

### Evaluation Logic

```python
def evaluate_progress(prev_state, curr_state):
    prev_pending = count_pending_atoms(prev_state)
    curr_pending = count_pending_atoms(curr_state)

    if curr_pending < prev_pending:
        return "progress"      # DAG shrinking
    elif curr_pending == prev_pending:
        return "stall"         # DAG stalled
    else:
        return "expansion"     # DAG expanding (over-decomposition)
```

### Decision Criteria and Actions

| Result | Criteria | Action |
|----------|----------|-----------|
| progress | `|unresolved| < previous` | Continue (stall_count = 0) |
| stall | `|unresolved| = previous` | stall_count++, consider strategy switch |
| expansion | `|unresolved| > previous` | Over-decomposition → consider re-integration |

## Stall Detection and Strategy Switching

### stall_count Management

```yaml
control:
  stall_count: 2           # Consecutive stall count
  # max_stall_count: 3 (defined in constraints)
```

**Stall handling:**

1. **stall_count < max**: Consider strategy switch
2. **stall_count >= max**: Auto-stop (prevent infinite loop)

### Strategy Switch Patterns

| Situation | Switch Strategy |
|------|----------|
| Same approach keeps failing | Try different approach |
| Dependencies not progressing | Reconsider dependency graph |
| Stuck at OR branch | Backtrack to alternative |
| Over-decomposition | Re-integrate Atoms |
| Insufficient information | Investigate with Probe Agent |

### No Inertia Loops

**Don't repeat the same approach out of inertia.**

```
NG: Execute same command 3 times and fail
OK: After failure, analyze error → try different approach
```

## Stop Conditions

### Priority Order

1. `control.redirect_requested = true` → Redirect (interrupt, not stop)
2. `control.stop_requested = true` → Manual stop
3. `base_case` satisfied → Completion stop
4. `stall_count >= max_stall_count` → Stall stop
5. `iteration >= max_iterations` → Limit stop

### Recording Stop Reason

```yaml
control:
  status: stopped
  stop_reason: "max_stall_count exceeded"
```

## Hook Decision Logic

Continue/stop decision in SubagentStop hook:

```bash
# Decision flow (priority order)
#
# 1. redirect_requested = true → approve (redirect in progress)
# 2. stop_requested = true → approve, status = stopped
# 3. status = completed → approve (coordinator sets when base_case passes)
# 4. iteration >= max_iterations → approve, status = stopped
# 5. Progress evaluation:
#    - unresolved < prev_pending → progress, stall_count = 0
#    - unresolved >= prev_pending → stall, stall_count++
# 6. stall_count >= max_stall_count → approve, status = stopped
# 7. Otherwise → block (continue loop)

# Important: base_case verification is done by coordinator
# coordinator sets status = completed when base_case passes
# hook just looks at status to decide
```

**Responsibility division**:
- **coordinator**: Verify base_case, set status to completed
- **hook**: Decide continue/stop based on status/flags, manage iteration/stall_count

## Convergence Metrics

### Metrics to Track

| Metric | Meaning |
|------|------|
| `iteration` | Current iteration count |
| `pending_count` | Unresolved Atom count |
| `resolved_count` | Resolved Atom count |
| `stall_count` | Consecutive stall count |
| `or_switches` | OR branch switch count |

### Health Check

```
healthy:
  - pending_count trending down
  - stall_count < max_stall_count
  - iteration < max_iterations

unhealthy:
  - pending_count trending up
  - stall_count approaching max
  - Same Atom failing multiple times
```
