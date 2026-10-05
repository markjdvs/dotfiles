# dotfiles

Lives at `~/src/personal/dotfiles` on every machine. That path is load-bearing: installed agent context links back to it.

## Setup

```bash
cd ~/src/personal/dotfiles
./init.sh
git config core.hooksPath .git-hooks   # re-run init.sh after every pull
```

`init.sh` installs the `Brewfile`. For each top-level directory, it runs that directory's `install.sh` if it has one, or stows it into `$HOME` if it contains dotfiles. Finally it links and syncs agent context (below).

## Agent context

Skills, subagents and global instructions are written once in `agents/` and linked into every harness by [skillshare](https://github.com/runkids/skillshare). The links point into this repo, so edits are live everywhere without re-installing. The terms used here (skill, subagent, harness, vendored, third-party, trial) are defined in `CONTEXT.md`.

```
agents/
  AGENTS.md          global instructions
  skills/<name>/     skills: own, vendored and third-party
  subagents/         subagent definitions (none yet)
skillshare/.config/skillshare/config.yaml   (stowed to ~/.config/skillshare)
```

| Harness | Skills | Subagents | Instructions |
|---|---|---|---|
| Claude Code | `~/.claude/skills` (a link to `~/.agents/skills`) | `~/.claude/agents` | `~/.claude/CLAUDE.md` |
| Codex | `~/.agents/skills` | not yet: needs a TOML extension | `~/.codex/AGENTS.md` |
| Cursor | reads `~/.agents/skills` | reads `~/.claude/agents` | no global file: paste `AGENTS.md` into Settings → Rules → User Rules |

`init.sh` creates the `~/.claude/skills` link. skillshare can't link one target dir to another, and linking skills into both dirs would make Cursor, which reads both, list everything twice.

After adding, renaming or removing anything in `agents/`, run `skillshare sync --all`. The post-merge hook does this after a pull. `sync` links new items and prunes ones that were renamed or deleted.

### skillshare rules

- `skillshare` saves rewrite `config.yaml` and drop comments, so document things here, not in the config.
- Keep the nested target form (`targets.<name>.skills.path`). The flat form triggers a migration that replaces the stowed link with a real file.
- Don't use `skillshare plugin`; its saves also break the stowed link.

## Skills

### Naming

- **Invoked** (you trigger it by name): verb-first, e.g. `write-prd`, `review-in-hunk`.
- **Transform** (turns one artefact into another): `<input>-to-<output>`, e.g. `prd-to-plan`, `plan-to-tickets`.
- **Reference** (the agent loads it when relevant): named for its subject, e.g. `styling`.

Renaming a skill means renaming its directory and the `name:` in its frontmatter, then updating references: `bin/ralph/`, `CONTEXT.md`, other skills.

### Where skills come from

| Kind | How it gets here | In git |
|---|---|---|
| Own / vendored | written here, or copied in and adapted | yes |
| Third-party | `skillshare install <owner>/<repo>/<path-to-skill>` | yes. Recorded in `agents/skills/.metadata.json`, pinned to a commit. |
| Trial | `npx skills add <repo> -g -a claude-code codex -s <name>` | no. Lives in `~/.agents/skills` on that machine only. |

- **Never edit a third-party skill.** `skillshare update` silently overwrites local edits. To change one, delete its entry from `.metadata.json`; it's then vendored and yours.
- **Update third-party skills:** `skillshare check`, then `skillshare update <name>` (or `--all`), then review the diff and commit.
- **Before a trial, check the name isn't already one of yours.** A trial with the same name silently replaces yours at runtime, and `npx skills update -g` can do it again later.
- **Which trials are installed:** `skillshare diff` shows them as "Local only", or "Local override" if one is shadowing a skill of yours.
- **Discard a trial:** `npx skills remove <name> -g -y`, then `skillshare sync` if it was shadowing one of yours.
- **Keep a trial:** for third-party, `npx skills remove <name> -g -y`, then `skillshare install …` and commit. For vendored, run `skillshare collect codex`, then `npx skills remove <name> -g -y`, then `skillshare sync`, then adapt and commit.

### Subagents and model tiers

Write subagents in Claude Code's format in `agents/subagents/`. Set `model:` with a Claude family name (`haiku`, `sonnet`, `opus`) as the tier: how much capability the subagent needs. Claude Code reads it as-is. Before the first subagent goes to Codex, add a skillshare agent extension that converts it to TOML and maps the tier to a Codex model and reasoning effort.

## Claude Code: opt-in only

`claude/.claude/settings.json` keeps out skills you didn't choose:

- `disableBundledSkills`: removes the skills and workflows that ship with Claude Code. Built-in commands like `/init` can still be typed.
- `enableArtifact: false` and `disableWorkflows: true`.
