#!/bin/bash

# AoT Loop SubagentStop Hook
# Decides whether to continue or stop the loop when any subagent exits
#
# This hook is called for ALL subagent completions.
# It checks if an AoT Loop is active and manages the loop continuation.
#
# Decision logic:
# - No AoT state file → exit 0 (allow normal completion)
# - stop_requested = true → approve (manual stop)
# - status = completed → approve (goal achieved)
# - status != running → exit 0 (not in active loop)
# - Otherwise → block and continue to next iteration

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
  # No active AoT loop - allow normal exit
  exit 0
fi

# Parse YAML frontmatter (between first two --- lines)
FRONTMATTER=$(awk '/^---$/{p=!p; if(!p) exit; next} p' "$AOT_STATE_FILE")

# Robust field extraction - handles quotes, colons in values
extract_field() {
  local field=$1
  local indent=${2:-2}  # default 2 spaces for control fields
  local pattern="^"
  for ((i=0; i<indent; i++)); do pattern+=" "; done
  pattern+="${field}:"

  echo "$FRONTMATTER" | awk -v pat="$pattern" '
    $0 ~ pat {
      sub(/^[^:]+: */, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  '
}

extract_constraint() {
  local field=$1
  extract_field "$field" 4  # constraints are 4-space indented
}

STATUS=$(extract_field "status")
ITERATION=$(extract_field "iteration")
STALL_COUNT=$(extract_field "stall_count")
STOP_REQUESTED=$(extract_field "stop_requested")
REDIRECT_REQUESTED=$(extract_field "redirect_requested")
PREV_PENDING=$(extract_field "prev_pending_count")

MAX_ITERATIONS=$(extract_constraint "max_iterations")
MAX_STALL_COUNT=$(extract_constraint "max_stall_count")

# Default values
# Use -1 for PREV_PENDING to detect first iteration (no previous count)
ITERATION=${ITERATION:-0}
STALL_COUNT=${STALL_COUNT:-0}
PREV_PENDING=${PREV_PENDING:--1}
MAX_ITERATIONS=${MAX_ITERATIONS:-20}
MAX_STALL_COUNT=${MAX_STALL_COUNT:-3}

# Check status - only active loops need processing
if [[ "$STATUS" == "completed" ]]; then
  # Coordinator marked as completed (base_case passed)
  jq -n '{
    "decision": "approve",
    "reason": "AoT Loop completed - base_case satisfied"
  }'
  exit 0
fi

if [[ "$STATUS" != "running" ]]; then
  # pending, stopped, or unknown - use default behavior
  exit 0
fi

# Count current pending/resolved atoms (4-space indent = atoms, not control)
# Note: in_progress is counted as pending for progress evaluation (not yet resolved)
# Use grep with || true to avoid exit on no match (set -e)
PENDING_COUNT=$(echo "$FRONTMATTER" | grep -c '^    status: pending' || true)
IN_PROGRESS_COUNT=$(echo "$FRONTMATTER" | grep -c '^    status: in_progress' || true)
RESOLVED_COUNT=$(echo "$FRONTMATTER" | grep -c '^    status: resolved' || true)

# Ensure numeric values (default to 0 if empty)
PENDING_COUNT=${PENDING_COUNT:-0}
IN_PROGRESS_COUNT=${IN_PROGRESS_COUNT:-0}
RESOLVED_COUNT=${RESOLVED_COUNT:-0}

# For progress evaluation, treat in_progress as pending (work not yet complete)
UNRESOLVED_COUNT=$((PENDING_COUNT + IN_PROGRESS_COUNT))

# ============================================================
# Decision Logic
# ============================================================

# 1. Check redirect requested
if [[ "$REDIRECT_REQUESTED" == "true" ]]; then
  jq -n '{
    "decision": "approve",
    "reason": "Redirect in progress - user intervention"
  }'
  exit 0
fi

# 2. Check manual stop requested
if [[ "$STOP_REQUESTED" == "true" ]]; then
  # Update status to stopped
  TEMP_FILE="${AOT_STATE_FILE}.tmp.$$"
  sed "s/^  status: .*/  status: stopped/" "$AOT_STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$AOT_STATE_FILE"

  jq -n '{
    "decision": "approve",
    "reason": "Manual stop requested"
  }'
  exit 0
fi

