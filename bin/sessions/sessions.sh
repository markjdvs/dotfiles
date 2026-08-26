#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIRS=(
  "$HOME/src/personal"
  "$HOME/src/work"
)

TASKS_DIR="$HOME/src/tasks"

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

  local size_args=() client_width client_height
  client_width=$(tmux display-message -p '#{client_width}' 2>/dev/null || true)
  client_height=$(tmux display-message -p '#{client_height}' 2>/dev/null || true)
  if [[ -n "$client_width" && -n "$client_height" ]]; then
    size_args=(-x "$client_width" -y "$client_height")
  fi

  tmux new-session -d -s "$session_name" -c "$project_path" -n "editor" "${size_args[@]}"
  tmux send-keys -t "$session_name:0" "nvim ." Enter
  tmux split-window -h -l 25% -t "$session_name:0" -c "$project_path"
  tmux send-keys -t "$session_name:0.1" "claude" Enter
  tmux select-pane -t "$session_name:0.0" -T "editor"
  tmux select-pane -t "$session_name:0.1" -T "agent"

  tmux new-window -t "$session_name" -n "dev" -c "$project_path"
  tmux split-window -h -t "$session_name:1" -c "$project_path"
  tmux split-window -h -t "$session_name:1" -c "$project_path"
  tmux select-layout -t "$session_name:1" even-horizontal
  tmux select-pane -t "$session_name:1.0" -T "run"
  tmux select-pane -t "$session_name:1.1" -T "test"
  tmux select-pane -t "$session_name:1.2" -T "review"
  if git -C "$project_path" rev-parse --git-dir >/dev/null 2>&1; then
    tmux send-keys -t "$session_name:1.2" "hunk diff --watch" Enter
  fi

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
  *)
    echo "Error: Invalid parent directory" >&2
    exit 1
    ;;
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

add_worktree() {
  local project_path="$1"
  local worktree_path="$2"
  local branch_name="$3"

  local branch_exists_local branch_exists_remote
  branch_exists_local=$(git -C "$project_path" branch --list "$branch_name" | grep -c . || true)
  branch_exists_remote=$(git -C "$project_path" branch -r --list "origin/$branch_name" | grep -c . || true)

  if [[ "$branch_exists_local" -gt 0 ]]; then
    git -C "$project_path" worktree add "$worktree_path" "$branch_name"
  elif [[ "$branch_exists_remote" -gt 0 ]]; then
    git -C "$project_path" worktree add "$worktree_path" -b "$branch_name" "origin/$branch_name"
  else
    local default_branch
    default_branch=$(git -C "$project_path" branch --show-current 2>/dev/null || true)

    if [[ "$default_branch" == "main" || "$default_branch" == "master" ]]; then
      git -C "$project_path" pull --ff-only origin "$default_branch" 2>/dev/null || true
    else
      default_branch="main"
      if ! git -C "$project_path" fetch origin main:main 2>/dev/null; then
        git -C "$project_path" fetch origin master:master 2>/dev/null || true
        default_branch="master"
      fi
    fi

    git -C "$project_path" worktree add "$worktree_path" -b "$branch_name" "$default_branch"
  fi
}

