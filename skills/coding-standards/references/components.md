# Components

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for UI component structure, organisation, and library usage. Apply to all UI stacks
(React / Next.js, Vue, Svelte, Angular, React Native, etc.).

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### CS-001
Entry-point files (pages, routes, screens, views) must only compose existing components —
they must not define new UI components inline. Every reusable UI unit belongs in its own
dedicated file under the project's component folder.

```
enforcement: agent
check: For every entry-point file touched in the diff (pages/, routes/, screens/,
       views/, or the framework-equivalent), cite file:line.
       1. Does the file define any new component, widget, or JSX/template function
          inline, rather than importing it from a component file? If yes → MAJOR.
       2. Does a reusable UI element exist only as an unnamed or ad-hoc construct
          inside the entry-point, rather than extracted into its own file? → MAJOR.
       Entry-point files are composition roots. They assemble; they do not define.
evidence-required: yes
```

### CS-002
Components must be grouped into domain or feature subfolders that reflect their
responsibility. Flat-dumping all components into a single root folder is forbidden.

```
enforcement: agent
check: For every new component file introduced in the diff, cite file:line.
       1. Is the file placed directly in the components root with no domain or feature
          subfolder? (e.g. components/StatusBadge.tsx instead of
          components/invoices/InvoiceStatusBadge.tsx) → MAJOR.
       2. Does the subfolder name describe a meaningful domain or feature boundary,
          or is it a vague technical category (e.g. components/misc/, components/common/
          with no further grouping)? If it is a catch-all with no real domain meaning → MINOR.
evidence-required: yes
```

### CS-003
Component names must include their domain or feature qualifier. A name that could belong
to any feature without change of meaning is too generic and is forbidden.

```
enforcement: agent
check: For every component name introduced or changed in the diff, cite file:line.
       1. Could this name exist unchanged in a completely different feature module and
          still make sense? (e.g. TypePill, Selector, StatusBadge, Card, Modal)
          If yes → MAJOR. The name must carry its domain: BuyerTypePill, ClientSelector,
          InvoiceStatusBadge, ProductCard, ConfirmDeleteModal.
       2. Does the name use a generic suffix (Item, Widget, Component, Element, Block)
          with no domain qualifier? → MAJOR.
       The test: if you removed this component's folder and kept only its name,
       could a new developer still place it in the right domain? If not → MAJOR.
evidence-required: yes
```

### CS-004
Always check the project's designated component library before implementing any UI
primitive or utility element. Use the library's component if one exists. Only write a
custom implementation when the library genuinely has no equivalent.

```
enforcement: agent
check: For every UI primitive or interactive element introduced in the diff, cite file:line.
       1. Does the project have a designated component library (e.g. Shadcn/UI,
          Material UI, Ant Design, Headless UI, PrimeVue, or similar)?
          If yes: does the newly written component duplicate something the library
          already provides? If yes → MAJOR.
       2. Is a raw HTML element used (button, input, select, dialog, etc.) when the
          project's component library has a typed, accessible equivalent?
          If yes → MAJOR.
       3. If the library equivalent does not yet exist in the codebase but the library
          offers it, was it installed via the library's official install command before
          writing a custom version? If a custom version was written instead → MAJOR.
       Library-first is non-negotiable. It keeps the UI consistent and accessible.
evidence-required: yes
```

### CS-005
Every component must have exactly one responsibility. A component that simultaneously
fetches data, manages complex form state, and renders a complex layout must be
decomposed into focused, single-purpose components.

```
enforcement: agent
check: For every component touched in the diff, cite file:line.
       1. Can you describe what the component does using the word "and"?
          (fetches data AND renders a table AND manages pagination) → MAJOR.
       2. Does the component contain more than one of: network/data fetching logic,
          complex local state management, and non-trivial render output? → MAJOR.
       3. Could you extract a meaningful sub-component with a name that is NOT
          a restatement of what the code already does? If yes → MAJOR.
       Rule: if you can split it, you must split it.
evidence-required: yes
```

### CS-006
The domain-subfolder pattern required for `components/` applies equally to every other
technical-layer folder: `hooks/`, `utils/`, `types/`, `services/`, and equivalents.
Domain-specific files must not be placed flat at the root of these folders.

