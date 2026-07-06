# Developer Workflow

Personal dotfiles powering a tmux/worktree-based development workflow where work moves fluidly between human-in-the-loop sessions and autonomous (async) agent execution.

## Language

**Task**:
A unit of work identified by `parent/project/branch`, with its own git worktree and tmux session.
_Avoid_: ticket, job

**Worktree**:
The human's checkout of a task branch at `$project/.worktrees/<branch>`, created by `sessions create-task`.

**Workspace**:
The async agent's separate clone of the repo, mounted into its sandbox. Never the same directory as the worktree.
_Avoid_: using "worktree" and "workspace" interchangeably

**Sandbox**:
The Docker container (`docker sandbox`) in which the async agent runs, with the workspace mounted in.
_Avoid_: container (ambiguous)

**Artefacts**:
The PRD and plan markdown files in `.context/` on the task branch, produced by `/to-prd` and `/prd-to-plan`. They are the agent's task specification.

**Authoring**:
The human-in-the-loop segment of the pipeline (grill → PRD → plan) that produces the artefacts. Only humans author; the ralph loop never invokes authoring skills, it only consumes their artefacts.
_Avoid_: planning (collides with the plan artefact)

**Handoff**:
The human→async transition: artefacts committed on the branch, branch pushed to origin, sandbox bootstrapped, loop started.
_Avoid_: kickoff, dispatch

**Pause**:
The async→human transition. Graceful (`ralph pause` stop-file): the in-flight iteration completes, syncs, exits. Hard (Ctrl-C): the iteration is killed and dirty workspace state is wip-committed and pushed host-side. Either way the human resumes by pulling in the worktree.
_Avoid_: takeover, stop (hard kill without sync)

**Sync boundary**:
Origin (the git remote) is the single canonical exchange point between worktree and workspace. Neither side reads the other's filesystem.

**Ralph loop**:
The iterative async execution: each iteration pulls, does one task from the plan, runs feedback loops, commits, and pushes.
_Avoid_: async run (ambiguous with other async work)

**Iteration**:
One stateless agent session inside the ralph loop, completing exactly one plan phase: sync, bootstrap, implement via TDD, verify behaviourally, tick the phase's checkboxes in the plan, commit, push. All continuity between iterations lives in the repo, none in the session.

**Bootstrap**:
The idempotent step that makes a working copy runnable (deps installed, toolchain present, env stubbed). Runs at the start of every ralph iteration; prefers a project-provided entrypoint, else discovers from the repo.
_Avoid_: init, setup (overloaded)
