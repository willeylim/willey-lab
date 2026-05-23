#!/bin/bash
# =============================================================================
# File-path entry point for coding-standards checks.
# Used by Aider (lint-cmd) and git pre-commit, which pass file paths, not
# tool-call JSON. Synthesizes the JSON shape that coding-standards-check.sh
# expects and pipes it through.
#
# Usage: lint-file.sh <path> [<path> ...]
# Exit codes:
#   0  all files clean (or skipped because extension not in scope)
#   1  usage error / missing dependency
#   2  one or more files failed the check
# =============================================================================

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "lint-file.sh: 'jq' is required but not installed." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKER="$SCRIPT_DIR/coding-standards-check.sh"

if [[ ! -x "$CHECKER" ]]; then
  echo "lint-file.sh: cannot find executable checker at $CHECKER" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: lint-file.sh <path> [<path> ...]" >&2
  exit 1
fi

FAILED=0

for FILE in "$@"; do
  [[ -f "$FILE" ]] || continue
  CONTENT=$(cat "$FILE")
  JSON=$(jq -n \
    --arg path "$FILE" \
    --arg content "$CONTENT" \
    '{tool_name: "Write", tool_input: {file_path: $path, content: $content}}')

  if ! echo "$JSON" | "$CHECKER"; then
    FAILED=1
  fi
done

exit "$FAILED"
