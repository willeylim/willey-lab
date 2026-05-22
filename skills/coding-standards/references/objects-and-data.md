# Objects and Data Structures

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for designing classes, data structures, and their boundaries. Apply to all stacks and languages.

Source: @s4.codes clean code series (4 videos)

---

## Section A — Hook-Enforced Rules

Mechanical checks. Run as PreToolUse hooks before every file write — the hook exits 2 to block the write. Cannot be skipped.

### OD-003a
Method call chains must not reach more than 2 objects deep on real objects.
Chaining through returned objects (a.getB().getC().doThing()) violates the Law of Demeter.

```
enforcement: agent
note: Too many false positives for shell-based hook enforcement (builder patterns, fluent APIs, test chains). You must self-enforce this rule.
```

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### OD-001
Classes must expose behaviour, not structure. Never blindly add getters and setters.

```
enforcement: agent
check: For every class introduced or modified in the diff, cite file:line.
       1. Does the class have a getter and/or setter for every private field,
          making it effectively public? If yes → MAJOR.
          The rule: if you can change the internal representation (e.g. from x/y
          to radius/theta) without touching any caller, the abstraction is correct.
          If callers would break, the implementation is exposed.
       2. Do the public methods describe the internal storage shape (getX, getY,
          setRadius) rather than what callers can DO with the object (setCartesian,
          getFuelPercentage)? If yes → MAJOR.
       3. Does the interface enforce access policy where needed — e.g. coordinates
          that must be set together as an atomic operation? Public fields cannot
          enforce this. If the class requires coordinated writes but exposes
          individual setters → MAJOR.
evidence-required: yes
```

### OD-002
Choose the right structure for the expected direction of change. Not everything
is an object.

```
enforcement: agent
check: For every new class or data structure introduced in the diff, cite file:line.
       Determine whether it is primarily a data structure (exposes data, no behaviour)
       or an object (hides data, exposes behaviour), then check the fit:
       1. If the system frequently needs new operations on a fixed set of types
          → data structures + procedural functions is the better fit.
          Using objects here makes adding new functions hard (every class must change).
       2. If the system frequently needs new types with a fixed set of operations
          → objects are the better fit.
          Using data structures here makes adding new types hard (every function
          must handle the new case).
       If the chosen approach clearly does not match the expected direction of change
       for this part of the system → MAJOR.
evidence-required: yes
```

### OD-003
Law of Demeter — talk to friends, not strangers.

```
enforcement: agent
check: For every method in the diff, cite file:line. Does it call methods on
       objects other than:
       (a) the object it belongs to
       (b) objects it creates
       (c) objects passed as arguments
       (d) objects it holds as fields
       Calling methods on objects returned by other calls is a violation.

       Important distinction: this rule applies only to real objects (hiding
       behaviour). Data structures are meant to expose their internals — chaining
       through pure data structures is not a violation. Getters on data structures
       create false ambiguity; prefer direct field access on data structures.

       Wrong fix: collapsing the chain into one method that encodes all the
       intermediate names — this moves structural knowledge without removing it.
       Right fix: tell the object what you need; it returns the answer directly.
       If a method reaches through returned objects to get what it needs → MAJOR.
evidence-required: yes
```

### OD-004
No hybrid classes — a class must be either an object or a data structure, not both.

```
enforcement: agent
check: For every class introduced or modified in the diff, cite file:line.
       Does it both expose data through getters/setters AND contain behaviour
       methods that do real work (calculations, business logic, decisions)?
       A hybrid is the worst of both worlds: it makes adding new functions hard
       (like a bad OO design) AND adding new types hard (like bad procedural design).

       Specific case — Active Records and DTOs: these are data structures.
       Their only permitted methods are navigational (save, delete, find) that
       map directly to persistence. Business logic must live in a separate object.
       If an Active Record or DTO contains business logic (discount calculations,
       validation rules, pricing logic) → MAJOR.

       Rule: objects hide data and expose behaviour.
             Data structures expose data and have no behaviour.
             Commit to one. If a class tries to do both → MAJOR.
evidence-required: yes
```
