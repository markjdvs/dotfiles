#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

usage() {
  cat <<EOF
Usage: ralph <subcommand>

Run from a task worktree — everything is derived from the cwd.

Subcommands:
  provision [--check]       Create/reuse the task's sandbox and workspace
  iterate [--prd P --plan P] Run exactly one loop iteration
  handoff [--iterations N]  Push, provision, and run the loop to completion
  pause                     Stop the loop gracefully at the iteration boundary
EOF
  exit 1
}

case "${1:-}" in
  provision) shift; exec "$SCRIPT_DIR/provision.sh" "$@" ;;
  iterate)   shift; exec "$SCRIPT_DIR/iterate.sh" "$@" ;;
  handoff)   shift; exec "$SCRIPT_DIR/handoff.sh" "$@" ;;
  pause)     shift; exec "$SCRIPT_DIR/pause.sh" "$@" ;;
  *)         usage ;;
esac
