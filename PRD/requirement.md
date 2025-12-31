## 1) Goal

Implement a general-purpose agent that autonomously iterates until objective completion, not as a simple loop, but with **halting guarantees** and **convergence guarantees**.

* Outer: Agent loop (observe → update → verify → continue/stop)
* Inner: Recursive function analogy (base case and monotonic argument reduction)
* Problem representation: Unified as a DAG including AND/OR from AoT (Atom of Thoughts)

---

## 2) Core Concepts (Invariants)

### 2.1 Halting: Base Case (Externally Verifiable)

* Completion conditions are expressed as **externally verifiable** (e.g., tests pass, artifact exists, verification command succeeds).
* When the base case is satisfied, **immediately halt**.

### 2.2 Convergence: Monotonic Decrease

* The essence of progress in each iteration is that the "problem (recursive arguments)" **becomes smaller**.
* If it doesn't become smaller, don't repeat the same approach out of inertia—**switch exploration strategies**.

### 2.3 AoT = Arguments: DAG Contraction

* Decompose problems into Atoms and maintain them as a DAG with dependencies (AND/OR).
* Replace solved Atoms with **result summaries** to contract the DAG (for problem reduction, not context bloat).

### 2.4 OR Branches and Backtracking

* The DAG has OR (alternative choice points) in addition to AND.
* On failure, don't restart everything—backtrack to the OR branch with highest relevance and **swap to an alternative branch** (internal AoT operation).

### 2.5 Persistence: Single State File

* Persistence is minimal, assuming a single file.
* The state answers three questions:

    1. What must be satisfied to complete (Goal/Base case)
    2. What is currently unresolved (Atom + dependency DAG)
    3. Where can we backtrack to change branches (OR selection history)

---

## 3) User Operations (Command Requirements)

### 3.1 Alignment Command (Pre-loop)

**Responsibilities**

* Establish agreement equivalent to "alignment with manager" as the Objective.
* Simultaneously form the initial AoT DAG (Work graph) (initial decomposition is the responsibility).
* The agent loop cannot start without established alignment.

**Agreements to Establish (Minimum)**

* Background purpose (why do it)
* Output image (what should be produced)
* Completion criteria summary (assumes externally verifiable)

### 3.2 Agent Loop Start Command

**Preconditions (Gate)**

* Objective is "aligned" (background purpose, output image, completion criteria summary exist in state).
* Initial Work graph (AoT DAG) exists in state.

### 3.3 Stop Command (Manual Stop)

**Responsibilities**

* Issue a stop request to the running agent loop and record the stop reason (optional) in state.
* Can stop independently of the base case (treated as a stop reason separate from success/failure).
* Work graph / Bindings / Trail at stop time are preserved (stop without losing state).

### 3.4 Redirect Command (Immediate Interrupt)

**Responsibilities**

* Immediately interrupt the running agent loop, redirect, and continue the loop.
* Immediately interrupt running sub agents (Worker/Verifier, etc.) and discard results.
* Accept user instructions and interactively clarify modification details through agent dialogue.

**Modifiable Scope**

* Alignment change (goal, base_case, background purpose, deliverables) → Clear Trail
* DAG adjustment (add/remove Atom, force OR selection) → Append to Trail
* Constraint change (iteration limit, etc.) → Preserve Trail
* Bindings modification (overwrite resolved summary) → Clear only affected scope

**Trail Impact Rules**

* Alignment change: Past selection history becomes invalid, clear Trail and start fresh
* DAG adjustment: Selection history remains valid, append `{type: "user_correction", ...}`
* Record all redirects in corrections[] (audit trail)

---

## 4) State File Contract (State Contract v1.2)

### 4.1 Objective (goal / base_case / constraints + alignment + execution control)

* `goal`: Purpose (minimal summary)
* `base_case`: Externally verifiable completion condition (assumes machine-evaluable)
* `constraints`: Minimal constraints (iteration limit, etc.)

**[Alignment Information (Added)]**

* `background_intent`: Background purpose summary
* `deliverables`: Output image (deliverables summary)
* `definition_of_done`: Human-readable completion criteria summary (consistent with base_case)

**[Execution Control (Added)]**

* `control.stop_requested`: boolean
* `control.stop_reason`: Short summary (optional)
* `control.redirect_requested`: boolean (redirect in progress flag)

**[Redirect History (Added)]**

* `corrections[]`: List of redirect records
    * `timestamp`: Modification datetime
    * `type`: `"objective_change"` | `"dag_adjustment"` | `"constraint_change"` | `"bindings_override"`
    * `description`: Modification summary
    * `trail_cleared`: Whether Trail was cleared

### 4.2 Work Graph (AoT DAG: Atoms and AND/OR Dependencies)

* Atom node collection
* Dependencies (AND/OR)
* Unresolved Atoms must be identifiable

### 4.3 Bindings (Replacement Results for Contraction)

* References replacing solved Atoms with "result summaries"
* Contract the DAG through summary references thereafter

### 4.4 Trail (OR Branch Selection History)

* OR branch selection history (minimal stack)
* Must be able to identify OR selection points to backtrack to on failure

---

## 5) Loop Operation Requirements (Observe → Update → Verify → Continue/Stop)

* **Observe**: Reference externally verifiable information and state (unresolved Atoms / Trail / stop_requested).
* **Update**: Choose the next action to solve unresolved Atoms, and when solved, reflect summary in Bindings and contract DAG.
* **Verify**: Evaluate base_case with external verification.
* **Continue/Stop**:

    * `control.redirect_requested = true` → Redirect (interrupt running agent, continue after interactive modification)
    * `control.stop_requested = true` → Manual stop (may stop with priority over base_case)
    * base_case satisfied → Completion stop
    * Not satisfied → Next iteration. However, if "problem doesn't shrink", switch exploration strategy (no inertia loops)

