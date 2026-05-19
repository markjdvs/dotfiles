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

# --- Subcommand: create-project ---

cmd_create_project() {
  # Create a new project by cloning a remote repo or initializing locally
  # Uses gum for all free-text input

  # Step 1: Pick parent directory
  local parent
  parent=$(gum choose --header "Select parent directory" "personal" "work")
  [[ -z "$parent" ]] && exit 0

  # Map parent to base directory
  local base_dir
  case "$parent" in
    personal) base_dir="$HOME/src/personal" ;;
    work) base_dir="$HOME/src/work" ;;
    *) echo "Error: Invalid parent directory" >&2; exit 1 ;;
  esac

  # Ensure base directory exists
  mkdir -p "$base_dir"

  # Step 2: Get project name
  local project_name
  project_name=$(gum input --header "Project name" --placeholder "my-project")
  [[ -z "$project_name" ]] && exit 0

  # Check if directory already exists
  local project_path="$base_dir/$project_name"
  if [[ -d "$project_path" ]]; then
    gum style --foreground 196 "Error: Directory already exists: $project_path"
    gum style "Use C-a p to open the existing project instead."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  # Step 3: Optionally get git URL
  local git_url
  git_url=$(gum input --header "Git URL (leave empty for local init)" --placeholder "https://github.com/org/repo.git")

  # Step 4: Clone or init
  if [[ -n "$git_url" ]]; then
    gum spin --spinner dot --title "Cloning repository..." -- git clone "$git_url" "$project_path"
  else
    mkdir -p "$project_path"
    git -C "$project_path" init
  fi

  # Step 5: Create session and switch to it
  local session_name="$parent/$project_name"
  create_session "$session_name" "$project_path"
  tmux switch-client -t "$session_name"
}

# --- Subcommand: create-task ---

cmd_create_task() {
  # Create a new task: worktree + branch + tmux session
  # Two-step picker: project selection, then branch selection/creation

  # Step 1: Pick a project via television
  local project_selection
  project_selection=$(get_project_dirs | tv --input-header "Select project" --no-preview --no-remote)
  [[ -z "$project_selection" ]] && exit 0

  local project_path
  project_path=$(resolve_project_path "$project_selection")
  if [[ ! -d "$project_path" ]]; then
    echo "Error: Project path not found: $project_path" >&2
    exit 1
  fi

  # Step 2: Fetch remote refs to ensure we have current state
  gum spin --spinner dot --title "Fetching remote refs..." -- git -C "$project_path" fetch origin 2>/dev/null || true

  # Step 3: Build branch list (deduplicated local + remote)
  local branches
  branches=$(get_branch_list "$project_path")

  # Step 4: Pick existing branch or type new branch name
  local branch_name
  branch_name=$(echo "$branches" | tv --input-header "Select or type branch" --no-preview --no-remote)

  # If no selection from tv, prompt for new branch name via gum
  if [[ -z "$branch_name" ]]; then
    branch_name=$(gum input --header "New branch name" --placeholder "feat/my-feature")
    [[ -z "$branch_name" ]] && exit 0
  fi

  # Step 5: Determine branch state and create worktree
  local worktree_path="$project_path/.worktrees/$branch_name"
  local session_name="$project_selection/$branch_name"

  # Check if branch is already checked out in main working tree
  local current_branch
  current_branch=$(git -C "$project_path" branch --show-current 2>/dev/null || true)
  if [[ "$current_branch" == "$branch_name" ]]; then
    gum style --foreground 196 "Error: Branch '$branch_name' is already checked out in the main working tree."
    gum style "Switch to the project session or use a different branch."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  # Check if worktree already exists
  if [[ -d "$worktree_path" ]]; then
    gum style --foreground 196 "Error: Worktree already exists at: $worktree_path"
    gum style "Use C-a t to switch to the existing task."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  # Create .worktrees directory if needed
  mkdir -p "$(dirname "$worktree_path")"

  # Determine how to create the worktree based on branch state
  local branch_exists_local branch_exists_remote
  branch_exists_local=$(git -C "$project_path" branch --list "$branch_name" | grep -c . || true)
  branch_exists_remote=$(git -C "$project_path" branch -r --list "origin/$branch_name" | grep -c . || true)

  if [[ "$branch_exists_local" -gt 0 ]]; then
    # Existing local branch: attach worktree without -b
    gum spin --spinner dot --title "Creating worktree from local branch..." -- \
      git -C "$project_path" worktree add "$worktree_path" "$branch_name"
  elif [[ "$branch_exists_remote" -gt 0 ]]; then
    # Remote-only branch: create local tracking branch
    gum spin --spinner dot --title "Creating worktree from remote branch..." -- \
      git -C "$project_path" worktree add "$worktree_path" -b "$branch_name" "origin/$branch_name"
  else
    # New branch: ensure main is up to date, create from main
    gum spin --spinner dot --title "Updating main branch..." -- \
      git -C "$project_path" fetch origin main:main 2>/dev/null || true
    gum spin --spinner dot --title "Creating worktree with new branch..." -- \
      git -C "$project_path" worktree add "$worktree_path" -b "$branch_name" main
  fi

  # Step 6: Create session and switch to it
  create_session "$session_name" "$worktree_path"
  tmux switch-client -t "$session_name"
}

get_branch_list() {
  # Get deduplicated list of local and remote branches
  local project_path="$1"

  {
    # Local branches (strip leading whitespace and asterisk)
    git -C "$project_path" branch --list --format='%(refname:short)' 2>/dev/null

    # Remote branches (strip origin/ prefix)
    git -C "$project_path" branch -r --list --format='%(refname:short)' 2>/dev/null | \
      grep '^origin/' | sed 's|^origin/||' | grep -v '^HEAD$'
  } | sort -u
}

