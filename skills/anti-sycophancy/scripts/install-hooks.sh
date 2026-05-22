#!/bin/bash
# =============================================================================
# Anti-Sycophancy Hook Installer
# Copies hooks into .claude/hooks/ and wires them into settings.json
# Run this after `npx skills add` to enable enforcement hooks.
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
CLAUDE_DIR="$PROJECT_DIR/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "Installing anti-sycophancy hooks..."

mkdir -p "$HOOKS_DIR"

cp "$SKILL_DIR/scripts/sycophancy-check.sh" "$HOOKS_DIR/sycophancy-check.sh"
cp "$SKILL_DIR/scripts/stop-evaluator.sh" "$HOOKS_DIR/stop-evaluator.sh"
chmod +x "$HOOKS_DIR/sycophancy-check.sh"
chmod +x "$HOOKS_DIR/stop-evaluator.sh"

HOOKS_CONFIG='{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/sycophancy-check.sh",
            "args": [],
            "timeout": 10,
            "statusMessage": "Running integrity check..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/stop-evaluator.sh",
            "args": [],
            "timeout": 15,
            "statusMessage": "Evaluating response integrity..."
          }
        ]
      }
    ]
  }
}'

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  if echo "$EXISTING" | jq -e '.hooks' >/dev/null 2>&1; then
    echo "WARNING: $SETTINGS_FILE already has hooks configured."
    echo "Hooks NOT overwritten. Merge manually if needed."
    echo ""
    echo "Required hook config:"
    echo "$HOOKS_CONFIG" | jq .
    exit 0
  fi
  MERGED=$(echo "$EXISTING" | jq --argjson hooks "$(echo "$HOOKS_CONFIG" | jq .hooks)" '. + {hooks: $hooks}')
  echo "$MERGED" | jq . > "$SETTINGS_FILE"
else
  echo "$HOOKS_CONFIG" | jq . > "$SETTINGS_FILE"
fi

echo "Done. Hooks installed to $HOOKS_DIR"
echo "Settings updated at $SETTINGS_FILE"
echo ""
echo "Verify with: claude /hooks"
