#!/usr/bin/env bats
# Iteration outcome classification from stream-json transcripts.

setup() {
  source "$BATS_TEST_DIRNAME/../lib/outcome.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures/transcripts"
}

@test "a successful iteration classifies as worked" {
  run classify_outcome "$FIXTURES/worked.jsonl" 0
  [ "$status" -eq 0 ]
  [ "$output" = "worked" ]
}

@test "the NO MORE TASKS promise classifies as no-more-tasks" {
  run classify_outcome "$FIXTURES/no-more-tasks.jsonl" 0
  [ "$status" -eq 0 ]
  [ "$output" = "no-more-tasks" ]
}

@test "an error result classifies as failed" {
  run classify_outcome "$FIXTURES/error.jsonl" 0
  [ "$output" = "failed" ]
}

@test "a transcript without a result line classifies as failed" {
  run classify_outcome "$FIXTURES/truncated.jsonl" 0
  [ "$output" = "failed" ]
}

@test "a non-zero run exit code classifies as failed regardless of transcript" {
  run classify_outcome "$FIXTURES/worked.jsonl" 137
  [ "$output" = "failed" ]
}

@test "the stream filter extracts assistant text" {
  run bash -c "jq -rj '$RALPH_STREAM_TEXT_FILTER' '$FIXTURES/worked.jsonl'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Syncing and bootstrapping"* ]]
  [[ "$output" == *"Phase 1 implemented"* ]]
}

@test "outcome exit codes distinguish worked, no-more-tasks, and failed" {
  [ "$(outcome_exit_code worked)" -eq 0 ]
  [ "$(outcome_exit_code no-more-tasks)" -eq 10 ]
  [ "$(outcome_exit_code failed)" -eq 1 ]
}
