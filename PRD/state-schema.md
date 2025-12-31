# State Schema v1.3

Structure definition for state file `.claude/aot-loop-state.md`.

**v1.3 Changes**: Supports checklist format for base_case, negative conditions, and qualitative assessment (LLM as a Judge).

---

## 1. File Format

YAML frontmatter + Markdown body structure.

```
---
(YAML frontmatter: structured data)
---

# Original Prompt

(Markdown body: user's original request)
```

---

## 2. Section List

| Section | Required | Empty Allowed | Description |
|-----------|:----:|:------:|------|
| objective | ✓ | × | Goal, completion criteria, constraints |
| control | ✓ | × | Execution control flags |
| atoms | ✓ | × | Work Graph (at least 1) |
| decompositions | × | ✓ | Atom decomposition relationships |
| or_groups | × | ✓ | OR branch definitions |
| bindings | ✓ | ✓ | Resolved Atom summaries |
| trail | ✓ | ✓ | OR selection history |
| corrections | ✓ | ✓ | Redirect history |

---

## 3. Complete Schema

```yaml
---
# === Objective ===
objective:
  goal: "Implement authentication feature"

  # base_case: Legacy format (backward compatible) or Checklist format
  # Format 1: Legacy format
  # base_case:
  #   type: command
  #   value: "npm test -- --grep auth"

  # Format 2: Checklist format (v1.3+)
  base_case:
    checklist:
      - item: "Functional Requirements"
        group:
          - item: "Auth tests pass"
            check:
              type: command
              value: "npm test -- --grep auth"
          - item: "Login API works"
            check:
              type: command
              value: "curl -f http://localhost:3000/api/auth/login"

      - item: "Quality Requirements"
        group:
          - item: "No lint errors"
            check:
              type: command
              value: "npm run lint"
          - item: "No vulnerabilities"
            check:
              type: not_command
              value: "npm audit --audit-level=high"

      - item: "Code Quality"
        check:
          type: quality
          rubric:
            - criterion: "Readability"
              weight: 0.5
              levels:
                1: "Hard to read"
                3: "Mostly readable"
                5: "Very readable"
            - criterion: "Design"
              weight: 0.5
              levels:
                1: "Poor design"
                3: "Mostly appropriate"
                5: "Excellent design"
          pass_threshold: 3.5

  background_intent: "Enable existing users to log in"
  deliverables: "Login API with JWT authentication"
  definition_of_done: "All auth tests pass"
  constraints:
    max_iterations: 20
    max_parallel_agents: 3
    max_stall_count: 3

# === Execution Control ===
control:
  status: running                           # pending | running | stopped | completed
  iteration: 5
  stall_count: 0
  prev_pending_count: 3                     # Previous pending Atom count (for progress evaluation)
  stop_requested: false
  stop_reason: null
  redirect_requested: false

# === Work Graph ===
atoms:
  - id: A1
    description: "User model definition"
    status: resolved                        # pending | in_progress | resolved
    depends_on: []

  - id: A2
    description: "Auth logic implementation"
    status: pending
    depends_on: [A1]

  - id: A3
    description: "Password hashing"
    status: resolved
    depends_on: [A1]

  - id: A4
    description: "JWT generation"
    status: in_progress
    depends_on: [A1]
    or_group: token_method                  # Optional: only when belonging to OR group

  - id: A5
    description: "Login endpoint"
    status: pending
    depends_on: [A3, A4]                    # AND dependency

# === Decompositions ===
decompositions:
  - parent: A2
    children: [A3, A4]
    reason: "Split auth logic into hashing and token"

# === OR Groups (Optional: only when needed) ===
or_groups:
  token_method:
    choices: [A4, A4_alt]
    selected: A4
    failed: []              # Failed choices (for auto-backtracking)

# === Bindings ===
bindings:
  A1:
    summary: "Created User model"
    artifacts: ["src/models/user.ts"]
  A3:
    summary: "Implemented hashing with bcrypt"
    artifacts: ["src/utils/auth.ts"]

# === Trail ===
trail:
  - or_group: token_method
    selected: A4
    reason: "JWT is stateless"
    timestamp: "2025-01-15T10:00:00Z"

# === Corrections ===
corrections: []
---

# Original Prompt

Please implement user authentication feature.
```

---

## 4. Field Details

### 4.1 objective

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| goal | string | ✓ | Minimal summary of purpose |
| base_case | object | ✓ | Completion criteria (legacy or checklist format) |
| background_intent | string | ✓ | Background purpose |
| deliverables | string | ✓ | Deliverables summary |
| definition_of_done | string | ✓ | Human-readable completion criteria summary |
| constraints.max_iterations | int | ✓ | Iteration limit (default: 20) |
| constraints.max_parallel_agents | int | ✓ | Parallel limit (default: 3) |
| constraints.max_stall_count | int | ✓ | Stall tolerance count (default: 3) |

#### base_case Format

**Format 1: Legacy format (backward compatible)**

```yaml
base_case:
  type: command | file | assertion
  value: "verification command/path/condition"
```

**Format 2: Checklist format (v1.3+)**

