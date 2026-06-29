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
if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: iterations must be a positive integer" >&2
  exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)

if [[ ! "$branch" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
  echo "Error: Branch name contains unsafe characters: '$branch'" >&2
  exit 1
fi

git_dir=$(git rev-parse --git-dir)
git_common_dir=$(git rev-parse --git-common-dir)

if [ "$git_dir" = "$git_common_dir" ]; then
  main_repo=$(git rev-parse --show-toplevel)
else
  main_repo=$(cd "$git_common_dir/.." && pwd)
fi

sandbox_name="async-${branch//\//-}"
workspace_dir="$HOME/.ralph/workspaces/$sandbox_name"

# Cleanup tmpfiles only — workspace is reused across runs
cleanup_files=()
cleanup() {
  for f in "${cleanup_files[@]+"${cleanup_files[@]}"}"; do
    rm -rf "$f"
  done
}
trap cleanup EXIT

inject_host_config() {
  local sandbox=$1

  # Claude OAuth credentials from macOS Keychain
  local creds
  if ! creds=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null); then
    echo "Error: No Claude credentials found in macOS Keychain." >&2
    echo "Run 'claude' and log in first." >&2
    exit 1
  fi
  echo "$creds" | docker sandbox exec -i "$sandbox" sh -c \
    'umask 077 && mkdir -p /home/agent/.claude && cat > /home/agent/.claude/.credentials.json'
  unset creds

  # SSH private keys only — not config/authorized_keys
  docker sandbox exec "$sandbox" sh -c 'install -dm 700 /home/agent/.ssh'
  for key in id_ed25519 id_rsa id_ecdsa; do
    if [ -f "$HOME/.ssh/$key" ]; then
      docker sandbox exec -i "$sandbox" sh -c \
        "umask 077 && cat > /home/agent/.ssh/$key" < "$HOME/.ssh/$key"
    fi
  done

  # known_hosts for git remote host only
  local remote_url
  remote_url=$(git -C "$workspace_dir" remote get-url origin 2>/dev/null || true)
  if [[ "$remote_url" == *@* ]]; then
    local remote_host
    remote_host=$(echo "$remote_url" | sed -n 's/.*@\([^:]*\):.*/\1/p')
    if [ -n "$remote_host" ]; then
      ssh-keyscan "$remote_host" 2>/dev/null | docker sandbox exec -i "$sandbox" sh -c \
        'cat > /home/agent/.ssh/known_hosts'
    fi
  fi

  if [ -f "$HOME/.npmrc" ]; then
    docker sandbox exec -i "$sandbox" sh -c \
      'umask 077 && cat > /home/agent/.npmrc' < "$HOME/.npmrc"
  fi

  local name email
  name=$(git config --global user.name 2>/dev/null || true)
  email=$(git config --global user.email 2>/dev/null || true)
  if [ -n "$name" ]; then
    docker sandbox exec "$sandbox" git config --global user.name "$name"
  fi
  if [ -n "$email" ]; then
    docker sandbox exec "$sandbox" git config --global user.email "$email"
  fi
}

sandbox_exists() {
  docker sandbox ls 2>/dev/null | awk 'NR>1 {print $1}' | grep -qxF "$sandbox_name"
}

# Stale sandbox — workspace was deleted from under it
if sandbox_exists && [ ! -d "$workspace_dir" ]; then
  echo "Sandbox workspace missing, removing stale sandbox: $sandbox_name"
  docker sandbox stop "$sandbox_name" 2>/dev/null || true
  docker sandbox rm "$sandbox_name" 2>/dev/null || true
fi

if [ ! -d "$workspace_dir" ]; then
  mkdir -p "$(dirname "$workspace_dir")"
  git clone --local --branch "$branch" "$main_repo" "$workspace_dir"

  # --local clone points remote to filesystem path; fix to actual remote URL
  remote_url=$(git -C "$main_repo" remote get-url origin 2>/dev/null || true)
  if [ -n "$remote_url" ]; then
    git -C "$workspace_dir" remote set-url origin "$remote_url"
  fi

  echo "Created local clone at $workspace_dir on branch $branch"
fi

if sandbox_exists; then
  echo "Reusing existing sandbox: $sandbox_name"
else
  docker sandbox create --name "$sandbox_name" claude "$workspace_dir" ~/.claude:ro
  echo "Created sandbox: $sandbox_name"
fi

# Re-inject every run to pick up refreshed tokens/keys
inject_host_config "$sandbox_name"

stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'

prompt=$(cat "$SCRIPT_DIR/prompt.md")

for ((i = 1; i <= iterations; i++)); do
  echo "--- Iteration $i of $iterations ---"

  tmpfile=$(mktemp)
  chmod 600 "$tmpfile"
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
