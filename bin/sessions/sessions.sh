#!/usr/bin/env bash
set -euo pipefail

# Session manager for tmux using television as fuzzy finder
# Presents a unified list of existing sessions and project directories
# Selecting an entry switches to existing session or creates a new one

PROJECT_DIRS=(
  "$HOME/src/personal"
  "$HOME/src/work"
)

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

build_candidates() {
  local active_sessions
  active_sessions=$(get_active_sessions)

  # Output active sessions first
  if [[ -n "$active_sessions" ]]; then
    echo "$active_sessions"
  fi

  # Output project directories that don't have active sessions
  while IFS= read -r project; do
    if ! echo "$active_sessions" | grep -qxF "$project"; then
      echo "$project"
    fi
  done < <(get_project_dirs)
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

  # Create session with Phase 2 template: two windows with standard layout
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

main() {
  # Build and present candidates via television
  selection=$(build_candidates | sort -u | tv --input-header "Sessions" --no-preview --no-remote)

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

main
