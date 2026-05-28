# TypeScript

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for writing clean, maintainable TypeScript. Applies wherever TypeScript is
detected in the stack (frontend, backend, or shared packages). Layer routing via
`references/layer-standards.json` maps this file to the frontend layer.

Source: TypeScript Handbook, `tsconfig` reference, idiomatic community practice.

---

## Section A — Hook-Enforced Rules

Mechanical checks the PreToolUse hook (`scripts/coding-standards-check.sh`) detects
with high precision. It exits 2 to block the write. The script strips comments and
blanks string/template contents before matching, so `any` inside a string or comment
does not false-positive.

### TS-001
No use of the `any` type. `any` in any type position — `: any`, `as any`,
`<any>`, `any[]`, `Array<any>`, `Record<string, any>`, `Map<K, any>`,
`x | any` — is a type-safety escape hatch and is blocked. Use a specific type, a
generic, or `unknown` with a type guard instead.

```
enforcement: hook
script: scripts/coding-standards-check.sh → check_ts_no_any()
trigger: PreToolUse(Write, Create, Edit, ApplyPatch) on .ts/.tsx
input: tool-call JSON via stdin (Claude Code / Factory hook protocol).
on-fail: exit 2 with stderr "TS-001: Type 'any' found. Use a specific type, a generic, or 'unknown' with a type guard."
```

### TS-002
Exported functions and class methods must have explicit return types. Implicit
return types on public API surfaces force consumers to infer the contract from
implementation rather than from the signature.

```
enforcement: hook (high-precision subset) + agent (remainder)
script: scripts/coding-standards-check.sh → check_ts_explicit_return()
trigger: PreToolUse(Write, Create, Edit, ApplyPatch) on .ts/.tsx
hook covers: exported function declarations, exported arrow-function consts, and
       public/private/protected class methods (excluding constructors and setters).
self-enforce: object-literal methods, modifier-less class methods, and multi-line
       signatures — the hook intentionally skips these to avoid false positives;
       you must check them during write/review.
on-fail: exit 2 with stderr "TS-002: ... lacks an explicit return type."
```

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### TS-003
Prefer union types over enums. TypeScript enums generate runtime code and
have surprising scoping behaviour (const enums, ambient enums, declaration
merging). String literal unions provide the same type safety without the
runtime overhead.

```
enforcement: agent
check: For every enum declaration in the diff, cite file:line.
       1. Can this enum be replaced with a union of string literals?
          (e.g. `type Status = 'active' | 'inactive'` instead of
          `enum Status { Active, Inactive }`) → MINOR.
       2. If the enum uses computed or constant values that are NOT
          string literals (e.g. numeric flags, bitwise masks), is the
          enum justified by a requirement that string unions cannot meet?
          If not justified → MAJOR.
       3. Does the enum use `const enum`? These have cross-module
          inlining issues and should also prefer string unions → MINOR.
evidence-required: yes
```

### TS-004
Enable strict mode and `noUncheckedIndexedAccess` in tsconfig.json. Every
TypeScript project must set `"strict": true` at minimum. Index-access
results (`arr[i]`, `obj[key]`) are `T | undefined` when
`noUncheckedIndexedAccess` is on — this catches out-of-bounds and
missing-key bugs at compile time.

```
enforcement: agent
check: For every tsconfig.json touched in the diff, cite file:line.
       1. Is `"strict": true` set (or all individual strict flags enabled)?
          If not → MAJOR.
       2. Is `noUncheckedIndexedAccess` set to `true`? If not → MINOR.
       3. Are any strict-family flags explicitly set to `false`?
          If yes, does a comment explain why? If not → MINOR.
evidence-required: yes
```

### TS-005
Prefer `interface` for object shapes that may be extended or merged; prefer
`type` for unions, intersections, mapped types, and one-off shapes. Do not
use `interface` and `type` interchangeably for the same conceptual category
— pick one per category and stay consistent.

```
enforcement: agent
check: For every interface or type alias declaration in the diff, cite file:line.
       1. Is an interface used where a union, intersection, or mapped type
          is needed? → MINOR (switch to type alias).
       2. Is a type alias used for a plain object shape that another module
          might need to extend (declaration merging)? → MINOR (switch to
          interface).
       3. Within a single file or module, are both interface and type used
          for the same kind of construct (e.g. all API response shapes use
          type but one uses interface)? → MINOR (pick one and be consistent).
evidence-required: yes
```

### TS-006
Use type guards and type predicates instead of type assertions (`as X`,
`<X>`). Type assertions silence the compiler without verifying the claim
at runtime. A type guard (function returning `x is T`) proves the narrowing
and is checkable at the call site.

```
enforcement: agent
check: For every type assertion (`as X` or `<X>`) in the diff, cite file:line.
       1. Could this assertion be replaced by a type guard or type
          predicate? If yes → MINOR.
       2. Is the assertion used to downcast (narrow from a wider type to a
          narrower type) without any runtime verification? If yes → MAJOR.
       3. Is the assertion used to work around a legitimate type error
          caused by a third-party library's incorrect types? If yes, is
          there a comment explaining the override? If no comment → MINOR.
evidence-required: yes
```

### TS-007
Module resolution must use `"bundler"` (or `"nodenext"` for Node-only
projects). Declaration emit (`"declaration": true` and
`"declarationMap": true`) must be enabled for any package that is
consumed by other packages or published.

```
enforcement: agent
check: For every tsconfig.json touched in the diff, cite file:line.
       1. Is `moduleResolution` set to `"bundler"` or `"nodenext"`?
          If set to `"node"` or `"classic"` → MAJOR.
       2. For packages that export types for external consumption, are
          `"declaration": true` and `"declarationMap": true` set?
          If not → MINOR.
       3. Is `module` set consistently with `moduleResolution`?
          (e.g. `"ESNext"` with `"bundler"`, `"NodeNext"` with `"nodenext"`)
          If mismatched → MINOR.
evidence-required: yes
```

### TS-008
Prefer nullish coalescing (`??`) and optional chaining (`?.`) over
truthy-falsy checks (`||`, `&&`) when the intent is specifically to handle
`null` or `undefined`. The `||` operator treats `0`, `""`, and `false` as
falsy, which is a common source of bugs when the valid domain includes those
values.

```
enforcement: agent
check: For every use of `||` or `&&` in the diff where the operand type
       is nullable (`T | null | undefined`), cite file:line.
       1. Is the intent to handle only `null`/`undefined` (not `0`, `""`,
          `false`)? If yes and `||` is used instead of `??` → MINOR.
       2. Is `||` used as a default-value pattern with a nullable left side
          where the valid type includes `0` or `""`? → MAJOR (will silently
          replace valid falsy values).
       3. Is optional chaining (`?.`) used for property access on a
          nullable receiver? If not (manual null check instead) → MINOR.
evidence-required: yes
```

### TS-009
Every non-void function path must return a value. When `strictNullChecks`
is enabled (required by TS-004), the compiler catches missing returns, but
explicit `return` statements at the end of every branch make the intent
clear and prevent accidental `undefined` returns.

```
enforcement: agent
check: For every function with a non-void return type in the diff,
       cite file:line.
       1. Does every code path through the function end with a return
          statement? If any path can fall through without returning → MAJOR.
       2. Are there early-return guard clauses that narrow the type before
          the main logic? This is the preferred pattern — if a function
          nests its logic inside multiple if-else blocks instead of using
          guard clauses → MINOR.
evidence-required: yes
```
