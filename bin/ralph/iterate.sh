#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/task.sh
source "$SCRIPT_DIR/lib/task.sh"
# shellcheck source=lib/sandbox.sh
source "$SCRIPT_DIR/lib/sandbox.sh"
# shellcheck source=lib/outcome.sh
source "$SCRIPT_DIR/lib/outcome.sh"

usage() {
  echo "Usage: ralph iterate [--prd PATH --plan PATH]"
  echo ""
  echo "Runs exactly one loop iteration in the task's sandbox."
  echo "Exit status: 0 = worked, 10 = no more tasks, 1 = failed."
  exit 1
}

prd=""
plan=""
while [ $# -gt 0 ]; do
  case "$1" in
    --prd) prd=${2:?--prd needs a path}; shift 2 ;;
    --plan) plan=${2:?--plan needs a path}; shift 2 ;;
    *) usage ;;
  esac
done

require_docker

branch=$(task_branch)
sandbox_name=$(task_sandbox_name)
workspace_dir=$(task_workspace_dir)

if [ ! -d "$workspace_dir/.git" ] || ! sandbox_exists "$sandbox_name"; then
  echo "Error: task '$branch' is not provisioned. Run 'ralph provision' first." >&2
  exit 1
fi

# Host-side sync: the sandbox has no network access to the remote, so the host
# keeps the workspace current with origin before each iteration.
if git -C "$workspace_dir" fetch --quiet origin "$branch" 2>/dev/null; then
  git -C "$workspace_dir" merge --quiet --ff-only "origin/$branch" 2>/dev/null || true
else
  echo "warning: could not fetch origin/$branch — proceeding with current workspace" >&2
fi

# Resolve the artefact pair unless the caller already did (handoff does).
if [ -z "$prd" ] || [ -z "$plan" ]; then
  pairs=$(task_artefact_pairs)
  pair_count=$(grep -c . <<<"$pairs" 2>/dev/null || true)
  [ -n "$pairs" ] || pair_count=0

  if [ "$pair_count" -eq 0 ]; then
    echo "Error: no PRD/plan artefact pair found in .context/ on branch '$branch'." >&2
    echo "Author the task first (grill → /to-prd → /prd-to-plan) and commit the artefacts." >&2
    exit 1
  fi

  if [ "$pair_count" -gt 1 ]; then
    if [ ! -t 0 ]; then
      echo "Error: multiple artefact pairs on this branch; pass --prd/--plan to choose:" >&2
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
fi

echo "Task artefacts: $prd + $plan"

prompt=$(cat "$SCRIPT_DIR/iteration-prompt.md")
prompt=${prompt//\{\{PRD_PATH\}\}/$prd}
prompt=${prompt//\{\{PLAN_PATH\}\}/$plan}

transcript=$(mktemp)
chmod 600 "$transcript"
cleanup() { rm -f "$transcript"; }
trap cleanup EXIT

token=$(ralph_token)
if [ -z "$token" ]; then
  echo "Error: no ralph setup-token in the Keychain — run 'ralph provision'." >&2
  exit 1
fi

head_before=$(git -C "$workspace_dir" rev-parse HEAD 2>/dev/null || true)

set +e
docker sandbox exec "$sandbox_name" sh -c '
  cd "$1" || exit 1
  export CLAUDE_CODE_OAUTH_TOKEN="$2"
  exec claude --verbose --print --output-format stream-json "$3"
' _ "$workspace_dir" "$token" "$prompt" |
  grep --line-buffered '^{' |
  tee "$transcript" |
  jq --unbuffered -rj "$RALPH_STREAM_TEXT_FILTER"
run_rc=${PIPESTATUS[0]}
set -e

outcome=$(classify_outcome "$transcript" "$run_rc")

head_after=$(git -C "$workspace_dir" rev-parse HEAD 2>/dev/null || true)
committed=false
if [ -n "$head_before" ] && [ -n "$head_after" ] && [ "$head_after" != "$head_before" ]; then
  committed=true
fi

# No-progress backstop: a "worked" iteration must leave a commit. If HEAD did
# not move, the agent spun without committing (typically stalled on an
# unanswerable interactive prompt) — treat it as blocked so the loop halts and
# surfaces it, rather than silently burning the budget one empty turn at a time.
if [ "$outcome" = "worked" ] && [ "$committed" = false ]; then
  echo "No commit produced this iteration — the agent made no progress." >&2
  outcome=blocked
fi

echo ""
echo "Iteration outcome: $outcome"

# Host-side push: the agent commits but never touches the remote. Push whenever
# the iteration produced a commit — keyed on HEAD moving, not the outcome word,
# because the agent may finish the FINAL phase and declare NO MORE TASKS in the
# same turn. A fully-ticked plan gets a CI-validated push; work still in
# progress (or a blocker's safe commit) skips CI.
if [ "$committed" = true ] && [ "$outcome" != "failed" ]; then
  if [ "$(task_unticked_phases "$workspace_dir/$plan")" = "0" ]; then
    echo "Plan complete — pushing with CI."
    push_mode=--run-ci
  else
    push_mode=--ci-skip
  fi
  if ! ralph_push "$workspace_dir" "$branch" "$push_mode"; then
    echo "Error: iteration committed work but host push failed — commit is safe in $workspace_dir" >&2
    exit 1
  fi
fi

exit "$(outcome_exit_code "$outcome")"
