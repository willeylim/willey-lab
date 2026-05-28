# Error Handling

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for writing clean, maintainable error handling. Apply to all stacks and languages.

Source: Robert C. Martin, *Clean Code: A Handbook of Agile Software Craftsmanship* (2008) — the primary source for these principles. Secondary explainer: the @s4.codes clean-code video series.

Note: FN-010 (prefer exceptions over error codes) and FN-010b (extract try/catch into
its own function) in functions.md are the foundation. The rules here build on top of them.

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### EH-001
Algorithm and error handling must be fully independent — neither knows about the other.
When two concerns share one function, separate them.

```
enforcement: agent
check: For every function touched that contains both logic and error handling, cite file:line.
       1. Can you read the algorithm (the happy path) as a clean sequence of steps
          without error handling branches obscuring it? If return codes or nested
          checks wrap every step so that the algorithm is buried → MAJOR.
          (The algorithm should read: step 1, step 2, step 3 — nothing else.)
       2. Can you read the error handling independently without the algorithm
          getting in the way? If error handling and logic are interleaved so that
          neither is readable on its own → MAJOR.
       3. Does the algorithm know about error handling? (e.g. does the algorithm
          check error states, return error codes, or branch on failure inline?)
          If yes → MAJOR. The algorithm must delegate all error concerns to
          a separate layer.
evidence-required: yes
```

### EH-002
Try/catch defines the contract. The catch block must translate exceptions into
a meaningful domain exception — never let raw implementation exceptions leak through.

```
enforcement: agent
check: For every try/catch block in the diff, cite file:line.
       1. Does the catch block catch a raw/generic exception (Exception, Error,
          Throwable, \Exception, error) and re-throw it without translating it into
          a domain-meaningful exception? If yes → MAJOR.
          The catch is the contract: it must state clearly what this function
          throws so every caller knows what to expect and can handle it.
       2. Does the catch block swallow exceptions silently (catch with no re-throw,
          no logging, no propagation)? If yes → MAJOR.
       3. Is the try block doing more than one conceptual job — making the contract
          hard to define? If yes → MAJOR. (Each try block should wrap one
          coherent operation with one clear failure mode.)
evidence-required: yes
```

### EH-003
Write the try/catch/finally before writing the logic when a function is expected
to throw. The contract must be defined before the implementation.

```
enforcement: agent
applicability: Point 2 (test coverage) applies ONLY when test files are in the
       diff/scope. Tests usually live in separate files; if none are in scope you
       cannot see them, so do NOT emit a MAJOR for "missing test" — instead flag
       it for verification. Points 1 and 3 always apply.
check: For every new function in the diff that contains a try/catch block, cite file:line.
       1. Does the try/catch define a clear, named exception type that callers can
          depend on? If the catch re-throws a vague or generic exception with no
          domain meaning → MAJOR.
       2. If test files are in scope: is there a test that verifies the failure
          case — that the function throws the expected exception when something
          goes wrong? If a failure path has no covering test → MAJOR.
          If no test files are in scope: do not emit MAJOR; report
          "failure path needs a test — not visible in this diff" for verification.
       3. Does anything added inside the try block fall outside the original
          contract — introducing new failure modes that the catch does not handle?
          If yes → MAJOR.
evidence-required: yes
```
