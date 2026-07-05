# shellcheck shell=bash
# Iteration outcome classification from a claude stream-json transcript.
# Source this file; requires jq.

# jq filter that live-streams assistant text from a stream-json transcript.
# shellcheck disable=SC2034  # consumed by the sourcing scripts
RALPH_STREAM_TEXT_FILTER='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

RALPH_NO_MORE_TASKS_PROMISE='<promise>NO MORE TASKS</promise>'
# A blocked iteration commits what is safe and reports this, carrying an
# optional reason: <promise>BLOCKED: reason</promise>.
RALPH_BLOCKED_PROMISE='<promise>BLOCKED'

# classify_outcome TRANSCRIPT_FILE [RUN_EXIT_CODE]
# Prints one of: worked | no-more-tasks | blocked | failed
classify_outcome() {
  local transcript=$1 run_rc=${2:-0}

  if [ "$run_rc" -ne 0 ]; then
    echo "failed"
    return 0
  fi

  local result_json
  result_json=$(jq -c 'select(.type == "result")' "$transcript" 2>/dev/null | tail -n 1)
  if [ -z "$result_json" ]; then
    echo "failed"
    return 0
  fi

  local is_error result
  is_error=$(jq -r '.is_error // false' <<<"$result_json")
  result=$(jq -r '.result // ""' <<<"$result_json")

  if [ "$is_error" = "true" ]; then
    echo "failed"
    return 0
  fi

  if [[ "$result" == *"$RALPH_NO_MORE_TASKS_PROMISE"* ]]; then
    echo "no-more-tasks"
  elif [[ "$result" == *"$RALPH_BLOCKED_PROMISE"* ]]; then
    echo "blocked"
  else
    echo "worked"
  fi
}

# Map an outcome word to the ralph exit-status contract:
# 0 = worked, 10 = no-more-tasks, 1 = failed.
outcome_exit_code() {
  case "$1" in
    worked) echo 0 ;;
    no-more-tasks) echo 10 ;;
    blocked) echo 1 ;;
    *) echo 1 ;;
  esac
}
