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

set +e
docker sandbox run "$sandbox_name" -- \
  --verbose \
  --print \
  --output-format stream-json \
  "$prompt" |
  grep --line-buffered '^{' |
  tee "$transcript" |
  jq --unbuffered -rj "$RALPH_STREAM_TEXT_FILTER"
run_rc=${PIPESTATUS[0]}
set -e

outcome=$(classify_outcome "$transcript" "$run_rc")
echo ""
echo "Iteration outcome: $outcome"
exit "$(outcome_exit_code "$outcome")"
