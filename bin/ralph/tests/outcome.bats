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

@test "the BLOCKED promise classifies as blocked" {
  run classify_outcome "$FIXTURES/blocked.jsonl" 0
  [ "$status" -eq 0 ]
  [ "$output" = "blocked" ]
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

@test "push_decision ships a final phase declared complete in the same turn" {
  # The regression: agent implemented the last phase, committed, AND emitted
  # NO MORE TASKS in one turn. A commit exists and the plan is fully ticked —
  # it must push with CI, never be stranded on 'no-more-tasks'.
  [ "$(push_decision true no-more-tasks 0)" = "run-ci" ]
}

@test "push_decision skips CI while phases remain" {
  [ "$(push_decision true worked 2)" = "ci-skip" ]
  [ "$(push_decision true blocked 3)" = "ci-skip" ]
}

@test "push_decision pushes with CI when a worked iteration ticks the last box" {
  [ "$(push_decision true worked 0)" = "run-ci" ]
}

@test "push_decision does nothing without a commit" {
  [ "$(push_decision false worked 2)" = "none" ]
  [ "$(push_decision false no-more-tasks 0)" = "none" ]
}

@test "push_decision never auto-pushes a failed run" {
  [ "$(push_decision true failed 1)" = "none" ]
}

@test "outcome exit codes distinguish worked, no-more-tasks, blocked, and failed" {
  [ "$(outcome_exit_code worked)" -eq 0 ]
  [ "$(outcome_exit_code no-more-tasks)" -eq 10 ]
  [ "$(outcome_exit_code blocked)" -eq 1 ]
  [ "$(outcome_exit_code failed)" -eq 1 ]
}
