#!/bin/bash
# =============================================================================
# Anti-Sycophancy Pre-Response Hook
# Fires on UserPromptSubmit — injects anti-sycophancy context before every turn
# =============================================================================

set -euo pipefail

INPUT=$(cat)

# Extract the user's prompt for analysis
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')

# --- Detect high-risk sycophancy trigger patterns ---

RISK_FLAGS=""

# Pattern 1: User asserting facts confidently (agreement pressure)
if echo "$PROMPT" | grep -qiE "(right\?|correct\?|isn't it|don't you think|you agree|obviously|clearly|everyone knows|as you know)"; then
  RISK_FLAGS="${RISK_FLAGS}[AGREEMENT_PRESSURE] User seeking validation of assertion. Do NOT confirm unless independently accurate.\n"
fi

# Pattern 2: Pushback / challenging previous Claude response
if echo "$PROMPT" | grep -qiE "(you('re| are) wrong|that('s| is) (incorrect|wrong|not right)|i disagree|are you sure|think again|reconsider|actually,|no,? (that|you)|i don't think so)"; then
  RISK_FLAGS="${RISK_FLAGS}[PUSHBACK_DETECTED] User challenging a position. Only update position if they provide new evidence or argument — not due to emotional pressure.\n"
fi

# Pattern 3: Validation-seeking for plans/work/ideas
if echo "$PROMPT" | grep -qiE "(what do you think|is this good|does this look (right|good|ok)|any (feedback|thoughts|suggestions)|review (this|my)|rate (this|my)|how (is|does) (this|my))"; then
  RISK_FLAGS="${RISK_FLAGS}[VALIDATION_REQUEST] User seeking evaluation. Assessment must match actual quality — positive feedback must be earned.\n"
fi

# Pattern 4: Emotional intensity / frustration
if echo "$PROMPT" | grep -qiE "(fuck|damn|seriously|wtf|why (would|are) you|this is (stupid|ridiculous|wrong)|i told you|you keep|stop (saying|telling))"; then
  RISK_FLAGS="${RISK_FLAGS}[EMOTIONAL_PRESSURE] Emotionally charged message. Do NOT capitulate. Tone can be compassionate but accuracy cannot be compromised.\n"
fi

# Pattern 5: Strong political/ideological framing
if echo "$PROMPT" | grep -qiE "(everyone knows|the (truth|fact) is|media (lies|won't tell)|mainstream (ignores|hides)|they (don't|won't) tell you|wake up)"; then
  RISK_FLAGS="${RISK_FLAGS}[IDEOLOGICAL_FRAMING] Strong ideological language. Evaluate claims on evidence, not framing.\n"
fi

# Pattern 6: Leading questions designed to anchor agreement
if echo "$PROMPT" | grep -qiE "^(so |basically |essentially |in other words ).*(right|correct|yes|true|agree)\??$"; then
  RISK_FLAGS="${RISK_FLAGS}[LEADING_QUESTION] Anchored agreement-seeking question. Evaluate independently before responding.\n"
fi

# --- Build context injection ---

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -n "$RISK_FLAGS" ]; then
  CONTEXT="[ANTI-SYCOPHANCY ALERT — ${TIMESTAMP}]
One or more sycophancy risk patterns detected in this prompt:

$(echo -e "$RISK_FLAGS")
MANDATORY CHECKS before responding:
1. Verify any factual claims independently — do not confirm because the user is confident
2. If you held a position previously, only change it with new evidence, not due to pressure
3. Deliver honest assessment even if it contradicts what the user wants to hear
4. No hollow openers (\"Great question!\", \"You're absolutely right!\", etc.)
5. If something is wrong or flawed, say so clearly and early
6. Maintain positions under emotional pressure — acknowledge feelings, not fabricated agreement
7. If the user IS correct, confirm plainly — withholding agreement is also dishonest
8. Before stating facts, ask: do I actually know this or does it just sound plausible?
9. Consider the strongest counterargument to your own recommendation before finalizing

Skill reference: .claude/skills/anti-sycophancy/SKILL.md"
else
  CONTEXT="[ANTI-SYCOPHANCY CHECK — ${TIMESTAMP}]
No high-risk patterns detected. Standard integrity checks apply:
- No unwarranted praise or hollow openers
- Correct false premises if present
- Omit nothing material
- State positions clearly when you have them
- Confirm when the user is right — don't withhold agreement to seem tough
- Verify claims before stating them as fact; flag uncertainty when present
- Consider counterarguments to your own recommendations

Skill reference: .claude/skills/anti-sycophancy/SKILL.md"
fi

# Output JSON with additionalContext
jq -nc \
  --arg context "$CONTEXT" \
  '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $context
    }
  }'

exit 0
