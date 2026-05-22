# Functions

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Clean code principles for functions. Apply to all stacks and languages.

Source: @s4.codes clean code series (12 videos, Jan–Feb 2026)

---

## Section A — Hook-Enforced Rules

Mechanical checks. Run as PreToolUse hooks before every file write — the hook exits 2 to block the write. Cannot be skipped.

### FN-001
Functions must not exceed 20 lines (excluding blank lines and comments).

```
enforcement: hook
command: scripts/checks/check-function-size.sh
trigger: PreToolUse(Write, Edit)
input: JSON via stdin (Claude Code hook protocol). Script reads tool_input.file_path and derives new content from tool_input fields (content for Write; old_string/new_string for Edit).
on-fail: exit 2 with stderr "Function '{name}' at {file}:{line} is {count} lines. Maximum is 20. Extract sub-functions."
```

### FN-001b
Blocks inside if, else, while, for, and similar control structures must be one line long — always a function call, never inline logic.

```
enforcement: hook
command: scripts/checks/check-block-body-size.sh
trigger: PreToolUse(Write, Edit)
input: JSON via stdin (Claude Code hook protocol).
on-fail: exit 2 with stderr "Multi-line block body found at {file}:{line}. Extract the block into a named function."
```

### FN-005
Functions must not have more than 3 parameters. 4 or more is always a block.

```
enforcement: hook
command: scripts/checks/check-param-count.sh
trigger: PreToolUse(Write, Edit)
input: JSON via stdin (Claude Code hook protocol).
on-fail: exit 2 with stderr "Function '{name}' at {file}:{line} has {count} parameters. Maximum is 3. Group related parameters into an object/struct."
```

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### FN-002
Each function does exactly one thing.

```
enforcement: agent
check: For every function touched in the diff, cite file:line and state its name.
       Answer two questions:
       1. Can you identify labeled "sections" within it — groups of lines serving
          different purposes? If yes → MAJOR.
       2. Can you extract another function from it with a name that is NOT merely
          a restatement of what the code already does? If yes → MAJOR.
evidence-required: yes
```

### FN-003
Functions operate at a single level of abstraction. They form a step-down narrative —
each function reads as a to-do list at one level, each step delegating to the next.

```
enforcement: agent
check: For every function touched, cite file:line.
       Negative test: Does it mix high-level intent (what the system should do) with
       low-level implementation details (how)? Example: a function that both orchestrates
       an order flow AND directly calls raw Stripe API syntax is mixing levels → MAJOR.

       Positive test: Does each line read as a single action at the same abstraction level,
       pointing to the next? Example of correct shape:
         processOrder → validateStock, calculateBill, chargeCustomer, notifyWarehouse
         calculateBill → sumItems, applyDiscounts, addTax
       Each function describes its scope at one level and delegates details below.
       If a function mixes CEO-level steps with specialist-level implementation in the
       same body → MAJOR.
evidence-required: yes
```

### FN-004
Switch statements (or language equivalents: match, pattern-match) are buried in
factories — never duplicated across multiple functions.

```
enforcement: agent
check: For every switch/match statement in the diff, cite file:line.
       Is this the only place this type-dispatch logic appears, inside a dedicated
       factory/dispatcher whose sole job is to create or route? If the same
       type-dispatch logic appears in more than one function → MAJOR.
       If a switch appears in business logic rather than a factory → MAJOR.
evidence-required: yes
```

### FN-005b
3 parameters is the signal to consider grouping. When exactly 3 parameters appear,
review whether they belong together as an object.

```
enforcement: agent
check: For every function with exactly 3 parameters touched in the diff, cite file:line.
       Do the 3 parameters represent related data that could be expressed as a named
       object/struct? If they can be naturally grouped — and the function is not a
       well-known triad like coordinates (x, y, z) or assert(expected, actual, message) —
       → MINOR (consider grouping into an object).
evidence-required: yes
```

### FN-006
No boolean flag arguments that control which code path runs inside the function.

```
enforcement: agent
check: For every function call in the diff that passes a literal true or false
       as an argument, cite file:line. Does that boolean select which branch of
       logic executes (flag argument)? If yes → MAJOR.
       Exception: passing true/false as data (e.g. setVisible(true), setActive(false))
       is acceptable — only flag arguments that split internal behaviour are violations.
evidence-required: yes
```

