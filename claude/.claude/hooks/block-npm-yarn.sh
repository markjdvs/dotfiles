#!/usr/bin/env bash
set -euo pipefail

command=$(jq -r '.tool_input.command // empty')

if printf '%s' "$command" | grep -qE '(^|[^[:alnum:]_.-])(npm|yarn)([[:space:]]|$|;)'; then
  echo "npm/yarn are blocked on this machine. Use pnpm instead: pnpm install, pnpm add, pnpm exec. npx is allowed." >&2
  exit 2
fi

exit 0
