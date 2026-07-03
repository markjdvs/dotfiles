#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/task.sh
source "$SCRIPT_DIR/lib/task.sh"
# shellcheck source=lib/sandbox.sh
source "$SCRIPT_DIR/lib/sandbox.sh"

usage() {
  echo "Usage: ralph handoff [--iterations N]"
  exit 1
}

iterations_override=""
while [ $# -gt 0 ]; do
  case "$1" in
    --iterations)
      iterations_override=${2:?--iterations needs a number}
      if ! [[ "$iterations_override" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: --iterations must be a positive integer" >&2
        exit 1
      fi
      shift 2
      ;;
    *) usage ;;
  esac
done

require_docker

# --- Validations: refuse before touching anything ---

branch=$(task_branch)
sandbox_name=$(task_sandbox_name)
workspace_dir=$(task_workspace_dir)
stop_file=$(task_stop_file)
checkout_dir=$(task_checkout_dir)

default_branch=$(task_default_branch)
if [ "$branch" = "$default_branch" ]; then
  echo "Error: refusing to hand off the default branch ('$branch'). Run from a task worktree." >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: worktree has uncommitted changes. Commit (or stash) everything first —" >&2
  echo "the agent builds on exactly what origin holds." >&2
  exit 1
fi

pairs=$(task_artefact_pairs)
if [ -z "$pairs" ]; then
  echo "Error: branch '$branch' carries no PRD/plan artefact pair in .context/." >&2
  echo "Author the task first (grill → /to-prd → /prd-to-plan) and commit the artefacts." >&2
  exit 1
fi

pair_count=$(grep -c . <<<"$pairs")
if [ "$pair_count" -gt 1 ]; then
  if [ ! -t 0 ]; then
    echo "Error: multiple artefact pairs on this branch and no TTY to disambiguate:" >&2
    echo "$pairs" >&2
    exit 1
  fi
  echo "Multiple artefact pairs changed on this branch:"
  i=1
  while IFS=$'\t' read -r p_prd p_plan; do
    echo "  $i) $p_plan (PRD: $p_prd)"
    i=$((i + 1))
  done <<<"$pairs"
  printf 'Which pair is the task? [1-%s]: ' "$pair_count"
  read -r choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$pair_count" ]; then
    echo "Error: invalid selection" >&2
    exit 1
  fi
  selected=$(sed -n "${choice}p" <<<"$pairs")
else
  selected=$pairs
fi

prd=$(cut -f1 <<<"$selected")
plan=$(cut -f2 <<<"$selected")

ralph_ensure_token

# --- Budget: unticked phases + 5 unless overridden ---

if [ -n "$iterations_override" ]; then
  budget=$iterations_override
else
  unticked=$(task_unticked_phases "$checkout_dir/$plan")
  budget=$((unticked + 5))
fi

# --- Hand off: push, provision, loop ---

echo "Handing off '$branch' ($prd + $plan, budget: $budget iterations)"
ralph_push "$checkout_dir" "$branch" --ci-skip

"$SCRIPT_DIR/provision.sh"

# A stale stop-file from an earlier pause must not kill this run immediately.
rm -f "$stop_file"

# Hard stop: kill the in-flight sandbox run, then rescue whatever the
# workspace holds — wip-commit and push host-side (works even with the
# sandbox dead, the workspace is a host directory).
child_pid=""
on_interrupt() {
  trap - INT TERM
  echo ""
  echo "Interrupted — stopping sandbox and rescuing workspace state..."
  docker sandbox stop "$sandbox_name" >/dev/null 2>&1 || true
  if [ -n "$child_pid" ]; then
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  if [ -d "$workspace_dir/.git" ]; then
    if [ -n "$(git -C "$workspace_dir" status --porcelain)" ]; then
      git -C "$workspace_dir" add -A
      git -C "$workspace_dir" commit -m "wip(ralph): interrupted mid-iteration on $branch" >/dev/null
      echo "Created wip commit from interrupted workspace state."
    fi
    if ! ralph_push "$workspace_dir" "$branch" --ci-skip; then
      echo "warning: could not push rescued state — it remains in $workspace_dir" >&2
    fi
  fi
  ralph_notify "ralph" "Interrupted: $branch — workspace state pushed to origin"
  exit 130
}
trap on_interrupt INT TERM

for ((i = 1; i <= budget; i++)); do
  if [ -f "$stop_file" ]; then
    rm -f "$stop_file"
    echo "Pause requested — stopping before iteration $i."
    ralph_notify "ralph" "Paused: $branch (after $((i - 1)) iterations)"
    exit 0
  fi

  echo "--- Iteration $i of $budget ---"
  set +e
  "$SCRIPT_DIR/iterate.sh" --prd "$prd" --plan "$plan" &
  child_pid=$!
  wait "$child_pid"
  rc=$?
  set -e
  child_pid=""

  case "$rc" in
    0) ;;
    10)
      echo "Ralph complete after $i iterations."
      ralph_notify "ralph" "Complete: $branch — no more tasks"
      exit 0
      ;;
    130) on_interrupt ;;
    *)
      echo "Iteration $i failed (exit $rc) — stopping." >&2
      ralph_notify "ralph" "Failed: $branch (iteration $i)"
      exit 1
      ;;
  esac
done

echo "Budget of $budget iterations exhausted — stopping." >&2
ralph_notify "ralph" "Budget exhausted: $branch after $budget iterations"
exit 2
