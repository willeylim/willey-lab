# Formatting

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for code formatting and file organisation. Apply to all stacks and languages.

Source: Robert C. Martin, *Clean Code: A Handbook of Agile Software Craftsmanship* (2008) — the primary source for these principles. Secondary explainer: the @s4.codes clean-code video series.

---

## Section A-SELF — Mechanical Rules (Agent Self-Enforced)

Mechanical in spirit, but requiring scope awareness a shell hook cannot reliably provide. **Not** hook-blocked — self-enforce on every write and review.

### FMT-003a
Local variables must be declared close to where they are first used.
A variable declared more than 5 lines before its first use is flagged.

```
enforcement: agent (self-enforced; no hook)
note: Requires scope awareness beyond what shell scripts can reliably detect. Self-enforce this rule with the same rigor as a hook.
```

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### FMT-001
Source files must read like a newspaper — highest-level function at the top,
every function defined just below its first caller, conceptually related functions
grouped together.

```
enforcement: agent
check: For every file touched in the diff, cite file:line.
       1. Is the highest-level function (the one that orchestrates the others)
          at or near the top of the file? If lower-level implementation details
          appear before the high-level entry point → MAJOR.
       2. Is each function defined close to and below the point where it is first
          called — in the same order the calls appear? If a function's definition
          appears far above or in a different section from where it is called,
          forcing the reader to jump around → MINOR.
       3. Are functions with conceptual affinity (same naming pattern, same domain
          purpose) grouped together even if they don't directly call each other?
          If related utilities are scattered across the file → MINOR.
       Overall structure should flow: high-level orchestration at top →
       supporting functions in call order → shared utilities grouped at bottom.
evidence-required: yes
```

### FMT-002
Blank lines separate concepts. Related lines stay vertically dense.
Indentation creates a visual hierarchy for scope.

```
enforcement: agent
check: For every file touched in the diff, cite file:line.
       1. Are blank lines used to separate distinct logical groups (data extraction,
          business logic, result output)? If a file has no blank lines between
          clearly different concerns → MINOR.
       2. Are blank lines inserted between lines that belong to the same logical
          group, disconnecting related code unnecessarily? If yes → MINOR.
       3. Does indentation consistently reflect scope depth — each nested level
          indented one level deeper? Inconsistent indentation that hides the
          visual hierarchy → MAJOR.
       Rule: blank lines = concept boundary. No blank line = same concept.
       Density shows belonging; spacing shows separation.
evidence-required: yes
```

### FMT-003
Local variables must be declared as close as possible to where they are first used.
Class properties must be kept in one designated place, not scattered near individual methods.

```
enforcement: agent
check: For every variable or property introduced in the diff, cite file:line.
       1. Is this a local variable declared significantly before its first use,
          forcing the reader to carry it as mental baggage through unrelated code?
          (FMT-003a catches the mechanical case; this rule catches the judgment case
          where proximity is close but the variable still adds unnecessary mental load.)
          If a local variable spans multiple unrelated logical groups before use → MINOR.
       2. Is this a class property declared near one specific method rather than in
          the class's designated properties section? Class properties are shared —
          placing them near one method makes them hard to find for others.
          If yes → MAJOR.
evidence-required: yes
```

### FMT-004
Formatting conventions must be consistent with the rest of the codebase.
Brace placement, indentation style, quote style, and spacing are team decisions —
whatever the existing codebase uses, new code must follow.

```
enforcement: agent
check: For every file touched in the diff, cite file:line.
       Compare the formatting of new or modified code against the existing
       conventions in the codebase:
       1. Brace placement (same line vs next line) — does new code match? → MINOR if not.
       2. Indentation (tabs vs spaces, indent size) — does new code match? → MINOR if not.
       3. Quote style (single vs double) — does new code match? → MINOR if not.
       4. Any other formatting pattern the codebase consistently follows —
          does new code break the pattern? → MINOR if not.
       These are team decisions. There is no universally correct answer.
       Consistency is the only rule.
evidence-required: yes
```
