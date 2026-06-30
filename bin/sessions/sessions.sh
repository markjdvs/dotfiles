#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIRS=(
  "$HOME/src/personal"
  "$HOME/src/work"
)

get_active_sessions() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null || true
}

get_project_dirs() {
  local parent project project_name
  for base_dir in "${PROJECT_DIRS[@]}"; do
    if [[ -d "$base_dir" ]]; then
      parent=$(basename "$base_dir")
      for project in "$base_dir"/*/; do
        if [[ -d "$project" ]]; then
          project_name=$(basename "$project")
          echo "$parent/$project_name"
        fi
      done
    fi
  done
}

resolve_project_path() {
  local selection="$1"
  local parent="${selection%%/*}"
  local project="${selection#*/}"

  for base_dir in "${PROJECT_DIRS[@]}"; do
    if [[ "$(basename "$base_dir")" == "$parent" ]]; then
      echo "$base_dir/$project"
      return
    fi
  done
}

create_session() {
  local session_name="$1"
  local project_path="$2"

  # Window indices instead of names — tmux misparses named targets
  # when session names contain /

  # Window 0: neovim (left) + claude (right)
  tmux new-session -d -s "$session_name" -c "$project_path" -n "editor"
  tmux send-keys -t "$session_name:0" "nvim ." Enter
  tmux split-window -h -t "$session_name:0" -c "$project_path"
  tmux send-keys -t "$session_name:0.1" "claude" Enter

  # Window 1: dev server (left) + logs (right)
  tmux new-window -t "$session_name" -n "dev" -c "$project_path"
  tmux split-window -h -t "$session_name:1" -c "$project_path"

  tmux select-window -t "$session_name:0"
  tmux select-pane -t "$session_name:0.0"
}

cmd_create_project() {
  local parent
  parent=$(gum choose --header "Select parent directory" "personal" "work")
  [[ -z "$parent" ]] && exit 0

  local base_dir
  case "$parent" in
    personal) base_dir="$HOME/src/personal" ;;
    work) base_dir="$HOME/src/work" ;;
    *) echo "Error: Invalid parent directory" >&2; exit 1 ;;
  esac

  mkdir -p "$base_dir"

  local project_name
  project_name=$(gum input --header "Project name" --placeholder "my-project")
  [[ -z "$project_name" ]] && exit 0

  local project_path="$base_dir/$project_name"
  if [[ -d "$project_path" ]]; then
    gum style --foreground 196 "Error: Directory already exists: $project_path"
    gum style "Use C-a p to open the existing project instead."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local git_url
  git_url=$(gum input --header "Git URL (leave empty for local init)" --placeholder "https://github.com/org/repo.git")

  if [[ -n "$git_url" ]]; then
    if ! git clone "$git_url" "$project_path"; then
      gum style --foreground 196 "Error: Failed to clone repository."
      read -r -n 1 -p "Press any key to exit..."
      exit 1
    fi
  else
    mkdir -p "$project_path"
    git -C "$project_path" init
  fi

  local session_name="$parent/$project_name"
  create_session "$session_name" "$project_path"
  tmux switch-client -t "$session_name"
}

cmd_create_task() {
  local project_selection
  project_selection=$(get_project_dirs | tv --input-header "Select project" --no-preview --no-remote)
  [[ -z "$project_selection" ]] && exit 0

  local project_path
  project_path=$(resolve_project_path "$project_selection")
  if [[ ! -d "$project_path" ]]; then
    echo "Error: Project path not found: $project_path" >&2
    exit 1
  fi

  if ! git -C "$project_path" fetch origin; then
    gum style --foreground 208 "Warning: Failed to fetch from origin. Continuing with local refs only."
  fi

  local branches
  branches=$(get_branch_list "$project_path")

  local branch_name
  branch_name=$(echo "$branches" | tv --input-header "Select or type branch" --no-preview --no-remote)

  if [[ -z "$branch_name" ]]; then
    branch_name=$(gum input --header "New branch name" --placeholder "feat/my-feature")
    [[ -z "$branch_name" ]] && exit 0
  fi

  local worktree_path="$project_path/.worktrees/$branch_name"
  local session_name="$project_selection/$branch_name"

  local current_branch
  current_branch=$(git -C "$project_path" branch --show-current 2>/dev/null || true)
  if [[ "$current_branch" == "$branch_name" ]]; then
    gum style --foreground 196 "Error: Branch '$branch_name' is already checked out in the main working tree."
    gum style "Switch to the project session or use a different branch."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  if [[ -d "$worktree_path" ]]; then
    gum style --foreground 196 "Error: Worktree already exists at: $worktree_path"
    gum style "Use C-a t to switch to the existing task."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  mkdir -p "$(dirname "$worktree_path")"

  local branch_exists_local branch_exists_remote
  branch_exists_local=$(git -C "$project_path" branch --list "$branch_name" | grep -c . || true)
  branch_exists_remote=$(git -C "$project_path" branch -r --list "origin/$branch_name" | grep -c . || true)

  if [[ "$branch_exists_local" -gt 0 ]]; then
    git -C "$project_path" worktree add "$worktree_path" "$branch_name"
  elif [[ "$branch_exists_remote" -gt 0 ]]; then
    git -C "$project_path" worktree add "$worktree_path" -b "$branch_name" "origin/$branch_name"
  else
    local default_branch="main"
    if ! git -C "$project_path" fetch origin main:main 2>/dev/null; then
      git -C "$project_path" fetch origin master:master 2>/dev/null || true
      default_branch="master"
    fi
    git -C "$project_path" worktree add "$worktree_path" -b "$branch_name" "$default_branch"
  fi

  create_session "$session_name" "$worktree_path"
  tmux switch-client -t "$session_name"
}

