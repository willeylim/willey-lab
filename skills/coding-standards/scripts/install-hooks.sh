#!/bin/bash
# =============================================================================
# Coding Standards Hook Installer
# Copies hook scripts into .claude/hooks/ and wires them into settings.json
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
cp "$SKILL_DIR/scripts/validate-review.sh" "$HOOKS_DIR/validate-review.sh"
cp "$SKILL_DIR/scripts/validate-review-hook.sh" "$HOOKS_DIR/validate-review-hook.sh"
chmod +x "$HOOKS_DIR/coding-standards-check.sh"
chmod +x "$HOOKS_DIR/validate-review.sh"
chmod +x "$HOOKS_DIR/validate-review-hook.sh"

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
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-review-hook.sh",
            "args": [],
            "timeout": 30,
            "statusMessage": "Validating review completeness..."
          }
        ]
      }
    ]
  }
}'

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")

  HAS_PRE=$(echo "$EXISTING" | jq -e '.hooks.PreToolUse' 2>/dev/null && echo "yes" || echo "no")
  HAS_POST=$(echo "$EXISTING" | jq -e '.hooks.PostToolUse' 2>/dev/null && echo "yes" || echo "no")

  if [[ "$HAS_PRE" == "yes" || "$HAS_POST" == "yes" ]]; then
    echo "WARNING: $SETTINGS_FILE already has hooks configured."
    echo "Existing hooks NOT overwritten. Merge manually if needed."
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

echo ""
echo "Done. Hooks installed:"
echo "  PreToolUse:  $HOOKS_DIR/coding-standards-check.sh"
echo "  PostToolUse: $HOOKS_DIR/validate-review-hook.sh"
echo ""
echo "Settings updated at $SETTINGS_FILE"
echo "Verify with: claude /hooks"