```yaml
base_case:
  checklist:
    - item: "Item name"
      check:               # Single check
        type: command | file | not_command | not_file | assertion | quality
        value: "..."       # For command/file/not_command/not_file/assertion
        # For quality, specify rubric or criteria separately

    - item: "Group name"
      group:               # AND group (all must pass)
        - item: "Child item 1"
          check: ...
        - item: "Child item 2"
          check: ...

    - item: "Choice group"
      any_of:              # OR group (any one passes is OK)
        - item: "Choice 1"
          check: ...
        - item: "Choice 2"
          check: ...
```

#### Verification Method by check.type

| type | value format | Verification Method | PASS Condition | Autonomy |
|------|-------------|---------|-----------|--------|
| `command` | Shell command | Execute command | exit code = 0 | High |
| `file` | File path or glob | Check existence | File exists | High |
| `not_command` | Shell command | Execute command | exit code ≠ 0 | High |
| `not_file` | File path or glob | Check existence | File doesn't exist | High |
| `assertion` | Natural language condition | Agent judgment | Judgment result | Low (confirmation required) |
| `quality` | rubric or criteria | LLM as a Judge | weighted average >= threshold | High |

#### quality Type Details

**Rubric format (recommended)**:

```yaml
check:
  type: quality
  rubric:
    - criterion: "Readability"
      description: "Functions have single responsibility, variable names are meaningful"
      weight: 0.4
      levels:
        1: "Hard to read, unclear what it does"
        3: "Mostly readable but room for improvement"
        5: "Very readable and clear"
    - criterion: "Design"
      description: "Appropriate abstraction and responsibility separation"
      weight: 0.4
      levels:
        1: "God class or giant functions exist"
        3: "Mostly separated but some issues"
        5: "Well separated and extensible"
  pass_threshold: 3.5      # PASS if weighted average is this or higher
  scope: "src/**/*.ts"     # Optional: files to evaluate
```

**Simple format**:

```yaml
check:
  type: quality
  criteria: "Functions under 20 lines, single responsibility, meaningful variable names"
  pass_threshold: 3        # PASS if score 3+ on 1-5 scale
```

**LLM as a Judge Evaluation Flow**:
1. Verifier Agent reads target code
2. Scores each criterion (1-5)
3. Calculates weighted average
4. Compares with pass_threshold to determine PASS/FAIL
5. Returns with judgment rationale (evidence)

### 4.2 control

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| status | enum | ✓ | `pending` \| `running` \| `stopped` \| `completed` |
| iteration | int | ✓ | Current iteration count |
| stall_count | int | ✓ | Consecutive stall count |
| prev_pending_count | int | ✓ | Previous unresolved Atom count (-1 = first, for progress evaluation) |
| stop_requested | bool | ✓ | Manual stop request flag |
| stop_reason | string? | × | Stop reason (optional) |
| redirect_requested | bool | ✓ | Redirect in progress flag |

### 4.3 atoms

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| id | string | ✓ | Unique identifier (sequential: A1, A2, ...) |
| description | string | ✓ | Atom description |
| status | enum | ✓ | `pending` \| `in_progress` \| `resolved` |
| depends_on | string[] | ✓ | List of AND-dependent Atom IDs |
| or_group | string? | × | OR group name if member |

### 4.4 decompositions

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| parent | string | ✓ | Source Atom ID |
| children | string[] | ✓ | Target Atom ID list |
| reason | string | ✓ | Decomposition reason |

### 4.5 or_groups

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| (group_name).choices | string[] | ✓ | Choice Atom ID list |
| (group_name).selected | string | ✓ | Currently selected Atom ID |
| (group_name).failed | string[] | ✓ | Failed choice list (for auto-backtracking) |

### 4.6 bindings

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| (atom_id).summary | string | ✓ | Resolution result summary |
| (atom_id).artifacts | string[] | ✓ | Created/modified file paths |

### 4.7 trail

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| or_group | string | ✓ | OR group name |
| selected | string | ✓ | Selected Atom ID |
| reason | string | ✓ | Selection reason |
| timestamp | string | ✓ | ISO 8601 format |

### 4.8 corrections

| Field | Type | Required | Description |
|-----------|-----|:----:|------|
| timestamp | string | ✓ | ISO 8601 format |
| type | enum | ✓ | `objective_change` \| `dag_adjustment` \| `constraint_change` \| `bindings_override` |
| description | string | ✓ | Modification summary |
| trail_cleared | bool | ✓ | Whether Trail was cleared |

---

## 5. Invariants

### 5.1 Structural Invariants

| Condition | Description |
|------|------|
| `atoms.length >= 1` | At least 1 Atom exists after /align-goal completion |
| `atoms[].id` is unique | Duplicate IDs prohibited |
| `depends_on` is explicit | Dependencies explicitly noted on decomposition |
| No circular dependencies | `depends_on` forms a DAG |
| Parent Atom is pending | Decomposed parent stays pending until all children resolved |

### 5.2 State Transition Invariants

| Condition | Description |
|------|------|
| Atom: `pending → in_progress → resolved` | On failure, reset to pending |
| Control: `pending → running → {stopped, completed}` | One-way transition |

