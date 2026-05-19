#!/usr/bin/env bash
set -euo pipefail

# Session manager for tmux using television as fuzzy finder
# Subcommand-based dispatch for project and task session management
#
# Subcommands:
#   list-projects  - List and switch between project sessions
#   create-project - Create a new project (clone or init)
#   list-tasks     - List and switch between task sessions
#   create-task    - Create a new task (worktree + branch + session)
#   finish-task    - Clean up current task (push, remove worktree, kill session)

PROJECT_DIRS=(
  "$HOME/src/personal"
  "$HOME/src/work"
)

# --- Shared Functions ---

get_active_sessions() {
  # Get list of active tmux sessions in format: parent/project
  tmux list-sessions -F '#{session_name}' 2>/dev/null || true
}

get_project_dirs() {
  # Get list of project directories as parent/project format
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
  # Map session name segments to filesystem path
  # Input: parent/project (e.g. "work/calton")
  # Output: full path (e.g. "/Users/mark/src/work/calton")
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
  # Create a tmux session with the standard two-window template
  # Used identically for both project and task sessions
  local session_name="$1"
  local project_path="$2"

  # Use window indices instead of names — tmux misparses named targets
  # when session names contain /

  # Window 0 - Editor: neovim (left) + claude (right)
  tmux new-session -d -s "$session_name" -c "$project_path" -n "editor"
  tmux send-keys -t "$session_name:0" "nvim ." Enter
  tmux split-window -h -t "$session_name:0" -c "$project_path"
  tmux send-keys -t "$session_name:0.1" "claude" Enter

  # Window 1 - Development: dev server (left) + logs (right)
  tmux new-window -t "$session_name" -n "dev" -c "$project_path"
  tmux split-window -h -t "$session_name:1" -c "$project_path"

  # Focus back on editor window
  tmux select-window -t "$session_name:0"
  tmux select-pane -t "$session_name:0.0"
}

# --- Subcommand: list-projects ---

build_project_candidates() {
  local active_sessions
  active_sessions=$(get_active_sessions)

  # Output active sessions first (only project sessions, not task sessions)
  if [[ -n "$active_sessions" ]]; then
    while IFS= read -r session; do
      # Project sessions have exactly one / (parent/project)
      # Task sessions have 2+ slashes (parent/project/branch...)
      local slash_count
      slash_count=$(echo "$session" | tr -cd '/' | wc -c)
      if [[ "$slash_count" -eq 1 ]]; then
        echo "$session"
      fi
    done <<< "$active_sessions"
  fi

  # Output project directories that don't have active sessions
  while IFS= read -r project; do
    if ! echo "$active_sessions" | grep -qxF "$project"; then
      echo "$project"
    fi
  done < <(get_project_dirs)
}

cmd_list_projects() {
  # Build and present candidates via television
  selection=$(build_project_candidates | sort -u | tv --input-header "Sessions" --no-preview --no-remote)

  # Exit if no selection
  [[ -z "$selection" ]] && exit 0

  # Check if session already exists
  if tmux has-session -t "$selection" 2>/dev/null; then
    # Switch to existing session
    tmux switch-client -t "$selection"
  else
    # Create new session and switch to it
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

# --- Usage ---

usage() {
  cat <<EOF
Usage: sessions <subcommand>

Subcommands:
  list-projects   List and switch between project sessions (C-a p)
  create-project  Create a new project by cloning or initializing (C-a P)
  list-tasks      List and switch between task sessions (C-a t)
  create-task     Create a new task with worktree and session (C-a T)
  finish-task     Clean up current task: push, remove worktree, kill session (C-a X)

EOF
  exit 1
}

# --- Main Dispatch ---

main() {
  local subcommand="${1:-}"

  case "$subcommand" in
    list-projects)
      cmd_list_projects
      ;;
    create-project)
      echo "Error: create-project not yet implemented" >&2
      exit 1
      ;;
    list-tasks)
      echo "Error: list-tasks not yet implemented" >&2
      exit 1
      ;;
    create-task)
      echo "Error: create-task not yet implemented" >&2
      exit 1
      ;;
    finish-task)
      echo "Error: finish-task not yet implemented" >&2
      exit 1
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
