---
name: distil
description: Distil the current tmux task session into task-local SNAPSHOT.md (working state to resume from) and FRICTION.md (operational issues hit + tooling ideas), so you can /clear back under the token ceiling without losing context. Use before running /clear in a task session.
---

# Distil

Capture the session's value into two task-local files so `/clear` can reset the
context window without losing what matters. Run this, then `/clear`; resume
later by reading the snapshot.

Task sessions only. Does **not** touch the memory system.

## 1. Locate the task dir

```
sn=$(tmux display-message -p '#{session_name}')
```

If `$sn` starts with `tasks/`, the task dir is `$HOME/src/tasks/${sn#tasks/}` —
the parent that holds the worktrees, alongside `CLAUDE.md`. If it does not, stop
and tell the user: distil only runs in a tmux task session.

## 2. Write SNAPSHOT.md — overwrite

Replace `<task-dir>/SNAPSHOT.md` with the current working state: only what a
fresh session needs to resume without the transcript. Be concise — this is a
token-saving artefact, not a log. Suggested shape:

```
# Snapshot — <branch> — <date>

## Working on
<the goal in a sentence or two>

## Decisions & approach
- <decision + one-line why>

## In flight / open threads
- <what's half-done, what's unresolved>

## Next steps
- [ ] <the very next actions>

## Key paths
- <files/dirs that matter, one word on each>
```

Omit empty sections. Prefer the fewest lines that let you pick up where you left
off.

## 3. Append to FRICTION.md

Append (never overwrite) a dated entry to `<task-dir>/FRICTION.md` capturing
operational or structural issues you hit this session and the tooling they
suggest — skills, commands, hooks, ways of working. These are seeds the human
harvests into real tooling later.

```
## <date> — <session focus>
- **Friction:** <what got in the way> → **Idea:** <tooling that would help>
```

Only real friction worth acting on. If nothing genuine came up, write nothing.

## 4. Report

Tell the user what was written (paths) and that it is safe to `/clear`. Remind
them the task dir's `CLAUDE.md` points at `SNAPSHOT.md`, so a fresh session
resumes on demand.

## Rules

- Task-local only: write inside the task dir, never into a worktree/repo (it
  would become committable litter) and never into the memory store.
- Snapshot is replaced each run; friction is appended.
- Signal over volume: capture what earns its tokens, skip the rest.
