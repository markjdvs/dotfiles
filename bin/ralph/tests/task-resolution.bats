#!/usr/bin/env bats
# Task resolution: branch, paths, and names derived from a task worktree cwd.

setup() {
  RALPH_LIB="$BATS_TEST_DIRNAME/../lib/task.sh"
  export RALPH_HOME="$BATS_TEST_TMPDIR/ralph-home"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_SYSTEM=/dev/null

  source "$RALPH_LIB"
}

# Build a project repo with an origin remote whose default branch is $1.
make_project() {
  local default_branch=$1
  ORIGIN_DIR="$BATS_TEST_TMPDIR/origin.git"
  PROJECT_DIR="$BATS_TEST_TMPDIR/project"

  git init -q --bare --initial-branch="$default_branch" "$ORIGIN_DIR"
  git init -q --initial-branch="$default_branch" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  git config user.name test
  git config user.email test@example.com
  echo "hello" > README.md
  git add README.md
  git commit -qm "initial commit"
  git remote add origin "$ORIGIN_DIR"
  git push -qu origin "$default_branch" 2>/dev/null
  git remote set-head origin "$default_branch"
}

make_worktree() {
  local branch=$1
  WORKTREE_DIR="$PROJECT_DIR/.worktrees/$branch"
  git -C "$PROJECT_DIR" worktree add -q "$WORKTREE_DIR" -b "$branch"
  cd "$WORKTREE_DIR"
}

@test "task_branch derives the branch from a worktree cwd" {
  make_project main
  make_worktree feat/thing

  run task_branch
  [ "$status" -eq 0 ]
  [ "$output" = "feat/thing" ]
}

@test "task_branch fails on detached HEAD" {
  make_project main
  git checkout -q --detach

  run task_branch
  [ "$status" -ne 0 ]
  [[ "$output" == *"detached HEAD"* ]]
}

@test "task_project_dir resolves the main repo from inside a worktree" {
  make_project main
  make_worktree feat/thing

  run task_project_dir
  [ "$status" -eq 0 ]
  [ "$output" = "$(cd "$PROJECT_DIR" && pwd -P)" ]
}

@test "task_project_dir resolves the repo root when cwd is the main checkout" {
  make_project main

  run task_project_dir
  [ "$status" -eq 0 ]
  [ "$output" = "$(cd "$PROJECT_DIR" && pwd -P)" ]
}

@test "task resolution works from a subdirectory of the worktree" {
  make_project main
  make_worktree feat/thing
  mkdir -p src/deep
  cd src/deep

  run task_branch
  [ "$output" = "feat/thing" ]
  run task_project_dir
  [ "$output" = "$(cd "$PROJECT_DIR" && pwd -P)" ]
}

@test "sandbox name and workspace dir slug slashes to dashes" {
  make_project main
  make_worktree feat/PAC-123

  run task_sandbox_name
  [ "$output" = "async-feat-PAC-123" ]

  run task_workspace_dir
  [ "$output" = "$RALPH_HOME/workspaces/async-feat-PAC-123" ]

  run task_stop_file
  [ "$output" = "$RALPH_HOME/workspaces/async-feat-PAC-123.stop" ]
}

@test "task_default_branch reads origin/HEAD when set" {
  make_project main
  make_worktree feat/thing

  run task_default_branch
  [ "$status" -eq 0 ]
  [ "$output" = "main" ]
}

@test "task_default_branch detects master repos" {
  make_project master
  make_worktree feat/thing

  run task_default_branch
  [ "$status" -eq 0 ]
  [ "$output" = "master" ]
}

@test "task_default_branch falls back to origin/main without origin/HEAD" {
  make_project main
  git remote set-head origin -d
  make_worktree feat/thing

  run task_default_branch
  [ "$status" -eq 0 ]
  [ "$output" = "main" ]
}

@test "task_default_branch falls back to local main with no remote" {
  PROJECT_DIR="$BATS_TEST_TMPDIR/local-only"
  git init -q --initial-branch=main "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  git config user.name test
  git config user.email test@example.com
  git commit -q --allow-empty -m "initial"
  git checkout -qb feat/thing

  run task_default_branch
  [ "$status" -eq 0 ]
  [ "$output" = "main" ]
}

@test "task_unticked_phases counts phases with any unticked checkbox" {
  cat > "$BATS_TEST_TMPDIR/plan.md" <<'EOF'
# Plan: Fixture

## Phase 1: Done

### Acceptance criteria

- [x] first
- [x] second

## Phase 2: Partially done

- [x] first
- [ ] second

## Phase 3: Untouched

- [ ] first
- [ ] second
EOF

  run task_unticked_phases "$BATS_TEST_TMPDIR/plan.md"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "task_unticked_phases is zero for a fully ticked plan" {
  cat > "$BATS_TEST_TMPDIR/plan.md" <<'EOF'
## Phase 1: Done

- [x] first

## Phase 2: Also done

- [x] first
EOF

  run task_unticked_phases "$BATS_TEST_TMPDIR/plan.md"
  [ "$output" = "0" ]
}

@test "task_unticked_phases fails on a missing plan file" {
  run task_unticked_phases "$BATS_TEST_TMPDIR/nope.md"
  [ "$status" -ne 0 ]
}
