---
name: coding-standards
description: >
  Coding standards for writing, editing, and reviewing code — functions, naming,
  components, TypeScript, error handling, formatting, objects/data, code principles
  (SOLID/KISS/DRY), and UI/UX. Consult before any code change. A PreToolUse hook
  hard-blocks a high-precision subset (no `any`, explicit return types, no Hungarian
  notation); the remaining rules are applied by the agent. Use for requests like
  "write a component", "refactor this", "review this diff/PR", or "is this clean?".
license: MIT
metadata:
  author: willey-lab
  version: "2.1.0"
---

# Coding Standards

Every line of code you write or edit must comply with these rules. No exceptions.

## Skill Location

All paths in this document are **relative to this SKILL.md file**. For example, `references/functions.md` means the `references/` subdirectory next to this file. This works regardless of whether the skill is installed at project-level or user-level — the agent resolves paths from where it loaded this file.

## Bootstrap (run once per project)

The very first time this skill is loaded in a project, install the enforcement hooks. Most rules are applied by you (the agent) whether or not the hooks are present; the hooks add an automatic hard gate for the A-HARD rules so they can't slip through. Install them.

Procedure (silent unless something fails):

1. If a marker file already exists at `<project>/.coding-standards-installed`, skip — hooks are already set up.
2. Locate the install script at `scripts/install-hooks.sh` (relative to this SKILL.md).
3. Run the install script with no arguments. It auto-detects the scope (running inside a session pins it to the current project) and which AI tools and version controls are present, and installs hooks for each. For a global skill that should enforce in every project, run it with `--user`.
4. On success, create the marker file `<project>/.coding-standards-installed` containing the current ISO timestamp so this bootstrap does not run again.
5. Report to the user in one line: which targets were installed (e.g. `hooks installed: claude, git`).

If the install script is missing or fails, surface the error to the user but continue with the rest of this skill.

## Layer Routing

First apply **CS-SCOPE** (see Components) as a gating filter: vendor, generated, and third-party files — e.g. `components/ui/**` scaffolded by shadcn, or anything under `vendor/`, `node_modules/`, `generated/` — are excluded from **all** rules. CS-SCOPE wins over the routing below. Only then route the remaining files:

| Layer | File Patterns | Sections to Follow |
|---|---|---|
| **backend** | `*.service.ts`, `*.controller.ts`, `*.module.ts`, `*.guard.ts`, `*.pipe.ts`, `*.decorator.ts`, `*.go`, `*.rs`, `*.php`, `*.py` | Functions + Naming + Error Handling + Objects & Data + Formatting + Code Principles |
| **frontend** | every `*.ts` / `*.tsx` / `*.js` / `*.jsx` | All backend sections + Components + TypeScript |
| **ui** | `*.css`, `*.scss`, `*.module.css`, `*.tsx`, `*.jsx`, `*.vue`, `*.svelte` | UI/UX |

- **Section A** (mechanical rules) applies to all code files regardless of layer — the hook enforces it by file extension, not folder.
- **TypeScript rules (TS-*)** apply to **every** `.ts`/`.tsx` file. This matches the PreToolUse hook, which checks all TypeScript regardless of folder.
- A `.tsx` file matches frontend **and** ui — follow both.
- **Component rules (CS-*)** carry their own applicability guards (e.g. CS-008 skips backend code), so they are safe to consider on any frontend file.

Full routing config: `references/layer-standards.json`

---

## Scope Definitions

- **"touched in the diff"** = the function/component/class contains at least one changed, added, or deleted line.
- **"introduced in the diff"** = the function/component/class is entirely new (did not exist before).
- **"in the diff"** = anywhere in the set of changed files.

---

## Write Mode vs Review Mode

**Write Mode** — When writing or editing code, apply all applicable rules proactively. Write compliant code the first time. If you catch a violation in code you just wrote, fix it immediately before moving on.

**Review Mode** — When reviewing code (diff, PR, or file), follow the Review Protocol below. Iterate through every applicable rule systematically. Never skip a rule silently.

---

## Review Protocol (Mandatory)

When this skill is invoked for code review, you MUST execute these steps in order. Do not freelance — follow the procedure.

### Step 1 — Scope
List all files in the diff. For each file, determine its layer using the Layer Routing table above. Report the mapping.

### Step 2 — Filter
Apply CS-SCOPE first. List any excluded files and why. Remaining files proceed to review.

