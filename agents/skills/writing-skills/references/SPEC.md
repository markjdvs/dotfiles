# Agent Skill Spec — Format and Packaging

The file format a skill must satisfy, condensed from the Agent Skills specification (agentskills.io/specification). This is the disclosed reference for [`writing-skills`](../SKILL.md) — consult it when creating a skill's files or checking one for conformance.

## Directory structure

A skill is a directory containing, at minimum, a `SKILL.md`:

```
skill-name/
├── SKILL.md          # Required: frontmatter + instructions
├── scripts/          # Optional: executable code the agent can run
├── references/       # Optional: documentation loaded on demand
└── assets/           # Optional: templates, images, data files
```

## Frontmatter

`SKILL.md` opens with YAML frontmatter:

| Field           | Required | Constraints                                                                                     |
| --------------- | -------- | ----------------------------------------------------------------------------------------------- |
| `name`          | Yes      | 1–64 chars; lowercase `a-z`, `0-9`, hyphens; no leading/trailing/consecutive hyphens; **must match the directory name** |
| `description`   | Yes      | 1–1024 chars; what the skill does **and** when to use it, with the trigger keywords you actually use |
| `license`       | No       | License name, or the name of a bundled license file                                              |
| `compatibility` | No       | ≤500 chars; environment requirements only (intended product, system packages, network access) — most skills omit it |
| `metadata`      | No       | String→string map for properties outside the spec                                               |
| `allowed-tools` | No       | Space-separated pre-approved tools, e.g. `Bash(git:*) Read` (experimental)                       |

The body after the frontmatter has no format restrictions.

## Progressive disclosure

Agents load a skill in three levels, each only when needed:

1. **Metadata** (~100 tokens) — `name` + `description`, preloaded at startup for every skill. This is the only part that is always in the context window.
2. **Instructions** (<5000 tokens recommended) — the `SKILL.md` body, loaded when the skill activates. Keep it under 500 lines.
3. **Resources** (as needed) — files in `references/`, `scripts/`, `assets/`, read only when a pointer in the body fires.

Structure a skill for this: the description carries invocation, the body carries what every run needs, and everything else moves down a level.

## File references

Link other files by relative path from the skill root (`references/GLOSSARY.md`), and keep pointers **one level deep** from `SKILL.md` — a disclosed file that points onward to further disclosed files makes the chain unreliable.

## Placement

Global skills live in the dotfiles repo at `~/src/personal/dotfiles/agents/skills/<skill-name>/`, symlinked into `~/.claude/skills/` by `agents/install.sh`. Never create a skill directly in `~/.claude/skills/` — it would exist only on this machine and outside version control. A pattern that only applies to one project belongs in that project's instructions file, not a skill.

## Validation

```bash
skills-ref validate ./my-skill
```

(from the `skills-ref` reference library, github.com/agentskills/agentskills) — checks frontmatter validity and naming conventions.
