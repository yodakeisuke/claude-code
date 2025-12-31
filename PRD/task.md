# AoT Loop Plugin Implementation Tasks

PRD: [requirement.md](./requirement.md) | Design: [design.md](./design.md) | Schema: [state-schema.md](./state-schema.md)

---

## Phase 1: Foundation Setup

- [x] **1.1** Create directory structure
  - [x] Create `skills/` directory
  - [x] Create `agents/` directory
  - [x] Create `skills/state-contract/`
  - [x] Create `skills/aot-dag/`
  - [x] Create `skills/convergence/`
  - [x] Create `skills/parallel-exec/`

- [x] **1.2** Update plugin.json
  - [x] Add AoT Loop functionality to description
  - [x] Update version

---

## Phase 2: Skills Implementation

### 2.1 state-contract skill
- [x] Create `skills/state-contract/SKILL.md`
  - [x] State Contract v1.2 schema definition
  - [x] YAML frontmatter read/write methods
  - [x] Detailed explanation of each section (objective, control, atoms, etc.)
  - [x] Invariants list
  - [x] Operation examples (Atom resolution, backtracking updates)

### 2.2 aot-dag skill
- [x] Create `skills/aot-dag/SKILL.md`
  - [x] DAG structure explanation (AND/OR dependencies)
  - [x] Atom lifecycle (pending → in_progress → resolved)
  - [x] Decomposition rules (decompositions section)
  - [x] Contraction operation (Bindings replacement)
  - [x] Backtracking procedure (OR branch switching)
  - [x] Parent Atom auto-resolution rules

### 2.3 convergence skill
- [x] Create `skills/convergence/SKILL.md`
  - [x] Progress evaluation logic (DAG shrinking/stalling/expanding)
  - [x] stall_count management
  - [x] Strategy switching patterns
  - [x] Stop conditions (base_case, stop_requested, max_iterations)
  - [x] Inertia loop prohibition principle

### 2.4 parallel-exec skill
- [x] Create `skills/parallel-exec/SKILL.md`
  - [x] AND parallel execution permission conditions
  - [x] OR speculative parallel execution (speculative: true)
  - [x] Parallel-ready Atom determination logic
  - [x] Side-effect conflict detection
  - [x] Result integration patterns

---

## Phase 3: Commands Implementation

### 3.1 align-goal command
- [x] Create `commands/align-goal.md`
  - [x] frontmatter definition (description, argument-hint, allowed-tools)
  - [x] Dialogue flow implementation (free dialogue → extraction/structuring → agreement confirmation)
  - [x] Agreement item verification logic
  - [x] Initial DAG (Work graph) generation
  - [x] State file `.claude/aot-loop-state.md` writing
  - [x] base_case type-specific processing (command/file/assertion)

### 3.2 enter-recursion command
- [x] Create `commands/enter-recursion.md`
  - [x] frontmatter definition
  - [x] Gate verification (alignment confirmation, initial DAG existence confirmation)
  - [x] Update control.status to running
  - [x] coordinator agent spawn
  - [x] Error handling (message on alignment not established)

### 3.3 exit-recursion command
- [x] Create `commands/exit-recursion.md`
  - [x] frontmatter definition
  - [x] Set stop_requested = true
  - [x] Record stop_reason (from arguments)
  - [x] State preservation confirmation message

### 3.4 redirect command
- [x] Create `commands/redirect.md`
  - [x] frontmatter definition (include KillShell in allowed-tools)
  - [x] Immediate interruption of running Worker (KillShell)
  - [x] Present current state (Objective, Work graph, progress)
  - [x] Accept user instructions (AskUserQuestion)
  - [x] Modification scope classification (alignment change/DAG adjustment/constraint change/Bindings modification)
  - [x] Apply Trail impact rules
  - [x] Record in corrections[]
  - [x] Restart coordinator

---

## Phase 4: Agents Implementation

### 4.1 coordinator agent
- [x] Create `agents/coordinator.md`
  - [x] frontmatter (whenToUse, tools, model)
  - [x] systemPrompt definition
  - [x] DAG analysis logic
  - [x] Agent spawn decisions (probe/worker/verifier selection)
  - [x] Parallel execution determination (parallel-exec skill reference)
  - [x] Result integration (Bindings update)
  - [x] Progress evaluation (convergence skill reference)
  - [x] Handoff to next iteration

### 4.2 probe agent
- [x] Create `agents/probe.md`
  - [x] frontmatter (tools: Read, Glob, Grep only)
  - [x] systemPrompt definition
  - [x] Feasibility investigation procedure
  - [x] Output format: `{feasible: bool, findings: string, cost_estimate?: string}`
  - [x] Modification prohibition constraint noted