cmd_create_task() {
  local raw_selection
  raw_selection=$(get_project_dirs | tv --input-header "Select projects (Tab to mark, Enter to confirm)" --no-preview --no-remote) || true
  [[ -z "$raw_selection" ]] && exit 0

  local -a selections=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && selections+=("$line")
  done <<<"$raw_selection"
  [[ "${#selections[@]}" -eq 0 ]] && exit 0

  local -a project_paths=() repo_names=()
  local sel path name existing
  for sel in "${selections[@]}"; do
    path=$(resolve_project_path "$sel")
    if [[ ! -d "$path" ]]; then
      gum style --foreground 196 "Error: Project path not found: $path"
      read -r -n 1 -p "Press any key to exit..."
      exit 1
    fi
    name=$(basename "$path")
    if [[ "${#repo_names[@]}" -gt 0 ]]; then
      for existing in "${repo_names[@]}"; do
        if [[ "$existing" == "$name" ]]; then
          gum style --foreground 196 "Error: Two selected repos are both named '$name'."
          gum style "Task dirs key on repo name, so this would collide. Pick only one."
          read -r -n 1 -p "Press any key to exit..."
          exit 1
        fi
      done
    fi
    project_paths+=("$path")
    repo_names+=("$name")
  done

  local i
  for i in "${!project_paths[@]}"; do
    if ! git -C "${project_paths[$i]}" fetch origin; then
      gum style --foreground 208 "Warning: Failed to fetch ${repo_names[$i]}. Continuing with local refs only."
    fi
  done

  local branches
  branches=$(for path in "${project_paths[@]}"; do get_branch_list "$path"; done | sort -u)

  local branch_name
  branch_name=$(echo "$branches" | tv --input-header "Select or type branch" --no-preview --no-remote)

  if [[ -z "$branch_name" ]]; then
    branch_name=$(gum input --header "New branch name" --placeholder "feat/my-feature")
    [[ -z "$branch_name" ]] && exit 0
  fi

  local task_dir="$TASKS_DIR/$branch_name"
  local session_name="tasks/$branch_name"

  if [[ -d "$task_dir" ]]; then
    gum style --foreground 196 "Error: Task already exists at: $task_dir"
    gum style "Use C-a t to switch to the existing task."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  for i in "${!project_paths[@]}"; do
    local current_branch
    current_branch=$(git -C "${project_paths[$i]}" branch --show-current 2>/dev/null || true)
    if [[ "$current_branch" == "$branch_name" ]]; then
      gum style --foreground 196 "Error: Branch '$branch_name' is already checked out in the main tree of ${repo_names[$i]}."
      gum style "Switch to that project session or use a different branch."
      read -r -n 1 -p "Press any key to exit..."
      exit 1
    fi
  done

  mkdir -p "$task_dir"

  local created=0
  for i in "${!project_paths[@]}"; do
    gum style "Adding worktree: ${repo_names[$i]}"
    if add_worktree "${project_paths[$i]}" "$task_dir/${repo_names[$i]}" "$branch_name"; then
      created=$((created + 1))
    else
      gum style --foreground 208 "Warning: Failed to add worktree for ${repo_names[$i]}. Skipping."
    fi
  done

  if [[ "$created" -eq 0 ]]; then
    gum style --foreground 196 "Error: No worktrees could be created."
    rmdir "$task_dir" 2>/dev/null || true
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  create_session "$session_name" "$task_dir"
  tmux switch-client -t "$session_name"
}

get_branch_list() {
  local project_path="$1"

  {
    git -C "$project_path" branch --list --format='%(refname:short)' 2>/dev/null

    git -C "$project_path" branch -r --list --format='%(refname:short)' 2>/dev/null |
      grep '^origin/' | sed 's|^origin/||' | grep -v '^HEAD$'
  } | sort -u
}

