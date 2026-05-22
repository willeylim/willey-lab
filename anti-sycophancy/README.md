# Anti-Sycophancy Framework

Enforces epistemic honesty on every Claude Code interaction. Prevents agreement bias, capitulation under pressure, false validation, unwarranted praise, and overcorrection.

## Install

```bash
npx skills add willey-lab/anti-sycophancy
```

### Enable enforcement hooks (optional but recommended)

The skill itself works as a reference Claude consults. For active enforcement (pre-response scanning + post-response blocking), install the hooks:

```bash
bash .claude/skills/anti-sycophancy/scripts/install-hooks.sh
```

Verify with `/hooks` in Claude Code — you should see:

```
UserPromptSubmit  1 hook configured
Stop              1 hook configured
```

---

## What It Does

### SKILL.md (always active after install)
Claude consults this before every response. Covers 7 failure modes, a pre-response checklist, language patterns, fact-seeking protocol, source hierarchy, and counterargument generation.

### Pre-response hook (`UserPromptSubmit`)
Scans each prompt for sycophancy risk patterns:
- Agreement pressure ("right?", "don't you think")
- Pushback without evidence ("you're wrong", "reconsider")
- Validation-seeking ("what do you think of my code?")
- Emotional pressure ("wtf", "this is stupid")
- Ideological framing ("everyone knows", "they won't tell you")
- Leading questions ("so basically X, right?")

Injects targeted context into Claude's awareness before it responds.

### Post-response hook (`Stop`)
Evaluates Claude's response for:
- Hollow openers ("Great question!")
- Position reversals without evidence
- Excessive/unwarranted apologies
- Buried critical information
- Epistemic cowardice (hedging without position)
- Unverified absolute claims

**2+ violations = hard block** — Claude must revise before finishing.
1 violation = soft warning.

---

## Structure

```
skills/
└── anti-sycophancy/
    ├── SKILL.md                    # Integrity framework (installed by npx skills add)
    └── scripts/
        ├── sycophancy-check.sh     # UserPromptSubmit hook
        ├── stop-evaluator.sh       # Stop hook (post-response enforcer)
        └── install-hooks.sh        # Hook installer
```

---

## Tuning

### Adjust enforcement threshold
In `stop-evaluator.sh`, change the threshold:
- `VIOLATION_COUNT -ge 2` — hard block (default)
- `VIOLATION_COUNT -ge 1` — block on any violation (stricter)
- `VIOLATION_COUNT -ge 3` — only block on severe cases (looser)

### Add custom risk patterns
Add regex patterns in `sycophancy-check.sh`:

```bash
if echo "$PROMPT" | grep -qiE "(your pattern here)"; then
  RISK_FLAGS="${RISK_FLAGS}[YOUR_FLAG] Description.\n"
fi
```

### Disable hooks temporarily
In `.claude/settings.json`, set `"disableAllHooks": true`.

---

## Philosophy

> A model that always agrees with you isn't a helpful model.

Sycophancy feels helpful in the moment. It isn't. This framework ensures Claude behaves like a knowledgeable friend who respects you enough to tell you the truth — not an assistant optimized for your immediate emotional comfort.

---

## License

MIT