### 4.3 worker agent
- [x] Create `agents/worker.md`
  - [x] frontmatter (tools: Full)
  - [x] systemPrompt definition
  - [x] Atom resolution procedure
  - [x] Success: commit + return summary
  - [x] Failure: discard changes + return failure reason
  - [x] Output format: `{success: bool, bindings_delta: object, artifacts: string[]}`

### 4.4 verifier agent
- [x] Create `agents/verifier.md`
  - [x] frontmatter (tools: Bash only)
  - [x] systemPrompt definition
  - [x] base_case evaluation procedure
    - [x] type: command → exit code check
    - [x] type: file → existence check
    - [x] type: assertion → Agent judgment
  - [x] Output format: `{passed: bool, evidence: string, failures?: string[]}`

---

## Phase 5: Hooks Extension

### 5.1 SubagentStop hook
- [x] Create `hooks/subagent-stop-hook.sh`
  - [x] Read hook input (JSON from stdin)
  - [x] Read state file
  - [x] Implement decision logic:
    - [x] `stop_requested == true` → approve
    - [x] base_case satisfied → approve
    - [x] DAG shrinking → block + systemMessage
    - [x] DAG stalled → stall_count++, suggest strategy switch
    - [x] `stall_count >= max` → approve
  - [x] JSON output (decision, reason, systemMessage)

### 5.2 hooks.json update
- [x] Add SubagentStop event
  - [x] matcher condition (when coordinator agent exits)
  - [x] command reference

---

## Phase 6: Verification & Integration

### 6.1 State file template
- [x] Create `templates/aot-loop-state.template.md`
  - [x] Initial state sample
  - [x] Commented fields

### 6.2 Documentation update
- [x] Update `README.md`
  - [x] Add AoT Loop feature overview
  - [x] Update command list
  - [x] Add usage examples
- [x] Update `commands/help.md`
  - [x] Add new command descriptions

### 6.3 Integration testing
- [x] Plugin structure verification (18 files)
- [x] JSON syntax verification (hooks.json, plugin.json)
- [x] Shell script syntax verification (subagent-stop-hook.sh)
- [x] Command frontmatter verification (4 commands)
- [x] Agent frontmatter verification (4 agents)
- [x] Skill frontmatter verification (4 skills)
- [x] Template YAML structure verification

---

## Progress Summary

| Phase | Items | Completed | Progress |
|-------|--------|------|--------|
| Phase 1: Foundation Setup | 8 | 8 | 100% |
| Phase 2: Skills | 20 | 20 | 100% |
| Phase 3: Commands | 20 | 20 | 100% |
| Phase 4: Agents | 16 | 16 | 100% |
| Phase 5: Hooks | 8 | 8 | 100% |
| Phase 6: Verification & Integration | 10 | 10 | 100% |
| **Total** | **82** | **82** | **100%** |

---

## Dependencies

```
Phase 1 ──┬──→ Phase 2 (Skills) ✓
          │
          └──→ Phase 3 (Commands) ✓ ──→ Phase 4 (Agents) ✓ ──→ Phase 5 (Hooks) ✓
                                                                    │
                                                                    ↓
                                                             Phase 6 (Verification) ✓
```

**Critical Path**: 1 → 2.1 (state-contract) → 3.1 (align-goal) → 4.1 (coordinator) → 5.1 (SubagentStop) → 6.3 (Integration testing)

---

## Created Files List

### Skills (4 files)
- `skills/state-contract/SKILL.md`
- `skills/aot-dag/SKILL.md`
- `skills/convergence/SKILL.md`
- `skills/parallel-exec/SKILL.md`

### Commands (4 files)
- `commands/align-goal.md`
- `commands/enter-recursion.md`
- `commands/exit-recursion.md`
- `commands/redirect.md`

### Agents (4 files)
- `agents/coordinator.md`
- `agents/probe.md`
- `agents/worker.md`
- `agents/verifier.md`

### Hooks (2 files)
- `hooks/subagent-stop-hook.sh`
- `hooks/hooks.json` (updated)

### Templates (1 file)
- `templates/aot-loop-state.template.md`

### Documentation (2 files)
- `.claude-plugin/plugin.json` (updated)
- `README.md` (updated)

---

## Notes

- Skills are referenced by other components, so implement them first
- state-contract skill is the foundation for all components, highest priority
- coordinator agent controls overall flow, requires thorough testing
- SubagentStop hook coexists with existing Stop hook
- Integration testing requires actual Claude Code environment verification
