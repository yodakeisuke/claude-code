---
description: "This skill should be used when you need to manipulate the AoT DAG (Work Graph) structure. Use it when decomposing Atoms into sub-tasks, resolving Atoms, managing AND/OR dependencies, performing backtracking on OR branches, or shrinking the DAG by replacing resolved Atoms with summaries in Bindings."
---

# AoT DAG (Atom of Thoughts)

Decompose problems into Atoms and manage them as a DAG with dependencies (AND/OR).

## DAG Structure

### Atom

The smallest unit of a task:

| status | Description |
|--------|------|
| `pending` | Not started, waiting for dependencies |
| `in_progress` | In execution |
| `resolved` | Complete, summary in Bindings |

### Dependencies

**AND dependency**: Specified via `depends_on`. Cannot execute until all resolved.

**OR dependency**: Defined in `or_groups`. Select and execute one from choices.

## Atom Operations

### Decomposition

```yaml
# Before
atoms:
  - id: A2
    description: "Implement auth logic"
    status: pending
    depends_on: [A1]

# After
atoms:
  - id: A2
    status: pending              # Parent stays pending
    depends_on: [A1]
  - id: A3
    description: "Password hashing"
    depends_on: [A1]             # Copy dependencies
  - id: A4
    description: "JWT generation"
    depends_on: [A1]

decompositions:
  - parent: A2
    children: [A3, A4]
    reason: "Split auth logic into hashing and token"
```

### Resolution

```yaml
atoms:
  - id: A1
    status: resolved
bindings:
  A1:
    summary: "Created User model"
    artifacts: ["src/models/user.ts"]
```

## Auto-Backtracking

On OR branch failure, automatically switch to alternative.

```yaml
# After A4_jwt fails
or_groups:
  auth_method:
    choices: [A4_jwt, A4_session]
    selected: A4_session      # Auto-switched
    failed: [A4_jwt]          # Failure tracking
trail:
  - or_group: auth_method
    selected: A4_session
    reason: "Auto-backtrack: A4_jwt failed"
```

## Executable Atom Determination

```python
def get_executable_atoms(state):
    ready = []
    for atom in state.atoms:
        if atom.status != 'pending':
            continue
        if atom.or_group:
            if state.or_groups[atom.or_group].selected != atom.id:
                continue
        if all(get_atom(dep).status == 'resolved' for dep in atom.depends_on):
            ready.append(atom)
    return ready
```