# 3. Check iteration limit
if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  TEMP_FILE="${AOT_STATE_FILE}.tmp.$$"
  sed -e "s/^  status: .*/  status: stopped/" \
      -e "s/^  stop_reason: .*/  stop_reason: \"Max iterations reached\"/" \
      "$AOT_STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$AOT_STATE_FILE"

  jq -n --arg iter "$ITERATION" '{
    "decision": "approve",
    "reason": ("Max iterations (" + $iter + ") reached")
  }'
  exit 0
fi

# 4. Evaluate progress and update stall_count
# Use UNRESOLVED_COUNT (pending + in_progress) for accurate progress tracking
NEW_STALL_COUNT=$STALL_COUNT
if [[ $PREV_PENDING -lt 0 ]]; then
  # First iteration - no previous count, don't evaluate stall
  NEW_STALL_COUNT=0
elif [[ $UNRESOLVED_COUNT -lt $PREV_PENDING ]]; then
  # Progress! Reset stall count
  NEW_STALL_COUNT=0
else
  # Stalled or expanding (unresolved >= prev)
  NEW_STALL_COUNT=$((STALL_COUNT + 1))
fi

# 5. Check stall limit
if [[ $NEW_STALL_COUNT -ge $MAX_STALL_COUNT ]]; then
  TEMP_FILE="${AOT_STATE_FILE}.tmp.$$"
  sed -e "s/^  status: .*/  status: stopped/" \
      -e "s/^  stop_reason: .*/  stop_reason: \"Max stall count reached\"/" \
      -e "s/^  stall_count: .*/  stall_count: $NEW_STALL_COUNT/" \
      "$AOT_STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$AOT_STATE_FILE"

  jq -n --arg stall "$NEW_STALL_COUNT" '{
    "decision": "approve",
    "reason": ("Stalled " + $stall + " times without progress, stopping")
  }'
  exit 0
fi

# 6. Check for empty atoms (error state)
if [[ $UNRESOLVED_COUNT -eq 0 ]] && [[ $RESOLVED_COUNT -eq 0 ]]; then
  TEMP_FILE="${AOT_STATE_FILE}.tmp.$$"
  sed -e "s/^  status: .*/  status: stopped/" \
      -e "s/^  stop_reason: .*/  stop_reason: \"No atoms in Work Graph\"/" \
      "$AOT_STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$AOT_STATE_FILE"

  jq -n '{
    "decision": "approve",
    "reason": "Error: No atoms in Work Graph - stopping to prevent infinite loop"
  }'
  exit 0
fi

# 7. Continue iteration
NEXT_ITERATION=$((ITERATION + 1))

# Update state: iteration, stall_count, prev_pending_count
TEMP_FILE="${AOT_STATE_FILE}.tmp.$$"

# Update state file (cross-platform compatible)
# Save UNRESOLVED_COUNT as prev_pending_count for next iteration's progress check
if grep -q '^  prev_pending_count:' "$AOT_STATE_FILE"; then
  # Update existing fields
  sed -e "s/^  iteration: .*/  iteration: $NEXT_ITERATION/" \
      -e "s/^  stall_count: .*/  stall_count: $NEW_STALL_COUNT/" \
      -e "s/^  prev_pending_count: .*/  prev_pending_count: $UNRESOLVED_COUNT/" \
      "$AOT_STATE_FILE" > "$TEMP_FILE"
else
  # Add prev_pending_count after stall_count using awk (portable)
  awk -v iter="$NEXT_ITERATION" -v stall="$NEW_STALL_COUNT" -v pending="$UNRESOLVED_COUNT" '
    /^  iteration:/ { print "  iteration: " iter; next }
    /^  stall_count:/ { print "  stall_count: " stall; print "  prev_pending_count: " pending; next }
    { print }
  ' "$AOT_STATE_FILE" > "$TEMP_FILE"
fi
mv "$TEMP_FILE" "$AOT_STATE_FILE"

# Build system message
if [[ $NEW_STALL_COUNT -gt 0 ]]; then
  SYSTEM_MSG="AoT iteration $NEXT_ITERATION | WARNING: Stall count $NEW_STALL_COUNT/$MAX_STALL_COUNT - Switch strategy or decompose differently"
else
  SYSTEM_MSG="AoT iteration $NEXT_ITERATION | Unresolved: $UNRESOLVED_COUNT | Resolved: $RESOLVED_COUNT | Progress OK"
fi

# Block and continue - the coordinator will be re-invoked
jq -n \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": "Continue AoT Loop iteration",
    "systemMessage": $msg
  }'

exit 0
