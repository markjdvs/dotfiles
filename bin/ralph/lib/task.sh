# shellcheck shell=bash
# Task resolution: everything ralph knows about a task, derived from the cwd.
# Source this file; all functions read git state from the current directory.

RALPH_HOME="${RALPH_HOME:-$HOME/.ralph}"

task_branch() {
  local branch
  if ! branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
    echo "Error: not inside a git repository" >&2
    return 1
  fi
  if [ "$branch" = "HEAD" ]; then
    echo "Error: detached HEAD — ralph needs a task branch" >&2
    return 1
  fi
  if [[ ! "$branch" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
    echo "Error: branch name contains unsafe characters: '$branch'" >&2
    return 1
  fi
  echo "$branch"
}

# Root of the main repository, even when cwd is a linked worktree.
task_project_dir() {
  local git_dir git_common_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || {
    echo "Error: not inside a git repository" >&2
    return 1
  }
  git_common_dir=$(git rev-parse --git-common-dir)

  if [ "$git_dir" = "$git_common_dir" ]; then
    git rev-parse --show-toplevel
  else
    (cd "$git_common_dir/.." && pwd)
  fi
}

# Root of the current checkout (the worktree itself when cwd is one).
task_checkout_dir() {
  git rev-parse --show-toplevel
}

task_branch_slug() {
  local branch
  branch=$(task_branch) || return 1
  echo "${branch//\//-}"
}

task_sandbox_name() {
  local slug
  slug=$(task_branch_slug) || return 1
  echo "async-$slug"
}

task_workspace_dir() {
  local name
  name=$(task_sandbox_name) || return 1
  echo "$RALPH_HOME/workspaces/$name"
}

task_stop_file() {
  local name
  name=$(task_sandbox_name) || return 1
  echo "$RALPH_HOME/workspaces/$name.stop"
}

task_default_branch() {
  local ref branch
  if ref=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null); then
    echo "${ref#refs/remotes/origin/}"
    return 0
  fi
  for branch in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      echo "$branch"
      return 0
    fi
  done
  for branch in main master; do
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      echo "$branch"
      return 0
    fi
  done
  echo "Error: cannot determine default branch (no origin/HEAD, main, or master)" >&2
  return 1
}

# Artefact pairs changed on this branch relative to the default branch.
# A pair is keyed by its plan file: .context/plan-<slug>.md added/changed on
# the branch, with .context/prd-<slug>.md present at HEAD. One pair per line,
# tab-separated: "<prd-path>\t<plan-path>".
task_artefact_pairs() {
  local default default_ref base
  default=$(task_default_branch) || return 1
  if git show-ref --verify --quiet "refs/remotes/origin/$default"; then
    default_ref="refs/remotes/origin/$default"
  else
    default_ref="refs/heads/$default"
  fi
  base=$(git merge-base "$default_ref" HEAD) || {
    echo "Error: no merge base between $default and HEAD" >&2
    return 1
  }

  local file slug prd
  while IFS= read -r file; do
    case "$file" in
      .context/plan-*.md)
        slug=${file#.context/plan-}
        slug=${slug%.md}
        prd=".context/prd-$slug.md"
        if git cat-file -e "HEAD:$prd" 2>/dev/null; then
          printf '%s\t%s\n' "$prd" "$file"
        fi
        ;;
    esac
  done < <(git diff --name-only --diff-filter=ACMR "$base" HEAD -- '.context/')
}

# Count phases in a plan file that still have at least one unticked checkbox.
task_unticked_phases() {
  local plan_file=$1
  if [ ! -f "$plan_file" ]; then
    echo "Error: plan file not found: $plan_file" >&2
    return 1
  fi
  awk '
    /^## Phase / { if (in_phase && unticked) count++; in_phase = 1; unticked = 0; next }
    in_phase && /^[[:space:]]*- \[ \]/ { unticked = 1 }
    END { if (in_phase && unticked) count++; print count + 0 }
  ' "$plan_file"
}
