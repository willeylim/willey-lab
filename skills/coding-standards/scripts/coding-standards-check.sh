#!/bin/bash
# =============================================================================
# Coding Standards PreToolUse Hook
# Fires on Write and Edit — blocks code that violates mechanical rules
# =============================================================================

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only check Write and Edit
[[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Only check code files
[[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|go|rs|php|vue|svelte)$ ]] && exit 0

# Extract content to check
if [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
  IS_FULL_FILE=true
else
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""')
  IS_FULL_FILE=false
fi

[[ -z "$CONTENT" ]] && exit 0

IS_TS=false
[[ "$FILE_PATH" =~ \.(ts|tsx)$ ]] && IS_TS=true

# Strip comments to reduce false positives
strip_comments() {
  sed 's|//.*||' | sed '/\/\*/,/\*\//d'
}

STRIPPED=$(echo "$CONTENT" | strip_comments)

VIOLATIONS=""
WARNINGS=""

# -----------------------------------------------------------------------------
# CHECK: TS-001 — No `any` type
# -----------------------------------------------------------------------------
check_ts_no_any() {
  [[ "$IS_TS" != true ]] && return

  local matches
  matches=$(echo "$STRIPPED" | grep -nE ':\s*any\b|as\s+any\b|<any>' || true)
  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      VIOLATIONS="${VIOLATIONS}TS-001: Type 'any' found. Use a specific type, generic, or 'unknown'. Near: ${line}\n"
    done <<< "$matches"
  fi
}

# -----------------------------------------------------------------------------
# CHECK: TS-002 — Explicit return types on exported functions
# -----------------------------------------------------------------------------
check_ts_explicit_return() {
  [[ "$IS_TS" != true ]] && return

  local matches
  matches=$(echo "$STRIPPED" | grep -nE '^export\s+(async\s+)?function\s+\w+\s*\([^)]*\)\s*\{' || true)
  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      VIOLATIONS="${VIOLATIONS}TS-002: Exported function lacks explicit return type. Near: ${line}\n"
    done <<< "$matches"
  fi

  local arrow_matches
  arrow_matches=$(echo "$STRIPPED" | grep -nE '^export\s+const\s+\w+\s*=\s*(async\s+)?\([^)]*\)\s*=>' || true)
  if [[ -n "$arrow_matches" ]]; then
    while IFS= read -r line; do
      if ! echo "$line" | grep -qE '\)\s*:\s*\w' ; then
        VIOLATIONS="${VIOLATIONS}TS-002: Exported arrow function lacks explicit return type. Near: ${line}\n"
      fi
    done <<< "$arrow_matches"
  fi
}

# -----------------------------------------------------------------------------
# CHECK: NM-006 — No Hungarian notation
# -----------------------------------------------------------------------------
check_hungarian_notation() {
  local prefixes='(str[A-Z]|bIs|bHas|bCan|bShould|iCount|iNum|iTotal|nSize|nLen|oObj|szStr|pPtr|aArr|aList)'
  local matches
  matches=$(echo "$STRIPPED" | grep -nE "(const|let|var|function|param)\s+${prefixes}" || true)
  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      VIOLATIONS="${VIOLATIONS}NM-006: Hungarian notation detected. Remove type prefix from name. Near: ${line}\n"
    done <<< "$matches"
  fi
}

# -----------------------------------------------------------------------------
# CHECK: NM-001a — No single-letter variable names (except i,j,k in loops)
# -----------------------------------------------------------------------------
check_single_letter_names() {
  local matches
  matches=$(echo "$STRIPPED" | grep -nE '(const|let|var)\s+[a-zA-Z]\s*[=:;,)]' | grep -vE '(const|let|var)\s+[ijk]\s*[=]' || true)

  if [[ -n "$matches" ]]; then
    local filtered=""
    while IFS= read -r line; do
      if ! echo "$line" | grep -qE '^\s*for\s*\('; then
        filtered="${filtered}${line}\n"
      fi
    done <<< "$matches"

    if [[ -n "$filtered" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        VIOLATIONS="${VIOLATIONS}NM-001a: Single-letter variable name. Use an intent-revealing name. Near: ${line}\n"
      done <<< "$(echo -e "$filtered")"
    fi
  fi
}

# -----------------------------------------------------------------------------
# CHECK: FN-005 — Max 3 parameters
# -----------------------------------------------------------------------------
check_param_count() {
  [[ "$IS_FULL_FILE" != true ]] && return

  echo "$CONTENT" | awk '
    /function\s+\w+\s*\(/ || /^\s*(export\s+)?(async\s+)?function\s/ || /\w+\s*[:=]\s*(async\s+)?\(/ {
      line = $0
      lineno = NR

      # Find the opening paren
      paren_start = index(line, "(")
      if (paren_start == 0) next

      # Collect everything between parens (handle multi-line)
      depth = 0
      params = ""
      started = 0
      for (i = paren_start; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "(") { depth++; started = 1; next }
        if (c == ")") { depth--; if (depth == 0) break }
        if (started && depth > 0) params = params c
      }

      # Empty params
      if (params == "" || params ~ /^\s*$/) next

      # Count params: split by comma at depth 0
      count = 1
      d = 0
      for (i = 1; i <= length(params); i++) {
        c = substr(params, i, 1)
        if (c == "(" || c == "<" || c == "{" || c == "[") d++
        if (c == ")" || c == ">" || c == "}" || c == "]") d--
        if (c == "," && d == 0) count++
      }

      if (count > 3) {
        # Extract function name
        name = line
        gsub(/^\s*(export\s+)?(default\s+)?(async\s+)?/, "", name)
        gsub(/function\s+/, "", name)
        gsub(/\s*[:=(].*/, "", name)
        printf "FN-005:%d: Function '\''%s'\'' has %d parameters (max 3). Group into an object.\n", lineno, name, count
      }
    }
  ' | while IFS= read -r line; do
    VIOLATIONS="${VIOLATIONS}${line}\n"
  done
}

# -----------------------------------------------------------------------------
# CHECK: FN-001 — Functions max 20 lines
# -----------------------------------------------------------------------------
check_fn_size() {
  [[ "$IS_FULL_FILE" != true ]] && return

  echo "$CONTENT" | awk '
    /^\s*(export\s+)?(default\s+)?(async\s+)?function\s+\w+/ ||
    /^\s*(public|private|protected|static|async)\s+(async\s+)?\w+\s*\(/ {
      if (fn_name != "" && fn_lines > 20) {
        printf "FN-001:%d: Function '\''%s'\'' is %d lines (max 20). Extract sub-functions.\n", fn_start, fn_name, fn_lines
      }
      fn_name = $0
      gsub(/^\s*(export\s+)?(default\s+)?(async\s+)?/, "", fn_name)
      gsub(/function\s+/, "", fn_name)
      gsub(/\s*\(.*/, "", fn_name)
      fn_start = NR
      fn_depth = 0
      fn_lines = 0
      in_fn = 0
    }

    /{/ {
      for (i = 1; i <= length($0); i++) {
        if (substr($0, i, 1) == "{") {
          fn_depth++
          if (!in_fn) in_fn = 1
        }
      }
    }

    in_fn && fn_depth > 0 {
      if ($0 !~ /^\s*$/ && $0 !~ /^\s*\/\//) fn_lines++
    }

    /}/ {
      for (i = 1; i <= length($0); i++) {
        if (substr($0, i, 1) == "}") fn_depth--
      }
      if (in_fn && fn_depth == 0) {
        if (fn_lines > 20) {
          printf "FN-001:%d: Function '\''%s'\'' is %d lines (max 20). Extract sub-functions.\n", fn_start, fn_name, fn_lines
        }
        fn_name = ""
        in_fn = 0
        fn_lines = 0
      }
    }
  ' | while IFS= read -r line; do
    VIOLATIONS="${VIOLATIONS}${line}\n"
  done
}

# -----------------------------------------------------------------------------
# CHECK: NM-005a — No magic numbers (WARN ONLY)
# -----------------------------------------------------------------------------
check_magic_numbers() {
  local matches
  matches=$(echo "$STRIPPED" | grep -nE '[^a-zA-Z_\.]\b[2-9][0-9]*\b|\b[0-9]{2,}\b' \
    | grep -vE '(const|let|var|type|interface|import|export)\s' \
    | grep -vE '(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+)' \
    | grep -vE '\[(0|1)\]' \
    | grep -vE '^\s*(\/\/|\*)' \
    | grep -vE '\.(test|spec|stories)\.' \
    | head -5 || true)

  if [[ -n "$matches" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      WARNINGS="${WARNINGS}NM-005a: Possible magic number. Consider naming it as a constant. Near: ${line}\n"
    done <<< "$matches"
  fi
}

# -----------------------------------------------------------------------------
# CHECK: FN-001b — Control blocks must be one line (WARN ONLY)
# -----------------------------------------------------------------------------
check_block_body() {
  [[ "$IS_FULL_FILE" != true ]] && return

  echo "$CONTENT" | awk '
    /^\s*(if|else if|else|while|for)\s*(\(|{)/ {
      ctrl_line = NR
      ctrl_depth = 0
      in_block = 0
      body_lines = 0

      # Find opening brace
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") { ctrl_depth++; in_block = 1 }
      }
    }

    in_block && NR > ctrl_line {
      if ($0 !~ /^\s*$/ && $0 !~ /^\s*[{}]\s*$/) body_lines++

      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") ctrl_depth++
        if (c == "}") ctrl_depth--
      }

      if (ctrl_depth == 0) {
        if (body_lines > 1) {
          printf "FN-001b:%d: Multi-line block body. Extract into a named function.\n", ctrl_line
        }
        in_block = 0
        body_lines = 0
      }
    }
  ' | while IFS= read -r line; do
    WARNINGS="${WARNINGS}${line}\n"
  done
}

# -----------------------------------------------------------------------------
# Run all checks
# -----------------------------------------------------------------------------
check_ts_no_any
check_ts_explicit_return
check_hungarian_notation
check_single_letter_names
check_param_count
check_fn_size
check_magic_numbers
check_block_body

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
if [[ -n "$VIOLATIONS" ]]; then
  echo -e "Coding standards violations found:\n" >&2
  echo -e "$VIOLATIONS" >&2
  if [[ -n "$WARNINGS" ]]; then
    echo -e "\nWarnings (non-blocking):\n" >&2
    echo -e "$WARNINGS" >&2
  fi
  echo -e "\nFix all violations before writing. See coding-standards skill for details." >&2
  exit 2
fi

if [[ -n "$WARNINGS" ]]; then
  echo -e "Coding standards warnings:\n" >&2
  echo -e "$WARNINGS" >&2
  echo -e "\nThese are non-blocking but should be addressed." >&2
fi

exit 0
