#!/bin/bash
#
# Keeper Gate - PreToolUse Hook for Mayor
# Enforces that beads cannot be created without Keeper approval
#
# This hook intercepts bd create and gt convoy create commands
# and blocks them if no keeper_decision exists for the work.
#
# Installed by: install-keeper.sh
# Removed by: uninstall-keeper.sh
#

set -e

# Read the tool input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Extract the command being run
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only check Bash commands
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Check if this is a bead creation or convoy creation command
IS_BD_CREATE=false
IS_CONVOY_CREATE=false

if echo "$COMMAND" | grep -qE '^bd\s+create|^bd\s+--[a-z-]+\s+create'; then
    IS_BD_CREATE=true
fi

if echo "$COMMAND" | grep -qE '^gt\s+convoy\s+create'; then
    IS_CONVOY_CREATE=true
fi

# If not a create command, allow it
if [[ "$IS_BD_CREATE" != true ]] && [[ "$IS_CONVOY_CREATE" != true ]]; then
    exit 0
fi

# Find the keeper decisions directory
# Look in current directory, then parent directories
KEEPER_DECISIONS=""
SEARCH_DIR="$(pwd)"

while [[ "$SEARCH_DIR" != "/" ]]; do
    if [[ -d "$SEARCH_DIR/keeper/decisions" ]]; then
        KEEPER_DECISIONS="$SEARCH_DIR/keeper/decisions"
        break
    fi
    SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done

# If no keeper directory found, Keeper isn't installed - allow command
if [[ -z "$KEEPER_DECISIONS" ]]; then
    exit 0
fi

# Check for recent keeper_decision (within last 24 hours that's still open)
# A decision is considered "active" if it exists and status is approved*
RECENT_DECISION=""
LATEST_DECISION=$(ls -t "$KEEPER_DECISIONS"/*.yaml 2>/dev/null | head -1)

if [[ -n "$LATEST_DECISION" ]]; then
    # Check if decision status is approved
    STATUS=$(grep -E '^\s+status:' "$LATEST_DECISION" | head -1 | sed 's/.*status:\s*//' | tr -d ' "')

    if [[ "$STATUS" == "approved"* ]]; then
        RECENT_DECISION="$LATEST_DECISION"
    fi
fi

# If no approved decision found, BLOCK the command
if [[ -z "$RECENT_DECISION" ]]; then
    echo "KEEPER GATE: BLOCKED" >&2
    echo "" >&2
    echo "Cannot create beads without Keeper approval." >&2
    echo "" >&2
    echo "Run '/keeper-review <spec>' first to get architectural approval." >&2
    echo "" >&2
    echo "Decisions directory: $KEEPER_DECISIONS" >&2
    echo "No approved keeper_decision found." >&2
    exit 1
fi

# Decision exists - allow the command but remind about constraints
DECISION_ID=$(basename "$RECENT_DECISION" .yaml)
echo "KEEPER: Using decision $DECISION_ID" >&2
echo "Remember to include 'Keeper ADR: $DECISION_ID' in bead descriptions." >&2

exit 0
