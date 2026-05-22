#!/bin/bash
# =============================================================================
# Coding Standards Hook Installer
# Copies the check script into .claude/hooks/ and wires it into settings.json
# Run this after `npx skills add` to enable enforcement hooks.
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
CLAUDE_DIR="$PROJECT_DIR/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "Installing coding-standards hooks..."

mkdir -p "$HOOKS_DIR"

cp "$SKILL_DIR/scripts/coding-standards-check.sh" "$HOOKS_DIR/coding-standards-check.sh"
chmod +x "$HOOKS_DIR/coding-standards-check.sh"

HOOKS_CONFIG='{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/coding-standards-check.sh",
            "args": [],
            "timeout": 15,
            "statusMessage": "Checking coding standards..."
          }
        ]
      }
    ]
  }
}'

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  if echo "$EXISTING" | jq -e '.hooks.PreToolUse' >/dev/null 2>&1; then
    echo "WARNING: $SETTINGS_FILE already has PreToolUse hooks."
    echo "Hooks NOT overwritten. Merge manually if needed."
    echo ""
    echo "Required hook config:"
    echo "$HOOKS_CONFIG" | jq .
    exit 0
  fi
  MERGED=$(echo "$EXISTING" | jq --argjson hooks "$(echo "$HOOKS_CONFIG" | jq '.hooks')" '.hooks = ((.hooks // {}) + $hooks)')
  echo "$MERGED" | jq . > "$SETTINGS_FILE"
else
  echo "$HOOKS_CONFIG" | jq . > "$SETTINGS_FILE"
fi

echo "Done. Hook installed to $HOOKS_DIR/coding-standards-check.sh"
echo "Settings updated at $SETTINGS_FILE"
echo ""
echo "Verify with: claude /hooks"
