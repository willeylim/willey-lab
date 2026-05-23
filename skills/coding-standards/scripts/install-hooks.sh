#!/bin/bash
# =============================================================================
# Coding Standards Hook Installer (multi-tool)
#
# Installs enforcement hooks for any of:
#   - Claude Code       (.claude/settings.json + .claude/hooks/)
#   - Factory Droid     (.factory/settings.json + .factory/hooks/)
#   - Aider             (.aider.conf.yml lint-cmd)
#   - Git pre-commit    (.git/hooks/pre-commit)
#
# Usage:
#   install-hooks.sh                # auto-detect installed tools, install for each
#   install-hooks.sh --all          # install for every supported tool
#   install-hooks.sh --claude       # Claude Code only
#   install-hooks.sh --droid        # Factory Droid only
#   install-hooks.sh --aider        # Aider only
#   install-hooks.sh --git          # Git pre-commit only
#   install-hooks.sh --claude --git # Multiple flags allowed
#
# Run after `npx skills add` (or equivalent) to enable enforcement.
# =============================================================================

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

find_project_root() {
  local explicit="${SKILL_PROJECT_DIR:-}"
  if [[ -n "$explicit" ]]; then
    echo "$explicit"; return
  fi

  local dir="$SKILL_DIR"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -d "$dir/.git" || -f "$dir/package.json" || -f "$dir/pyproject.toml" \
       || -f "$dir/go.mod" || -f "$dir/Cargo.toml" || -f "$dir/composer.json" ]]; then
      echo "$dir"; return
    fi
    dir="$(dirname "$dir")"
  done

  echo "$PWD"
}

PROJECT_DIR="$(find_project_root)"

if ! command -v jq >/dev/null 2>&1; then
  echo "install-hooks.sh: 'jq' is required but not installed." >&2
  exit 1
fi

WANT_CLAUDE=0
WANT_DROID=0
WANT_AIDER=0
WANT_GIT=0
AUTO=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)    WANT_CLAUDE=1; WANT_DROID=1; WANT_AIDER=1; WANT_GIT=1; AUTO=0 ;;
    --claude) WANT_CLAUDE=1; AUTO=0 ;;
    --droid)  WANT_DROID=1;  AUTO=0 ;;
    --aider)  WANT_AIDER=1;  AUTO=0 ;;
    --git)    WANT_GIT=1;    AUTO=0 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "install-hooks.sh: unknown flag '$1'" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$AUTO" -eq 1 ]]; then
  [[ -d "$PROJECT_DIR/.claude" ]]              && WANT_CLAUDE=1
  [[ -d "$PROJECT_DIR/.factory" ]]             && WANT_DROID=1
  [[ -f "$PROJECT_DIR/.aider.conf.yml" ]]      && WANT_AIDER=1
  [[ -d "$PROJECT_DIR/.git" ]]                 && WANT_GIT=1

  if [[ $WANT_CLAUDE -eq 0 && $WANT_DROID -eq 0 && $WANT_AIDER -eq 0 && $WANT_GIT -eq 0 ]]; then
    echo "install-hooks.sh: no supported tool configs detected in $PROJECT_DIR." >&2
    echo "Re-run with --claude / --droid / --aider / --git / --all to force install." >&2
    exit 1
  fi
fi

