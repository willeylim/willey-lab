#!/bin/bash
# =============================================================================
# Coding Standards Hook Installer (multi-tool, project- or user-scoped)
#
# Installs enforcement hooks for any of:
#   - Claude Code       (settings.json + hooks)
#   - Factory Droid     (settings.json + hooks)
#   - Aider             (.aider.conf.yml lint-cmd)
#   - Git pre-commit    (.git/hooks/pre-commit)        [always repo-scoped]
#
# Scope:
#   project (default)  hooks live in <project>/.claude (or .factory); the command
#                      uses ${CLAUDE_PROJECT_DIR} and a per-project copy of the scripts.
#   user / global      hooks live in ~/.claude (or ~/.factory) and apply to EVERY
#                      project; the command points at this skill's scripts in place.
#   Scope is auto-detected: inside an agent session (CLAUDE_PROJECT_DIR set) -> project;
#   a globally-installed skill run from a plain shell -> user. Override with the flags.
#
# Usage:
#   install-hooks.sh                 # auto-detect scope + tools
#   install-hooks.sh --user          # force user/global scope (alias: --global)
#   install-hooks.sh --project       # force project scope (alias: --local)
#   install-hooks.sh --all           # every supported tool
#   install-hooks.sh --claude        # Claude Code only
#   install-hooks.sh --droid         # Factory Droid only
#   install-hooks.sh --aider         # Aider only
#   install-hooks.sh --git           # Git pre-commit only (repo-scoped)
#   Flags combine, e.g.:  install-hooks.sh --user --claude
#
# Run after `npx skills add` (or equivalent) to enable enforcement.
# =============================================================================

set -euo pipefail

ORIG_DIR="$(pwd)"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"