get_branch_list() {
  local project_path="$1"

  {
    git -C "$project_path" branch --list --format='%(refname:short)' 2>/dev/null

    git -C "$project_path" branch -r --list --format='%(refname:short)' 2>/dev/null | \
      grep '^origin/' | sed 's|^origin/||' | grep -v '^HEAD$'
  } | sort -u
}

cmd_finish_task() {
  local session_name
  session_name=$(tmux display-message -p '#{session_name}')

  local slash_count
  slash_count=$(echo "$session_name" | tr -cd '/' | wc -c)
  if [[ "$slash_count" -lt 2 ]]; then
    gum style --foreground 196 "Error: Not a task session."
    gum style "finish-task can only be run from a task session (parent/project/branch)."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local parent project branch_name
  parent="${session_name%%/*}"
  local rest="${session_name#*/}"
  project="${rest%%/*}"
  branch_name="${rest#*/}"

  local project_path=""
  for base_dir in "${PROJECT_DIRS[@]}"; do
    if [[ "$(basename "$base_dir")" == "$parent" ]]; then
      project_path="$base_dir/$project"
      break
    fi
  done

  if [[ -z "$project_path" || ! -d "$project_path" ]]; then
    gum style --foreground 196 "Error: Could not resolve project path for: $session_name"
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local worktree_path="$project_path/.worktrees/$branch_name"

  if [[ ! -d "$worktree_path" ]]; then
    gum style --foreground 196 "Error: Worktree not found: $worktree_path"
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  if ! git -C "$worktree_path" diff --quiet 2>/dev/null || \
     ! git -C "$worktree_path" diff --cached --quiet 2>/dev/null; then
    gum style --foreground 196 "Error: Uncommitted changes detected in worktree."
    gum style "Commit or stash your changes before finishing the task."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local untracked_count
  untracked_count=$(git -C "$worktree_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$untracked_count" -gt 0 ]]; then
    gum style --foreground 208 "Warning: $untracked_count untracked file(s) in worktree."
    if ! gum confirm "Continue anyway?"; then
      exit 0
    fi
  fi

  local do_push=false
  if gum confirm "Push branch '$branch_name' to remote before cleanup?"; then
    do_push=true
  fi

  gum style --bold --foreground 196 "⚠️  DESTRUCTIVE ACTION"
  gum style ""
  gum style "This will:"
  if [[ "$do_push" == true ]]; then
    gum style "  • Push branch '$branch_name' to remote"
  fi
  gum style "  • Kill session '$session_name'"
  gum style "  • Remove worktree at: $worktree_path"
  gum style "  • Delete local branch '$branch_name'"
  gum style ""
  gum style --foreground 208 "Type the full session name to confirm:"
  gum style --faint "$session_name"
  gum style ""

  local confirmation
  confirmation=$(gum input --placeholder "Type session name to confirm")

  if [[ "$confirmation" != "$session_name" ]]; then
    gum style --foreground 208 "Confirmation did not match. Aborting."
    read -r -n 1 -p "Press any key to exit..."
    exit 0
  fi

  if [[ "$do_push" == true ]]; then
    gum style "Pushing branch to remote..."
    if ! git -C "$worktree_path" push origin "$branch_name" 2>&1; then
      gum style --foreground 208 "Warning: Failed to push branch. Continuing with cleanup..."
    fi
  fi

  tmux switch-client -l 2>/dev/null || true
  tmux kill-session -t "$session_name" 2>/dev/null || true

  gum style "Removing worktree..."
  git -C "$project_path" worktree remove "$worktree_path" --force 2>/dev/null || true

  gum style "Deleting local branch..."
  git -C "$project_path" branch -D "$branch_name" 2>/dev/null || true

  gum style --foreground 76 "✓ Task finished successfully."
}

get_active_task_sessions() {
  local sessions
  sessions=$(get_active_sessions)

  if [[ -n "$sessions" ]]; then
    while IFS= read -r session; do
      local slash_count
      slash_count=$(echo "$session" | tr -cd '/' | wc -c)
      # Task sessions have 2+ slashes (parent/project/branch)
      if [[ "$slash_count" -ge 2 ]]; then
        echo "$session"
      fi
    done <<< "$sessions"
  fi
}

