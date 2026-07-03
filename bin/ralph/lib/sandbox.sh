# shellcheck shell=bash
# Sandbox, auth, push, and notification helpers shared by the ralph commands.
# Source after lib/task.sh.

RALPH_KEYCHAIN_SERVICE="ralph-claude-token"
# shellcheck disable=SC2034  # consumed by the sourcing scripts
RALPH_SANDBOX_HOME="/home/agent"

sandbox_exists() {
  local name=$1
  docker sandbox ls 2>/dev/null | awk 'NR>1 {print $1}' | grep -qxF "$name"
}

sandbox_remove() {
  local name=$1
  docker sandbox stop "$name" 2>/dev/null || true
  docker sandbox rm "$name" 2>/dev/null || true
}

require_docker() {
  if ! command -v docker &>/dev/null; then
    echo "Error: docker is not installed. Install Docker Desktop from https://www.docker.com/products/docker-desktop" >&2
    return 1
  fi
}

# Print the long-lived setup-token from the Keychain; fails silently if absent.
ralph_token() {
  security find-generic-password -s "$RALPH_KEYCHAIN_SERVICE" -w 2>/dev/null
}

# Ensure the setup-token exists, walking through creation once if it doesn't.
ralph_ensure_token() {
  if ralph_token >/dev/null; then
    return 0
  fi

  if [ ! -t 0 ]; then
    echo "Error: no ralph setup-token in the Keychain and no TTY to create one." >&2
    echo "Run 'ralph provision' interactively once to set it up." >&2
    return 1
  fi

  cat >&2 <<EOF
No ralph setup-token found in the macOS Keychain (service: $RALPH_KEYCHAIN_SERVICE).

The sandboxed agent authenticates with a long-lived token backed by your
Claude subscription, kept separate from your interactive session so async
runs never log you out.

Launching 'claude setup-token' — complete the browser flow, then paste the
generated token (sk-ant-oat01-...) below.
EOF

  claude setup-token || true

  local token
  printf 'Paste setup-token: ' >&2
  read -rs token
  echo >&2

  if [[ ! "$token" =~ ^sk-ant- ]]; then
    echo "Error: that doesn't look like a setup-token (expected sk-ant-... prefix)." >&2
    return 1
  fi

  security add-generic-password -a "$USER" -s "$RALPH_KEYCHAIN_SERVICE" -w "$token" -U
  echo "Stored setup-token in Keychain (service: $RALPH_KEYCHAIN_SERVICE)." >&2
}

ralph_notify() {
  local title=$1 message=$2
  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# Push a branch, skipping CI unless --run-ci is given. Falls back to a plain
# push (with a warning) when the remote doesn't support push options.
ralph_push() {
  local dir=$1 branch=$2 mode=${3:---ci-skip}

  if [ "$mode" = "--run-ci" ]; then
    git -C "$dir" push origin "$branch"
    return
  fi

  local err
  if ! err=$(git -C "$dir" push -o ci.skip origin "$branch" 2>&1); then
    if grep -qi "push options" <<<"$err"; then
      echo "warning: remote does not support push options; pushing without ci.skip" >&2
      git -C "$dir" push origin "$branch"
    else
      echo "$err" >&2
      return 1
    fi
  else
    echo "$err"
  fi
}