---

## 6) Failure/Stop Requirements (Stop Reason Organization)

* **Alignment not established** (Objective alignment information insufficient, or initial Work graph not formed):

    * Loop doesn't start, stop at start gate
* **Manual stop** (stop_requested):

    * Can stop even without reaching base case (state preserved)
* **Completion stop** (base_case satisfied):

    * Immediate stop

---

## 7) Sub Agent Utilization Requirements

Define design requirements that leverage the essential benefits of Sub Agents (child agents via Task tool).

### 7.1 Essential Characteristics of Sub Agents

| Characteristic | Description | Design Implication |
|------|------|-------------|
| **Context isolation** | Independent workspace from parent context | Exploration failures/trials don't pollute main |
| **Concurrent operation** | Multiple agents can run simultaneously | Can solve AND-independent Atoms simultaneously |
| **Failure localization** | Child failures don't propagate to parent | Backtrack cost becomes lightweight |
| **Summary return** | Returns only results to parent | Naturally aligns with DAG contraction (Bindings replacement) |

### 7.2 Parallel Execution Requirements

#### 7.2.1 AND Parallel (Simultaneous Execution of Independent Atoms)

**Permission Conditions**

* Multiple Atoms are "dependency-resolved" and "mutually AND-independent"
* Each Atom's execution doesn't destroy other Atoms' state (no side-effect collision)

**Behavior**

* Simultaneously execute qualifying Atom groups via sub agents
* Wait for all agents to complete, reflect results in Bindings
* If even one fails, reflect only successes, record failures in Trail

**Example**

```
Work graph:
  A (resolved)
  ├─ B (AND) ← executable
  └─ C (AND) ← executable (independent of B)
      └─ D (AND) ← depends on B, C, waiting

→ Execute B, C in parallel
→ After both succeed, D becomes executable
```

#### 7.2.2 OR Parallel (Speculative Parallel Execution)

**Permission Conditions**

* Multiple OR branch choices exist
* Each choice's execution cost is sufficiently smaller than "retry cost after failure"
* Explicitly set `speculative: true` (default is sequential)

**Behavior**

* Simultaneously execute multiple OR branch choices via sub agents
* Adopt the first successful choice, abort others (discard results)
* If all fail, record all results in Trail and backtrack

**Example**

```
OR_group: "auth_method"
  ├─ choice_1: JWT implementation
  └─ choice_2: Session implementation

If speculative: true
→ Execute both in parallel
→ Adopt whichever succeeds first, abort the other
```

### 7.3 Context Isolation Utilization Patterns

#### 7.3.1 Exploration Phase Isolation (Probe Agent)

**Purpose**

* Isolate "is this approach viable" investigation from main context
* Failures don't pollute parent state

**Pattern**

1. Parent agent delegates "exploration task" to sub agent
2. Sub agent only investigates (no code changes, or temporary branch)
3. Returns summary result: `feasible: true/false` + `findings`
4. Parent decides whether to proceed based on result

**Application Scenarios**

* Investigating new library adoption viability
* Pre-validation of refactoring approach
* Hypothesis verification for error causes

#### 7.3.2 Execution Phase Isolation (Worker Agent)

**Purpose**

* Confine actual code changes to sub agent
* Facilitate rollback on failure

**Pattern**

1. Parent agent passes "execution task" and "success criteria" to sub agent
2. Sub agent executes and verifies success criteria
3. Success: Commit changes + return summary to parent
4. Failure: Discard changes + return failure reason to parent

#### 7.3.3 Verification Phase Isolation (Verifier Agent)

**Purpose**

* Perform base_case evaluation in independent agent
* Handle verification logic complexity

**Pattern**

1. Parent agent passes "verification target" and "base_case definition" to sub agent
2. Sub agent verifies via external command execution, etc.
3. Returns result: `passed: true/false` + `evidence`

### 7.4 Agent Types and Responsibilities

| Agent Type | Responsibility | Tool Restrictions | Output Format |
|------------|------|-----------|----------|
| **Coordinator** | DAG management, agent spawning, result integration | State file operations only | N/A (parent) |
| **Probe** | Feasibility investigation | Read-only (no modifications) | `{feasible, findings, cost_estimate}` |
| **Worker** | Actual Atom resolution | Full (can modify) | `{success, bindings_delta, artifacts}` |
| **Verifier** | External base_case verification | Bash (verification commands) only | `{passed, evidence, failures}` |

#### 7.4.1 Agent Coordination Patterns

```
Coordinator (parent)
    │
    ├─ Probe ──→ Decide based on investigation results
    │
    ├─ Worker ──→ Reflect execution results in Bindings
    │    ├─ Worker (parallel)
    │    └─ Worker (parallel)
    │
    └─ Verifier ──→ base_case determination
```

#### 7.4.2 Agent Spawning Decision Criteria

| Situation | Agent to Spawn | Reason |
|------|---------------|------|
| Entering unknown technical territory | Probe | Isolate failure risk from main |
| Multiple AND-independent Atoms exist | Worker × N (parallel) | Efficiency through parallelization |
| Stuck at OR branch | Probe × N or Worker × N | Speculative execution or pre-investigation |
| Complex base_case evaluation | Verifier | Separate verification logic |
| Solving a single simple Atom | Worker (sequential) | Avoid overhead |

### 7.5 Sub Agent Utilization Constraints

* **Parallel limit**: Concurrent agent count limited by `constraints.max_parallel_agents` (default: 3)
* **Speculative execution cost**: `speculative: true` requires explicit specification, default is sequential
* **Probe modification prohibition**: Probe agents cannot use file modification tools
* **Summary obligation**: All sub agents must return results as structured summaries (no raw logs)
