#!/bin/bash
# =============================================================================
# Coding Standards Review Validator
# Checks that a review output covers every applicable rule for the diff.
#
# Usage:
#   validate-review.sh <review-file>                  # auto-detect diff base
#   validate-review.sh <review-file> --base main      # diff against branch
#   validate-review.sh <review-file> --staged         # validate against staged
# =============================================================================

set -euo pipefail

REVIEW_FILE="${1:-}"
shift || true

DIFF_MODE="auto"
DIFF_BASE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) DIFF_BASE="$2"; DIFF_MODE="base"; shift 2 ;;
    --staged) DIFF_MODE="staged"; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$REVIEW_FILE" ]]; then
  echo "Usage: validate-review.sh <review-file> [--base <branch>] [--staged]" >&2
  exit 1
fi

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo "Review file not found: $REVIEW_FILE" >&2
  exit 1
fi

REVIEW=$(cat "$REVIEW_FILE")

# ---------------------------------------------------------------------------
# Detect changed files
# ---------------------------------------------------------------------------
get_changed_files() {
  case "$DIFF_MODE" in
    base)
      git diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null || git diff --name-only "$DIFF_BASE" 2>/dev/null
      ;;
    staged)
      git diff --name-only --cached 2>/dev/null
      ;;
    auto)
      local base
      base=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "")
      if [[ -n "$base" ]] && [[ "$base" != "$(git rev-parse HEAD)" ]]; then
        git diff --name-only "$base"...HEAD 2>/dev/null
      else
        local staged
        staged=$(git diff --name-only --cached 2>/dev/null)
        if [[ -n "$staged" ]]; then
          echo "$staged"
        else
          git diff --name-only HEAD~1 2>/dev/null || echo ""
        fi
      fi
      ;;
  esac
}

CHANGED_FILES=$(get_changed_files)

if [[ -z "$CHANGED_FILES" ]]; then
  echo "No changed files detected. Cannot determine applicable rules." >&2
  echo "Specify --base <branch> or --staged." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Determine layers from file patterns
# ---------------------------------------------------------------------------
HAS_BACKEND=false
HAS_FRONTEND=false
HAS_UI=false

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Skip non-code files
  if [[ ! "$file" =~ \.(ts|tsx|js|jsx|py|go|rs|php|vue|svelte|css|scss)$ ]]; then
    continue
  fi

  # Backend patterns
  if [[ "$file" =~ \.(service|controller|module|guard|pipe|decorator)\.(ts|js)$ ]] ||
     [[ "$file" =~ \.(go|rs|php|py)$ ]] ||
     [[ "$file" =~ ^app/Http/ ]] ||
     [[ "$file" =~ ^app/Models/ ]] ||
     [[ "$file" =~ ^app/Providers/ ]]; then
    HAS_BACKEND=true
  fi

  # Frontend patterns
  if [[ "$file" =~ components/.*\.(ts|tsx)$ ]] ||
     [[ "$file" =~ hooks/ ]] ||
     [[ "$file" =~ /use[A-Z].*\.(ts|tsx)$ ]] ||
     [[ "$file" =~ ^use[A-Z].*\.(ts|tsx)$ ]] ||
     [[ "$file" =~ utils/ ]] ||
     [[ "$file" =~ lib/ ]] ||
     [[ "$file" =~ types/ ]]; then
    HAS_FRONTEND=true
  fi

  # UI patterns
  if [[ "$file" =~ \.(css|scss)$ ]] ||
     [[ "$file" =~ components/ui/ ]] ||
     [[ "$file" =~ \.(tsx|vue|svelte)$ ]]; then
    HAS_UI=true
  fi
done <<< "$CHANGED_FILES"

if [[ "$HAS_BACKEND" == false && "$HAS_FRONTEND" == false && "$HAS_UI" == false ]]; then
  echo "No code files matched any layer pattern. Review validation skipped."
  exit 0
fi

# ---------------------------------------------------------------------------
# Build expected rule set per layer
# ---------------------------------------------------------------------------
EXPECTED_RULES=()

EXPECTED_RULES+=("CS-SCOPE")

BACKEND_RULES=(
  FN-001 FN-001b FN-002 FN-003 FN-004 FN-005 FN-005b
  FN-006 FN-006b FN-006c FN-007 FN-008 FN-009
  FN-010 FN-010b FN-011
  NM-001 NM-001a NM-002 NM-003 NM-004 NM-005 NM-005a NM-006 NM-007
  EH-001 EH-002 EH-003
  OD-001 OD-002 OD-003 OD-003a OD-004
  FMT-001 FMT-002 FMT-003 FMT-003a FMT-004
  DP-001 DP-002 DP-003 DP-004 DP-005 DP-006 DP-007
)