### Step 3 — Load References
For each applicable layer, you MUST read the full reference file from `references/` (relative to this SKILL.md). The summaries in this document are abbreviated — the reference files contain the full check procedure, applicability guards, and edge cases required to apply each rule correctly. Do NOT rely solely on the summaries below.

### Step 4 — Systematic Check
For each applicable rule, in rule-ID order:
1. State the rule ID and name.
2. Apply the `applicability:` guard from the reference file. If the rule does not apply to any file in the diff, report SKIPPED with reason.
3. Check every file/function/component the rule covers.
4. Report each finding as: `file:line` — violation description.
5. If no violations found, report PASS.

Never skip a rule without reporting SKIPPED with a reason.

### Step 5 — Write Review to File

Write your review output to a file using the Write tool. Use the path `.coding-standards-review.md`. The file must use this exact format — the validation hook parses it:

```
## Coding Standards Review

**Files reviewed:** [list with layers]
**Files excluded (CS-SCOPE):** [list with reasons, or "None"]

### Findings

**[RULE-ID] Rule Name** — PASS | MAJOR(n) | MINOR(n) | SKIPPED(reason)
- `file.tsx:42` — Description of violation

(repeat for every applicable rule)

### Summary
| Severity | Count |
|----------|-------|
| MAJOR    | n     |
| MINOR    | n     |
| PASS     | n     |
| SKIPPED  | n     |

Rules checked: n/N applicable
```

### Step 6 — Coverage Check

After writing the review file, a PostToolUse hook runs a **coverage gate** (`validate-review.sh`): it verifies that every applicable rule ID appears in the review and that each MAJOR/MINOR finding carries a `file:line` citation. It does **not** verify that your findings are correct — a rubber-stamped "PASS" for every rule would pass this gate. Correctness is your responsibility. If the gate reports missing rules, add findings for them and re-write the file.

If hooks are not installed, run the gate manually:
```bash
bash scripts/validate-review.sh .coding-standards-review.md
```

### Step 7 — Completion
A review is complete only when:
1. Every applicable rule has been **genuinely evaluated** and reported as PASS, MAJOR, MINOR, or SKIPPED — not rubber-stamped. The coverage gate cannot detect a fabricated PASS; your integrity must.
2. The coverage gate exits 0.
3. All MAJOR/MINOR findings include a `file:line` citation.

If you have not genuinely evaluated a rule, you have not finished the review.

---

## Section A — Mechanical Rules

These rules have deterministic right/wrong answers. A small, high-precision subset is enforced by a hook that blocks the write. The rest are self-enforced by you — detecting them reliably needs scope and structural understanding a shell script cannot provide on real TypeScript/JSX, and a hook that tried would block idiomatic code while missing real violations. "Not hooked" does **not** mean "optional."

### A-HARD — Hook blocks the write (Write / Create / Edit / ApplyPatch)

The PreToolUse hook (`scripts/coding-standards-check.sh`) hard-blocks these. Matching runs on comment-and-string-stripped code, so text inside strings or comments never false-positives.

**TS-001** No `any` type. `any` in any type position — `: any`, `as any`, `<any>`, `any[]`, `Array<any>`, `Record<string, any>`, `x | any` — is blocked. Use a specific type, a generic, or `unknown` with a type guard.

**TS-002** Exported functions, exported arrow consts, and `public`/`private`/`protected` class methods must have explicit return types. (The hook covers those forms; you self-enforce object-literal methods, modifier-less methods, and multi-line signatures.)

**NM-006** No Hungarian notation. Do not encode types into names (`strName`, `bIsActive`, `iCount`, `oObj`, `aList`). Names describe intent, not type.

### A-SELF — Agent must self-enforce (no hook)

Mechanical in spirit, but NOT hook-blocked: reliably detecting them needs scope, semantic, or structural context a shell script cannot provide. You MUST check these with the same rigor as the hook-enforced rules, on every write and review.

**NM-001a** No single-letter variable names except loop counters (`i`, `j`, `k`) or obvious short-scope locals. Use intent-revealing names. *(Not hooked: a regex hook blocks idioms like `const t = useTranslations()`.)*

**NM-005a** No magic numbers. Raw numeric values — other than 0/1, array indices, and framework/style tokens (e.g. Tailwind class numbers) — must be named constants. *(Not hooked: indistinguishable from legitimate literals without a parser.)*

**FN-001** Functions must not exceed 20 lines (excluding blanks and comments). Extract sub-functions. *(Not hooked: brace counting desyncs on JSX, generics, and braces in strings.)*

