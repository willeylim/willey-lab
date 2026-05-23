---
name: coding-standards
description: >
  Mandatory coding standards enforced on every code write. Covers functions, naming,
  components, TypeScript, error handling, formatting, objects/data structures, code
  principles (SOLID/KISS/DRY), and UI/UX. This skill MUST be consulted before writing,
  editing, or reviewing any code.
license: MIT
metadata:
  author: willey-lab
  version: "2.0.0"
---

# Coding Standards

Every line of code you write or edit must comply with these rules. No exceptions.

## Layer Routing

Determine which sections apply based on the file you are editing:

| Layer | File Patterns | Sections to Follow |
|---|---|---|
| **backend** | `*.service.ts`, `*.controller.ts`, `*.module.ts`, `*.guard.ts`, `*.pipe.ts`, `*.decorator.ts`, `*.go`, `*.rs`, `*.php`, `*.py` | Section A + Functions + Naming + Error Handling + Objects & Data + Formatting + Code Principles |
| **frontend** | `components/**/*.ts(x)`, `hooks/**`, `use*.ts(x)`, `utils/**`, `lib/**`, `types/**` | All backend sections + Components + TypeScript |
| **ui** | `*.css`, `*.scss`, `*.module.css`, `components/ui/**`, `*.tsx`, `*.vue`, `*.svelte` | UI/UX |

A `.tsx` file matches both frontend and ui — follow both.

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
For each applicable layer, you MUST read the full reference file from `references/`. The summaries in this document are abbreviated — the reference files contain the full check procedure, applicability guards, and edge cases required to apply each rule correctly. Do NOT rely solely on the summaries below.

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

### Step 6 — Validation

After writing the review file, a PostToolUse hook automatically validates that every applicable rule is covered. If the hook reports missing rules, add findings for those rules and re-write the file.

If hooks are not installed, run the validation manually:
```bash
bash scripts/validate-review.sh .coding-standards-review.md
```

### Step 7 — Completion
A review is complete only when:
1. Every applicable rule has been reported as PASS, MAJOR, MINOR, or SKIPPED.
2. The validation script exits 0 (PASS).
3. All MAJOR/MINOR findings include a `file:line` citation.

If you have not reported on a rule, you have not finished the review.

---

## Section A — Mechanical Rules

These rules have deterministic right/wrong answers. Some are enforced by hook scripts, some require agent self-enforcement because they need context a shell script cannot detect.

### A-HARD — Hook blocks the write on every Write and Edit

**TS-001** No `any` type. Every `: any`, `as any`, or `<any>` is blocked. Use a specific type, a generic, or `unknown` with a type guard.

**TS-002** Exported functions and class methods must have explicit return types. Do not force consumers to infer the contract from implementation.

**NM-001a** No single-letter variable names except loop counters (`i`, `j`, `k`). Use intent-revealing names.

**NM-005a** No magic numbers. Raw numeric values (other than 0 and 1) must be named constants that reveal what the number represents.

**NM-006** No Hungarian notation. Do not encode types into names (`strName`, `bActive`, `iCount`, `oObject`, `aList`). Names describe intent, not type.

### A-WRITE-ONLY — Hook blocks on Write operations only (not Edit)

These checks require full file context. On Edit operations the hook cannot verify them — you must self-enforce during edits.

**FN-001** Functions must not exceed 20 lines (excluding blanks and comments). Extract sub-functions.

**FN-001b** Control blocks (`if`/`else`/`while`/`for`) must be one line long — always a function call, never inline logic.

**FN-005** Functions must not have more than 3 parameters. Group related parameters into an object.

### A-SELF — Agent must self-enforce (no hook)

These are mechanical rules but require semantic context that shell scripts cannot reliably detect. You MUST check these with the same rigor as hook-enforced rules.

**OD-003a** No method chains deeper than 2 objects. `a.getB().getC().doThing()` violates the Law of Demeter. Tell the object what you need; it returns the answer directly.

**FMT-003a** Variables must be declared within 5 lines of first use. Move declarations close to where they are needed.

> Post-install: run `bash scripts/install-hooks.sh` to enable automatic enforcement for A-HARD and A-WRITE-ONLY rules.

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

**EH-003** Define the try/catch contract before writing the logic. Each try block wraps one coherent operation with one clear failure mode. Every failure path must have a corresponding test.

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

**UI-005 — Interaction & Accessibility** `audit: code` Touch targets minimum 44x44px. Never remove focus outlines without a `:focus-visible` replacement. No skipped heading levels. Button labels must describe the action (not "OK", "Submit", "Click here"). Form inputs must have associated labels, not just placeholders.

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

- Section A rules (hook-enforced) are absolute — no judgment calls.
- For Section B rules, KISS (DP-006) is the tiebreaker: choose the simpler design.
- CS-SCOPE: never flag third-party, generated, or vendor code.
