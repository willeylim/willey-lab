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

## Skills

### anti-sycophancy
Epistemic integrity framework. Prevents agreement bias, capitulation under pressure, false validation, and unwarranted praise. Includes enforcement hooks that scan prompts for sycophancy risk and block sycophantic responses.

**Post-install:** Enable enforcement hooks with:
```bash
bash .claude/skills/anti-sycophancy/scripts/install-hooks.sh
```

### coding-standards
Mandatory coding standards covering functions, naming, components, TypeScript, error handling, formatting, SOLID/KISS/DRY, objects/data, and UI/UX. 75+ rules across 9 domains, all inlined in SKILL.md for immediate agent consumption. Reference files provide detailed check procedures and edge cases.

Enforcement hooks auto-detect your tools (Claude Code, Factory Droid, Aider, git) and block writes that violate any rule. If you use the one-liner above, hooks are active immediately. Otherwise they install on the agent's first code task.

Installer flags (optional): `--all`, `--claude`, `--droid`, `--aider`, `--git`.

## License

MIT
