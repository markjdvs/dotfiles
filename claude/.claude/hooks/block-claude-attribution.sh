#!/usr/bin/env bash
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

case "$cmd" in
*"git commit"* | *"glab mr"* | *"gh pr"*)
  if printf '%s' "$cmd" | grep -qiE 'co-authored-by:[[:space:]]*claude|generated with \[?claude code'; then
    printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Claude attribution (Co-Authored-By trailer / Generated with Claude Code footer) is not allowed in commits or MR descriptions. Remove it and retry."}}'
    exit 0
  fi
  ;;
esac
exit 0