### FN-006b
Single-argument functions must serve one of three purposes: asking a question
(passes something in, returns an answer), transforming input (passes something in,
returns something new), or handling an event (something happened, function reacts).

```
enforcement: agent
check: For every function with exactly 1 parameter touched in the diff, cite file:line.
       Does the argument serve one of the three valid purposes:
       1. Question — passes a value in, returns a boolean or answer
       2. Transformation — passes input, returns a transformed output
       3. Event — signals that something happened, return value may be void
       If the single argument does not clearly fit any of these patterns → MINOR.
evidence-required: yes
```

### FN-006c
Argument pairs must not be two unrelated concepts with no clear owner.
Natural pairs (two halves of one idea, e.g. coordinates) are acceptable.
For unrelated pairs, make one the owner. Encode ordering into the name when
a triad's order is not naturally obvious to any reader.

```
enforcement: agent
check: For every function with 2–3 parameters touched in the diff, cite file:line.
       1. Are the two parameters unrelated concepts forced together with no natural
          ordering? If yes — and neither is clearly the owner/receiver — → MAJOR.
          Exception: natural pairs that form one concept (e.g. x and y coordinates)
          are fine.
       2. For 3 parameters: would a reader guess the correct order without checking
          the signature? If the order is ambiguous and the function name does not
          encode it (e.g. assertExpectedEqualsActual encodes the order) → MAJOR.
evidence-required: yes
```

### FN-007
No output arguments — functions return results, they do not mutate their inputs.

```
enforcement: agent
check: For every function touched, cite file:line. Does any parameter get mutated
       inside the function and produce its result via side effect rather than a
       return value? If a function modifies its arguments instead of returning
       a result → MAJOR.
evidence-required: yes
```

### FN-008
No side effects — a function does exactly what its name promises, nothing more.
Renaming the function to make it honest is NOT an acceptable fix — the function must
be split so each part does one thing.

```
enforcement: agent
check: For every function touched, cite file:line and state what the name promises.
       1. Does the function modify any state outside its own scope beyond what the name
          indicates? Examples: checkPassword() that also starts a session;
          validateInput() that also writes to a database. If yes → MAJOR.
       2. If the function was recently renamed to acknowledge dual behaviour (e.g.
          checkPasswordAndStartSession), the rename is not a fix — it still does two
          things. Cite file:line and flag → MAJOR. The side effect must be extracted
          into its own separate function.
evidence-required: yes
```

### FN-009
Command-Query Separation — a function either changes state (command) or returns
information (query), never both.

```
enforcement: agent
check: For every function touched, cite file:line. Does it both modify state AND
       return a meaningful value other than a simple success/error indicator?
       If a function sets or changes data AND returns a query result → MAJOR.
evidence-required: yes
```

### FN-010
Prefer exceptions over error codes. Never use shared error code enums.

```
enforcement: agent
check: For every function touched, cite file:line.
       1. Does it return error codes — strings like "ERROR_X", integers signalling
          failure, or enum error values that callers must check inline? If yes → MAJOR.
       2. Does it use or reference a shared error enum imported across multiple files?
          Shared error enums couple the entire codebase — change one value and you
          break every importer. If yes → MAJOR.
       Exception: functions at true system boundaries (external APIs, DB drivers)
       that return Result/Option/Either types are acceptable.
evidence-required: yes
```

### FN-010b
Try/catch blocks must be extracted into their own functions — normal processing
and error processing must not sit side by side in the same function body.

```
enforcement: agent
check: For every function touched that contains a try/catch block, cite file:line.
       Is there meaningful logic both inside the try block AND outside it in the same
       function? If the function does real work AND handles errors in the same body → MAJOR.
       The correct shape: one function calls a try-function and a catch-function,
       each containing only their respective logic.
evidence-required: yes
```

### FN-011
DRY — no duplicated logic across functions.

```
enforcement: agent
check: Scan the entire diff for logic that appears more than once with the same
       intent: same operation repeated in 2+ places, or copied blocks with only
       minor variations. Cite file:line for each duplicate pair. If duplicated
       logic is found → MAJOR.
evidence-required: yes
```
