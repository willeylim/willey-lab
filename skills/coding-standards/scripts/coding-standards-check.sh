#!/bin/bash
# =============================================================================
# Coding Standards PreToolUse Hook
# Fires on file-writing tool calls — blocks code that violates the rules a shell
# script can detect with HIGH PRECISION (near-zero false positives).
#
# Hard-blocked (exit 2):
#   TS-001  no `any` type             (TypeScript files)
#   TS-002  explicit return types     (exported fns / arrows / public methods)
#   NM-006  no Hungarian notation
#
# Deliberately NOT hard-blocked here: single-letter names, magic numbers,
# function length, control-block bodies, and parameter count. Those require
# scope/structural understanding that regex + line-based awk cannot do
# reliably on real React/TS/JSX code (they block idiomatic code and miss real
# violations). They are agent-self-enforced instead — see the skill references.
#
# Supports Claude Code (Write/Edit) and Factory Droid (Create/Edit/ApplyPatch).
# =============================================================================

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

case "$TOOL_NAME" in
  Write|Create|Edit|ApplyPatch) ;;
  *) exit 0 ;;
esac

# Extract the file path and the new code introduced by this tool call.
case "$TOOL_NAME" in
  Write|Create)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
    ;;
  Edit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""')
    ;;
  ApplyPatch)
    # Factory patches carry a diff rather than file content; field naming
    # varies, so probe the common shapes and keep only the added (`+`) lines.
    # The target path may live in a field or only in the patch header.
    PATCH=$(echo "$INPUT" | jq -r '.tool_input.patch // .tool_input.input // .tool_input.diff // .tool_input.content // ""')
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    if [[ -z "$FILE_PATH" ]]; then
      FILE_PATH=$(printf '%s\n' "$PATCH" | sed -nE 's/^\*\*\* (Update|Add|Move) File: (.*)$/\2/p' | head -1)
    fi
    if [[ -z "$FILE_PATH" ]]; then
      FILE_PATH=$(printf '%s\n' "$PATCH" | sed -nE 's#^\+\+\+ b?/?(.*)$#\1#p' | head -1)
    fi
    CONTENT=$(printf '%s\n' "$PATCH" | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' || true)
    ;;
esac

# Only check code files.
[[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|go|rs|php|vue|svelte)$ ]] && exit 0

[[ -z "$CONTENT" ]] && exit 0

IS_TS=false
[[ "$FILE_PATH" =~ \.(ts|tsx)$ ]] && IS_TS=true

# -----------------------------------------------------------------------------
# strip_code — remove comments and blank the *contents* of string and template
# literals, preserving the delimiters and surrounding token structure. Every
# check below runs on this so that string/comment text cannot produce false
# positives (e.g. the word "any" inside a string, or `: any` in a comment).
# Tracks multi-line block comments and multi-line template literals.
# Known limitation: regex literals (/.../ ) are not modeled (rare; a regex
# whose body looks like a type token could slip through) — documented, not
# blocking, consistent with this hook's "precision over recall" stance.
# -----------------------------------------------------------------------------
strip_code() {
  awk '
    BEGIN { in_block = 0; in_tmpl = 0 }
    {
      line = ""
      i = 1
      len = length($0)
      while (i <= len) {
        c  = substr($0, i, 1)
        c2 = substr($0, i, 2)

        if (in_block) {
          if (c2 == "*/") { in_block = 0; i += 2; continue }
          i++; continue
        }
        if (in_tmpl) {
          if (c == "\\") { i += 2; continue }
          if (c == "`")  { line = line "`"; in_tmpl = 0; i++; continue }
          i++; continue
        }

        if (c2 == "//") break
        if (c2 == "/*") { in_block = 1; i += 2; continue }

        if (c == "\"" || c == "'\''") {
          q = c; line = line c; i++
          while (i <= len) {
            ch = substr($0, i, 1)
            if (ch == "\\") { i += 2; continue }
            if (ch == q)    { line = line q; i++; break }
            i++
          }
          continue
        }

        if (c == "`") { line = line "`"; in_tmpl = 1; i++; continue }

        line = line c
        i++
      }
      print line
    }
  '
}

STRIPPED=$(echo "$CONTENT" | strip_code)

VIOLATIONS=""