origin_project_for_worktree() {
  local worktree_path="$1" common
  common=$(git -C "$worktree_path" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$common" in
  /*) : ;;
  *) common="$worktree_path/$common" ;;
  esac
  dirname "$common"
}

term_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    term_tree "$child"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

graceful_teardown() {
  local session_name="$1" pane_pid
  while IFS= read -r pane_pid; do
    [[ -n "$pane_pid" ]] && term_tree "$pane_pid"
  done < <(tmux list-panes -s -t "$session_name" -F '#{pane_pid}' 2>/dev/null || true)
  sleep 2
}

cmd_finish_task() {
  local session_name
  session_name=$(tmux display-message -p '#{session_name}')

  if [[ "$session_name" != tasks/* ]]; then
    gum style --foreground 196 "Error: Not a task session."
    gum style "finish-task can only be run from a task session (tasks/<branch>)."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local branch_name="${session_name#tasks/}"
  local task_dir="$TASKS_DIR/$branch_name"

  if [[ ! -d "$task_dir" ]]; then
    gum style --foreground 196 "Error: Task dir not found: $task_dir"
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local -a worktrees=() origins=()
  local child origin
  for child in "$task_dir"/*/; do
    child="${child%/}"
    [[ -e "$child/.git" ]] || continue
    origin=$(origin_project_for_worktree "$child" || true)
    worktrees+=("$child")
    origins+=("$origin")
  done

  if [[ "${#worktrees[@]}" -eq 0 ]]; then
    gum style --foreground 196 "Error: No worktrees found under $task_dir."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local dirty=false
  for child in "${worktrees[@]}"; do
    if ! git -C "$child" diff --quiet 2>/dev/null ||
      ! git -C "$child" diff --cached --quiet 2>/dev/null; then
      gum style --foreground 196 "Uncommitted changes in $(basename "$child")."
      dirty=true
    fi
  done
  if [[ "$dirty" == true ]]; then
    gum style "Commit or stash your changes before finishing the task."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  local untracked_total=0 count
  for child in "${worktrees[@]}"; do
    count=$(git -C "$child" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    untracked_total=$((untracked_total + count))
  done
  if [[ "$untracked_total" -gt 0 ]]; then
    gum style --foreground 208 "Warning: $untracked_total untracked file(s) across worktrees."
    if ! gum confirm "Continue anyway?"; then
      exit 0
    fi
  fi

  local do_push=false
  if gum confirm "Push branch '$branch_name' to remote in all repos before cleanup?"; then
    do_push=true
  fi

  gum style --bold --foreground 196 "⚠️  DESTRUCTIVE ACTION"
  gum style ""
  gum style "This will:"
  if [[ "$do_push" == true ]]; then
    gum style "  • Push branch '$branch_name' in ${#worktrees[@]} repo(s)"
  fi
  gum style "  • Kill session '$session_name'"
  gum style "  • Remove ${#worktrees[@]} worktree(s) under: $task_dir"
  gum style "  • Delete local branch '$branch_name' in each repo:"
  for child in "${worktrees[@]}"; do
    gum style "      - $(basename "$child")"
  done
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
    for child in "${worktrees[@]}"; do
      gum style "Pushing $(basename "$child")..."
      if ! git -C "$child" push origin "$branch_name" 2>&1; then
        gum style --foreground 208 "Warning: Failed to push $(basename "$child"). Continuing..."
      fi
    done
  fi

  graceful_teardown "$session_name"
  tmux switch-client -l 2>/dev/null || true
  tmux kill-session -t "$session_name" 2>/dev/null || true

  local -a failed=()
  local i name remove_output
  for i in "${!worktrees[@]}"; do
    child="${worktrees[$i]}"
    origin="${origins[$i]}"
    name=$(basename "$child")

    if [[ -z "$origin" ]]; then
      gum style --foreground 208 "Warning: Could not resolve origin repo for $name. Removing files only."
      rm -rf "$child"
      [[ -e "$child" ]] && failed+=("$name")
      continue
    fi

    gum style "Removing worktree: $name"
    if ! remove_output=$(git -C "$origin" worktree remove "$child" --force 2>&1); then
      git -C "$origin" worktree prune 2>/dev/null || true
      remove_output=$(git -C "$origin" worktree remove "$child" --force 2>&1) || true
    fi

    if [[ -e "$child" ]]; then
      rm -rf "$child"
      git -C "$origin" worktree prune 2>/dev/null || true
    fi

    if [[ -e "$child" ]]; then
      gum style --foreground 196 "Error: Could not remove worktree $name."
      gum style --faint "$remove_output"
      failed+=("$name")
      continue
    fi

    if ! git -C "$origin" branch -D "$branch_name" 2>&1; then
      gum style --foreground 208 "Warning: Worktree $name removed, but branch could not be deleted in $(basename "$origin")."
    fi
  done

  if [[ "${#failed[@]}" -gt 0 ]]; then
    gum style --foreground 196 "Some worktrees could not be removed: ${failed[*]}"
    gum style "Resolve manually under $task_dir. Branch(es) left intact."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  rm -rf "$task_dir"
  local parent
  parent=$(dirname "$task_dir")
  while [[ "$parent" == "$TASKS_DIR"/* ]]; do
    rmdir "$parent" 2>/dev/null || break
    parent=$(dirname "$parent")
  done

  gum style --foreground 76 "✓ Task finished successfully."
}

get_active_task_sessions() {
  get_active_sessions | grep '^tasks/' || true
}

get_orphaned_worktrees() {
  [[ -d "$TASKS_DIR" ]] || return 0

  local active
  active=$(get_active_task_sessions)

  local base_dir project_dir wt branch session
  {
    for base_dir in "${PROJECT_DIRS[@]}"; do
      [[ -d "$base_dir" ]] || continue
      for project_dir in "$base_dir"/*/; do
        [[ -e "${project_dir}.git" ]] || continue
        git -C "$project_dir" worktree list --porcelain 2>/dev/null |
          awk '/^worktree /{print $2}'
      done
    done
  } | while IFS= read -r wt; do
    [[ "$wt" == "$TASKS_DIR/"* ]] || continue
    branch="$(dirname "$wt")"
    branch="${branch#"$TASKS_DIR/"}"
    echo "tasks/$branch"
  done | sort -u | while IFS= read -r session; do
    if [[ -n "$active" ]] && grep -qxF "$session" <<<"$active"; then
      continue
    fi
    echo "$session"
  done
}

build_task_candidates() {
  {
    get_active_task_sessions
    get_orphaned_worktrees
  } | sort -u
}

resolve_task_dir() {
  local session_name="$1"
  echo "$TASKS_DIR/${session_name#tasks/}"
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
    local task_dir
    task_dir=$(resolve_task_dir "$selection")

    if [[ -d "$task_dir" ]]; then
      create_session "$selection" "$task_dir"
      tmux switch-client -t "$selection"
    else
      gum style --foreground 196 "Error: Task dir not found: $task_dir"
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
    done <<<"$active_sessions"
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
  create-task     Create a task across one or more repos on a shared branch (C-a T)
  finish-task     Clean up current task: optionally push, remove worktrees, kill session (C-a X)

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
