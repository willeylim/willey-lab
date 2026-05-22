# UI/UX

> Detailed check procedures and examples for rules summarized in SKILL.md.
> Consult this file for edge cases and verification procedures.

Rules for visual design quality and user experience. Apply to all UI stacks.

Two layers:
- UI-001–006: Technical rules derived from impeccable (pbakaus/impeccable)
- UI-007–015: Classic visual design principles — Balance, Contrast, Emphasis, Movement,
  Hierarchy, Repetition, Proportion, White Space, Unity

---

## Section B — Agent-Judgment Rules

Semantic checks. You must apply these when writing or reviewing code.
Every finding must cite `file:line`.

### UI-001 — Color & Contrast
Color choices must meet accessibility minimums and avoid visual anti-patterns.

```
enforcement: agent
check: For every color value introduced in the diff, cite file:line.
       1. Does any text element fail WCAG AA contrast — below 4.5:1 against its
          background, including placeholder text? → MAJOR.
       2. Is pure black (#000000) or pure white (#ffffff) used? Tint neutrals toward
          the brand hue instead. → MINOR.
       3. Is gray text placed on a colored background? Gray loses contrast and
          vibrancy against color — use a tinted neutral or white instead. → MAJOR.
       4. Is the AI color palette present — purple gradients, cyan-on-dark-black,
          or neon glow effects — with no intentional brand reason? → MAJOR.
evidence-required: yes
```

### UI-002 — Typography
Type must be readable, hierarchical, and scaled consistently.

```
enforcement: agent
check: For every typography value introduced in the diff, cite file:line.
       1. Is body line-height below 1.5? → MAJOR.
       2. Does any body text container exceed 75ch width? Long lines hurt readability.
          → MINOR.
       3. Is the font size hierarchy less than a 1.25× ratio between adjacent steps?
          Flat type hierarchies make everything feel the same weight. → MINOR.
       4. Is body font size below 14px? → MAJOR.
       5. Is ALL-CAPS used for body text (not labels or headings)? → MINOR.
       6. Is letter-spacing on body text above 0.05em? → MINOR.
       7. Are heading sizes hardcoded instead of using clamp() for responsiveness?
          → MINOR.
       8. Does the UI use only a single font family with no display/body pairing?
          → MINOR.
evidence-required: yes
```

### UI-003 — Spacing & Layout
Spacing must follow a consistent scale. Layout must avoid structural anti-patterns.

```
enforcement: agent
check: For every spacing value introduced in the diff, cite file:line.
       1. Is an arbitrary spacing value used that falls outside the project's defined
          spacing scale? → MINOR.
       2. Are cards nested inside other cards? → MAJOR.
       3. Are related elements spaced with more than 24px, disconnecting things that
          belong together? → MINOR.
       4. Are section breaks below 40px, making distinct content sections feel merged?
          → MINOR.
evidence-required: yes
```

### UI-004 — Motion & Animation
Animation must be purposeful, performant, and respect user preferences.

```
enforcement: agent
check: For every animation or transition introduced in the diff, cite file:line.
       1. Does the animation target layout properties — width, height, top, left,
          margin, padding? Only transform and opacity are safe to animate. → MAJOR.
       2. Is duration below 100ms (imperceptible) or above 500ms (sluggish)? → MINOR.
       3. Does the easing use bounce or elastic curves (cubic-bezier control points
          above 1.0)? → MAJOR.
       4. Is ease-in-out used instead of ease-out? Ease-out feels more responsive.
          → MINOR.
       5. Is there no @media (prefers-reduced-motion) fallback for non-trivial
          animations? → MAJOR.
evidence-required: yes
```

### UI-005 — Interaction & Accessibility
Interactive elements must be reachable, operable, and clearly labelled.

```
enforcement: agent
check: For every interactive element introduced in the diff, cite file:line.
       1. Is any touch target below 44×44px? → MAJOR.
       2. Is outline: none or outline: 0 applied without a :focus-visible replacement?
          Removing focus indicators breaks keyboard navigation. → MAJOR.
       3. Are heading levels skipped — e.g. h1 followed by h3 with no h2? → MAJOR.
       4. Does any button or CTA use a generic label — OK, Submit, Yes, No, Click here?
          Labels must describe the action. → MAJOR.
       5. Are form inputs missing associated labels (relying on placeholder only)?
          → MAJOR.
evidence-required: yes
```

### UI-006 — Visual Anti-Patterns
Patterns that consistently produce low-quality or inaccessible UI are forbidden.

```
enforcement: agent
check: For every component or style introduced in the diff, cite file:line.
       1. Is gradient text used (background-clip: text with a gradient)? → MAJOR.
       2. Is the icon-tile-stack pattern used — a rounded icon centered above a
          heading with centered text below? → MINOR.
       3. Is body or paragraph text center-aligned outside of a hero or CTA context?
          → MINOR.
       4. Do cards have a thick accent border on one side (>1px)? → MINOR.
       5. Are dark glow or box-shadow glow effects used decoratively? → MINOR.
evidence-required: yes
```

### UI-007 — Hierarchy
Visual weight must match content importance. The most important element must be
the most visually prominent — in size, color, contrast, or position.

```
enforcement: agent
check: For every screen, page, or section introduced in the diff, cite file:line.
       1. Is there more than one element competing for primary visual attention —
          multiple elements at the same visual weight with no clear dominant one?
          → MAJOR.
       2. Does the primary action or most important content appear below the fold
          while secondary content is above it? → MAJOR.
       3. Do heading sizes visually reflect their level — or does a lower-level heading
          appear larger or heavier than a higher-level one? → MAJOR.
       4. Are secondary elements (helper text, metadata, labels) styled at the same
          visual weight as primary content? → MINOR.
evidence-required: yes
```

