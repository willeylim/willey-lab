# willey-lab/skills

Agent skills for AI coding agents.

## Install

One-liner (installs the skill **and** enables enforcement hooks in the same command):

```bash
npx skills add willey-lab/skills --skill coding-standards && \
  bash "$(ls -1 .claude/skills/coding-standards/scripts/install-hooks.sh \
              .factory/skills/coding-standards/scripts/install-hooks.sh \
              skills/coding-standards/scripts/install-hooks.sh 2>/dev/null | head -n1)"
```

If you only want the skill files (hooks will auto-install on the agent's next code task):

```bash
npx skills add willey-lab/skills --skill coding-standards
```

Install all skills in this repo:

```bash
npx skills add willey-lab/skills
```

### Project vs. user (global) install

Both installers support two scopes and **auto-detect** which one you want:

| Scope | Where hooks are configured | Applies to | Hook command points at |
|---|---|---|---|
| **project** (default) | `<project>/.claude/settings.json` (+ a per-project copy of the scripts) | that one project | `${CLAUDE_PROJECT_DIR}/.claude/hooks/…` |
| **user / global** | `~/.claude/settings.json` | **every** project you open | the skill's scripts in place (absolute path) |

- Inside an agent session (`CLAUDE_PROJECT_DIR` is set), it installs **project** scope — so a globally-installed skill still enforces on whatever project you're working in.
- Run from a plain shell against a skill that lives under `~/.claude/skills/`, it installs **user** scope automatically.
- Force it either way: `install-hooks.sh --user` (global) or `install-hooks.sh --project`.

```bash
# Enforce in every project from one global install:
bash ~/.claude/skills/coding-standards/scripts/install-hooks.sh --user
bash ~/.claude/skills/anti-sycophancy/scripts/install-hooks.sh --user
```

Git pre-commit hooks are always per-repository — run `install-hooks.sh --git` inside each repo.

## Skills

### anti-sycophancy
Epistemic integrity framework. Counters agreement bias, capitulation under pressure, false validation, and unwarranted praise. Ships two optional hooks:

- **`UserPromptSubmit`** — scans the incoming prompt for sycophancy-risk patterns and injects targeted integrity reminders before the model responds (advisory; never blocks).
- **`Stop`** — evaluates the finished response and, if multiple sycophancy patterns are detected, forces a revision before the turn can end.

These hooks are heuristic nudges, not guarantees — the framework in `SKILL.md` is the substance; the hooks reinforce it.

**Post-install:** Enable the hooks with:
```bash
bash .claude/skills/anti-sycophancy/scripts/install-hooks.sh
```

### coding-standards
Mandatory coding standards covering functions, naming, components, TypeScript, error handling, formatting, SOLID/KISS/DRY, objects/data, and UI/UX. 75+ rules across 9 domains, all inlined in SKILL.md for immediate agent consumption. Reference files provide detailed check procedures and edge cases.

Enforcement hooks auto-detect your tools and wire in the checker. The enforcement
model differs by tool:

- **Claude Code / Factory Droid** — a `PreToolUse` hook runs *before* each write
  and **blocks** the edit (exit 2) if it violates a hard-enforced rule.
- **Git** — a `pre-commit` hook checks staged files and **blocks the commit** on a
  violation.
- **Aider** — registered as a `lint-cmd` with `auto-lint`, so it runs *after* an
  edit; Aider reads the non-zero result and tries to **auto-fix and re-lint**. It
  does not block the write up front.

The hook hard-blocks only the rules a script can detect with high precision
(TS-001 no `any`, TS-002 explicit return types, NM-006 no Hungarian notation).
Every other rule is applied by the agent during write/review — a shell script
cannot reliably judge function length, magic numbers, or naming scope without a
real parser, and a hook that blocks idiomatic code is worse than no hook.

If you use the one-liner above, hooks are active immediately. Otherwise they
install on the agent's first code task.

Installer flags (optional): scope — `--user`/`--global`, `--project`/`--local`; tools — `--all`, `--claude`, `--droid`, `--aider`, `--git`.

## License

MIT
