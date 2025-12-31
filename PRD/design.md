# AoT Loop Plugin Design Document

## 1. Purpose

Based on PRD/requirement.md, implement a general-purpose autonomous iterative agent with halting and convergence guarantees.

---

## 2. Responsibility Distribution

### 2.1 Commands (Entry Points)

| Command            | Responsibility | Preconditions | Output |
|--------------------|------|----------|------|
| `/align-goal`      | Interactive agreement formation (background purpose, deliverables, completion criteria) → Initial DAG generation | None | State file |
| `/enter-recursion` | Verify alignment gate → Start loop-iteration Agent | State file exists | Agent start |
| `/exit-recursion`  | Set stop_requested=true, record stop reason | Loop running | State update |
| `/redirect`        | Immediate interrupt, direction modification → Continue loop | Loop running | State update + continue |

### 2.2 Skills (Knowledge)

| Skill | Knowledge Domain | Reference Timing |
|-------|----------|----------------|
| **state-contract** | State Contract v1.2 schema, read/write methods | State operations |
| **aot-dag** | DAG structure, AND/OR dependencies, contraction/backtracking | DAG operations |
| **convergence** | Convergence determination, stall detection, strategy switching | Iteration end |
| **parallel-exec** | Parallel execution decisions, side-effect conflict detection, result integration | Coordinator decisions |

### 2.3 Agents (Execution)

| Agent | Responsibility | Tool Restrictions | Output |
|-------|------|-----------|------|
| **coordinator** | DAG analysis, agent spawn decisions, result integration | State operations only | Next agent spawn |
| **probe** | Feasibility investigation (no modifications) | Read-only | `{feasible, findings}` |
| **worker** | Actual Atom resolution | Full | `{success, bindings_delta}` |
| **verifier** | External base_case verification | Bash only | `{passed, evidence}` |

**Coordinator Decision Logic**

【1. Execution Decisions】

| DAG State | Agent to Spawn |
|----------|-----------|
| Multiple AND-independent Atoms | worker × N (parallel) |
| Unknown territory Atom | probe → worker based on results |
| Single Atom | worker (sequential) |

【2. base_case Evaluation】

| Timing | Decision Criteria | Action |
|-----------|----------|-----------|
| After all Atoms resolved | Spawn verifier → passed? | true → completion stop |
| Per iteration (optional) | Early success detection possible | true → completion stop |

【3. Progress Evaluation】

| Evaluation Target | Decision Criteria | Action |
|----------|----------|-----------|
| DAG shrinking | \|unresolved Atoms\| < previous | Continue (normal progress) |
| DAG stalled | \|unresolved Atoms\| = previous | stall_count++, consider strategy switch |
| DAG expanding | \|unresolved Atoms\| > previous | Over-decomposition → re-integration or approach review |

### 2.4 Hooks (Control)

**SubagentStop** (when coordinator exits):

| Condition | decision | systemMessage |
|------|----------|---------------|
| `stop_requested == true` | `approve` | - |
| base_case satisfied | `approve` | - |
| DAG shrinking | `block` | `"Continue: DAG reduced, proceed to next iteration"` |
| DAG stalled | `block` | `"Stalled: switch strategy for atom X"` |
| `stall_count >= max` | `approve` | - |

**Hook Output Example:**
```json
{
  "decision": "block",
  "reason": "DAG reduced from 5 to 3 atoms",
  "systemMessage": "Continue iteration. Focus on unresolved atoms: [A, B, C]"
}
```

---

## 3. Data Flow

```
User
  │
  ├─ /align-goal ───────→ State file generation
  │                          ↓
  ├─ /enter-recursion ──→ Gate verification → coordinator spawn
  │                                       ↓
  │                              ┌── DAG analysis ──┐
  │                              ↓              ↓
  │                          Parallel      Sequential
  │                          decision      decision
  │                              ↓              ↓
  │                     ┌───────┴───────┐      │
  │                     ↓               ↓      ↓
  │                  worker          worker  worker ←─────────┐
  │                     └───────┬───────┘      │              │
  │                             ↓              ↓              │
  │                        Result integration ←┘              │
  │                             ↓                             │
  │                         verifier                          │
  │                             ↓                             │
  │                       SubagentStop hook                   │
  │                             │                             │
  │               ┌─────────────┼─────────────┐               │
  │               ↓             ↓             ↓               │
  │           Completion    Manual stop   Next iteration      │
  │          (base_case)  (stop_req)    (block)              │
  │               ↓             ↓             ↓               │
  ├─ /exit-recursion ──→ stop_requested   loop back          │
  │                                                           │
  └─ /redirect ─────────→ Immediate interrupt → Interactive modification → State update ────┘
                               ↑
                          Running Workers
                          terminated via
                          KillShell
```

---

## 4. State File Schema

**See [state-schema.md](./state-schema.md) for details.**

File: `.claude/aot-loop-state.md` (YAML frontmatter + Markdown body)

| Section | Contents | Required |
|------------|------|:----:|
| **objective** | goal, base_case, constraints, alignment info | ✓ |
| **control** | status, iteration, stall_count, stop/redirect flags | ✓ |
| **atoms** | Work Graph (Atom ID, description, status, depends_on) | ✓ |
| **decompositions** | Atom decomposition relationships (parent, children, reason) | × |
| **or_groups** | OR branch definitions (choices, selected) | × |
| **bindings** | Resolved Atom summaries (summary, artifacts) | ✓ |
| **trail** | OR selection history stack | ✓ |
| **corrections** | Redirect history | ✓ |
| **Body** | Original prompt (Markdown) | ✓ |

### Design Decision Summary

