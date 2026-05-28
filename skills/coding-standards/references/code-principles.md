# Code Principles

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

SOLID, KISS, and DRY. Apply to all stacks and languages.

Note: FN-002 (functions do one thing) and CS-005 (components do one thing) enforce SRP
at function and component level. DP-001 extends that coverage to classes, modules, and
services. FN-011 enforces DRY at function level. DP-007 extends DRY to all artifacts.

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### DP-001 — Single Responsibility Principle
Every class, module, and service has exactly one reason to change. When a unit serves
two different actors or owns two different concerns, it must be split.

```
enforcement: agent
applicability: Apply only to units with meaningful size and responsibility — classes,
       services, and modules. Do not apply to simple data-holder structs, single-function
       files, or trivial utilities that have no real scope for responsibility creep.
check: For every class, module, or service touched in the diff, cite file:line.
       First ask: is this unit large or complex enough that SRP is meaningful here?
       If it is a trivial wrapper, a single-method helper, or a pure data struct → skip.
       1. Can you identify more than one distinct reason this unit would need to change?
          (e.g. a service that handles both business logic and persistence, a module
          that owns both authentication and email delivery) → MAJOR.
       2. Does the unit import from two or more unrelated domains, suggesting it
          is serving multiple masters? → MAJOR.
       Note: FN-002 covers functions; CS-005 covers components.
       This rule targets classes, modules, and services not covered by those rules.
evidence-required: yes
```

### DP-002 — Open/Closed Principle
Existing, working code should not need to be modified to add new behaviour.
Extend by adding new code — not by editing existing code that already works.

```
enforcement: agent
applicability: Apply only when there is a clear, recurring pattern of variation —
       multiple types, variants, or cases that are likely to keep growing. Do not apply
       to code that handles a fixed, stable set of cases with no realistic expectation
       of extension. Forcing OCP onto simple, stable code produces needless abstraction.
check: For every change in the diff that adds new behaviour, cite file:line.
       First ask: is there a real, demonstrated pattern of variation here — not just
       a hypothetical future one? If the variation is a one-off or the set of cases
       is known and fixed → skip.
       1. Was an existing, working function, class, or module modified to accommodate
          a new type, case, or variant — and is this part of a growing pattern where
          OCP would have prevented repeated modifications? → MAJOR.
       2. Is there a switch/if-else chain that has already been extended multiple times,
          where a polymorphic or strategy-based extension would eliminate future
          modifications entirely? → MAJOR.
       The test: did adding this feature require touching code that was already correct
       and passing its tests, AND is this a pattern likely to repeat? If yes → MAJOR.
evidence-required: yes
```

### DP-003 — Liskov Substitution Principle
A subtype must honour the full contract of the type it extends. Any caller that works
with the parent must work identically with the child — no surprises, no broken promises.

```
enforcement: agent
applicability: Apply only when actual inheritance, subclassing, or interface
       implementation is present in the diff. If the code has no type hierarchy —
       no extends, implements, or structural subtyping — skip this rule entirely.
check: For every subclass, interface implementation, or type extension in the diff,
       cite file:line.
       1. Does the subtype throw exceptions the parent does not? → MAJOR.
       2. Does the subtype weaken preconditions or strengthen postconditions beyond
          what the parent contract allows? → MAJOR.
       3. Does the subtype override a method in a way that changes observable behaviour
          for callers that only know about the parent type? → MAJOR.
       4. Does the subtype refuse to implement part of the parent interface by throwing
          "not implemented" or returning a no-op? → MAJOR.
evidence-required: yes
```

### DP-004 — Interface Segregation Principle
No code should be forced to depend on methods it does not use. Prefer many small,
focused interfaces over one large general-purpose one.