copy_shared_scripts() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  cp "$SKILL_DIR/scripts/coding-standards-check.sh" "$target_dir/coding-standards-check.sh"
  cp "$SKILL_DIR/scripts/validate-review.sh"        "$target_dir/validate-review.sh"
  cp "$SKILL_DIR/scripts/validate-review-hook.sh"   "$target_dir/validate-review-hook.sh"
  cp "$SKILL_DIR/scripts/lint-file.sh"              "$target_dir/lint-file.sh"
  chmod +x "$target_dir"/*.sh
}

merge_settings() {
  local settings_file="$1"
  local hooks_config="$2"
  local label="$3"

  if [[ -f "$settings_file" ]]; then
    local existing has_pre has_post
    existing=$(cat "$settings_file")

    has_pre=$(echo "$existing"  | jq -e '.hooks.PreToolUse'  >/dev/null 2>&1 && echo yes || echo no)
    has_post=$(echo "$existing" | jq -e '.hooks.PostToolUse' >/dev/null 2>&1 && echo yes || echo no)

    if [[ "$has_pre" == "yes" || "$has_post" == "yes" ]]; then
      echo "  WARNING: $settings_file already has hooks configured." >&2
      echo "  Existing hooks NOT overwritten. Required $label hooks:" >&2
      echo "$hooks_config" | jq . >&2
      return 0
    fi

    local merged
    merged=$(echo "$existing" | jq --argjson hooks "$(echo "$hooks_config" | jq '.hooks')" \
      '.hooks = ((.hooks // {}) + $hooks)')
    echo "$merged" | jq . > "$settings_file"
  else
    mkdir -p "$(dirname "$settings_file")"
    echo "$hooks_config" | jq . > "$settings_file"
  fi
}

# -----------------------------------------------------------------------------
# Claude Code
# -----------------------------------------------------------------------------
install_claude() {
  echo "Installing for Claude Code..."
  local hooks_dir="$PROJECT_DIR/.claude/hooks"
  local settings_file="$PROJECT_DIR/.claude/settings.json"

  copy_shared_scripts "$hooks_dir"

  local config
  config=$(cat <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/coding-standards-check.sh",
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
            "timeout": 30,
            "statusMessage": "Validating review completeness..."
          }
        ]
      }
    ]
  }
}
JSON
)

  merge_settings "$settings_file" "$config" "Claude"
  echo "  Claude hooks installed at $hooks_dir"
  echo "  Settings: $settings_file"
}

# -----------------------------------------------------------------------------
# Factory Droid
# -----------------------------------------------------------------------------
install_droid() {
  echo "Installing for Factory Droid..."
  local hooks_dir="$PROJECT_DIR/.factory/hooks"
  local settings_file="$PROJECT_DIR/.factory/settings.json"

  copy_shared_scripts "$hooks_dir"

  local config
  config=$(cat <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Create|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/coding-standards-check.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Create",
        "hooks": [
          {
            "type": "command",
            "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/validate-review-hook.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
JSON
)

  merge_settings "$settings_file" "$config" "Droid"
  echo "  Droid hooks installed at $hooks_dir"
  echo "  Settings: $settings_file"
}

# -----------------------------------------------------------------------------
# Aider
# -----------------------------------------------------------------------------
install_aider() {
  echo "Installing for Aider..."
  local hooks_dir="$PROJECT_DIR/.aider-hooks"
  local conf="$PROJECT_DIR/.aider.conf.yml"

  copy_shared_scripts "$hooks_dir"

  local cmd
  cmd="$hooks_dir/lint-file.sh"

  if [[ -f "$conf" ]]; then
    if grep -qE '^\s*lint-cmd:' "$conf"; then
      echo "  WARNING: $conf already defines lint-cmd. Not overwriting." >&2
      echo "  Add manually:" >&2
      echo "    lint-cmd:" >&2
      echo "      - \"typescript: $cmd\"" >&2
      echo "      - \"javascript: $cmd\"" >&2
      echo "      - \"python: $cmd\"" >&2
      return 0
    fi
    cat >> "$conf" <<YAML

# Added by coding-standards install-hooks.sh
auto-lint: true
lint-cmd:
  - "typescript: $cmd"
  - "javascript: $cmd"
  - "python: $cmd"
  - "go: $cmd"
  - "rust: $cmd"
  - "php: $cmd"
YAML
  else
    cat > "$conf" <<YAML
# Created by coding-standards install-hooks.sh
auto-lint: true
lint-cmd:
  - "typescript: $cmd"
  - "javascript: $cmd"
  - "python: $cmd"
  - "go: $cmd"
  - "rust: $cmd"
  - "php: $cmd"
YAML
  fi

  echo "  Aider lint scripts installed at $hooks_dir"
  echo "  Config: $conf"
}

# -----------------------------------------------------------------------------
# Git pre-commit
# -----------------------------------------------------------------------------
install_git() {
  echo "Installing git pre-commit hook..."
  local git_dir
  git_dir=$(git -C "$PROJECT_DIR" rev-parse --git-dir 2>/dev/null || true)
  if [[ -z "$git_dir" ]]; then
    echo "  Not a git repository — skipping." >&2
    return 0
  fi
  if [[ "$git_dir" != /* ]]; then
    git_dir="$PROJECT_DIR/$git_dir"
  fi

  local target="$git_dir/hooks/pre-commit"

  if [[ -f "$target" ]] && ! grep -q 'coding-standards' "$target" 2>/dev/null; then
    echo "  WARNING: $target already exists and is not ours. Backing up to $target.bak" >&2
    cp "$target" "$target.bak"
  fi

  cp "$SKILL_DIR/scripts/pre-commit.sh" "$target"
  chmod +x "$target"

  # Ensure shared scripts are reachable from the canonical location
  local shared_dir
  if [[ -d "$PROJECT_DIR/.claude/hooks" ]]; then
    shared_dir="$PROJECT_DIR/.claude/hooks"
  elif [[ -d "$PROJECT_DIR/.factory/hooks" ]]; then
    shared_dir="$PROJECT_DIR/.factory/hooks"
  else
    shared_dir="$SKILL_DIR/scripts"
  fi

  echo "  Pre-commit installed at $target"
  echo "  Lint script source: $shared_dir/lint-file.sh"
}

# -----------------------------------------------------------------------------
# Drive
# -----------------------------------------------------------------------------
echo "Coding standards installer"
echo "  project: $PROJECT_DIR"
echo "  skill:   $SKILL_DIR"
echo

INSTALLED=0
if [[ $WANT_CLAUDE -eq 1 ]]; then install_claude; INSTALLED=1; echo; fi
if [[ $WANT_DROID  -eq 1 ]]; then install_droid;  INSTALLED=1; echo; fi
if [[ $WANT_AIDER  -eq 1 ]]; then install_aider;  INSTALLED=1; echo; fi
if [[ $WANT_GIT    -eq 1 ]]; then install_git;    INSTALLED=1; echo; fi

if [[ $INSTALLED -eq 0 ]]; then
  echo "Nothing installed." >&2
  exit 1
fi

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$PROJECT_DIR/.coding-standards-installed"

echo "Done."
echo
echo "Verify:"
[[ $WANT_CLAUDE -eq 1 ]] && echo "  Claude:  claude /hooks"
[[ $WANT_DROID  -eq 1 ]] && echo "  Droid:   droid /hooks"
[[ $WANT_AIDER  -eq 1 ]] && echo "  Aider:   inspect .aider.conf.yml"
[[ $WANT_GIT    -eq 1 ]] && echo "  Git:     git commit (stage a violating file to test)"
