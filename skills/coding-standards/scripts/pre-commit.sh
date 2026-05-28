#!/bin/bash
# =============================================================================
# Git pre-commit hook — Coding Standards
# Universal, tool-agnostic enforcement. Runs against the staged contents of
# changed files so that any AI coding tool (or human) is gated equally.
#
# Installed to .git/hooks/pre-commit by install-hooks.sh.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GIT_DIR="$(git rev-parse --absolute-git-dir)"

LINTER=""
for candidate in \
  "$REPO_ROOT/.claude/hooks/lint-file.sh" \
  "$REPO_ROOT/.factory/hooks/lint-file.sh" \
  "$GIT_DIR/hooks/coding-standards-lib/lint-file.sh"; do
  if [[ -x "$candidate" ]]; then
    LINTER="$candidate"
    break
  fi
done

if [[ -z "$LINTER" ]]; then
  echo "pre-commit: coding-standards lint-file.sh not found — skipping." >&2
  exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACM \
  | grep -E '\.(ts|tsx|js|jsx|py|go|rs|php|vue|svelte)$' || true)

[[ -z "$STAGED" ]] && exit 0

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

FILES=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  STAGED_PATH="$TMPDIR/$f"
  mkdir -p "$(dirname "$STAGED_PATH")"
  git show ":$f" > "$STAGED_PATH"
  FILES+=("$STAGED_PATH")
done <<< "$STAGED"

[[ ${#FILES[@]} -eq 0 ]] && exit 0

if ! "$LINTER" "${FILES[@]}"; then
  echo "" >&2
  echo "pre-commit: coding standards violations detected. Fix and re-stage." >&2
  exit 1
fi

exit 0
