---
name: ha-ios-skill-maintenance
description: How these AI agent skills are structured and kept up to date. Use when adding, editing, splitting, or reorganizing skills under .agents/skills, or updating the AGENTS.md router.
---

# Skill Maintenance

AI agent instructions for this repo live as modular skills under `.agents/skills/`, with a compact router in `AGENTS.md`. This keeps startup context small: an agent loads only the skill relevant to the task instead of one large always-loaded file.

## Layout

- `AGENTS.md` (repo root) is the router. It carries a short project intro and a table that maps each skill to when it should be loaded.
- Each skill is a directory `.agents/skills/<skill-name>/SKILL.md`.
- `.claude/skills` symlinks to `../.agents/skills` so Claude Code discovers the skills. Editor-specific instruction files (`CLAUDE.md`, `.cursorrules`, `.windsurfrules`, `.github/copilot-instructions.md`) remain symlinks to `AGENTS.md`.

## SKILL.md format

Each file starts with YAML frontmatter:

```
---
name: ha-ios-<topic>
description: <what the skill covers>. Use when <the concrete triggers that should route an agent here>.
---
```

- `name` must match the directory name.
- `description` is the routing trigger. Write it as "what it covers. Use when …" and name concrete actions/APIs an agent would be doing, so the right skill loads without being told which one.

## When you change guidance

- Put each topic's content in exactly one skill; cross-reference other skills by name rather than duplicating.
- When adding a new skill, create its directory and `SKILL.md`, then add a row to the routing table in `AGENTS.md`.
- Keep skills small and single-purpose. If a skill grows to cover several unrelated topics, split it.