# Resolve the project root robustly, regardless of where the skill is installed
# (repo-root skills/, .claude/skills/, .factory/skills/) and whether an agent
# session env var is present. The README one-liner runs this from a plain shell
# where CLAUDE_PROJECT_DIR is unset, so we must not assume it.
resolve_project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s' "$CLAUDE_PROJECT_DIR"; return; fi
  if [ -n "${FACTORY_PROJECT_DIR:-}" ]; then printf '%s' "$FACTORY_PROJECT_DIR"; return; fi
  case "$SKILL_DIR" in
    */.claude/skills/*)  printf '%s' "${SKILL_DIR%%/.claude/skills/*}";  return ;;
    */.factory/skills/*) printf '%s' "${SKILL_DIR%%/.factory/skills/*}"; return ;;
  esac
  # Caller's working dir — agent sessions run from the project root
  local root
  root="$(git -C "$ORIG_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ]; then printf '%s' "$root"; return; fi
  if [ "$ORIG_DIR" != "$HOME" ]; then printf '%s' "$ORIG_DIR"; return; fi
  # Last resort: climb from skill dir
  root="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ]; then printf '%s' "$root"; return; fi
  (cd "$SKILL_DIR/../.." && pwd)
}
PROJECT_DIR="$(resolve_project_dir)"

if ! command -v jq >/dev/null 2>&1; then
  echo "install-hooks.sh: 'jq' is required but not installed." >&2
  exit 1
fi

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

WANT_CLAUDE=0
WANT_DROID=0
WANT_AIDER=0
WANT_GIT=0
AUTO=1
SCOPE=""   # "" = auto-detect; otherwise "user" or "project"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)             WANT_CLAUDE=1; WANT_DROID=1; WANT_AIDER=1; WANT_GIT=1; AUTO=0 ;;
    --claude)          WANT_CLAUDE=1; AUTO=0 ;;
    --droid)           WANT_DROID=1;  AUTO=0 ;;
    --aider)           WANT_AIDER=1;  AUTO=0 ;;
    --git)             WANT_GIT=1;    AUTO=0 ;;
    --user|--global)   SCOPE="user" ;;
    --project|--local) SCOPE="project" ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "install-hooks.sh: unknown flag '$1'" >&2; exit 1 ;;
  esac
  shift
done

# Auto-detect scope when not forced. An agent session pins us to its project;
# a globally-installed skill (resolved to $HOME) with no project context is a
# user/global install.
if [[ -z "$SCOPE" ]]; then
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" || -n "${FACTORY_PROJECT_DIR:-}" ]]; then
    SCOPE="project"
  elif [[ "$PROJECT_DIR" == "$HOME" ]]; then
    SCOPE="user"
  else
    SCOPE="project"
  fi
fi

# BASE is where project-scope artifacts live; user scope always uses $HOME.
if [[ "$SCOPE" == "user" ]]; then
  BASE="$HOME"
else
  BASE="$PROJECT_DIR"
fi

# In user scope the hooks reference the skill's scripts in place — make sure
# they are executable (npx may not preserve the bit).
if [[ "$SCOPE" == "user" ]]; then
  chmod +x "$SKILL_DIR"/scripts/*.sh 2>/dev/null || true
fi

# Auto-detect targets.
if [[ "$AUTO" -eq 1 ]]; then
  if [[ "$SCOPE" == "user" ]]; then
    [[ -d "$HOME/.claude" ]]         && WANT_CLAUDE=1
    [[ -d "$HOME/.factory" ]]        && WANT_DROID=1
    [[ -f "$HOME/.aider.conf.yml" ]] && WANT_AIDER=1
    # Git hooks are per-repo; not auto-selected for a user install.
    [[ $WANT_CLAUDE -eq 0 && $WANT_DROID -eq 0 && $WANT_AIDER -eq 0 ]] && WANT_CLAUDE=1
  else
    [[ -d "$BASE/.claude" ]]         && WANT_CLAUDE=1
    [[ -d "$BASE/.factory" ]]        && WANT_DROID=1
    [[ -f "$BASE/.aider.conf.yml" ]] && WANT_AIDER=1
    [[ -d "$BASE/.git" ]]            && WANT_GIT=1
    if [[ $WANT_CLAUDE -eq 0 && $WANT_DROID -eq 0 && $WANT_AIDER -eq 0 && $WANT_GIT -eq 0 ]]; then
      if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        WANT_CLAUDE=1
      elif [[ -n "${FACTORY_PROJECT_DIR:-}" ]]; then
        WANT_DROID=1
      else
        echo "  No tool configs detected in $BASE — defaulting to Claude Code hooks." >&2
        WANT_CLAUDE=1
      fi
    fi
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
  local settings_file pre_cmd post_cmd
  if [[ "$SCOPE" == "user" ]]; then
    echo "Installing for Claude Code (user/global)..."
    settings_file="$HOME/.claude/settings.json"
    pre_cmd="$SKILL_DIR/scripts/coding-standards-check.sh"
    post_cmd="$SKILL_DIR/scripts/validate-review-hook.sh"
  else
    echo "Installing for Claude Code (project)..."
    settings_file="$BASE/.claude/settings.json"
    pre_cmd='${CLAUDE_PROJECT_DIR}/.claude/hooks/coding-standards-check.sh'
    post_cmd='${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-review-hook.sh'
    copy_shared_scripts "$BASE/.claude/hooks"
  fi

  local config
  config=$(jq -n --arg pre "$pre_cmd" --arg post "$post_cmd" '{
    hooks: {
      PreToolUse: [ { matcher: "Write|Edit", hooks: [ { type: "command", command: $pre, timeout: 15, statusMessage: "Checking coding standards..." } ] } ],
      PostToolUse: [ { matcher: "Write", hooks: [ { type: "command", command: $post, timeout: 30, statusMessage: "Validating review completeness..." } ] } ]
    }
  }')

  merge_settings "$settings_file" "$config" "Claude"
  echo "  Settings: $settings_file"
  [[ "$SCOPE" == "user" ]] && echo "  Scripts referenced in place: $SKILL_DIR/scripts/ (applies to all projects)"
  [[ "$SCOPE" == "project" ]] && echo "  Hooks: $BASE/.claude/hooks"
}

# -----------------------------------------------------------------------------
# Factory Droid
# -----------------------------------------------------------------------------
install_droid() {
  local settings_file pre_cmd post_cmd
  if [[ "$SCOPE" == "user" ]]; then
    echo "Installing for Factory Droid (user/global)..."
    settings_file="$HOME/.factory/settings.json"
    pre_cmd="$SKILL_DIR/scripts/coding-standards-check.sh"
    post_cmd="$SKILL_DIR/scripts/validate-review-hook.sh"
  else
    echo "Installing for Factory Droid (project)..."
    settings_file="$BASE/.factory/settings.json"
    pre_cmd='"$FACTORY_PROJECT_DIR"/.factory/hooks/coding-standards-check.sh'
    post_cmd='"$FACTORY_PROJECT_DIR"/.factory/hooks/validate-review-hook.sh'
    copy_shared_scripts "$BASE/.factory/hooks"
  fi

  local config
  config=$(jq -n --arg pre "$pre_cmd" --arg post "$post_cmd" '{
    hooks: {
      PreToolUse: [ { matcher: "Create|Edit|ApplyPatch", hooks: [ { type: "command", command: $pre, timeout: 15 } ] } ],
      PostToolUse: [ { matcher: "Create", hooks: [ { type: "command", command: $post, timeout: 30 } ] } ]
    }
  }')

  merge_settings "$settings_file" "$config" "Droid"
  echo "  Settings: $settings_file"
  [[ "$SCOPE" == "user" ]] && echo "  Scripts referenced in place: $SKILL_DIR/scripts/ (applies to all projects)"
  [[ "$SCOPE" == "project" ]] && echo "  Hooks: $BASE/.factory/hooks"
}

# -----------------------------------------------------------------------------
# Aider
# -----------------------------------------------------------------------------
install_aider() {
  local conf cmd
  if [[ "$SCOPE" == "user" ]]; then
    echo "Installing for Aider (user/global)..."
    conf="$HOME/.aider.conf.yml"
    cmd="$SKILL_DIR/scripts/lint-file.sh"
  else
    echo "Installing for Aider (project)..."
    conf="$BASE/.aider.conf.yml"
    copy_shared_scripts "$BASE/.aider-hooks"
    cmd="$BASE/.aider-hooks/lint-file.sh"
  fi

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

  echo "  Config: $conf"
  echo "  Lint command: $cmd"
}

# -----------------------------------------------------------------------------
# Git pre-commit (always repo-scoped — operates on the repo at PROJECT_DIR)
# -----------------------------------------------------------------------------
install_git() {
  echo "Installing git pre-commit hook..."
  local git_dir
  git_dir=$(git -C "$PROJECT_DIR" rev-parse --git-dir 2>/dev/null || true)
  if [[ -z "$git_dir" ]]; then
    if [[ "$SCOPE" == "user" ]]; then
      echo "  Git hooks are per-repository — run 'install-hooks.sh --git' inside each repo." >&2
    else
      echo "  Not a git repository — skipping." >&2
    fi
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

  # Make the hook self-sufficient: ship the checker + lint entry point into the
  # git hooks dir so `--git` alone (without --claude/--droid) produces a working
  # hook. pre-commit.sh searches this location as a fallback.
  copy_shared_scripts "$git_dir/hooks/coding-standards-lib"

  echo "  Pre-commit installed at $target"
  echo "  Lint library: $git_dir/hooks/coding-standards-lib/"
}

# -----------------------------------------------------------------------------
# Drive
# -----------------------------------------------------------------------------
echo "Coding standards installer"
echo "  scope:   $SCOPE"
echo "  base:    $BASE"
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

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$BASE/.coding-standards-installed"

echo "Done. (scope: $SCOPE)"
echo
echo "Verify:"
[[ $WANT_CLAUDE -eq 1 ]] && echo "  Claude:  claude /hooks"
[[ $WANT_DROID  -eq 1 ]] && echo "  Droid:   droid /hooks"
[[ $WANT_AIDER  -eq 1 ]] && echo "  Aider:   inspect $([ "$SCOPE" = user ] && echo "$HOME/.aider.conf.yml" || echo ".aider.conf.yml")"
[[ $WANT_GIT    -eq 1 ]] && echo "  Git:     git commit (stage a violating file to test)"

exit 0
