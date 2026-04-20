#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [ -z "${1:-}" ]; then
  echo "Usage: ralph once <plan-and-prd>"
  exit 1
fi

commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
prompt=$(cat "$SCRIPT_DIR/prompt.md")

claude --permission-mode acceptEdits \
  "Previous commits: $commits Plan and PRD: $1 $prompt"
