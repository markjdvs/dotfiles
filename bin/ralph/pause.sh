#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/task.sh
source "$SCRIPT_DIR/lib/task.sh"

if [ -n "${1:-}" ]; then
  echo "Usage: ralph pause"
  exit 1
fi

branch=$(task_branch)
stop_file=$(task_stop_file)

mkdir -p "$(dirname "$stop_file")"
touch "$stop_file"

echo "Pause requested for '$branch'."
echo "The loop will finish the in-flight iteration, then stop cleanly."
echo "(If no loop is running, the request is cleared on the next handoff.)"
