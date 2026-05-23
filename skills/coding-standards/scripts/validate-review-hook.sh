#!/bin/bash
# =============================================================================
# PostToolUse Hook — Review Completeness Validator
# Fires after a full-file write. If the written file is a coding standards
# review, validates that every applicable rule is covered.
# Works with both Claude Code (Write) and Factory Droid (Create) tool names.
# =============================================================================

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

case "$TOOL_NAME" in
  Write|Create) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')

[[ -z "$CONTENT" ]] && exit 0

# Detect if this is a coding standards review by checking for the required header
if ! echo "$CONTENT" | grep -qE '## Coding Standards Review'; then
  exit 0
fi

# Found a review — validate it
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${FACTORY_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}"
SKILL_SCRIPTS=""

# Look for validate-review.sh in known locations
for candidate in \
  "$SCRIPT_DIR/validate-review.sh" \
  "$SCRIPT_DIR/../skills/coding-standards/scripts/validate-review.sh" \
  "$PROJECT_DIR/.claude/skills/coding-standards/scripts/validate-review.sh" \
  "$PROJECT_DIR/.factory/skills/coding-standards/scripts/validate-review.sh" \
  "$PROJECT_DIR/skills/coding-standards/scripts/validate-review.sh"; do
  if [[ -f "$candidate" ]]; then
    SKILL_SCRIPTS="$candidate"
    break
  fi
done

if [[ -z "$SKILL_SCRIPTS" ]]; then
  echo "validate-review.sh not found — skipping review validation." >&2
  exit 0
fi

# The file was already written by the Write tool, so validate it directly
if [[ -f "$FILE_PATH" ]]; then
  bash "$SKILL_SCRIPTS" "$FILE_PATH"
  exit $?
fi

# Fallback: write content to temp file and validate
TMPFILE=$(mktemp /tmp/review-validate-XXXXXX.md)
trap 'rm -f "$TMPFILE"' EXIT
echo "$CONTENT" > "$TMPFILE"
bash "$SKILL_SCRIPTS" "$TMPFILE"
exit $?
