#!/bin/bash

# AoT Loop PreToolUse Hook
# Auto-approves tool calls when AoT Loop state file exists
#
# This hook checks if an AoT Loop state file exists and is in an active state,
# then automatically approves Edit, Write, and Bash tool calls.
#
# Decision logic:
# - No AoT state file → exit 0 (no decision, use default behavior)
# - status = stopped or completed → exit 0 (loop finished)
# - status = pending or running → approve with permissionDecision: allow

set -euo pipefail

# Check for required dependencies
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if AoT state file exists
AOT_STATE_FILE=".claude/aot-loop-state.md"

if [[ ! -f "$AOT_STATE_FILE" ]]; then
  # No active AoT loop - use default behavior
  exit 0
fi

# Parse YAML frontmatter (between first two --- lines)
FRONTMATTER=$(awk '/^---$/{p=!p; if(!p) exit; next} p' "$AOT_STATE_FILE")

# Extract status field using robust awk-based extraction
STATUS=$(echo "$FRONTMATTER" | awk '/^  status:/ { sub(/^[^:]+: */, ""); gsub(/["'"'"']/, ""); print; exit }')

# Only auto-approve if loop is active (pending or running)
if [[ "$STATUS" == "stopped" ]] || [[ "$STATUS" == "completed" ]]; then
  exit 0
fi

# Auto-approve: Return PreToolUse decision to allow without permission prompt
jq -n --arg status "$STATUS" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": ("AoT Loop active (status: " + $status + ") - auto-approved")
  }
}'
exit 0
