#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.local/bin/ralph"

case "${1:-}" in
  install)
    mkdir -p "$(dirname "$TARGET")"
    ln -sfn "$SCRIPT_DIR/ralph.sh" "$TARGET"
    echo "Linked: $TARGET → $SCRIPT_DIR/ralph.sh"
    ;;
  uninstall)
    if [ -L "$TARGET" ]; then
      rm "$TARGET"
      echo "Removed: $TARGET"
    else
      echo "Nothing to remove."
    fi
    ;;
  status)
    if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" = "$SCRIPT_DIR/ralph.sh" ]; then
      echo "OK: $TARGET → $(readlink -f "$TARGET")"
    elif [ -e "$TARGET" ]; then
      echo "Conflict: $TARGET exists but is not our symlink" >&2
      exit 1
    else
      echo "Not installed. Run: $0 install" >&2
      exit 1
    fi
    ;;
  *)
    echo "Usage: $(basename "$0") {install|uninstall|status}"
    exit 1
    ;;
esac
