# willey-lab/skills

Agent skills for AI coding agents.

## Install

```bash
# Install all skills
npx skills add willey-lab/skills

# Install one skill
npx skills add willey-lab/skills --skill anti-sycophancy
npx skills add willey-lab/skills --skill coding-standards
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

**Post-install:** Enable enforcement hooks with:
```bash
bash .claude/skills/coding-standards/scripts/install-hooks.sh
```

## License

MIT
