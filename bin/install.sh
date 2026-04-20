#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for dir in "$BIN_DIR"/*/; do
  [ -f "$dir/install.sh" ] || continue
  echo "  → $(basename "$dir")"
  "$dir/install.sh" "${1:-install}"
done
