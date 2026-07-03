---
name: hunk-review
description: Drive a live Hunk diff review session — read the user's inline review comments and fix the code they flag, navigate the diff, or narrate a changeset with agent comments. Use when the user mentions hunk, review comments, "address my comments", or asks to walk through changes in the review pane.
compatibility: Requires the hunk CLI (brew install hunk) and a live Hunk TUI session
---

# Hunk Review

Hunk ships its own authoritative skill with the CLI. Do not rely on memorised
commands — load the bundled version so instructions always match the installed
release:

1. Run `hunk skill path` to get the bundled SKILL.md path.
2. Read that file and follow it.

Workflow reminders for this setup:

- Task sessions run `hunk diff --watch` in the `review` pane of window 1, so
  the diff reloads as you edit files — no manual `session reload` needed for
  working-tree changes.
- Select the session with `--repo <worktree-path>` (use the current working
  directory's repo root).
- The user's inline notes are `hunk session comment list --repo . --type user`.
  Read them, fix what they flag, then reply with your own comments
  (`comment add` / `comment apply`) where a response is useful.
- You cannot create or edit user notes — only your own agent comments.