### 5.3 Backtracking Invariants

| Condition | Description |
|------|------|
| Delete failed Atom's Bindings | Retry from clean state |
| Record in Trail before OR switch | Selection history preserved |

---

## 6. Operation Rules

### 6.1 Atom Decomposition

```yaml
# Before
atoms:
  - id: A2
    description: "Auth logic implementation"
    status: pending
    depends_on: [A1]

# After
atoms:
  - id: A2
    description: "Auth logic implementation"
    status: pending              # Parent preserved
    depends_on: [A1]
  - id: A3
    description: "Password hashing"
    status: pending
    depends_on: [A1]             # Explicitly copy dependencies
  - id: A4
    description: "JWT generation"
    status: pending
    depends_on: [A1]

decompositions:
  - parent: A2
    children: [A3, A4]
    reason: "Split auth logic into hashing and token"
```

### 6.2 Atom Resolution

```yaml
# Before
atoms:
  - id: A1
    status: in_progress
bindings: {}

# After
atoms:
  - id: A1
    status: resolved
bindings:
  A1:
    summary: "Created User model"
    artifacts: ["src/models/user.ts"]
```

### 6.3 Backtracking (OR Branch Switch)

```yaml
# Before (when A4 fails)
atoms:
  - id: A4
    status: in_progress
    or_group: token_method
bindings:
  A4:
    summary: "Attempted JWT implementation"
    artifacts: []
trail:
  - or_group: token_method
    selected: A4
    reason: "JWT is stateless"
    timestamp: "2025-01-15T10:00:00Z"

# After
atoms:
  - id: A4
    status: pending              # Reset to pending
    or_group: token_method
  - id: A4_alt
    status: in_progress          # Start alternative
    or_group: token_method
bindings: {}                     # Delete A4 bindings
trail:
  - or_group: token_method
    selected: A4
    reason: "JWT is stateless"
    timestamp: "2025-01-15T10:00:00Z"
  - or_group: token_method
    selected: A4_alt
    reason: "JWT failed, switching to Session"
    timestamp: "2025-01-15T11:00:00Z"
```

### 6.4 Parent Atom Auto-Resolution

```yaml
# Condition: Both A3 and A4 become resolved

# Before
atoms:
  - id: A2
    status: pending
decompositions:
  - parent: A2
    children: [A3, A4]

# After
atoms:
  - id: A2
    status: resolved             # Automatically resolved
bindings:
  A2:
    summary: "Completed via A3, A4 resolution"
    artifacts: []                # Reference children's artifacts
```

---

## 7. Parallel Execution Determination Logic

Agent calculates on-demand (not recorded in state file).

```python
def get_parallel_ready_atoms(state):
    """Return Atoms ready for parallel execution"""
    ready = []
    for atom in state.atoms:
        if atom.status != 'pending':
            continue
        # Check if all dependencies are resolved
        deps_resolved = all(
            get_atom(state, dep).status == 'resolved'
            for dep in atom.depends_on
        )
        if deps_resolved:
            ready.append(atom)
    return ready[:state.objective.constraints.max_parallel_agents]
```

---

## 8. Initial State (After /align-goal)

### 8.1 Legacy Format

```yaml
---
objective:
  goal: "..."
  base_case:
    type: command
    value: "..."
  background_intent: "..."
  deliverables: "..."
  definition_of_done: "..."
  constraints:
    max_iterations: 20
    max_parallel_agents: 3
    max_stall_count: 3

control:
  status: pending
  iteration: 0
  stall_count: 0
  prev_pending_count: -1
  stop_requested: false
  stop_reason: null
  redirect_requested: false

atoms:
  - id: A1
    description: "Initial task"
    status: pending
    depends_on: []

decompositions: []
or_groups: {}
bindings: {}
trail: []
corrections: []
---

# Original Prompt

(User's original request)
```

### 8.2 Checklist Format (v1.3+)

```yaml
---
objective:
  goal: "..."
  base_case:
    checklist:
      - item: "Functional Requirements"
        group:
          - item: "Tests pass"
            check:
              type: command
              value: "npm test"
          - item: "Build succeeds"
            check:
              type: command
              value: "npm run build"

      - item: "Quality Requirements"
        group:
          - item: "No lint errors"
            check:
              type: command
              value: "npm run lint"
          - item: "No vulnerabilities"
            check:
              type: not_command
              value: "npm audit --audit-level=high"

      - item: "Code Quality"
        check:
          type: quality
          criteria: "Code is readable and well designed"
          pass_threshold: 3

  background_intent: "..."
  deliverables: "..."
  definition_of_done: "..."
  constraints:
    max_iterations: 20
    max_parallel_agents: 3
    max_stall_count: 3

control:
  status: pending
  iteration: 0
  stall_count: 0
  prev_pending_count: -1
  stop_requested: false
  stop_reason: null
  redirect_requested: false

atoms:
  - id: A1
    description: "Initial task"
    status: pending
    depends_on: []

decompositions: []
or_groups: {}
bindings: {}
trail: []
corrections: []
---

# Original Prompt

(User's original request)
```