# --- Subcommand: finish-task ---

cmd_finish_task() {
  # Tear down the current task in a single action
  # Pushes branch, removes worktree, deletes local branch, kills session

  # Step 1: Capture current session name
  local session_name
  session_name=$(tmux display-message -p '#{session_name}')

  # Validate this is a task session (3+ /-separated segments)
  local slash_count
  slash_count=$(echo "$session_name" | tr -cd '/' | wc -c)
  if [[ "$slash_count" -lt 2 ]]; then
    gum style --foreground 196 "Error: Not a task session."
    gum style "finish-task can only be run from a task session (parent/project/branch)."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  # Step 2: Parse project path and branch name from session name
  local parent project branch_name
  parent="${session_name%%/*}"
  local rest="${session_name#*/}"
  project="${rest%%/*}"
  branch_name="${rest#*/}"

  # Resolve project base path
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

  # Step 3: Check for uncommitted changes in the worktree
  if ! git -C "$worktree_path" diff --quiet 2>/dev/null || \
     ! git -C "$worktree_path" diff --cached --quiet 2>/dev/null; then
    gum style --foreground 196 "Error: Uncommitted changes detected in worktree."
    gum style "Commit or stash your changes before finishing the task."
    read -r -n 1 -p "Press any key to exit..."
    exit 1
  fi

  # Also check for untracked files that might be important
  local untracked_count
  untracked_count=$(git -C "$worktree_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$untracked_count" -gt 0 ]]; then
    gum style --foreground 208 "Warning: $untracked_count untracked file(s) in worktree."
    if ! gum confirm "Continue anyway?"; then
      exit 0
    fi
  fi

  # Step 4: Display task session name and prompt user to type it to confirm
  gum style --bold --foreground 196 "⚠️  DESTRUCTIVE ACTION"
  gum style ""
  gum style "This will:"
  gum style "  • Push branch '$branch_name' to remote"
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

  # Step 5: Push branch to remote
  gum style "Pushing branch to remote..."
  if ! git -C "$worktree_path" push origin "$branch_name" 2>&1; then
    gum style --foreground 208 "Warning: Failed to push branch. Continuing with cleanup..."
  fi

  # Step 6: Switch to last session (before killing current session)
  # This may fail if no other session exists - that's OK
  tmux switch-client -l 2>/dev/null || true

  # Step 7: Kill the task session
  tmux kill-session -t "$session_name" 2>/dev/null || true

  # Step 8: Remove the worktree
  gum style "Removing worktree..."
  git -C "$project_path" worktree remove "$worktree_path" --force 2>/dev/null || true

  # Step 9: Delete the local branch (never delete remote)
  gum style "Deleting local branch..."
  git -C "$project_path" branch -D "$branch_name" 2>/dev/null || true

  gum style --foreground 76 "✓ Task finished successfully."
}

# --- Subcommand: list-tasks ---

get_active_task_sessions() {
  # Get task sessions (3+ /-separated segments)
  local sessions
  sessions=$(get_active_sessions)

  if [[ -n "$sessions" ]]; then
    while IFS= read -r session; do
      local slash_count
      slash_count=$(echo "$session" | tr -cd '/' | wc -c)
      # Task sessions have 2+ slashes (parent/project/branch...)
      if [[ "$slash_count" -ge 2 ]]; then
        echo "$session"
      fi
    done <<< "$sessions"
  fi
}

get_orphaned_worktrees() {
  # Find worktrees that exist on disk but have no matching tmux session
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

      # Find all worktrees (directories that are git worktrees)
      # Worktrees can be nested (e.g. .worktrees/feat/PAC-123/)
      while IFS= read -r worktree_path; do
        # Skip if not a valid git worktree (check for .git file)
        if [[ ! -e "$worktree_path/.git" ]]; then
          continue
        fi

        # Extract branch name from worktree path
        # worktree_path: /path/to/project/.worktrees/feat/PAC-123
        # branch_name: feat/PAC-123
        local branch_name
        branch_name="${worktree_path#"$worktrees_dir/"}"

        # Build the expected session name
        local session_name="$parent/$project_name/$branch_name"

        # Check if this session already exists
        if echo "$active_task_sessions" | grep -qxF "$session_name"; then
          continue
        fi

        # This is an orphaned worktree
        echo "$session_name"
      done < <(find "$worktrees_dir" -type d -name ".git" 2>/dev/null | while read -r git_file; do dirname "$git_file"; done)
    done
  done
}

build_task_candidates() {
  # Combine active task sessions and orphaned worktrees
  {
    get_active_task_sessions
    get_orphaned_worktrees
  } | sort -u
}

resolve_task_worktree_path() {
  # Map task session name to worktree filesystem path
  # Input: parent/project/branch (e.g. "work/calton/feat/PAC-123")
  # Output: full path (e.g. "/Users/mark/src/work/calton/.worktrees/feat/PAC-123")
  local session_name="$1"

  # Extract parent/project from the session name
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
  # Build and present task candidates via television
  local candidates
  candidates=$(build_task_candidates)

  if [[ -z "$candidates" ]]; then
    gum style --foreground 208 "No active tasks or orphaned worktrees found."
    read -r -n 1 -p "Press any key to exit..."
    exit 0
  fi

  local selection
  selection=$(echo "$candidates" | tv --input-header "Tasks" --no-preview --no-remote)

  # Exit if no selection
  [[ -z "$selection" ]] && exit 0

  # Check if session already exists
  if tmux has-session -t "$selection" 2>/dev/null; then
    # Switch to existing session
    tmux switch-client -t "$selection"
  else
    # Orphaned worktree: create a new session at the existing worktree path
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