**FN-001b** Control blocks (`if`/`else`/`while`/`for`) must be one line long — always a function call, never inline logic.

**FN-005** Functions must not have more than 3 parameters. Group related parameters into an object. *(Not hooked: arrow-const and object-method forms are missed by line-based detection.)*

**OD-003a** No method chains deeper than 2 objects. `a.getB().getC().doThing()` violates the Law of Demeter. Tell the object what you need; it returns the answer directly.

**FMT-003a** Variables must be declared within 5 lines of first use. Move declarations close to where they are needed.

> Post-install: run `bash scripts/install-hooks.sh` (relative to this SKILL.md) to enable the A-HARD hook. The A-SELF rules have no hook by design — they rely on you.

---

## Functions

> **You MUST read `references/functions.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**FN-002** Each function does exactly one thing. If you can describe it with "and" or extract a non-trivially-named sub-function, split it.

**FN-003** One abstraction level per function. Do not mix orchestration ("what to do") with implementation details ("how to do it") in the same body. Each function reads as a to-do list at one level, delegating details to the next.

**FN-004** Switch/match statements belong in factories. Never duplicate type-dispatch logic across multiple functions.

**FN-005b** When a function has exactly 3 parameters, consider whether they belong together as a named object. Well-known triads (x/y/z, expected/actual/message) are acceptable.

**FN-006** No boolean flag arguments that select which code path runs inside the function. Passing `true`/`false` as data (e.g. `setVisible(true)`) is fine; flags that split internal behaviour are not.

**FN-006b** Single-argument functions must serve one of three purposes: asking a question (returns an answer), transforming input (returns something new), or handling an event (reacts to something that happened).

**FN-006c** Argument pairs must not be two unrelated concepts forced together. Natural pairs (coordinates) are fine. For unrelated pairs, make one the owner. Encode ordering into the name when a triad's order is ambiguous.

**FN-007** No output arguments. Functions return results — they do not mutate their inputs to produce side effects.

**FN-008** No side effects. A function does exactly what its name promises, nothing more. Do not rename the function to acknowledge dual behaviour — split it so each part does one thing.

**FN-009** Command-Query Separation. A function either changes state (command) or returns information (query), never both.

**FN-010** Prefer exceptions over error codes. Never use shared error code enums — they couple the entire codebase.

**FN-010b** Try/catch blocks must be extracted into their own functions. Normal processing and error processing must not sit side by side in the same function body.

**FN-011** DRY — no duplicated logic across functions. If the same operation appears in 2+ places, extract it.

---

## Naming

> **You MUST read `references/naming.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**NM-001** Names must reveal intent — why the thing exists, what it does, how it is used. If a name requires a comment to be understood, rename it.

**NM-002** No disinformation in names. Never use a word that misrepresents the actual type, structure, or behaviour (e.g. calling a Map "accountList"). No names that differ by only one character.

**NM-003** Meaningful distinctions only. If two things have different names, they must do genuinely different things. No number suffixes (`data1`, `data2`). No noise words (`Manager`, `Handler`, `Data`, `Info`, `Processor`) without a specific qualifier.

**NM-004** Names must be pronounceable — speakable in a normal code review conversation. No acronym chains or unpronounceable abbreviations.

**NM-005** Name length must match scope size. Wide-scope variables need full, descriptive names. Short-scope locals may be brief but never cryptic.

**NM-007** No mental mapping. Names must not require the reader to translate abbreviations or remember what a short form stands for (`t` for transaction, `mgr` for manager, `ctrl` for controller).

---

## Error Handling

> **You MUST read `references/error-handling.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**EH-001** Algorithm and error handling must be fully independent. The happy path must read as a clean sequence of steps without error branches obscuring it. Neither concern knows about the other.

**EH-002** Catch blocks must translate exceptions into meaningful domain exceptions. Never let raw implementation exceptions leak through. Never swallow exceptions silently.

**EH-003** Define the try/catch contract before writing the logic. Each try block wraps one coherent operation with one clear failure mode. When test files are in scope, every failure path needs a covering test; if no tests are in scope, flag it for verification rather than reporting a violation.

---

## Objects & Data

> **You MUST read `references/objects-and-data.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**OD-001** Classes expose behaviour, not structure. Never blindly add getters/setters for every field. If callers would break when you change the internal representation, the abstraction is wrong.

**OD-002** Choose the right structure for the expected direction of change. Frequently adding new operations on fixed types → use data structures + functions. Frequently adding new types with fixed operations → use objects.

