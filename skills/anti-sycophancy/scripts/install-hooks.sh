#!/bin/bash
# =============================================================================
# Anti-Sycophancy Hook Installer (project- or user-scoped)
#
# Wires two Claude Code hooks into settings.json:
#   UserPromptSubmit -> sycophancy-check.sh   (injects integrity reminders)
#   Stop             -> stop-evaluator.sh      (can force a revision)
#
# Scope:
#   project (default)  hooks live in <project>/.claude/hooks; command uses
#                      ${CLAUDE_PROJECT_DIR} and a per-project copy of the scripts.
#   user / global      config in ~/.claude/settings.json applies to EVERY project;
#                      command points at this skill's scripts in place.
#   Auto-detected: agent session (CLAUDE_PROJECT_DIR set) -> project; a globally
#   installed skill run from a plain shell -> user. Override with --user/--project.
#
# Usage: install-hooks.sh [--user|--global] [--project|--local]
# Run after `npx skills add` to enable the hooks.
# =============================================================================

set -euo pipefail

ORIG_DIR="$(pwd)"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"

if ! command -v jq >/dev/null 2>&1; then
  echo "install-hooks.sh: 'jq' is required but not installed." >&2
  exit 1
fi

resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s' "$CLAUDE_PROJECT_DIR"; return; fi
  if [ -n "${FACTORY_PROJECT_DIR:-}" ]; then printf '%s' "$FACTORY_PROJECT_DIR"; return; fi
  case "$SKILL_DIR" in
    */.claude/skills/*)  printf '%s' "${SKILL_DIR%%/.claude/skills/*}";  return ;;
    */.factory/skills/*) printf '%s' "${SKILL_DIR%%/.factory/skills/*}"; return ;;
  esac
  local root
  root="$(git -C "$ORIG_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ]; then printf '%s' "$root"; return; fi
  if [ "$ORIG_DIR" != "$HOME" ]; then printf '%s' "$ORIG_DIR"; return; fi
  root="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ]; then printf '%s' "$root"; return; fi
  (cd "$SKILL_DIR/../.." && pwd)
}
PROJECT_DIR="$(resolve_project_dir)"

SCOPE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user|--global)   SCOPE="user" ;;
    --project|--local) SCOPE="project" ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-hooks.sh: unknown flag '$1'" >&2; exit 1 ;;
  esac
  shift
done

if [[ -z "$SCOPE" ]]; then
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" || -n "${FACTORY_PROJECT_DIR:-}" ]]; then
    SCOPE="project"
  elif [[ "$PROJECT_DIR" == "$HOME" ]]; then
    SCOPE="user"
  else
    SCOPE="project"
  fi
fi

if [[ "$SCOPE" == "user" ]]; then
  BASE="$HOME"
  SETTINGS_FILE="$HOME/.claude/settings.json"
  chmod +x "$SKILL_DIR"/scripts/*.sh 2>/dev/null || true
  UPS_CMD="$SKILL_DIR/scripts/sycophancy-check.sh"
  STOP_CMD="$SKILL_DIR/scripts/stop-evaluator.sh"
else
  BASE="$PROJECT_DIR"
  SETTINGS_FILE="$BASE/.claude/settings.json"
  HOOKS_DIR="$BASE/.claude/hooks"
  mkdir -p "$HOOKS_DIR"
  cp "$SKILL_DIR/scripts/sycophancy-check.sh" "$HOOKS_DIR/sycophancy-check.sh"
  cp "$SKILL_DIR/scripts/stop-evaluator.sh"   "$HOOKS_DIR/stop-evaluator.sh"
  chmod +x "$HOOKS_DIR/sycophancy-check.sh" "$HOOKS_DIR/stop-evaluator.sh"
  UPS_CMD='${CLAUDE_PROJECT_DIR}/.claude/hooks/sycophancy-check.sh'
  STOP_CMD='${CLAUDE_PROJECT_DIR}/.claude/hooks/stop-evaluator.sh'
fi

echo "Installing anti-sycophancy hooks (scope: $SCOPE)..."

HOOKS_CONFIG=$(jq -n --arg ups "$UPS_CMD" --arg stop "$STOP_CMD" '{
  hooks: {
    UserPromptSubmit: [ { hooks: [ { type: "command", command: $ups, timeout: 10, statusMessage: "Running integrity check..." } ] } ],
    Stop:             [ { hooks: [ { type: "command", command: $stop, timeout: 15, statusMessage: "Evaluating response integrity..." } ] } ]
  }
}')

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  HAS_UPS=$(echo "$EXISTING"  | jq -e '.hooks.UserPromptSubmit' >/dev/null 2>&1 && echo yes || echo no)
  HAS_STOP=$(echo "$EXISTING" | jq -e '.hooks.Stop'             >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$HAS_UPS" == "yes" || "$HAS_STOP" == "yes" ]]; then
    echo "WARNING: $SETTINGS_FILE already defines UserPromptSubmit/Stop hooks."
    echo "Not overwritten. Required hook config:"
    echo "$HOOKS_CONFIG" | jq .
    exit 0
  fi
  # Merge by event key so we coexist with other skills' hooks (e.g. PreToolUse).
  MERGED=$(echo "$EXISTING" | jq --argjson h "$(echo "$HOOKS_CONFIG" | jq '.hooks')" '.hooks = ((.hooks // {}) + $h)')
  echo "$MERGED" | jq . > "$SETTINGS_FILE"
else
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo "$HOOKS_CONFIG" | jq . > "$SETTINGS_FILE"
fi

echo "Done. (scope: $SCOPE)"
echo "Settings: $SETTINGS_FILE"
if [[ "$SCOPE" == "user" ]]; then
  echo "Scripts referenced in place: $SKILL_DIR/scripts/ (applies to all projects)"
else
  echo "Hooks: $BASE/.claude/hooks"
fi
echo ""
echo "Verify with: claude /hooks"

exit 0
