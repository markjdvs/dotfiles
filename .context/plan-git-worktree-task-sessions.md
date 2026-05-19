# Plan: Git Worktree Task Sessions

> Source PRD: `.context/prd-git-worktree-task-sessions.md`

## Architectural decisions

Durable decisions that apply across all phases:

- **Script structure**: Single script `sessions.sh` with subcommand dispatch (`list-projects`, `create-project`, `list-tasks`, `create-task`, `finish-task`). Installed via existing symlink pattern to `~/.local/bin/sessions`.
- **Session naming**: Project sessions use `<parent>/<project>` (e.g. `work/calton`). Task sessions use `<parent>/<project>/<branch-name>` (e.g. `work/calton/feat/PAC-123`). Task sessions are distinguished from project sessions by having 3+ `/`-separated segments.
- **Worktree layout**: Worktrees are stored at `<project-root>/.worktrees/<branch-name>/`. Branch names with `/` create nested directories. `.worktrees/` is created on demand with `mkdir -p`.
- **Keybinding taxonomy**: Lowercase = list/open existing, uppercase = create new/destroy. `p`/`P` for projects, `t`/`T` for tasks, `X` for destructive cleanup. `C-a f` is removed. `C-a L` (last session toggle) is unchanged.
- **Tool usage**: Television (`tv`) for all list-based selection. Gum (`gum`) for all free-text input and destructive confirmation prompts. Both run inside tmux popups at 100% width/height.
- **Session template**: Shared `create_session` function for both project and task sessions. Two windows: editor (nvim + claude) and dev (two shell panes). Any change to the template affects all session types.
- **Project directories**: `~/src/personal/` and `~/src/work/` as parent directories, matching current behaviour.

---

## Phase 1: Subcommand dispatch + keybinding rename

**User stories**: 1, 20

### What to build

Refactor `sessions.sh` from direct `main()` execution to subcommand dispatch. The current behaviour becomes the `list-projects` subcommand. Rename the tmux keybinding from `C-a f` to `C-a p`, passing `list-projects` as the subcommand argument. Add `gum` to the Brewfile so it is available for subsequent phases.

### Acceptance criteria

- [x] `sessions list-projects` produces the same behaviour as the current `sessions` (fuzzy pick from active sessions + project directories, switch or create)
- [x] `sessions` with no subcommand prints usage and exits non-zero
- [x] `C-a p` opens the session picker in a popup (replacing `C-a f`)
- [x] `C-a f` is removed from `.tmux.conf`
- [x] `gum` is present in the Brewfile

---

## Phase 2: Create project (`C-a P`)

**User stories**: 2, 3, 18, 19

### What to build

Add a `create-project` subcommand that walks the user through creating a new project without leaving tmux. The flow uses gum for all free-text input (parent directory selection, project name, optional git URL) and television for any list-based selection, establishing the tool-usage pattern for all subsequent phases. If a git URL is provided, clone the repo into the selected parent directory. If no URL is provided, create the directory and run `git init`. Then create a session using the shared template and switch to it. Refuse if the target directory already exists. Wire up `C-a P` to run this subcommand in a tmux popup.

### Acceptance criteria

- [x] `C-a P` opens a gum-driven flow in a popup
- [x] User can pick a parent directory (work/personal), type a project name, and optionally provide a git URL
- [x] Providing a URL clones the repo into `~/src/<parent>/<name>/`
- [x] Omitting the URL creates `~/src/<parent>/<name>/` with `git init`
- [x] A session is created with the standard two-window template and switched to
- [x] If `~/src/<parent>/<name>/` already exists, the flow refuses with an error message
- [x] Television is used for list-based picking, gum is used for free-text input

---

## Phase 3: Create task (`C-a T`)

**User stories**: 5, 6, 7, 8, 9, 10, 11

### What to build

Add a `create-task` subcommand that creates a git worktree, branch, and tmux session in one step. The flow has two stages: first, pick a project via television; second, pick an existing branch or type a new branch name. The subcommand runs `git fetch origin` to ensure remote refs are current. For a new branch, it updates `main` from `origin/main` and creates the worktree with `-b <branch> main`. For an existing remote-only branch, it creates the worktree with `-b <branch> origin/<branch>`. For an existing local branch, it creates the worktree without `-b`. The worktree is placed at `<project-root>/.worktrees/<branch-name>/`. A session is created using the shared template at the worktree path, named `<parent>/<project>/<branch-name>`, and switched to. Wire up `C-a T` to run this in a popup.

### Acceptance criteria

- [x] `C-a T` opens a two-step picker in a popup
- [x] First step shows all project directories via television
- [x] Second step shows deduplicated local and remote branches via television
- [x] Typing a name that doesn't match an existing branch falls through to gum for new branch name input
- [x] New branches are created from an up-to-date `main`
- [x] Existing remote-only branches are checked out correctly as local tracking branches
- [x] Existing local branches are attached to worktrees without `-b`
- [x] Worktree is created at `<project-root>/.worktrees/<branch-name>/`
- [x] Task session is named `<parent>/<project>/<branch-name>`
- [x] Session uses the standard two-window template
- [x] If the branch is already checked out in the main working tree, the flow refuses with an error

---

## Phase 4: List/switch tasks (`C-a t`)

**User stories**: 4, 16, 17

### What to build

Add a `list-tasks` subcommand that presents a unified list of all active task sessions and orphaned worktrees across all projects. Active task sessions are identified by session names with 3+ `/`-separated segments. Orphaned worktrees are `.worktrees/` subdirectories that have no matching tmux session. Empty `.worktrees/` directories are excluded. Selecting an active session switches to it. Selecting an orphaned worktree creates a new session at the existing worktree path (without re-creating the worktree) and switches to it. Wire up `C-a t` to run this in a popup.

### Acceptance criteria

- [x] `C-a t` opens a task picker in a popup via television
- [x] Active task sessions appear as candidates
- [x] Orphaned worktrees (worktree on disk, no matching session) appear as candidates
- [x] Empty `.worktrees/` directories do not appear
- [x] Selecting an active session switches to it
- [x] Selecting an orphaned worktree creates a session at the existing worktree path and switches to it
- [x] Projects with no tasks and no worktrees produce no entries

---

## Phase 5: Finish task (`C-a X`)

**User stories**: 12, 13, 14, 15

### What to build

Add a `finish-task` subcommand that tears down the current task in a single action. The flow captures the current session name, parses out the project path and branch name, and checks for uncommitted changes in the worktree — refusing if dirty. It then displays the task session name and prompts the user to type it to confirm via gum. On confirmation, it pushes the branch to the remote, switches to the last session, kills the task session, removes the worktree, and deletes the local branch. The remote branch is never deleted. Wire up `C-a X` to run this in a popup.

### Acceptance criteria

- [x] `C-a X` opens the finish-task flow in a popup
- [x] If the worktree has uncommitted changes, the flow refuses and warns
- [x] The user must type the full task session name to confirm
- [x] Mistyped confirmation aborts the flow
- [x] The branch is pushed to remote before cleanup
- [x] The task session is killed
- [x] The worktree is removed
- [x] The local branch is deleted
- [x] The remote branch is never deleted
- [x] After cleanup, the client is switched to the last session (or tmux handles session selection naturally if no other session exists)