**OD-003** Law of Demeter: talk to friends, not strangers. A method may only call methods on objects it owns, creates, receives as arguments, or holds as fields. Not on objects returned by those calls. This applies to real objects, not data structures (data structures expose internals by design).

**OD-004** No hybrid classes. A class is either an object (hides data, exposes behaviour) or a data structure (exposes data, no behaviour). Active Records/DTOs are data structures — business logic must live in a separate object.

---

## Formatting

> **You MUST read `references/formatting.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**FMT-001** Source files read like a newspaper: highest-level function at top, each function defined just below its first caller, related functions grouped together.

**FMT-002** Blank lines separate concepts. Related lines stay vertically dense. Indentation consistently reflects scope depth.

**FMT-003** Local variables declared close to first use. Class properties in one designated place, not scattered near individual methods.

**FMT-004** Formatting conventions must be consistent with the rest of the codebase. Brace placement, indentation style, quote style — follow what the existing code uses.

---

## Code Principles

> **You MUST read `references/code-principles.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**DP-001 — Single Responsibility** Every class, module, and service has exactly one reason to change. When a unit serves two different actors or owns two different concerns, split it. (Skip for trivial wrappers and data structs.)

**DP-002 — Open/Closed** Extend by adding new code, not by editing existing working code. Apply when there is a real, recurring pattern of variation — not hypothetical future ones.

**DP-003 — Liskov Substitution** A subtype must honour the full contract of its parent. No throwing unexpected exceptions, no weakening preconditions, no refusing to implement parts of the interface. (Apply only when actual inheritance is present.)

**DP-004 — Interface Segregation** No code should depend on methods it does not use. Prefer many small, focused interfaces over one large general-purpose one. (Apply only when an interface has multiple methods and multiple distinct consumers.)

**DP-005 — Dependency Inversion** High-level modules depend on abstractions, not concrete implementations. Apply when business logic depends on infrastructure (database, HTTP, file system, external SDK). Skip for stable same-layer imports.

**DP-006 — KISS** Choose the simplest design that satisfies current, stated requirements. If removing the complexity would not break anything real, it should not exist. KISS is the tiebreaker when other rules conflict.

**DP-007 — DRY** Every piece of knowledge has a single, authoritative representation. No duplicated business rules, type shapes, configuration values, or component structures across files.

---

## Components

> **You MUST read `references/components.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**CS-SCOPE** Only audit code written by the project team. Third-party, generated, or vendor-scaffolded files are out of scope. Apply this filter before any other rule.

**CS-001** Entry-point files (pages, routes, screens) only compose existing components. They must not define new components inline. Entry points assemble; they do not define.

**CS-002** Components must be grouped into domain or feature subfolders (`components/invoices/InvoiceStatusBadge.tsx`, not `components/StatusBadge.tsx`). No flat-dumping into a single root folder.

**CS-003** Component names must include their domain qualifier. A name that could belong to any feature (`Card`, `Modal`, `Selector`) is too generic. Use domain-qualified names: `ProductCard`, `ConfirmDeleteModal`, `ClientSelector`.

**CS-004** Always check the project's component library before writing any UI primitive. Use the library's component if one exists. Library-first is non-negotiable.

**CS-005** Every component has exactly one responsibility. If it fetches data AND manages form state AND renders a complex layout, decompose it. If you can split it, you must split it.

**CS-006** The domain-subfolder pattern applies equally to `hooks/`, `utils/`, `types/`, `services/`. Domain-specific files go in domain subfolders, not flat at the technical-layer root.

**CS-007** Hooks, utilities, types, and services that belong to one domain must include that domain's qualifier in their name (`useInvoiceList`, not `useList`; `InvoiceSchema`, not `Schema`).

**CS-008** Components must be presentational. Data fetching, mutations, non-trivial derivations, and complex state machines live in hooks or services, not in the component body. The component renders; hooks and services own the logic.

---

## TypeScript

> **You MUST read `references/typescript.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

**TS-003** Prefer union types over enums. String literal unions provide the same type safety without runtime overhead. Only use enums when justified by a requirement string unions cannot meet (e.g. bitwise flags).

**TS-004** Enable `strict: true` and `noUncheckedIndexedAccess: true` in tsconfig.json.

**TS-005** Use `interface` for object shapes that may be extended; use `type` for unions, intersections, and mapped types. Be consistent within each category across a file.

