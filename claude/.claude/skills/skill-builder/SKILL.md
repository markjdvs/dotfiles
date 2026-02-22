---
name: skill-builder
description: Create a new reusable Claude skill and place it in the correct location in the dotfiles repository.
allowed-tools: Read, Write, Bash
---

Skills are reusable implementation patterns — not project-specific context. They describe *how* to do something (an approach, a tool setup, a convention), not *what* a project does.

## Location

All skills live at:
```
~/src/personal/dotfiles/claude/.claude/skills/<skill-name>/
```

These are symlinked to `~/.claude/` via GNU stow, so they are available globally across all projects.

**Never** place skills inside a project directory or `~/.claude/` directly.

## Structure

Each skill requires a `SKILL.md`. A `REFERENCE.md` is optional but recommended when the skill has code examples or multi-section detail.

```
~/.claude/skills/<skill-name>/
  SKILL.md        # required — frontmatter + instructions
  REFERENCE.md    # optional — detailed reference sections
```

## SKILL.md format

```markdown
---
name: <skill-name>
description: <one-line description shown in skill picker>
allowed-tools: Read, Edit, Write, Bash   # list only what the skill needs
---

<Instructions for Claude. Be specific about what to do and what to avoid.>

See REFERENCE.md#<section> for examples.
```

## REFERENCE.md format

Use `## section-name` headings as anchors. Include concrete code examples.

```markdown
# <Skill Name> Reference

## section-one
...

## section-two
...
```

## Scope rules

- Scope to a *functional pattern* (e.g. "how to set up path aliases in Vite")
- Do NOT include project-specific domain knowledge (e.g. game rules, data schemas)
- If a pattern only applies to one project, it belongs in that project's CLAUDE.md instead
