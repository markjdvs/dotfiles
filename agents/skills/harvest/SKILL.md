---
name: harvest
description: Harvest a task dir's /distil artefacts into tooling, tickets and instructions, by grilling the user through every friction entry and durable finding.
disable-model-invocation: true
---

# Harvest

Turn a task's Friction log and Snapshot into permanent value. Every entry gets a **disposition** and nothing is skipped silently. Task sessions only; does not touch the memory system.

## 1. Gather

Run `scripts/harvest-context`. It locates the task dir from the tmux session, prints the Snapshot, numbers every Friction entry (marking ones already harvested), and inventories the other artefacts. If it exits non-zero, stop and relay its message.

Read every artefact it lists that is a document (`.md`): analyses, plans, findings, notes. Logs, data files and scripts are opened only when a friction entry or a document points at them.

Run `scripts/harvest-commands`. It lists every command run in the task dir and its worktrees, from atuin, with its author (the user, or the agent that ran it), most repeated first. Together with the command lines quoted in the Snapshot, documents and task-dir scripts, these are the session's **procedures**: the raw material for scripts. The user's commands are candidate skills for the user; the agent's are candidate scripts for the skill that ran them.

Done when: every Friction entry and every document is read, the procedures are listed, and you can name each candidate for the tree below.

## 2. Build the harvest tree

Each candidate is a node. There are two kinds:

- **Friction entry** — an issue plus the tooling idea distil recorded.
- **Finding** — a fact or decision from the Snapshot or a document that would change how a future session works, in this project or any. A product observation is a ticket candidate, not a finding; a next step stays in the Snapshot and is not a node.
- **Procedure** — a CLI sequence the session ran to gather context or to sense-check a claim (a `curl`, `hurl`, `aws`, `glab` or `step` invocation that proved something). A procedure that ran more than once, or that any friction entry or finding relies on, is a node.

Each node gets exactly one disposition:

| Disposition | Where it lands |
|---|---|
| **tool** | agent context in `~/src/personal/dotfiles`: a skill (hand off to `/write-skills`), a script, a hook, a subagent. A procedure always lands as a script under the `scripts/` of the skill it serves, never as prose |
| **ticket** | the issue tracker, as a Jira work item: a bug, an architectural change, or product work the team must own |
| **instruction** | user-scoped `~/src/personal/dotfiles/agents/AGENTS.md` when it holds in every project; the project's own instructions or `CONTEXT.md` in the worktree when it is specific to that repo |
| **drop** | not worth acting on; say why in one clause |

Several nodes can share one disposition target: three friction entries may collapse into one skill or one ticket. Group them before asking. A fact already saved to memory still gets a disposition; memory is per machine and per project, and the question is whether it deserves a durable home too.

## 3. Grill

Call the Skill tool for `grill`. Its design tree is the harvest tree: one question per node or node group, your recommended disposition as the answer, the whole frontier in each round. Ask what only the user can decide: whether the friction is real enough to pay for tooling, whether a ticket is theirs to raise, whether a rule belongs in instructions or is one task's quirk. Facts you can check in the task dir or dotfiles, check yourself first.

Done when: every node has a disposition the user confirmed.

## 4. Act

Work the confirmed dispositions in this order, so earlier results can be referenced by later ones:

1. **instruction** — one bullet under the matching heading of the chosen file, in that file's existing voice. New domain terms go in the matching `CONTEXT.md`.
2. **tool** — a skill: call the Skill tool for `write-skills` with the brief, naming the procedures it must ship as scripts. A script, hook or subagent: create it in dotfiles under the convention the neighbouring files use.
3. **ticket** — draft each under `<task-dir>/harvest/tickets/<slug>.md` using [`references/TICKET.md`](references/TICKET.md), pulling evidence from the artefacts at draft time; show all drafts in one message, and on the user's go publish each with `scripts/jira-create <project> <type> <draft-file>`. Record the returned key.
4. **drop** — nothing to create.

Then stamp every entry: `scripts/harvest-mark <n> "<disposition>: <reference>"`, where the reference is the skill name, the AGENTS.md heading, the Jira key, or the drop reason. A stamped entry is skipped by the next run.

Done when: every node is stamped and every created thing exists on disk or in Jira.

## 5. Report

List what was created, by disposition, with paths and keys. Remind the user to commit dotfiles and run `skillshare sync` if a skill was added.