# -----------------------------------------------------------------------------
# TS-001 — No `any` type.
# Flags `any` only in type positions: after `:`/`as`/`<`/`,`/`|`/`&`, or before
# `[]`/`>`/`,`/`|`/`&`. This catches `: any`, `as any`, `Array<any>`,
# `Record<string, any>`, `Map<K, any>`, `any[]`, `x | any`, etc. while leaving
# identifiers/properties (`company`, `arr.any()`) and regex bodies alone.
# -----------------------------------------------------------------------------
check_ts_no_any() {
  [[ "$IS_TS" != true ]] && return
  local matches
  matches=$(echo "$STRIPPED" | grep -nE '(:|<|,|\||&)[[:space:]]*\bany\b|\bas[[:space:]]+any\b|\bany[[:space:]]*(\[\]|>|,|\||&)' || true)
  [[ -z "$matches" ]] && return
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    VIOLATIONS="${VIOLATIONS}TS-001: Type 'any' found. Use a specific type, a generic, or 'unknown' with a type guard. Near: ${line}\n"
  done <<< "$matches"
}

# -----------------------------------------------------------------------------
# TS-002 — Explicit return types on exported functions, exported arrow
# functions, and public/private/protected class methods. A declaration is
# missing its return type when `)` is directly followed by `{` (no `): Type`).
# Conservative by design: prefers false negatives over false positives.
# -----------------------------------------------------------------------------
check_ts_explicit_return() {
  [[ "$IS_TS" != true ]] && return

  # Exported function declarations.
  local fn_matches
  fn_matches=$(echo "$STRIPPED" | grep -nE '^[[:space:]]*export[[:space:]]+(default[[:space:]]+)?(async[[:space:]]+)?function\b' || true)
  if [[ -n "$fn_matches" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "$line" | grep -qE '\)[[:space:]]*:' && continue
      echo "$line" | grep -qE '\)[[:space:]]*\{' || continue
      VIOLATIONS="${VIOLATIONS}TS-002: Exported function lacks an explicit return type. Near: ${line}\n"
    done <<< "$fn_matches"
  fi

  # Exported arrow-function consts.
  local arrow_matches
  arrow_matches=$(echo "$STRIPPED" | grep -nE '^[[:space:]]*export[[:space:]]+const[[:space:]]+[A-Za-z0-9_$]+[[:space:]]*=[[:space:]]*(async[[:space:]]+)?\([^)]*\)[[:space:]]*=>' || true)
  if [[ -n "$arrow_matches" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "$line" | grep -qE '\)[[:space:]]*:[[:space:]]*\S' && continue
      VIOLATIONS="${VIOLATIONS}TS-002: Exported arrow function lacks an explicit return type. Near: ${line}\n"
    done <<< "$arrow_matches"
  fi

  # Access-modifier class methods (public/private/protected). Excludes
  # constructors and setters, which legitimately have no return type.
  local method_matches
  method_matches=$(echo "$STRIPPED" | grep -nE '^[[:space:]]*(public|private|protected)[[:space:]]+(async[[:space:]]+|static[[:space:]]+|readonly[[:space:]]+)*[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*\([^)]*\)[[:space:]]*\{' || true)
  if [[ -n "$method_matches" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "$line" | grep -qE '\b(constructor|set)[[:space:]]*\(' && continue
      echo "$line" | grep -qE '\)[[:space:]]*:' && continue
      VIOLATIONS="${VIOLATIONS}TS-002: Public method lacks an explicit return type. Near: ${line}\n"
    done <<< "$method_matches"
  fi
}

# -----------------------------------------------------------------------------
# NM-006 — No Hungarian notation (type encoded into the name).
# -----------------------------------------------------------------------------
check_hungarian_notation() {
  local prefixes='(str[A-Z]|bIs|bHas|bCan|bShould|iCount|iNum|iTotal|nSize|nLen|oObj|szStr|pPtr|aArr|aList)'
  local matches
  matches=$(echo "$STRIPPED" | grep -nE "(const|let|var|function|param)[[:space:]]+${prefixes}" || true)
  [[ -z "$matches" ]] && return
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    VIOLATIONS="${VIOLATIONS}NM-006: Hungarian notation detected. Remove the type prefix; the name should describe intent, not type. Near: ${line}\n"
  done <<< "$matches"
}

check_ts_no_any
check_ts_explicit_return
check_hungarian_notation

if [[ -n "$VIOLATIONS" ]]; then
  echo -e "Coding standards violations found:\n" >&2
  echo -e "$VIOLATIONS" >&2
  echo -e "Fix all violations before writing. See the coding-standards skill for details." >&2
  exit 2
fi

exit 0