get_orphaned_worktrees() {
  local active_task_sessions
  active_task_sessions=$(get_active_task_sessions)

  for base_dir in "${PROJECT_DIRS[@]}"; do
    if [[ ! -d "$base_dir" ]]; then
      continue
    fi
    local parent
    parent=$(basename "$base_dir")

    for project_dir in "$base_dir"/*/; do
      if [[ ! -d "$project_dir" ]]; then
        continue
      fi
      local project_name
      project_name=$(basename "$project_dir")
      local worktrees_dir="$project_dir.worktrees"

      if [[ ! -d "$worktrees_dir" ]]; then
        continue
      fi

      # Worktrees can be nested (e.g. .worktrees/feat/PAC-123/)
      while IFS= read -r worktree_path; do
        if [[ ! -e "$worktree_path/.git" ]]; then
          continue
        fi

        local branch_name
        branch_name="${worktree_path#"$worktrees_dir/"}"

        local session_name="$parent/$project_name/$branch_name"

        if echo "$active_task_sessions" | grep -qxF "$session_name"; then
          continue
        fi

        echo "$session_name"
      done < <(find "$worktrees_dir" -type d -name ".git" 2>/dev/null | while read -r git_file; do dirname "$git_file"; done)
    done
  done
}

build_task_candidates() {
  {
    get_active_task_sessions
    get_orphaned_worktrees
  } | sort -u
}

resolve_task_worktree_path() {
  local session_name="$1"

  local parent project branch_name
  parent="${session_name%%/*}"
  local rest="${session_name#*/}"
  project="${rest%%/*}"
  branch_name="${rest#*/}"

  for base_dir in "${PROJECT_DIRS[@]}"; do
    if [[ "$(basename "$base_dir")" == "$parent" ]]; then
      echo "$base_dir/$project/.worktrees/$branch_name"
      return
    fi
  done
}

cmd_list_tasks() {
  local candidates
  candidates=$(build_task_candidates)

  if [[ -z "$candidates" ]]; then
    gum style --foreground 208 "No active tasks or orphaned worktrees found."
    read -r -n 1 -p "Press any key to exit..."
    exit 0
  fi

  local selection
  selection=$(echo "$candidates" | tv --input-header "Tasks" --no-preview --no-remote)
  [[ -z "$selection" ]] && exit 0

  if tmux has-session -t "$selection" 2>/dev/null; then
    tmux switch-client -t "$selection"
  else
    # Orphaned worktree — recreate session at existing worktree path
    local worktree_path
    worktree_path=$(resolve_task_worktree_path "$selection")

    if [[ -d "$worktree_path" ]]; then
      create_session "$selection" "$worktree_path"
      tmux switch-client -t "$selection"
    else
      gum style --foreground 196 "Error: Worktree path not found: $worktree_path"
      read -r -n 1 -p "Press any key to exit..."
      exit 1
    fi
  fi
}

build_project_candidates() {
  local active_sessions
  active_sessions=$(get_active_sessions)

  if [[ -n "$active_sessions" ]]; then
    while IFS= read -r session; do
      local slash_count
      slash_count=$(echo "$session" | tr -cd '/' | wc -c)
      if [[ "$slash_count" -eq 1 ]]; then
        echo "$session"
      fi
    done <<< "$active_sessions"
  fi

  while IFS= read -r project; do
    if ! echo "$active_sessions" | grep -qxF "$project"; then
      echo "$project"
    fi
  done < <(get_project_dirs)
}

cmd_list_projects() {
  local selection project_path
  selection=$(build_project_candidates | sort -u | tv --input-header "Sessions" --no-preview --no-remote)
  [[ -z "$selection" ]] && exit 0

  if tmux has-session -t "$selection" 2>/dev/null; then
    tmux switch-client -t "$selection"
  else
    project_path=$(resolve_project_path "$selection")
    if [[ -d "$project_path" ]]; then
      create_session "$selection" "$project_path"
      tmux switch-client -t "$selection"
    else
      echo "Error: Project path not found: $project_path" >&2
      exit 1
    fi
  fi
}

usage() {
  cat <<EOF
Usage: sessions <subcommand>

Subcommands:
  list-projects   List and switch between project sessions (C-a p)
  create-project  Create a new project by cloning or initializing (C-a P)
  list-tasks      List and switch between task sessions (C-a t)
  create-task     Create a new task with worktree and session (C-a T)
  finish-task     Clean up current task: optionally push, remove worktree, kill session (C-a X)

EOF
  exit 1
}

main() {
  local subcommand="${1:-}"

  case "$subcommand" in
    list-projects)
      cmd_list_projects
      ;;
    create-project)
      cmd_create_project
      ;;
    list-tasks)
      cmd_list_tasks
      ;;
    create-task)
      cmd_create_task
      ;;
    finish-task)
      cmd_finish_task
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
