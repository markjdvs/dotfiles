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

## Code

- Do not write comments. Put the effort into naming: a variable, function or type name should carry the meaning a comment would have. The only exception is when a name would have to become excessively long to do that; then keep the name reasonable and comment only what is not intuitive from it.
