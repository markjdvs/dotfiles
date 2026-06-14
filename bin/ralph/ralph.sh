#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

case "${1:-}" in
  once)  shift; exec "$SCRIPT_DIR/once.sh" "$@" ;;
  async) shift; exec "$SCRIPT_DIR/async.sh" "$@" ;;
  *)     echo "Usage: ralph {once <plan>|async <iterations>}"; exit 1 ;;
esac
