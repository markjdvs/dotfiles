# Global instructions

Applies to every project. Project instructions (`AGENTS.md`/`CLAUDE.md` in the repo) take precedence.

## Git

- Never add AI attribution to commits, PRs or MRs: no `Co-Authored-By: Claude` trailer, no "Generated with" footer. A hook blocks it in Claude Code.
- Commit or push only when asked.

## Packages

- JavaScript projects use pnpm (`pnpm install`, `pnpm add`, `pnpm exec`). Don't use npm or yarn in a project; `npx` is fine.
- Node comes from nvm, not Homebrew.

## Workflow

- Work happens in task dirs at `~/src/tasks/<branch>/`. A task dir is not a git repo; each project inside it is a worktree. `cd` into the project before running git, tests or a dev server.
- A repo's domain language lives in its root `CONTEXT.md`. Use its terms, avoid the ones it lists under _Avoid_, and add new terms there as they're settled.
- Working documents (plans, notes, HTML pages) are local files. Never publish them to a hosted service.

## Secrets

- Never put a token, password or key in plain text in a command, a script, a config file or a message. Shell history is recorded, so an inline secret persists the moment it runs.
- Read secrets at run time from somewhere that is not the command: at minimum a git-ignored `.env` file sourced into the environment, better the macOS Keychain (`security find-generic-password`) or the provider's secrets manager. Refer to them by variable name.
- A command that needs a secret the environment lacks stops and says which variable to set; it does not ask for the value in chat.

## Code

- Do not write comments. Put the effort into naming: a variable, function or type name should carry the meaning a comment would have. The only exception is when a name would have to become excessively long to do that; then keep the name reasonable and comment only what is not intuitive from it.
