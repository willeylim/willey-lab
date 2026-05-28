#!/bin/bash
# =============================================================================
# Anti-Sycophancy Stop Hook (Post-Response Evaluator)
# Fires after Claude finishes responding.
# Reads the transcript and evaluates the last response for sycophancy.
# If sycophancy detected: exits 2 → forces Claude to revise before stopping.
# =============================================================================

set -euo pipefail

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Extract the text of the most recent assistant message.
# Claude Code transcripts are JSONL: one record per line, discriminated by a
# top-level `.type`, with the payload under `.message.content` (an array of
# blocks). There is no top-level `.role`/`.content`. Parse each line
# independently so one malformed line cannot abort the whole read, and bound
# the scan to the tail (the last response is always near the end).
LAST_RESPONSE=$(
  tail -n 300 "$TRANSCRIPT_PATH" 2>/dev/null | while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s\n' "$line" | jq -rc '
      select(.type? == "assistant")
      | [ (.message.content // [])[]? | select(.type? == "text") | .text ]
      | join(" ")
    ' 2>/dev/null
  done | grep -v '^[[:space:]]*$' | tail -n 1 || true
)

if [ -z "$LAST_RESPONSE" ]; then
  exit 0
fi

VIOLATIONS=""
VIOLATION_COUNT=0

# --- Sycophancy Pattern Detectors ---

# Check 1: Hollow openers
if echo "$LAST_RESPONSE" | grep -qiE "^(great question|what a (great|fantastic|excellent|wonderful|interesting)|you('re| are) (absolutely|totally|completely) right|that('s| is) (a great|an excellent|a fantastic)|absolutely!|exactly right)"; then
  VIOLATIONS="${VIOLATIONS}VIOLATION: Hollow opener or unearned praise detected at start of response.\n"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
fi

# Check 2: Position reversal language without evidence
if echo "$LAST_RESPONSE" | grep -qiE "(you('re| are) (absolutely |totally |completely )?right,? (i|let me)|i('ll| will) reconsider|i (was|may have been) wrong|you've (convinced|persuaded) me|i see your point,? (let me|i'll) (change|revise|update))" && \
   ! echo "$LAST_RESPONSE" | grep -qiE "(because|evidence|source|data|study|shows|indicates|according to|the reason is|this changes|new information)"; then
  VIOLATIONS="${VIOLATIONS}VIOLATION: Position reversal detected without evidence-based justification.\n"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
fi

# Check 3: Over-apologizing
if echo "$LAST_RESPONSE" | grep -iE "(i('m| am) so sorry|i sincerely apologize|i deeply apologize|i apologize for (the confusion|misunderstanding|being wrong))" | grep -qiv "technical error\|system error\|actual mistake"; then
  VIOLATIONS="${VIOLATIONS}WARNING: Excessive or unwarranted apology may indicate capitulation.\n"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
fi

# Check 4: Burying bad news (positive framing before critical flaw)
WORD_COUNT=$(echo "$LAST_RESPONSE" | wc -w)
if [ "$WORD_COUNT" -gt 100 ]; then
  # Check if critical words appear only in second half of response
  HALF=$(echo "$LAST_RESPONSE" | awk '{for(i=1;i<=NF;i++) print $i}' | head -$((WORD_COUNT / 2)) | tr '\n' ' ')
  if ! echo "$HALF" | grep -qiE "(however|but|unfortunately|problem|issue|flaw|concern|risk|warning|caution|caveat)" && \
     echo "$LAST_RESPONSE" | grep -qiE "(however|but|unfortunately|problem|issue|flaw|concern|risk|warning|caution|caveat)"; then
    VIOLATIONS="${VIOLATIONS}WARNING: Critical information may be buried — negative/cautionary content appears only in second half.\n"
    VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
  fi
fi

# Check 5: Excessive hedge without position
if echo "$LAST_RESPONSE" | grep -qiE "(it depends|could go either way|both (sides|perspectives|approaches) have merit|there('s| is) no (clear|definitive|simple) answer)" && \
   [ "$WORD_COUNT" -lt 150 ]; then
  VIOLATIONS="${VIOLATIONS}WARNING: Short response uses hedge language without taking a position — possible epistemic cowardice.\n"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
fi

# Check 6: Unverified claims stated as fact
if echo "$LAST_RESPONSE" | grep -qiE "(it (is|was) (always|never|definitely|certainly)|this (always|never) (works|happens|fails)|every(one| developer| team) (knows|uses|does))" && \
   ! echo "$LAST_RESPONSE" | grep -qiE "(according to|based on|the docs (say|state|show)|per the|from the (source|spec|documentation))"; then
  VIOLATIONS="${VIOLATIONS}WARNING: Absolute claim stated without attribution — verify or qualify.\n"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
fi

# --- Decision ---

if [ "$VIOLATION_COUNT" -ge 2 ]; then
  # Hard block — force revision
  echo "SYCOPHANCY DETECTED (${VIOLATION_COUNT} violations). Revise your response before completing.

$(echo -e "$VIOLATIONS")
Required corrections:
- Remove hollow openers or unearned praise
- If you changed a position, state what new evidence justified it
- Move critical information to where it will actually be seen
- Replace hedges with your actual position where you have one
- Apologies should only appear for genuine errors, not to smooth over disagreement

Consult: .claude/skills/anti-sycophancy/SKILL.md" >&2
  exit 2

elif [ "$VIOLATION_COUNT" -eq 1 ]; then
  # Soft warning — log but don't block
  jq -nc \
    --arg msg "$(echo -e "$VIOLATIONS")" \
    '{
      systemMessage: $msg
    }'
  exit 0
fi

exit 0
