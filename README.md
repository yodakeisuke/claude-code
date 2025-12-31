# AoT Loop Plugin

Goal-aligned autonomous iteration with DAG-based task decomposition, convergence guarantees, and backtracking support.

## What is AoT Loop?

AoT (Atom of Thoughts) decomposes complex goals into a DAG (Directed Acyclic Graph) of atomic tasks:

- **Atoms**: Smallest units of work
- **Dependencies**: AND/OR relationships between tasks
- **Convergence**: Loop stops when base_case is satisfied
- **Backtracking**: OR branches allow alternative approaches on failure

## Quick Start

```bash
# Step 1: Align on the goal
/align-goal "Build a REST API with auth, CRUD for todos, and tests"

# Step 2: Start the autonomous loop
/enter-recursion

# The loop will:
# - Decompose into Atoms (user model, auth, endpoints, tests)
# - Execute in dependency order
# - Verify completion via base_case
# - Backtrack if an approach fails
```

## Commands

| Command | Description |
|---------|-------------|
| `/align-goal` | Interactive goal alignment - define objective, deliverables, completion criteria |
| `/enter-recursion` | Start the autonomous loop after alignment |
| `/exit-recursion` | Manually stop the loop (state preserved) |
| `/redirect` | Interrupt and modify direction without stopping |

## How It Works

### 1. Goal Alignment (`/align-goal`)

Interactive dialogue to establish:
- **Background intent**: Why this work is needed
- **Deliverables**: What will be produced
- **Base case**: Externally verifiable completion criteria (e.g., `npm test` passes)

### 2. Work Graph (DAG)

Tasks are decomposed into Atoms with dependencies:

```
A1: Create User model
 └─ A2: Implement auth (depends on A1)
     ├─ A3: Password hashing (depends on A1)
     └─ A4: JWT tokens (depends on A1)
         └─ A5: Login endpoint (depends on A3, A4)
```

### 3. Autonomous Execution

The **coordinator agent** manages each iteration:
1. Analyze the Work Graph
2. Identify executable Atoms (dependencies resolved)
3. Spawn sub-agents (Probe, Worker, Verifier)
4. Integrate results
5. Evaluate progress

### 4. Convergence Guarantees

- **Stopping**: Base case satisfaction, manual stop, or iteration limit
- **Progress**: DAG must shrink (fewer pending Atoms) each iteration
- **Stall detection**: Switch strategy if no progress after N iterations

### 5. Backtracking (OR Branches)

When an approach fails:

```yaml
or_groups:
  auth_method:
    choices: [jwt_auth, session_auth]
    selected: jwt_auth  # If this fails, try session_auth
```

## Sub-Agents

| Agent | Role | Tools |
|-------|------|-------|
| **Coordinator** | Manage iteration, spawn agents | Read, Write, Edit, Task, Glob, Grep, Bash |
| **Probe** | Investigate feasibility (read-only) | Read, Glob, Grep, WebSearch, WebFetch |
| **Worker** | Execute Atom tasks | Read, Write, Edit, Bash, Glob, Grep, Task, WebSearch, WebFetch |
| **Verifier** | Check base_case | Bash, Read, Glob |

## State File

Progress is persisted in `.claude/aot-loop-state.md`:

```yaml
objective:
  goal: "Build REST API"
  base_case:
    type: command
    value: "npm test"

control:
  status: running
  iteration: 5
  stall_count: 0
  prev_pending_count: 2

atoms:
  - id: A1
    description: "User model"
    status: resolved
  - id: A2
    description: "Auth logic"
    status: pending
    depends_on: [A1]
```

## When to Use AoT Loop

**Good for:**
- Complex multi-step tasks requiring decomposition
- Tasks with verifiable completion criteria (tests, commands)
- Work that may need alternative approaches
- Long-running autonomous development

**Not good for:**
- Simple one-shot operations
- Tasks requiring human judgment at each step
- Unclear or subjective success criteria

---

## Installation

### Method 1: Development Mode (Recommended for Testing)

Load the plugin directly from the local directory:

```bash
claude --plugin-dir /path/to/this/repo
```

Once started, commands are available with the `ralph-wiggum-aot:` prefix:
- `/ralph-wiggum-aot:align-goal`
- `/ralph-wiggum-aot:enter-recursion`
- etc.

### Method 2: Local Marketplace (Permanent Installation)

**Step 1:** Create a local marketplace directory with `marketplace.json`:

```bash
mkdir -p ~/claude-marketplace/.claude-plugin
```

Create `~/claude-marketplace/.claude-plugin/marketplace.json`:

```json
{
  "name": "local-marketplace",
  "owner": { "name": "Your Name" },
  "plugins": [
    {
      "name": "ralph-wiggum-aot",
      "source": "/path/to/this/repo",
      "description": "AoT Loop Plugin"
    }
  ]
}
```

**Step 2:** Add the marketplace to Claude Code:

```
/plugin marketplace add ~/claude-marketplace
```

**Step 3:** Install the plugin:

```
/plugin install ralph-wiggum-aot@local-marketplace
```

**Step 4:** Verify installation:

```
/plugin list
```

### Validate Plugin Structure

To verify the plugin is correctly structured:

```
/plugin validate /path/to/this/repo
```

---

## For Help

Run `/help` in Claude Code for detailed command reference and examples.