```
enforcement: agent
applicability: Apply only when an interface or abstract contract has multiple methods
       and multiple distinct consumers. A single-method interface, a single-consumer
       interface, or a simple type alias has no surface area to segregate — skip.
check: For every interface, abstract class, or type contract introduced or changed
       in the diff, cite file:line.
       First ask: does this interface have enough methods and enough distinct consumers
       for segregation to be meaningful? If not → skip.
       1. Does any implementor leave methods unimplemented, throw "not supported",
          or return stub values for methods it does not need? → MAJOR.
          This is a signal the interface is too broad.
       2. Does the interface serve more than one distinct client role — meaning
          different consumers only ever use a subset of its methods? → MAJOR.
          Split it into role-specific interfaces each consumer depends on fully.
       3. Does a consumer import an interface just to use one or two of its methods,
          ignoring the rest? → MINOR. Consider a narrower interface.
evidence-required: yes
```

### DP-005 — Dependency Inversion Principle
High-level modules depend on abstractions, not on concrete implementations.
Low-level modules implement those abstractions. Neither depends on the other directly.

```
enforcement: agent
applicability: Apply only when a high-level module depends on an infrastructure or
       third-party concern (database, HTTP client, file system, external SDK, message
       queue). Do not apply to simple utility imports, same-layer dependencies, or
       small scripts where introducing an abstraction layer would add complexity with
       no testability or flexibility benefit.
check: For every dependency on an infrastructure or external concern introduced in
       the diff, cite file:line.
       First ask: is this dependency on a volatile, infrastructure, or third-party
       concern that could change independently of business logic? If it is a stable
       same-layer import (e.g. a utility, a type, a constant) → skip.
       1. Does a high-level module (business logic, use-case, orchestration) directly
          import or instantiate a low-level module (database driver, HTTP client,
          file system, third-party SDK)? → MAJOR.
          High-level code must depend on an interface or abstraction, not a concrete.
       2. Is a concrete class instantiated inside business logic rather than injected
          through an abstraction? → MAJOR.
       3. If test files are in scope: does a unit test have to mock a concrete
          class (not an interface) because the dependency was not inverted? → MINOR
          (evidence of a DIP violation in production code). If no test files are in
          scope, skip this sub-check — do not infer a test's shape from production
          code alone.
evidence-required: yes
```

### DP-006 — KISS
Choose the simplest design that satisfies the current, stated requirements.
Complexity must be justified by a real and present need, not an anticipated future one.

```
enforcement: agent
check: For every design decision in the diff, cite file:line.
       1. Does the implementation introduce abstraction layers, base classes, factories,
          registries, or configuration that the current requirements do not need?
          If added "for future flexibility" with no concrete use case today → MAJOR.
       2. Could the same behaviour be achieved with a simpler construct?
          (a plain function instead of a class, a direct call instead of an event bus,
          an inline condition instead of a strategy pattern) → MAJOR if the simpler
          form is equally readable and maintainable.
       3. Does the code require a reader to understand more than one layer of
          indirection to trace what actually happens? → MINOR if the indirection
          adds no real value.
       Rule: if removing the complexity would not break anything real, it should not exist.
evidence-required: yes
```

### DP-007 — DRY
Every piece of knowledge has a single, authoritative representation in the codebase.
Duplication of logic, structure, or configuration is forbidden regardless of artifact type.

```
enforcement: agent
check: Scan the entire diff for knowledge that appears more than once, cite file:line
       for each duplicate pair.
       1. Is the same business rule, validation condition, or transformation expressed
          in more than one place — even if the code looks slightly different? → MAJOR.
       2. Is the same type shape, interface, or schema defined in more than one file
          rather than shared from a single source? → MAJOR.
       3. Is the same configuration value hardcoded in more than one place rather
          than defined once and referenced everywhere? → MAJOR.
       4. Is the same component structure or layout pattern copy-pasted across
          multiple components rather than extracted into a shared component? → MAJOR.
       Note: FN-011 covers function-level duplication. This rule covers all other
       artifacts — types, configs, components, validation rules, and styles.
evidence-required: yes
```
