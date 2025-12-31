---
description: "This skill should be used when you need to read, write, or manipulate the AoT Loop state file (.claude/aot-loop-state.md). Use it when implementing commands like /align-goal, /enter-recursion, /exit-recursion, /redirect, or when agents need to update Atom status, Bindings, or control flags."
---

# State Contract v1.3

State management schema and operation methods for AoT Loop.

**v1.3 Changes**: Supports checklist format for base_case, negative conditions (not_command, not_file), and qualitative quality assessment (quality).

## File Format

State file: `.claude/aot-loop-state.md`

YAML frontmatter + Markdown body structure:

```
---
(YAML frontmatter: structured data)
---

# Original Prompt

(Markdown body: user's original request)
```

## Section List

| Section | Required | Empty Allowed | Description |
|-----------|:----:|:------:|------|
| objective | Yes | No | Goal, completion criteria, constraints |
| control | Yes | No | Execution control flags |
| atoms | Yes | No | Work Graph (at least 1) |
| decompositions | No | Yes | Atom decomposition relationships |
| or_groups | No | Yes | OR branch definitions |
| bindings | Yes | Yes | Resolved Atom summaries |
| trail | Yes | Yes | OR selection history |
| corrections | Yes | Yes | Redirect history |

## Field Details

### objective

```yaml
objective:
  goal: "Implement authentication feature"
  base_case:
    checklist:
      - item: "Functional Requirements"
        group:
          - item: "Tests pass"
            check:
              type: command
              value: "npm test"
          - item: "No vulnerabilities"
            check:
              type: not_command
              value: "npm audit --audit-level=high"
      - item: "Code Quality"
        check:
          type: quality
          criteria: "Code is readable and well designed"
          pass_threshold: 3
  background_intent: "Enable existing users to log in"
  deliverables: "Login API with JWT authentication"
  definition_of_done: "All auth tests pass"
  constraints:
    max_iterations: 20
    max_parallel_agents: 3
    max_stall_count: 3
```

**Verification method by check.type:**

| type | Verification Method | PASS Condition | Autonomy |
|------|---------|-----------|--------|
| `command` | Execute command | exit code = 0 | High |
| `file` | Check existence | File exists | High |
| `not_command` | Execute command | exit code ≠ 0 | High |
| `not_file` | Check existence | File doesn't exist | High |
| `assertion` | Agent judgment | Judgment result | Low |
| `quality` | LLM as a Judge | weighted avg >= threshold | High |

### control

```yaml
control:
  status: running          # pending | running | stopped | completed
  iteration: 5
  stall_count: 0
  prev_pending_count: 3
  stop_requested: false
  stop_reason: null
  redirect_requested: false
```

### atoms

```yaml
atoms:
  - id: A1
    description: "User model definition"
    status: resolved       # pending | in_progress | resolved
    depends_on: []
    or_group: null         # Optional: OR group membership
```

### bindings

```yaml
bindings:
  A1:
    summary: "Created User model"
    artifacts: ["src/models/user.ts"]
```

### trail

```yaml
trail:
  - or_group: token_method
    selected: A4
    reason: "JWT is stateless"
    timestamp: "2025-01-15T10:00:00Z"
```

## Invariants

- `atoms.length >= 1`: At least 1 Atom after /align-goal
- `atoms[].id` is unique
- No circular dependencies in `depends_on`
- Atom: `pending → in_progress → resolved`
- Control: `pending → running → {stopped, completed}`

## Operation Examples

### Atom Status Update

```yaml
# Before
- id: A2
  status: pending

# After
- id: A2
  status: in_progress
```

### Adding Bindings

```yaml
bindings:
  A2:
    summary: "Implemented auth middleware"
    artifacts: ["src/middleware/auth.ts"]
```
