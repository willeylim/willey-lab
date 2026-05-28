# Naming

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for naming variables, functions, classes, and constants. Apply to all stacks and languages.

Source: Robert C. Martin, *Clean Code: A Handbook of Agile Software Craftsmanship* (2008) — the primary source for these principles. Secondary explainer: the @s4.codes clean-code video series.

---

## Section A — Hook-Enforced Rules

A mechanical check the PreToolUse hook detects with high precision. The hook (`scripts/coding-standards-check.sh`) exits 2 to block the write.

### NM-006
No Hungarian notation — do not encode the type into the variable name.

```
enforcement: hook
script: scripts/coding-standards-check.sh → check_hungarian_notation()
trigger: PreToolUse(Write, Create, Edit, ApplyPatch)
input: tool-call JSON via stdin (Claude Code / Factory hook protocol).
on-fail: exit 2 with stderr "Hungarian notation detected ... Remove the type prefix; the name should describe intent, not type."
```

Detected prefixes: `strName`, `bIsActive`/`bHas…`/`bCan…`/`bShould…`, `iCount`/`iNum`/`iTotal`, `nSize`/`nLen`, `oObj`, `szStr`, `pPtr`, `aArr`/`aList`.

---

## Section A-SELF — Mechanical Rules (Agent Self-Enforced)

Deterministic in spirit, but reliably detecting them needs scope and semantic context a shell hook lacks — a hook would block idiomatic code (`const t = useTranslations()`, every Tailwind numeric utility) while missing real cases. They are **not** hook-blocked. You MUST self-enforce them on every write and review.

### NM-001a
Single-letter variable names are only acceptable for: (a) loop counters (i, j, k), or (b) local variables inside short scopes where the context makes the meaning immediately obvious. All other single-letter names are violations.

```
enforcement: agent (self-enforced; no hook)
check: For every variable/parameter introduced in the diff, cite file:line.
       If a single-letter name is used outside a loop counter or an obvious
       short-scope local → MAJOR. Use an intention-revealing name.
```

### NM-005a
Magic number literals must be named constants. Raw numeric values used in logic (other than 0 and 1 in simple increment/index/null checks) are violations.

```
enforcement: agent (self-enforced; no hook)
check: For every numeric literal used in logic in the diff, cite file:line.
       Exclude framework/style tokens (e.g. Tailwind class numbers), array
       indices, and 0/1. If a raw number encodes a rule, limit, timeout, or
       other magic value → MAJOR. Assign it to a named constant.
```

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### NM-001
Names must reveal intent — why the thing exists, what it does, and how it is used —
without requiring a comment to explain it.

```
enforcement: agent
check: For every variable, parameter, function, and class name introduced or changed
       in the diff, cite file:line. Can a reader instantly understand why it exists,
       what it holds, and how to use it from the name alone — without reading any
       comment or tracing back to its definition?
       If the name requires a comment to be understood → MAJOR.
       If the name requires the reader to scroll to its definition to understand
       what it holds → MAJOR.
evidence-required: yes
```

### NM-002
Names must not contain disinformation — never use a word that misrepresents the
actual type, structure, or behaviour.

```
enforcement: agent
check: For every name introduced or changed in the diff, cite file:line.
       1. Does the name use a type word that does not match the actual type?
          (e.g. calling a Map "accountList", calling an Array "userSet") → MAJOR.
       2. Does the name promise behaviour or a value it does not deliver? → MAJOR.
       3. Do any two names in the diff differ only in subtle ways (one character,
          transposed letters, minor suffix change) that would cause autocomplete
          to pick the wrong one? → MAJOR.
       4. Does any name use visually ambiguous characters — lowercase l vs number 1,
          uppercase O vs zero 0? → MAJOR.
evidence-required: yes
```

### NM-003
Names must make meaningful distinctions. If two things have different names,
they must do genuinely different things. Noise words are banned.

```
enforcement: agent
check: For every pair of names in the diff that are close in spelling or use generic
       suffixes, cite file:line.
       1. Do these two names reveal a real difference in behaviour or purpose?
          If the only distinction is a number suffix (param1, param2, data1) → MAJOR.
       2. Do any class or function names use noise suffixes — Manager, Handler, Data,
          Info, Object, Variable, Processor — without a specific qualifier that
          distinguishes behaviour? ("UserManager" where the actual role could be named
          "UserAuthenticator" or "UserRepository") → MINOR.
          If EVERY class of a type ends in the same noise word with no specificity → MAJOR.
evidence-required: yes
```

### NM-004
Names must be pronounceable — speakable in a normal code review conversation.

```
enforcement: agent
check: For every name introduced or changed in the diff, cite file:line.
       Can a developer say this name aloud naturally in a sentence during a code review?
       Names with concatenated abbreviations, acronym chains, or character sequences
       that cannot be spoken as words → MAJOR.
       Example violations: genymdhms, modymdhms, pszqint, cntrl, usr_auth_tkn.
evidence-required: yes
```

### NM-005
Name length must match scope size. Variables used across a wide scope need full,
descriptive names. Short-scope locals may be brief but never cryptic.

```
enforcement: agent
check: For every variable introduced in the diff, cite file:line and note its scope.
       1. Is this a variable used across multiple functions, passed between layers,
          or visible at module/class level — with a name so short it requires context
          to understand? → MAJOR.
       2. Is this a numeric or string constant used directly as a literal in logic
          (magic value) without being assigned to a named constant? → MAJOR.
          (Note: NM-005a catches raw numbers as a hook; this check covers cases where
          a named variable is used but the name still hides what the value represents.)
evidence-required: yes
```

### NM-007
No mental mapping — names must not require the reader to translate abbreviations
or remember what a short form stands for.

```
enforcement: agent
check: For every name introduced or changed in the diff, cite file:line.
       Would a new developer reading this name for the first time need to look it up,
       trace through call sites, or remember a mapping to understand what it means?
       Examples of violations: t for transaction, u for user, cnt for count,
       tmp for anything non-obvious, mgr, ctrl, proc, idx when the context isn't clear.
       If the name forces mental translation → MAJOR.
       Single-letter loop counters (i, j, k) in short loops are the one accepted exception.
evidence-required: yes
```
