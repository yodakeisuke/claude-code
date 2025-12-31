---
description: "This skill should be used when deciding whether to execute multiple Atoms in parallel, detecting side-effect conflicts between concurrent operations, or integrating results from parallel Worker agents. Use it in the coordinator agent when multiple Atoms are ready for execution."
---

# Parallel Execution

Determine parallel execution of Sub Agents and integrate results.

## Sub Agent Characteristics

| Characteristic | Description | Design Implication |
|------|------|-------------|
| **Context isolation** | Independent workspace from parent | Exploration failures don't pollute main |
| **Concurrent operation** | Multiple agents run simultaneously | Solve AND-independent Atoms together |
| **Failure localization** | Child failures don't propagate to parent | Lightweight backtrack cost |
| **Summary return** | Returns only results to parent | Naturally aligns with DAG contraction |

## AND Parallel (Simultaneous Independent Atom Execution)

### Permission Conditions

1. Multiple Atoms are "dependency-resolved"
2. Atoms are "mutually AND-independent"
3. Each Atom's execution doesn't destroy other Atoms' state

### Determination Logic

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

    # Apply parallel limit
    max_parallel = state.objective.constraints.max_parallel_agents
    return ready[:max_parallel]
```

### Side-Effect Conflict Detection

**Conflict examples:**

| Atom A | Atom B | Conflict Reason |
|--------|--------|----------|
| Create `src/auth.ts` | Edit `src/auth.ts` | Same file operation |
| Run DB migration | Reference DB schema | DB state dependency |
| Use port 3000 | Test port 3000 | Resource contention |

**Conflict detection heuristics:**

1. Write to same file path
2. Dependency on same external resource (DB, API, port)
3. Global state modification

### Operation Flow

```
Work graph:
  A (resolved)
  ├─ B (AND) ← executable
  └─ C (AND) ← executable (independent of B)
      └─ D (AND) ← depends on B, C, waiting

→ Execute B, C in parallel
→ After both succeed, D becomes executable
```

## OR Parallel (Speculative Parallel Execution)

### Permission Conditions

1. Multiple OR branch choices exist
2. Each choice's execution cost is smaller than "retry cost after failure"
3. Explicitly set `speculative: true`

**Default is sequential execution.** Speculative parallel only when explicitly specified.

### Operation Flow

```
OR_group: "auth_method"
  ├─ choice_1: JWT implementation
  └─ choice_2: Session implementation

If speculative: true
→ Execute both in parallel
→ Adopt whichever succeeds first, abort the other
```

### Result Processing

| Result | Action |
|------|-----------|
| One success | Adopt successful choice, abort others |
| Multiple success | Adopt first success, abort others |
| All fail | Record all results in Trail, backtrack |

## Agent Types and Parallelization

| Agent Type | Parallel | Reason |
|------------|:------:|------|
| **Worker** | Yes | Simultaneous resolution of independent Atoms |
| **Probe** | Yes | Investigation has no side effects |
| **Verifier** | No | base_case evaluated sequentially |
| **Coordinator** | No | Single parent |

## Result Integration

### Parallel Worker Result Processing

```python
def integrate_results(results):
    """Integrate parallel execution results"""
    for result in results:
        atom_id = result['atom_id']

        if result['success']:
            # Reflect in Bindings
            state.bindings[atom_id] = {
                'summary': result['summary'],
                'artifacts': result['artifacts']
            }
            # Mark Atom as resolved
            set_atom_status(atom_id, 'resolved')
        else:
            # Failure: reset to pending
            set_atom_status(atom_id, 'pending')
            # For OR branch, record selection history in Trail
            if atom.or_group:
                record_or_selection(atom.or_group, atom_id, result['reason'])
```

### Partial Success Handling

- Successful Atoms reflected in Bindings
- Failed Atoms reset to pending
- Progress evaluation counts only successes

## Constraints

```yaml
constraints:
  max_parallel_agents: 3    # Concurrent execution limit
```

**When exceeding limit:**

1. Execute higher priority Atoms first
2. Execute remainder in next iteration

**Priority criteria:**

1. Prioritize Atoms with more dependents (critical path)
2. Prioritize shorter estimated execution time
3. Prioritize Atoms executable without decomposition
