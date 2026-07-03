#!/usr/bin/env bats
# Artefact-pair resolution: .context/ PRD+plan pairs changed on the branch
# relative to the default branch.

setup() {
  source "$BATS_TEST_DIRNAME/../lib/task.sh"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_SYSTEM=/dev/null

  ORIGIN_DIR="$BATS_TEST_TMPDIR/origin.git"
  PROJECT_DIR="$BATS_TEST_TMPDIR/project"

  git init -q --bare --initial-branch=main "$ORIGIN_DIR"
  git init -q --initial-branch=main "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  git config user.name test
  git config user.email test@example.com
  echo "hello" > README.md
  git add README.md
  git commit -qm "initial commit"
  git remote add origin "$ORIGIN_DIR"
  git push -qu origin main 2>/dev/null
  git remote set-head origin main
}

add_pair() {
  local slug=$1
  mkdir -p .context
  echo "# PRD: $slug" > ".context/prd-$slug.md"
  echo "# Plan: $slug" > ".context/plan-$slug.md"
  git add .context
  git commit -qm "docs: add $slug artefacts"
}

@test "a branch with one pair resolves it" {
  git checkout -qb feat/one
  add_pair one

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '.context/prd-one.md\t.context/plan-one.md')" ]
}

@test "a branch with two pairs yields both, one per line" {
  git checkout -qb feat/two
  add_pair alpha
  add_pair beta

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "$(printf '.context/prd-alpha.md\t.context/plan-alpha.md')" ]
  [ "${lines[1]}" = "$(printf '.context/prd-beta.md\t.context/plan-beta.md')" ]
}

@test "a branch with no artefact changes yields nothing" {
  git checkout -qb feat/none
  echo "change" >> README.md
  git add README.md
  git commit -qm "feat: unrelated change"

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "artefacts already on the default branch are not this branch's task" {
  add_pair old
  git push -q origin main
  git checkout -qb feat/next

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a plan changed on the branch pairs with a PRD from the default branch" {
  add_pair evolving
  git push -q origin main
  git checkout -qb feat/resume
  echo "- [ ] new phase" >> .context/plan-evolving.md
  git add .context
  git commit -qm "docs: extend plan"

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '.context/prd-evolving.md\t.context/plan-evolving.md')" ]
}

@test "a plan without its PRD is not a pair" {
  git checkout -qb feat/orphan
  mkdir -p .context
  echo "# Plan: orphan" > .context/plan-orphan.md
  git add .context
  git commit -qm "docs: plan without prd"

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pair resolution ignores non-artefact .context files" {
  git checkout -qb feat/extra
  add_pair real
  echo "notes" > .context/notes.md
  git add .context
  git commit -qm "docs: notes"

  run task_artefact_pairs
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}