FRONTEND_RULES=(
  CS-001 CS-002 CS-003 CS-004 CS-005 CS-006 CS-007 CS-008
  TS-001 TS-002 TS-003 TS-004 TS-005 TS-006 TS-007 TS-008 TS-009
)

UI_RULES=(
  UI-001 UI-002 UI-003 UI-004 UI-005 UI-006
  UI-007 UI-008 UI-009 UI-010 UI-011 UI-012 UI-013 UI-014 UI-015
)

if [[ "$HAS_BACKEND" == true || "$HAS_FRONTEND" == true ]]; then
  EXPECTED_RULES+=("${BACKEND_RULES[@]}")
fi

if [[ "$HAS_FRONTEND" == true ]]; then
  EXPECTED_RULES+=("${FRONTEND_RULES[@]}")
fi

if [[ "$HAS_UI" == true ]]; then
  EXPECTED_RULES+=("${UI_RULES[@]}")
fi

# Deduplicate
readarray -t EXPECTED_RULES < <(printf '%s\n' "${EXPECTED_RULES[@]}" | sort -u)

# ---------------------------------------------------------------------------
# Validate: every expected rule must appear in the review
# ---------------------------------------------------------------------------
MISSING=()
FOUND=()

for rule in "${EXPECTED_RULES[@]}"; do
  if grep -qE "(^|\W)${rule}(\W|$)" <<< "$REVIEW"; then
    FOUND+=("$rule")
  else
    MISSING+=("$rule")
  fi
done

TOTAL=${#EXPECTED_RULES[@]}
FOUND_COUNT=${#FOUND[@]}
MISSING_COUNT=${#MISSING[@]}

# ---------------------------------------------------------------------------
# Check for PASS stamps without evidence
# A rule marked PASS should be fine — the point is coverage, not depth.
# But a rule marked with a finding (MAJOR/MINOR) MUST have a file:line cite.
# ---------------------------------------------------------------------------
UNCITED=()
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  rule_id=$(echo "$match" | grep -oE '[A-Z]{2,3}-[0-9A-Z]{2,5}[a-z]?' | head -1 || true)
  [[ -z "$rule_id" ]] && continue

  if echo "$match" | grep -qiE 'MAJOR|MINOR'; then
    section="${REVIEW#*"$match"}"
    section_end=$(echo "$section" | grep -n -m1 -E '^\*\*\[' | cut -d: -f1 || true)
    if [[ -n "$section_end" ]]; then
      section=$(echo "$section" | head -n "$section_end")
    fi

    if ! echo "$section" | grep -qE '`[^`]+:[0-9]+`'; then
      UNCITED+=("$rule_id")
    fi
  fi
done < <(grep -E '^\*\*\[' <<< "$REVIEW" || true)

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
LAYERS=""
[[ "$HAS_BACKEND" == true ]] && LAYERS="${LAYERS}backend "
[[ "$HAS_FRONTEND" == true ]] && LAYERS="${LAYERS}frontend "
[[ "$HAS_UI" == true ]] && LAYERS="${LAYERS}ui "

echo "=== Coding Standards Review Validation ==="
echo ""
echo "Layers detected: ${LAYERS}"
echo "Changed files: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ')"
echo "Rules expected: ${TOTAL}"
echo "Rules found:    ${FOUND_COUNT}"
echo "Rules missing:  ${MISSING_COUNT}"
echo ""

HAS_ERROR=false

if [[ ${#MISSING[@]} -gt 0 ]]; then
  HAS_ERROR=true
  echo "MISSING RULES (${MISSING_COUNT}):" >&2
  for rule in "${MISSING[@]}"; do
    echo "  - ${rule}" >&2
  done
  echo "" >&2
fi

if [[ ${#UNCITED[@]} -gt 0 ]]; then
  echo "FINDINGS WITHOUT file:line CITATION (${#UNCITED[@]}):" >&2
  for rule in "${UNCITED[@]}"; do
    echo "  - ${rule}" >&2
  done
  echo "" >&2
fi

if [[ "$HAS_ERROR" == true ]]; then
  echo "FAIL — Review is incomplete. Add findings for all missing rules." >&2
  echo "Each rule must appear as: **[RULE-ID] Name** — PASS | MAJOR | MINOR | SKIPPED(reason)" >&2
  exit 2
fi

if [[ ${#UNCITED[@]} -gt 0 ]]; then
  echo "WARN — Review covers all rules but some findings lack file:line citations."
  exit 0
fi

echo "PASS — All ${TOTAL} applicable rules covered."
exit 0