```
enforcement: agent
check: For every new file introduced in the diff inside hooks/, utils/, types/,
       services/, or a similar technical-layer folder, cite file:line.
       1. Is the file placed directly at the root of its technical-layer folder with
          no domain subfolder, and does it clearly belong to one domain?
          (e.g. hooks/use[Domain]List.ts instead of hooks/[domain]/use[Domain]List.ts)
          If yes → MAJOR.
       2. Exception: files that are genuinely shared across multiple domains may live
          at the technical-layer root — utilities with no domain-specific logic
          (e.g. a generic date formatter, a debounce hook) that any feature could
          consume unchanged.
          The test: could this file be moved into any single domain folder without
          breaking other domains? If yes, it belongs in a domain subfolder.
       The rule: the same domain structure visible in components/ must be reflected
       in every other technical-layer folder.
evidence-required: yes
```

### CS-007
Hooks, utilities, types, and services that belong to one domain must include that domain's
qualifier in their name — the same requirement CS-003 places on component names.

```
enforcement: agent
check: For every hook, utility function, type, and service introduced in the diff,
       cite file:line.
       1. Could the name exist unchanged in a completely different domain and still
          make sense? Names like useList, Schema, ApiService, formatAmount are
          violations when they belong to a specific domain — the domain qualifier
          is required: use[Domain]List, [Domain]Schema, [Domain]ApiService,
          format[Domain]Amount.
          If the name carries no domain signal → MAJOR.
       2. Exception: genuinely shared cross-domain utilities may use generic names —
          only when they contain zero domain-specific logic and could be consumed
          by any feature unchanged.
evidence-required: yes
```

### CS-008
Components must be presentational. Business logic — data fetching, mutations, non-trivial
derivations, side effects, and complex state machines — must live in hooks or services,
not in the component body. The component renders; hooks and services own the logic that
produces what is rendered.

```
enforcement: agent
applicability: Apply to component-based UI stacks (React, Next.js, Vue, Svelte,
       Angular, React Native) and their component file patterns (*.tsx, *.jsx, *.vue,
       *.svelte, *.component.ts). The rule's examples reference React idioms (useMemo,
       useEffect, server actions, hooks) but the principle — components render, logic
       lives elsewhere — applies to any component model with an equivalent separation
       layer (composables in Vue, services in Angular, etc.). Do not apply to backend
       code, CLI scripts, or non-component utility modules.
check: For every component touched in the diff, cite file:line.
       1. Does the component body contain inline data fetching (fetch, axios, query
          client calls, ORM/SDK calls such as supabase/prisma, etc.) rather than
          consuming a hook or server-component boundary that owns the fetch? → MAJOR.
       2. Does the component body contain inline mutation logic (POST/PUT/DELETE
          calls, optimistic updates, cache invalidation) rather than delegating to
          a hook, server action, or service? → MAJOR.
       3. Does the component perform non-trivial derivations inline in render
          (multi-step transformations, sorting/filtering chains, aggregations,
          formatting that encodes business rules) rather than in a `useMemo` /
          extracted hook / pure helper? → MAJOR.
       4. Does the component contain complex state machines or multi-step effects
          (chained useEffects coordinating async flows, refs orchestrating
          imperative sequences) rather than encapsulating them in a custom hook? → MAJOR.
       5. Trivial mappings for display (e.g. `items.map(i => <Row …/>)`, a single
          ternary on a prop, a className join, a 1-line label transform) are NOT
          business logic and are allowed in the component body.
       Test: if you removed the component file, would the remaining hooks/services
       still describe what the feature does? If the answer is no — because the
       logic only existed in the component — the component is doing too much.
evidence-required: yes
```

### CS-SCOPE
Only audit code written by the project team. Third-party, generated, or vendor-scaffolded
files are out of scope regardless of where they live in the repository.

```
enforcement: agent
applicability: Apply this rule first, before any other Section A or Section B rule.
       It is a gating filter — files it excludes are not subject to any other rule.
check: For every file in the diff, determine its origin.
       Indicators that a file is out of scope:
       1. A comment header crediting an external source or tool.
       2. A path under a known vendor or library folder
          (e.g. src/components/ui/, vendor/, node_modules/, generated/).
       3. Code that exactly matches a well-known library's scaffolded output.
       If the file is third-party: exclude it from all findings and note the exclusion.
       If origin is uncertain: skip the file and note that it was excluded from review.
       Never flag a violation in a file the project team did not write.
evidence-required: no
```
