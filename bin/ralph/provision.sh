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

jq --arg tok "$token" '.env.CLAUDE_CODE_OAUTH_TOKEN = $tok' \
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

# --- Git plumbing the agent needs to push to origin ---

docker sandbox exec "$sandbox_name" sh -c "install -dm 700 $RALPH_SANDBOX_HOME/.ssh"
for key in id_ed25519 id_rsa id_ecdsa; do
  if [ -f "$HOME/.ssh/$key" ]; then
    docker sandbox exec -i "$sandbox_name" sh -c \
      "umask 077 && cat > $RALPH_SANDBOX_HOME/.ssh/$key" <"$HOME/.ssh/$key"
  fi
done

if [[ "$origin_url" == *@* ]]; then
  remote_host=$(echo "$origin_url" | sed -n 's/.*@\([^:]*\):.*/\1/p')
  if [ -n "$remote_host" ]; then
    ssh-keyscan "$remote_host" 2>/dev/null | docker sandbox exec -i "$sandbox_name" sh -c \
      "cat > $RALPH_SANDBOX_HOME/.ssh/known_hosts"
  fi
fi

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
  if ! docker sandbox run "$sandbox_name" -- --print "Reply with exactly: RALPH-OK" | grep -q "RALPH-OK"; then
    echo "Check failed: claude --print did not succeed inside the sandbox" >&2
    exit 1
  fi
  echo "Auth OK — provision check passed."
fi
