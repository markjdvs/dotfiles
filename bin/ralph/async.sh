#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if ! command -v docker &>/dev/null; then
  echo "Error: docker is not installed. Install Docker Desktop from https://www.docker.com/products/docker-desktop" >&2
  exit 1
fi

if [ -z "${1:-}" ]; then
  echo "Usage: ralph async <iterations>"
  exit 1
fi

iterations=$1

# --- Resolve repo and branch ---

branch=$(git rev-parse --abbrev-ref HEAD)
git_dir=$(git rev-parse --git-dir)
git_common_dir=$(git rev-parse --git-common-dir)

if [ "$git_dir" = "$git_common_dir" ]; then
  # Regular checkout — clone from current directory
  main_repo=$(git rev-parse --show-toplevel)
else
  # Worktree — resolve main repo from common dir
  main_repo=$(cd "$git_common_dir/.." && pwd)
fi

# --- Sandbox naming ---

sandbox_name="async-${branch}"

# --- Cleanup ---

cleanup_files=()
cleanup() {
  for f in "${cleanup_files[@]}"; do
    rm -rf "$f"
  done
}
trap cleanup EXIT

# --- Check if sandbox already exists ---

sandbox_exists=false
if docker sandbox ls 2>/dev/null | grep -qF "$sandbox_name"; then
  sandbox_exists=true
  echo "Reusing existing sandbox: $sandbox_name"
fi

# --- Create clone for new sandbox ---

if [ "$sandbox_exists" = false ]; then
  clone_dir=$(mktemp -d)
  cleanup_files+=("$clone_dir")
  git clone --local --branch "$branch" "$main_repo" "$clone_dir"
  echo "Created local clone at $clone_dir on branch $branch"
fi

# --- jq filters ---

stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'

# --- Prompt ---

prompt=$(cat "$SCRIPT_DIR/prompt.md")

# --- Run iterations ---

for ((i = 1; i <= iterations; i++)); do
  echo "--- Iteration $i of $iterations ---"

  tmpfile=$(mktemp)
  cleanup_files+=("$tmpfile")

  if [ "$sandbox_exists" = true ]; then
    docker sandbox exec "$sandbox_name" -- \
      claude \
      --verbose \
      --print \
      --output-format stream-json \
      "$prompt" |
      grep --line-buffered '^{' |
      tee "$tmpfile" |
      jq --unbuffered -rj "$stream_text"
  else
    docker sandbox run --name "$sandbox_name" claude "$clone_dir" ~/.claude -- \
      --verbose \
      --print \
      --output-format stream-json \
      "$prompt" |
      grep --line-buffered '^{' |
      tee "$tmpfile" |
      jq --unbuffered -rj "$stream_text"
    # After first run, sandbox exists for subsequent iterations
    sandbox_exists=true
  fi

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done