### UI-008 — Emphasis
Every screen or section must have exactly one focal point. When everything is
emphasized, nothing is.

```
enforcement: agent
check: For every screen or distinct section introduced in the diff, cite file:line.
       1. Are multiple elements competing for primary attention with equal visual
          prominence — multiple bold CTAs, multiple high-contrast blocks, multiple
          large headings at the same weight? → MAJOR.
       2. Is the primary CTA the most visually prominent interactive element on the
          screen — or is it styled the same as secondary actions? → MAJOR.
       3. Is emphasis achieved only by making everything large or bold, rather than
          through contrast with restrained surrounding elements? → MINOR.
evidence-required: yes
```

### UI-009 — Contrast
Visual contrast must create clear separation between element types — interactive vs
static, primary vs secondary, active vs inactive.

```
enforcement: agent
check: For every set of related elements introduced in the diff, cite file:line.
       Note: color contrast (WCAG) is covered by UI-001. This rule covers visual
       differentiation between element roles and states.
       1. Do interactive elements (buttons, links, inputs) look visually distinct
          from non-interactive elements? → MAJOR.
       2. Are active, selected, or current states clearly distinct from their default
          state — not just a subtle color shift? → MAJOR.
       3. Are primary and secondary actions styled so differently that the hierarchy
          is immediately clear without reading the labels? → MINOR if not.
evidence-required: yes
```

### UI-010 — Balance
Visual weight must be distributed intentionally. Layouts must not feel accidentally
lopsided or chaotic.

```
enforcement: agent
check: For every layout or composition introduced in the diff, cite file:line.
       1. Is visual weight — large elements, strong colors, high-contrast areas —
          heavily clustered on one side or corner with nothing to counterbalance it,
          and no intentional design reason for this? → MINOR.
       2. Is one element so visually dominant that all surrounding content feels
          insignificant or overlooked? → MINOR.
       3. In asymmetric layouts, is the imbalance clearly intentional (a deliberate
          design choice) or does it feel accidental and unstable? → MINOR if accidental.
evidence-required: yes
```

### UI-011 — Proportion & Scale
Element size must reflect its role in the hierarchy. Size communicates importance.

```
enforcement: agent
check: For every set of related elements introduced in the diff, cite file:line.
       1. Are secondary or tertiary elements (sub-labels, metadata, helper text)
          sized close to or larger than primary content? → MINOR.
       2. Are decorative elements (icons, dividers, borders) proportionally oversized
          relative to the content they support? → MINOR.
       3. Within a component family (e.g. buttons, cards, badges), are size variants
          consistent with a clear proportional scale — or are sizes arbitrary? → MINOR.
evidence-required: yes
```

### UI-012 — White Space & Negative Space
Empty space is a design element. It groups, separates, and gives elements room to
be understood. Cluttered layouts with no breathing room are a violation.

```
enforcement: agent
check: For every layout or component introduced in the diff, cite file:line.
       1. Are elements packed edge-to-edge with no padding or margin, making the
          layout feel dense and claustrophobic — without this being intentional
          (e.g. a data table)? → MAJOR.
       2. Is negative space used consistently to group related elements and separate
          unrelated ones — or does spacing appear random with no visual logic? → MINOR.
       3. Are section breaks generous enough to signal a new topic — or do distinct
          content areas blend together with insufficient separation? → MINOR.
evidence-required: yes
```

### UI-013 — Repetition & Pattern
The same UI pattern must be implemented the same way everywhere. Inconsistent
implementations of the same pattern are a violation.

```
enforcement: agent
check: For every component or pattern introduced in the diff, cite file:line.
       1. Does the diff introduce a second implementation of a pattern that already
          exists in the codebase — a list item, a status badge, a form field,
          a modal — styled or structured differently from the first? → MAJOR.
       2. Is the same interaction (e.g. delete confirmation, inline edit, expand/collapse)
          handled differently in this component than in other parts of the UI? → MAJOR.
       3. Are visual patterns established in one section (card style, header style,
          button grouping) not carried through to equivalent sections? → MINOR.
evidence-required: yes
```

### UI-014 — Movement & Visual Flow
Layout must guide the eye toward the main action. The reading path must be clear.

```
enforcement: agent
check: For every screen or major section introduced in the diff, cite file:line.
       1. Is there a clear reading path — does the layout lead the eye naturally
          from entry point to primary action? Or does the layout leave the user
          uncertain where to look first? → MINOR.
       2. Does visual flow contradict the content's logical order — e.g. the
          conclusion appears before the context, or the CTA appears before the
          value proposition? → MAJOR.
       3. Do competing focal points (UI-008) break the flow by pulling the eye in
          multiple directions simultaneously? → MINOR.
evidence-required: yes
```

### UI-015 — Unity & Harmony
All elements must feel like they belong to the same design. One-off styles,
orphaned decisions, and inconsistent design language are violations.

```
enforcement: agent
check: For every component or style introduced in the diff, cite file:line.
       1. Does any element use a color, font, radius, shadow, or spacing value that
          does not exist elsewhere in the design system — with no justification?
          → MAJOR.
       2. Does any component look visually disconnected from the surrounding UI —
          as if it came from a different product or design system? → MAJOR.
       3. Are border-radius values, shadow styles, or color choices consistent with
          the patterns established by the rest of the codebase? → MINOR if not.
evidence-required: yes
```