**TS-006** Prefer type guards and type predicates over type assertions (`as X`). Assertions silence the compiler without runtime verification. If an assertion is necessary for a third-party type bug, add a comment explaining why.

**TS-007** Module resolution must use `bundler` or `nodenext`. For packages consumed by other packages, enable `declaration: true` and `declarationMap: true`.

**TS-008** Use nullish coalescing (`??`) and optional chaining (`?.`) instead of truthy-falsy checks (`||`, `&&`) when handling `null`/`undefined`. The `||` operator treats `0`, `""`, and `false` as falsy.

**TS-009** Every non-void function path must return a value. Use early-return guard clauses to narrow types before the main logic.

---

## UI/UX

> **You MUST read `references/ui-ux.md`** for full check procedures, applicability guards, and edge cases before applying these rules.

### Code-Auditable (can be verified from code alone)

**UI-001 — Color & Contrast** `audit: code` Meet WCAG AA contrast (4.5:1 minimum for text). Avoid pure black/white — tint neutrals toward the brand hue. No gray text on colored backgrounds. No AI purple/cyan/neon palettes without brand justification.

**UI-002 — Typography** `audit: code` Body line-height at least 1.5. Body text containers max 75ch. Font size hierarchy at least 1.25x between steps. Body font minimum 14px. Use `clamp()` for responsive headings.

**UI-003 — Spacing & Layout** `audit: code` Follow the project's spacing scale. No cards nested inside cards. Related elements within 24px. Section breaks at least 40px.

**UI-004 — Motion & Animation** `audit: code` Only animate `transform` and `opacity`. Duration between 100ms–500ms. Use `ease-out` over `ease-in-out`. No bounce/elastic curves. Always provide `@media (prefers-reduced-motion)` fallback.

**UI-005 — Interaction & Accessibility** `audit: code` Touch targets at least 24×24px (WCAG 2.2 AA, SC 2.5.8); 44×44px recommended (AAA SC 2.5.5 / Apple HIG). Never remove focus outlines without a `:focus-visible` replacement. No skipped heading levels. Button labels must describe the action (not "OK", "Submit", "Click here"). Form inputs must have associated labels, not just placeholders.

**UI-006 — Visual Anti-Patterns** `audit: code` No gradient text. No icon-tile-stack pattern. No center-aligned body text outside hero/CTA. No thick accent borders on cards. No decorative glow effects.

### Visual-Inspection-Required (flag for browser verification)

These rules cannot be fully verified from code alone. During code review, check what you can from the code (sizes, values, structure) and flag the remainder for browser verification.

**UI-007 — Hierarchy** `audit: visual` The most important element must be the most visually prominent. Primary action above the fold. Heading sizes must reflect their level. Secondary elements styled lighter than primary content.

**UI-008 — Emphasis** `audit: visual` Every screen has exactly one focal point. When everything is emphasized, nothing is. The primary CTA must be the most prominent interactive element.

**UI-009 — Contrast** `audit: visual` Interactive elements must look distinct from static elements. Active/selected states must be clearly distinct from defaults. Primary and secondary actions must be visually differentiated.

**UI-010 — Balance** `audit: visual` Visual weight distributed intentionally. No accidental lopsided layouts. Asymmetry must be clearly deliberate.

**UI-011 — Proportion & Scale** `audit: visual` Element size reflects role in hierarchy. Secondary elements must not be sized close to or larger than primary content. Size variants within a component family must follow a consistent scale.

**UI-012 — White Space** `audit: visual` Empty space is a design element. No edge-to-edge packing without intention. Negative space groups related elements and separates unrelated ones.

**UI-013 — Repetition & Pattern** `audit: visual` Same UI pattern must be implemented the same way everywhere. No second implementation of an existing pattern with different styling.

**UI-014 — Movement & Visual Flow** `audit: visual` Layout must guide the eye toward the main action. Clear reading path from entry point to primary action. Visual flow must match content's logical order.

**UI-015 — Unity & Harmony** `audit: visual` All elements must feel like they belong to the same design. No orphaned styles, one-off values, or elements that look like they came from a different product.

---

## Conflict Resolution

- A-HARD rules (hook-enforced) are absolute — no judgment calls.
- A-SELF rules are mechanical and near-absolute, but applied with scope awareness (e.g. a single-letter loop index or an array index `0`/`1` is fine).
- For Section B rules, KISS (DP-006) is the tiebreaker: choose the simpler design.
- CS-SCOPE: never flag third-party, generated, or vendor code — it gates before every other rule.
