#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/task.sh
source "$SCRIPT_DIR/lib/task.sh"
# shellcheck source=lib/sandbox.sh
source "$SCRIPT_DIR/lib/sandbox.sh"

usage() {
  echo "Usage: ralph provision [--check]"
  exit 1
}

check_mode=false
case "${1:-}" in
  "") ;;
  --check) check_mode=true ;;
  *) usage ;;
esac

require_docker

branch=$(task_branch)
sandbox_name=$(task_sandbox_name)
workspace_dir=$(task_workspace_dir)

origin_url=$(git remote get-url origin 2>/dev/null) || {
  echo "Error: no 'origin' remote — ralph needs origin as the sync boundary" >&2
  exit 1
}

if ! git ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1; then
  echo "Error: branch '$branch' not found on origin." >&2
  echo "Push it first (or use 'ralph handoff', which pushes for you)." >&2
  exit 1
fi

ralph_ensure_token
token=$(ralph_token)

# Stale sandbox — its workspace was deleted from under it
if sandbox_exists "$sandbox_name" && [ ! -d "$workspace_dir" ]; then
  echo "Sandbox workspace missing, removing stale sandbox: $sandbox_name"
  sandbox_remove "$sandbox_name"
fi

# Workspace: disposable, always rebuilt from or hard-reset to origin/<branch>
if [ -d "$workspace_dir/.git" ]; then
  echo "Resetting workspace to origin/$branch"
  git -C "$workspace_dir" fetch origin "$branch"
  git -C "$workspace_dir" checkout -q "$branch" 2>/dev/null ||
    git -C "$workspace_dir" checkout -q -b "$branch" "origin/$branch"
  git -C "$workspace_dir" reset --hard "origin/$branch"
else
  mkdir -p "$(dirname "$workspace_dir")"
  git clone --branch "$branch" "$origin_url" "$workspace_dir"
  echo "Created workspace at $workspace_dir on branch $branch"
fi

if sandbox_exists "$sandbox_name"; then
  echo "Reusing existing sandbox: $sandbox_name"
else
  docker sandbox create --name "$sandbox_name" claude "$workspace_dir"
  echo "Created sandbox: $sandbox_name"
fi

# --- Config: resolved copy of host skills/agents/commands + curated settings ---

staging=$(mktemp -d)
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT

copy_resolved() {
  local kind=$1 src="$HOME/.claude/$1" entry resolved
  [ -d "$src" ] || return 0
  mkdir -p "$staging/$kind"
  for entry in "$src"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    if ! resolved=$(readlink -f "$entry") || [ ! -e "$resolved" ]; then
      echo "warning: skipping dangling entry: $entry" >&2
      continue
    fi
    if ! cp -RL "$resolved" "$staging/$kind/$(basename "$entry")" 2>/dev/null; then
      echo "warning: could not fully resolve $entry, skipping" >&2
      rm -rf "${staging:?}/$kind/$(basename "$entry")"
    fi
  done
}

copy_resolved skills
copy_resolved agents
copy_resolved commands

jq --arg tok "$token" \
  '.env.CLAUDE_CODE_OAUTH_TOKEN = $tok | .env.NODE_USE_ENV_PROXY = "1"' \
  "$SCRIPT_DIR/sandbox-settings.json" >"$staging/settings.json"

echo "Copying resolved config into sandbox"
tar -C "$staging" -cf - . | docker sandbox exec -i "$sandbox_name" sh -c "
  rm -rf $RALPH_SANDBOX_HOME/.claude/skills \
         $RALPH_SANDBOX_HOME/.claude/agents \
         $RALPH_SANDBOX_HOME/.claude/commands \
         $RALPH_SANDBOX_HOME/.claude/.credentials.json &&
  mkdir -p $RALPH_SANDBOX_HOME/.claude &&
  tar -xf - -C $RALPH_SANDBOX_HOME/.claude
"

# --- Toolchain: install the repo's pinned Node so every iteration starts
# runnable. The base image ships an older Node; the workspace often needs a
# newer one, and Node's fetch/undici (corepack, pnpm) ignore the sandbox proxy
# unless NODE_USE_ENV_PROXY=1 — which the injected settings.json sets. ---

node_version=""
for f in .nvmrc .node-version; do
  if [ -f "$workspace_dir/$f" ]; then
    node_version=$(tr -cd '0-9.' <"$workspace_dir/$f")
    break
  fi
done

if [ -n "$node_version" ]; then
  echo "Ensuring Node $node_version in sandbox"
  docker sandbox exec -i "$sandbox_name" sh -s "$node_version" <<'SETUP'
set -e
V=$1
if command -v node >/dev/null 2>&1 && [ "$(node --version)" = "v$V" ]; then
  echo "Node v$V already present"
  exit 0
fi
case "$(uname -m)" in
  aarch64 | arm64) arch=arm64 ;;
  x86_64) arch=x64 ;;
  *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/node.tar.gz" "https://nodejs.org/dist/v$V/node-v$V-linux-$arch.tar.gz"
mkdir -p "$HOME/.local"
tar -xzf "$tmp/node.tar.gz" --strip-components=1 -C "$HOME/.local"
hash -r 2>/dev/null || true
echo "Installed $(node --version) to $HOME/.local"
SETUP
fi

# --- Registry auth: pnpm needs .npmrc to reach private GitLab packages.
# Git push is host-side (the agent never touches the remote), so no SSH key
# or write token goes into the sandbox. ---

if [ -f "$HOME/.npmrc" ]; then
  docker sandbox exec -i "$sandbox_name" sh -c \
    "umask 077 && cat > $RALPH_SANDBOX_HOME/.npmrc" <"$HOME/.npmrc"
fi

git_name=$(git config --global user.name 2>/dev/null || true)
git_email=$(git config --global user.email 2>/dev/null || true)
[ -n "$git_name" ] && docker sandbox exec "$sandbox_name" git config --global user.name "$git_name"
[ -n "$git_email" ] && docker sandbox exec "$sandbox_name" git config --global user.email "$git_email"

echo "Provisioned sandbox '$sandbox_name' for branch '$branch'"

# --- Check mode: prove the result from inside the sandbox ---

if [ "$check_mode" = true ]; then
  echo "Checking skills inside the sandbox..."
  if ! docker sandbox exec "$sandbox_name" sh -c "
    test -f $RALPH_SANDBOX_HOME/.claude/skills/tdd/SKILL.md &&
    test -f $RALPH_SANDBOX_HOME/.claude/skills/bootstrap/SKILL.md
  "; then
    echo "Check failed: tdd/bootstrap skills missing from the sandbox" >&2
    exit 1
  fi

  dangling=$(docker sandbox exec "$sandbox_name" sh -c \
    "find $RALPH_SANDBOX_HOME/.claude/skills -type l 2>/dev/null" || true)
  if [ -n "$dangling" ]; then
    echo "Check failed: unresolved symlinks in sandbox skills:" >&2
    echo "$dangling" >&2
    exit 1
  fi
  echo "Skills present and fully resolved."

  echo "Checking claude auth inside the sandbox..."
  if ! docker sandbox exec "$sandbox_name" sh -c '
    cd "$1" || exit 1
    export CLAUDE_CODE_OAUTH_TOKEN="$2"
    exec claude --print "Reply with exactly: RALPH-OK"
  ' _ "$workspace_dir" "$token" | grep -q "RALPH-OK"; then
    echo "Check failed: claude --print did not succeed inside the sandbox" >&2
    exit 1
  fi
  echo "Auth OK — provision check passed."
fi
