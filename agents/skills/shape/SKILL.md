---
name: shape
description: Run a collaborative Shape Up shaping session that produces a work-package doc. Use when the user wants to shape a piece of work, scope a project to an appetite, prepare a pitch or work package for the betting table, or derisk an idea before building.
---

The human shapes; you interview, investigate, and scribe. Every solution decision — which option fits the problem, where slice boundaries fall, what is out of scope — belongs to the human. Your contributions are recon (facts read from code), challenges ("this seam is unverified — Sufficient or Good?"), and drafting labour. Propose options and drafts freely, but as moves in a conversation — never go dark and return with a finished solution.

Two fixed points anchor every session:

- **The problem is the anchor.** If the problem is wrong, the work cannot solve it. Critiquing a wrong solution is easier than proposing a right one, so options exist to be shot down — each elimination says what the problem is *not*, and sharpens what it is.
- **Appetite is a constraint, not an estimate.** Confidence is expressed in unknowns, never in day-estimates. Time appears exactly once: the appetite itself, for communicating with the wider organisation.

## Phase 1 — Intake

Ask for three things, one at a time:

1. The problem statement, however fuzzy.
2. The appetite. This is a hard gate: if the user cannot state one, stop — shaping without an appetite regresses to estimation — and offer to resume when they have one. Never propose an appetite yourself.
3. The repos in play. Siblings usually live alongside the current repo in the same parent directory; you will surface more candidates after recon.

Done when all three are stated.

## Phase 2 — Recon

Read-only scan of the repos in play: the systems the problem touches, their integration seams, existing instrumentation and data capture. Where a seam crosses into a repo you cannot read, name it as a candidate sibling ("this calls pricing-api — is that checked out alongside?") and ask. Anything you cannot verify by reading enters the unknowns register as Open.

Keep findings to inform phase 3; do not dump them on the user. Done when you hold a seam map and a first unknowns list.

## Phase 3 — Sharpen the problem

Present 2–3 genuinely different options, one at a time, each as a coarse Mermaid breadboard (places, affordances, connections — no visual design), framed as: "if the problem is X, this solves it." Invite critique. Record what each rejection taught about the problem, and restate the sharpened problem statement before showing the next option.

Exit on whichever comes first:

- **One shape fits** and the user says so → phase 4. The rejected options and their lessons become the "What this is not" trail — evidence about the problem, kept separate from risks.
- **The problem will not hold** — critiques keep pointing at different problems, or the pain cannot be observed. Say so plainly, write a problem brief from [references/PROBLEM-BRIEF.md](references/PROBLEM-BRIEF.md), and end the session there. Never inflate a weak problem to justify a shape doc; discovering that shaping is premature is a win, not a failure.

## Phase 4 — Slice and derisk

With the user, cut the chosen option into the ladder (below) and drive out each slice's Insights fork (below). Then make the deep recon pass: verify every seam each slice crosses, and assign every unknown a fate:

| Fate | Meaning | Ladder effect |
|---|---|---|
| **Resolved** | answered by reading code | its work may sit in Sufficient |
| **Patched** | human declared an approach without proving it | Sufficient only if the patch is trivially safe |
| **Open** | only building will answer it | its work leaves Sufficient; the user places it — Good when the blast radius is contained, Great when it could eat weeks |

Fit-to-appetite is judged by unknowns, not effort: known work can fill its budget; unknowns demand buffer in proportion to their number. Unknowns gravitate up the ladder.

Checkpoint: restate the slice boundaries and the unknowns register; the user confirms before any doc is written.

## Phase 5 — Write and review

Write `.context/shape-<slug>.md` following [references/DOC-TEMPLATE.md](references/DOC-TEMPLATE.md). Every template section — and each row of the Solution Assessment table — appears, in one of three states: transcribed from decisions the user made in session; drafted from code evidence and flagged for human verification; or scaffolded empty for a human to fill. No section is silently absent.

Walk the user through the doc and edit inline. Done when the user calls it betting-table-ready — a derisked shape a product engineer can take to production.

## The ladder

Sufficient ⊂ Good ⊂ Great: cumulative slices of one solution within one appetite, each independently deployable and instrumented.

- **Sufficient** — survives a bad cycle. Scope-hammered, zero open unknowns (patched only if trivially safe), too risk-free to fail.
- **Good** — the realistic fill of the appetite, building on Sufficient.
- **Great** — fits only if the named risks don't bite.

If moving up a level would rip out work from the level below, the lower level is shaped wrong — reshape before writing. Scope not reached in the cycle returns to the betting table as a fresh pitch, argued from the shipped slice's Insights data; it never rolls over.

## The Insights fork

Per slice, three parts, drawn as a decision fork:

1. **The question** this slice answers. Sufficient's question validates the problem ("was this the real pain?"); Good's and Great's are investment questions ("does more depth here pay?").
2. **The signal** — the behavioural or transactional events that answer it, checked during recon against what data capture already exists.
3. **The decision** it feeds: "if X after N weeks → pitch the next level; if not → stop, the problem is served or was mis-stated."

The events a slice needs are part of that slice's scope — a slice that ships blind is not shippable. Scope-hammer the instrumentation too: a crude proxy beats a measurement platform.

## Diagrams

Favour diagrams over prose: every structural section leads with a Mermaid diagram, prose reduced to short captions; only narrative (the problem statement) stays prose. Draw coarse on purpose — breadboard fidelity, no pixel-level UI, no exhaustive class diagrams. An over-specified diagram over-constrains the product engineer exactly as over-specified shaping does. The section-by-section diagram mapping lives in the template.