| Item | Decision |
|------|------|
| Atom ID | Sequential (A1, A2, ...) |
| Atom status | 3 states (pending, in_progress, resolved) |
| Decomposition representation | Separate management (decompositions section) |
| Dependency inheritance | Explicit notation |
| Bindings | summary + artifacts only |
| OR branches | Rare, defined only when needed |
| Trail | Full history preserved |
| Parallel determination | Agent calculates on-demand |
| On backtrack | Delete Bindings, reset to pending |

---

## 5. Skill Responsibility Details

| Skill | Responsibility |
|-------|------|
| **state-contract** | State schema knowledge, read/write methods |
| **aot-dag** | DAG structure, AND/OR dependencies, contraction/backtracking |
| **convergence** | Convergence determination, stall detection, strategy switching |
| **parallel-exec** | Parallel execution decisions, side-effect conflict detection, result integration |

---

## 6. Decisions

| Item | Decision |
|------|------|
| Plugin structure | Extend existing ralph-wiggum-aot |
| DAG storage | Embedded in YAML frontmatter |
| Backtracking | Agent decides and switches |
| Alignment flow | Interactive dialogue for agreement |
| Parallel execution | Coordinator determines AND independence and spawns |
| Parallel limit | max_parallel_agents = 3 (default) |
| Speculative OR | Only when explicitly specified with speculative: true |

---

## 7. `/align-goal` Detailed Design

### 7.1 Responsibility: Wicked → Tame Conversion

Transform ambiguous requests into a form where "Agent can make autonomous decisions".

- **Acceptable ambiguity**: "How to do it" (implementation approach) → Resolved through loop exploration
- **Unacceptable ambiguity**: "What to achieve" "When is it complete"

### 7.2 Dialogue Flow

1. **Free dialogue**: Deep-dive into user requirements
2. **Extraction/structuring**: Organize and present background purpose, deliverables, completion criteria
3. **Agreement confirmation**: On user OK, generate state file + form initial DAG

### 7.3 base_case Format

| type | Verification Method | Example |
|------|----------|-----|
| `command` | exit code = 0 | `npm test` |
| `file` | Existence/content condition | `exists: ./dist/bundle.js` |
| `assertion` | Agent judgment | "Auth API operates normally" |

### 7.4 Confirmation at Loop Completion

- `command` / `file`: No confirmation needed for mechanical verification
- `assertion`: Explicitly request user confirmation after completion

---

## 8. `/redirect` Detailed Design

### 8.1 Responsibility: Direction Modification via Immediate Interrupt

Change direction during loop execution without stopping. While `/exit-recursion` is "complete stop", `/redirect` handles "direction modification → continue".

### 8.2 Operation Flow

```
User: /redirect
    │
    ├─ 1. Immediate interruption of running Worker
    │     └─ Results are discarded (not reflected in Bindings)
    │
    ├─ 2. Present current state
    │     ├─ Objective (alignment info)
    │     ├─ Work graph (unresolved Atoms)
    │     ├─ Current progress (iteration, stall_count)
    │     └─ Recent failures/stalls (if any)
    │
    ├─ 3. Accept user instructions
    │     └─ User directly specifies modifications
    │
    ├─ 4. Interactive confirmation by Agent
    │     ├─ Questions about unclear points
    │     ├─ Specification of modification details
    │     └─ Identification of modification scope (alignment change or DAG adjustment)
    │
    ├─ 5. State file update
    │     ├─ 【For alignment change】
    │     │     ├─ Update Objective section
    │     │     ├─ Clear Trail
    │     │     └─ Record in corrections[]
    │     └─ 【For DAG adjustment】
    │           ├─ Update Work graph
    │           └─ Append to Trail
    │
    └─ 6. Restart coordinator
          └─ Continue from next iteration in new direction
```

### 8.3 Modification Scope Classification

| Modification Type | Target | Trail Impact | Notes |
|----------|------|----------------|------|
| **Alignment change** | goal, base_case, background_intent, deliverables | Clear Trail | Essentially a restart |
| **Constraint change** | constraints (iteration limit, parallel limit, etc.) | Preserve Trail | Minor adjustment |
| **DAG addition** | Add new Atom | Append to Trail | Scope expansion |
| **DAG deletion** | Delete unresolved Atom | Append to Trail | Scope reduction |
| **Force OR selection** | Force specify OR branch choice | Append to Trail | Fix exploration direction |
| **Bindings modification** | Overwrite resolved summary | Clear only affected scope | Partial redo |

### 8.4 State Field Addition

```yaml
# Add to Objective section
corrections:
  - timestamp: "2025-01-15T10:30:00Z"
    type: "dag_adjustment"    # or "objective_change"
    description: "Changed auth method from JWT to Session"
    trail_cleared: false
```

### 8.5 Worker Interruption Implementation

| Situation | Interruption Method | Result Handling |
|------|----------|-----------|
| Worker running | Terminate process via KillShell | Not reflected in Bindings |
| Multiple parallel Workers running | Terminate all Workers | Discard all results |
| Verifier running | Ignore post-termination judgment | Skip base_case evaluation |

### 8.6 `/redirect` Command Specification

```yaml
---
description: "Redirect - Immediately interrupt running loop and change direction"
argument-hint: "[modification content (optional)]"
allowed-tools: ["Read", "Edit", "AskUserQuestion", "KillShell"]
---
```

**Processing Steps**

1. Set `control.redirect_requested = true`
2. Terminate all running sub agents via KillShell
3. Load state file and present current state
4. Accept user instructions and confirm interactively
5. Determine modification type and update state file
6. Record in `corrections[]`
7. Reset `control.redirect_requested = false`
8. Restart coordinator (proceed to next iteration)
