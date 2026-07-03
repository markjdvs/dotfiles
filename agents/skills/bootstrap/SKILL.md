---
name: bootstrap
description: Make the current working copy runnable — dependencies installed, toolchain present, env stubbed — idempotently. Use at the start of every ralph iteration, on a fresh clone or worktree, or when the user asks to bootstrap or set up the environment.
---

# Bootstrap

Make the working copy runnable: after this skill, the project's tests can
execute. Idempotent by design — the first run may be slow, every later run
should cost seconds and report nothing to do.

## Process

### 1. Prefer a project-provided entrypoint

Environment knowledge belongs to the project when it has recorded it. Check,
in order, and use the FIRST match instead of discovery:

- A documented setup command in `CLAUDE.md`, `CONTRIBUTING.md`, or the
  README's setup/getting-started section
- A conventional setup script: `./script/setup`, `./script/bootstrap`,
  `./scripts/setup.sh`, `./bin/setup`
- A setup task in the task runner: `make setup`, `make bootstrap`,
  `just setup`, `mise run setup`

Run it and skip to step 3.

### 2. Discover from the repo

No entrypoint — derive the environment from what the repo declares:

**Dependencies** — pick the package manager from the lockfile, never from
habit, and prefer the frozen/CI-safe variant:

| Present | Run |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `package-lock.json` | `npm ci` |
| `yarn.lock` | `yarn install --immutable` |
| `bun.lockb` / `bun.lock` | `bun install --frozen-lockfile` |
| `uv.lock` | `uv sync` |
| `poetry.lock` | `poetry install` |
| `requirements.txt` | `pip install -r requirements.txt` (in a venv) |
| `go.mod` | `go mod download` |
| `Cargo.lock` | `cargo fetch` |
| `Gemfile.lock` | `bundle install` |

In a monorepo, install once at the root. Respect the `packageManager` field
in `package.json` (use corepack) over any global default.

**Toolchain** — if a version file (`.nvmrc`, `.node-version`,
`.tool-versions`, `mise.toml`, `.python-version`) demands a runtime that is
missing, install it through the version manager the file belongs to; if that
is impossible, report the gap instead of silently using the wrong version.

**Env stubs** — if `.env.example` (or `.env.template`) exists and `.env`
does not, copy it. NEVER overwrite an existing `.env`.

### 3. Prove it

Run the cheapest command that shows the environment works — typically listing
or dry-running the test suite (e.g. `pnpm test -- --list` or equivalent). If
it fails, fix the environment, not the code.

### 4. Report

State exactly what was done (or "nothing to do"): entrypoint used or tools
detected, commands run, gaps that need a human.

## Rules

- Idempotent: re-running must be safe and cheap. Frozen installs and
  copy-if-missing achieve this — no `rm -rf node_modules`, no cache purges.
- Environment only: never modify source code, migrations, or data.
- Works anywhere: the same steps serve a sandboxed agent workspace and a
  human's fresh clone.
