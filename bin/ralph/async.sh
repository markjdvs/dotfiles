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

# --- Sandbox naming + stable workspace ---

sandbox_name="async-${branch}"
workspace_dir="$HOME/.ralph/workspaces/$sandbox_name"

# --- Cleanup (tmpfiles only, not workspace) ---

cleanup_files=()
cleanup() {
  for f in "${cleanup_files[@]+"${cleanup_files[@]}"}"; do
    rm -rf "$f"
  done
}
trap cleanup EXIT

# --- Inject credentials from macOS Keychain into sandbox ---

inject_credentials() {
  local sandbox=$1

  local creds
  if ! creds=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null); then
    echo "Error: No Claude credentials found in macOS Keychain." >&2
    echo "Run 'claude' and log in first." >&2
    exit 1
  fi

  echo "$creds" | docker sandbox exec -i "$sandbox" sh -c \
    'mkdir -p /home/agent/.claude && cat > /home/agent/.claude/.credentials.json && chmod 600 /home/agent/.claude/.credentials.json'
}

# --- Check if sandbox already exists ---

sandbox_exists() {
  docker sandbox ls 2>/dev/null | awk 'NR>1 {print $1}' | grep -qxF "$sandbox_name"
}

# --- Handle stale sandbox (workspace deleted from under it) ---

if sandbox_exists && [ ! -d "$workspace_dir" ]; then
  echo "Sandbox workspace missing, removing stale sandbox: $sandbox_name"
  docker sandbox stop "$sandbox_name" 2>/dev/null || true
  docker sandbox rm "$sandbox_name" 2>/dev/null || true
fi

# --- Ensure workspace exists ---

if [ ! -d "$workspace_dir" ]; then
  mkdir -p "$(dirname "$workspace_dir")"
  git clone --local --branch "$branch" "$main_repo" "$workspace_dir"
  echo "Created local clone at $workspace_dir on branch $branch"
fi

# --- Ensure sandbox exists ---

if sandbox_exists; then
  echo "Reusing existing sandbox: $sandbox_name"
else
  docker sandbox create --name "$sandbox_name" claude "$workspace_dir" ~/.claude
  echo "Created sandbox: $sandbox_name"
fi

# --- Inject credentials (every run, to handle token refresh) ---

inject_credentials "$sandbox_name"

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

  docker sandbox run "$sandbox_name" -- \
    --verbose \
    --print \
    --output-format stream-json \
    "$prompt" |
    grep --line-buffered '^{' |
    tee "$tmpfile" |
    jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done
