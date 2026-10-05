# Developer Workflow

Personal dotfiles powering a tmux/worktree-based development workflow where work moves fluidly between human-in-the-loop sessions and autonomous (async) agent execution.

## Language

**Task**:
A unit of work on a single branch, spanning one or more projects. Each spanned project gets its own git worktree; all of them live under one shared task dir and are driven by one tmux session (`tasks/<branch>`).
_Avoid_: ticket, job

**Task dir**:
The shared parent directory of a task at `~/src/tasks/<branch>`, holding one Worktree subdirectory per project. Not itself a git repo — the repos are one layer down. Removed on Teardown when the task is finished.
_Avoid_: worktree (the task dir contains worktrees; it is not one)

**Worktree**:
The human's checkout of the task branch for a single project, at `~/src/tasks/<branch>/<repo>` under the task dir. One per project the task spans; created by `sessions create-task`.

**Workspace**:
The async agent's separate clone of the repo, mounted into its sandbox. Never the same directory as the worktree.
_Avoid_: using "worktree" and "workspace" interchangeably

**Sandbox**:
The Docker container (`docker sandbox`) in which the async agent runs, with the workspace mounted in.
_Avoid_: container (ambiguous)

**Artefacts**:
The PRD and plan markdown files in `.context/` on the task branch, produced by `/write-prd` and `/prd-to-plan`. They are the agent's task specification.

**Authoring**:
The human-in-the-loop segment of the pipeline (grill → PRD → plan) that produces the artefacts. Only humans author; the ralph loop never invokes authoring skills, it only consumes their artefacts.
_Avoid_: planning (collides with the plan artefact)

**Handoff**:
The human→async transition: artefacts committed on the branch, branch pushed to origin, sandbox bootstrapped, loop started.
_Avoid_: kickoff, dispatch

**Pause**:
The async→human transition. Graceful (`ralph pause` stop-file): the in-flight iteration completes, syncs, exits. Hard (Ctrl-C): the iteration is killed and dirty workspace state is wip-committed and pushed host-side. Either way the human resumes by pulling in the worktree.
_Avoid_: takeover, stop (hard kill without sync)

**Teardown**:
The clean end of a human Task session: its running processes are gracefully stopped and reaped before the session is dismantled, leaving no orphaned processes and no corrupted editor state. Distinct from Pause (which halts the async ralph loop); Teardown ends a human-in-the-loop session and, when the task is finished, releases its worktree.
_Avoid_: kill (the abrupt, orphan-leaving teardown this term is defined against)

**Distil**:
The manual pass (invoked as `/distil`), run before `/clear`, that distils the current session into task-local documents — the Snapshot and the Friction log — so working context can be reset back under the token ceiling without losing what matters. Task sessions only; does not touch memory.
_Avoid_: compaction (opaque, model-driven, in-context), Handoff (the human→async transition)

**Snapshot**:
A transient, curated capture of the session's working state — what's in flight, decisions made, next steps — written to `SNAPSHOT.md` in the task dir so a fresh session can resume after `/clear` without replaying the transcript. The task dir's `CLAUDE.md` points to it; it is read on demand, not auto-loaded. Discarded with the task.
_Avoid_: Artefacts (the task spec the agent consumes), memory (durable, cross-session)

**Friction log**:
A task-local, durable capture of operational or structural issues hit during a session and the tooling they suggest (skills, commands, hooks, ways of working), kept in `FRICTION.md` in the task dir. The human harvests it into real tooling over time; Teardown warns before deleting it.
_Avoid_: backlog (implies a formal, prioritised list rather than a scratch capture)

**Sync boundary**:
Origin (the git remote) is the single canonical exchange point between worktree and workspace. Neither side reads the other's filesystem.

**Ralph loop**:
The iterative async execution: each iteration pulls, does one task from the plan, runs feedback loops, commits, and pushes.
_Avoid_: async run (ambiguous with other async work)

**Iteration**:
One stateless agent session inside the ralph loop, completing exactly one plan phase: sync, bootstrap, implement via TDD, verify behaviourally, tick the phase's checkboxes in the plan, commit, push. All continuity between iterations lives in the repo, none in the session.

**Harness**:
An agent program that reads agent context and runs sessions — Claude Code, Cursor, Codex, Gemini CLI. Each has its own conventions for where it looks for context.
_Avoid_: provider, tool, agent (an agent runs inside a harness)

**Agent context**:
Everything authored once and made available to every harness: skills, subagents, and instructions. Harness configuration (settings, hooks, MCP servers) is not agent context.
_Avoid_: context (alone — collides with `.context/` artefacts), config

**Skill**:
A reusable, cross-project procedure available to every session. Earns its place only when wired into the pipeline (like bootstrap and tdd in the ralph loop) or actively invoked by the human; anything else is pruned. Either an invoked skill or a reference skill.

**Invoked skill**:
A skill the human triggers by name as a command (`/write-skill`). Named imperatively, verb first.
_Avoid_: command (a separate, legacy harness concept)

**Transform skill**:
An invoked skill that turns one named artefact into another, named `<input>-to-<output>` so the pipeline reads as a chain (`prd-to-plan`, `plan-to-tickets`). A skill whose only input is the conversation is not a transform and is named verb-first (`write-prd`).

**Reference skill**:
A skill the agent loads on its own when the situation matches (e.g. styling rules). Named for its subject; a noun is fine.

**Subagent**:
A named, specialised agent definition — its own prompt, and optionally restricted tools or model — that a session can delegate work to.
_Avoid_: agent (ambiguous with the harness's main agent)

**Model tier**:
How much model capability a subagent needs, stated once and translated per harness. Expressed in Claude's family names (haiku, sonnet, opus) as the shared vocabulary, not as a choice of Claude itself.
_Avoid_: model (names a specific harness's model)

**Instructions**:
Always-on guidance loaded into every session, authored once as AGENTS.md and presented to each harness under the name it expects (e.g. CLAUDE.md). Global or project-level.
_Avoid_: rules, memory

**Vendored**:
Third-party agent context copied into dotfiles, then adapted and owned exactly like the user's own. Upstream is a source of ideas, not a dependency.

**Third-party**:
A skill used exactly as upstream publishes it: recorded in dotfiles pinned to an upstream commit, refreshed from upstream, never edited. Editing one first makes it vendored.
_Avoid_: external, installed

**Trial**:
A third-party skill installed temporarily to evaluate it, kept visibly apart from everything else until it is promoted (to third-party or vendored) or discarded.

**Bootstrap**:
The idempotent step that makes a working copy runnable (deps installed, toolchain present, env stubbed). Runs at the start of every ralph iteration; prefers a project-provided entrypoint, else discovers from the repo.
_Avoid_: init, setup (overloaded)
