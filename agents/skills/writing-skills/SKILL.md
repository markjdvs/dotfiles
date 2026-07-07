---
name: writing-skills
description: Reference for writing and editing skills well — the vocabulary and principles that make a skill predictable. Use when creating new skills, editing or reviewing existing skills, verifying a skill works before deployment, or diagnosing why a skill misfires or fires unreliably.
---

A skill exists to wrangle determinism out of a stochastic system. **Predictability** — the agent taking the same _process_ every run, not producing the same output — is the root virtue; every lever below serves it.

**Bold terms** are defined in [`references/GLOSSARY.md`](references/GLOSSARY.md); look them up there for the full meaning. For the file format and packaging rules a skill must satisfy — frontmatter fields, naming, directory layout — see [`references/SPEC.md`](references/SPEC.md).

## Should this be a skill?

A skill earns its place when the technique is non-obvious, reusable across projects, and broadly applicable. A project-specific convention belongs in the project's instructions file, not a skill. And a rule enforceable with a regex, a linter, or validation should be automated instead — spend skill prose only on judgment calls.

## Invocation

Two choices, trading different costs:

- A **model-invoked** skill keeps a **description**, so the agent can fire it autonomously _and_ other skills can reach it (you can still type its name too). It contributes to **context load** — the description sits in the window every turn. Mechanics: omit `disable-model-invocation`, and write a model-facing description with rich trigger phrasing ("Use when the user wants…, mentions…").
- A **user-invoked** skill strips the description from the agent's reach: only you, typing its name, can invoke it — and no other skill can. Zero context load, but it spends **cognitive load**: _you_ are the index that must remember it exists. Mechanics: set `disable-model-invocation: true`; the `description` becomes human-facing — a one-line summary, trigger lists stripped.

Pick model-invocation only when the agent must reach the skill on its own, or another skill must. If it only ever fires by hand, make it user-invoked and pay no context load.

When user-invoked skills multiply past what you can remember, that piled-up cognitive load is cured by a **router skill**: one user-invoked skill that names the others and when to reach for each.

## Writing the description

A model-invoked **description** does two jobs — state what the skill is, and list the **branches** that should trigger it. Every word increases **context load**, so a description earns even harder pruning than the body:

- **Front-load the skill's leading word** — the description is where it does its invocation work.
- **One trigger per branch.** Synonyms that rename a single branch are **duplication** — "build features using TDD … asks for test-first development" is one branch written twice. Collapse them; keep only genuinely distinct branches.
- **Cut identity that's already in the body.** Keep the description to triggers, plus any "when another skill needs…" reach clause.
- **Triggers only — never a workflow summary.** A description that sketches the skill's process becomes a shortcut the agent takes instead of reading the body: in testing, a description saying "code review between tasks" produced one review where the body required two. Say when to fire; let the body own how.

The `name` is preloaded alongside the description and does invocation work too: verb-first, named for the action or the core insight — `condition-based-waiting`, not `async-test-helpers`.

## Information hierarchy

A skill is built from two content types — **steps** and **reference** — that mix freely: a skill can be all steps, all reference, or both. The core decision is which to use and where each sits on the **information hierarchy**, a ladder ranked by how immediately the agent needs the material:

1. **In-skill step** — an ordered action in `SKILL.md`, the primary tier: what the agent does, in order. Each step ends on a **completion criterion**, the condition that tells the agent the work is done. Make it _checkable_ (can the agent tell done from not-done?) and, where it matters, _exhaustive_ ("every modified model accounted for", not "produce a change list") — a vague criterion invites **premature completion**.
2. **In-skill reference** — a definition, rule, or fact in `SKILL.md`, consulted on demand. Often a legitimately flat peer-set (every rule of a review on one rung) — a fine arrangement, not a smell. _This skill is all reference._
3. **External reference** — reference pushed out of `SKILL.md` into a separate file, reached by a **context pointer**, loaded only when the pointer fires. (Spans _disclosed_ reference — a file in the skill's `references/` directory, still part of the skill — through fully **external reference** that lives outside the skill system and any skill can point at.)

A demanding completion criterion drives thorough **legwork** — the digging the agent does within the work — whether the skill has steps or not, since "every rule applied" binds flat reference just as "every step done" binds a sequence.

Push too little down and the top bloats; push too much and you hide material the agent actually needs. That tension is the whole decision.

For examples, one excellent, runnable example beats many mediocre ones — and it shows a reusable pattern, never a narrative of how you solved it once.

## Scripts

A procedure written in prose is re-derived on every run — the agent improvises the commands, and improvisation is variance. Wherever a repeatable CLI procedure exists — to gather context or to execute a change — abstract it into a **script** in `scripts/` and word the step to run it ("run `scripts/<name>`"), never to describe it. This is the strongest lever on **predictability** in the whole skill: prose steers the model's sampling, but a script removes the model from the loop for that step, converging probabilistic output to determinism — same inputs, same behaviour, every run.

The division of labour mirrors the gate above: mechanics belong in scripts; prose is spent on judgment calls. A script should solve, not punt — handle its own edge cases, document its dependencies, and fail with an error that tells the agent what to do next, rather than handing half the work back to the improvisation it exists to retire.

**Progressive disclosure** is the move down the ladder — out of `SKILL.md` into a linked file — so the top stays legible and nothing loads before it is needed: the agent preloads only the description, reads `SKILL.md` on activation, and reaches disclosed files only when a pointer fires. Mechanics: a linked `.md` file in the skill's `references/` directory, named for what it holds (this skill discloses its full definitions to `references/GLOSSARY.md`); keep pointers one level deep from `SKILL.md`. Some skills are used in more than one way, and each distinct way is a **branch** — different runs taking different paths through the skill. Branching is the cleanest disclosure test: inline what every branch needs, and push behind a pointer what only some branches reach. A **context pointer**'s _wording_, not its target, decides when and how reliably the agent reaches the material.

Where the ladder decides _how far down_ a piece sits, **co-location** decides _what sits beside it_ once there: keep a concept's definition, rules, and caveats under one heading rather than scattered, so reading one part brings its neighbours with it.

## When to split

**Granularity** is how finely you divide skills, and each cut spends one of the two loads, so split only when the cut earns it. Two cuts:

- **By invocation** — split off a **model-invoked** skill when you have a distinct **leading word** that should trigger it on its own, or another skill must reach it. You pay **context load** for the new always-loaded **description**, so that independent reach has to be worth it.
- **By sequence** — split a run of **steps** when the steps still ahead (a step's **post-completion steps**) tempt the agent to rush the one in front of it (**premature completion**). Keeping them out of view encourages the agent to do more **legwork** on the current task.

## Pruning

Keep each meaning in a **single source of truth**: one authoritative place, so changing the behaviour is a one-place edit.

Check every line for **relevance**: does it still bear on what the skill does?

Then hunt **no-ops** sentence by sentence, not just line by line: run the no-op test on each sentence in isolation, and when one fails, delete the whole sentence rather than trim words from it. Be aggressive — most prose that fails should go, not be rewritten.

## Leading words

A **leading word** is a compact concept already living in the model's pretraining that the agent thinks with while running the skill (e.g. _lesson_, _fog of war_, _tracer bullets_). Repeated throughout the text (though not necessarily - a strong leading word might only be needed once), it accumulates a distributed definition and anchors a whole region of behaviour in the fewest tokens, by recruiting priors the model already holds.

It serves predictability twice. In the body it anchors _execution_: the agent reaches for the same behaviour every time the word appears. In the description it anchors _invocation_: when the same word lives in your prompts, docs, and code, the agent links that shared language to the skill and fires it more reliably.

Hunt for opportunities to refactor skills to use leading words. A triad spelled out at three sites (**duplication**), a description spending a sentence to gesture at one idea — each is a passage begging to **collapse** into a single token. Examples include:

- "fast, deterministic, low-overhead" -> _tight_ — one quality restated across a phase — into a single pretrained word (a _tight_ loop).
- "a loop you believe in" -> _red_ — converts a fuzzy gate into a binary observable state (the loop goes _red_ on the bug, or it doesn't).

You win twice over: fewer tokens, _and_ a sharper hook for the agent to hang its thinking on. Assume every skill is carrying restatements that leading words retire — go find them.

## Match the form to the failure

Classify the baseline failure before writing the cure — the form that fixes one failure type backfires on another:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Skips a rule under pressure — knows better, does it anyway | Prohibition plus explicit rationalization counters ([`references/TESTING.md`](references/TESTING.md)) | Soft guidance ("prefer…", "consider…") |
| Complies, but the output is the wrong shape | Positive recipe: state what the output _is_ — its parts, in order | A prohibition list ("don't restate", "never narrate") |
| Omits an element from output it already produces | Structural: a REQUIRED slot in the template it fills | Prose reminders near the template |
| Behaviour should depend on a condition | Conditional keyed to an observable predicate ("if the brief exists, reference it") | Unconditional rule plus exemption clauses |

Two wording rules hold whichever form you pick. A nuance clause ("don't X unless it matters") reopens the negotiation — in wording tests, appending one to a winning recipe degraded it from consistent to noisy; express a real exception as its own conditional on an observable predicate. And exemption clauses don't scope — "this limit doesn't apply to code blocks" still suppresses code blocks; restructure so the rule can't reach the exempt part.

## Verifying

A skill is verified by watching a fresh agent — a subagent sharing none of your context — fail without it and comply with it; rereading the text verifies nothing, because clear-to-you is the wrong test for a skill that runs in someone else's window. Run the control first: baseline the agent _without_ the skill, and if the failure never appears there is nothing to write — the whole skill is a **no-op**. Verify in proportion to type: pressure scenarios for discipline skills, application scenarios for techniques, retrieval checks for reference. When creating a skill, or editing lines that steer behaviour, follow the loop in [`references/TESTING.md`](references/TESTING.md) — baseline, pressure scenarios, loophole-closing, micro-tests — before deploying.

## Failure modes

Use these to diagnose issues the user may be having with the skill.

- **Premature completion** — ending a step before it's genuinely done, attention slipping to _being done_. Defence, in order: sharpen the completion criterion first (cheap, local); only if it is irreducibly fuzzy _and_ you observe the rush, hide the post-completion steps by splitting (the sequence cut).
- **Duplication** — the same meaning in more than one place. Costs maintenance and tokens, and inflates a meaning's prominence on the ladder past its real rank.
- **Sediment** — stale layers that settle because adding feels safe and removing feels risky. The default fate of any skill without a pruning discipline.
- **Sprawl** — a skill simply too long, even when every line is live and unique. Hurts readability and maintainability and wastes tokens. The cure is the ladder: disclose **reference** behind pointers, and split by **branch** or sequence so each path carries only what it needs.
- **No-op** — a line the model already obeys by default, so you pay load to say nothing. The test: does it change behaviour versus the default? A weak leading word (_be thorough_ when the agent is already thorough-ish) is a no-op; the fix is a stronger word (_relentless_), not a different technique.
- **Negation** — steering by prohibition backfires on _shaping_ problems: _don't think of an elephant_ names the elephant and makes it more available, not less, so banning a shape of output half-instructs it. Prompt the **positive** — state the target behaviour so the banned one is never spoken. The exception is a _discipline_ failure — a rule the agent knows and skips under pressure — where prohibition is the right form, paired with explicit rationalization counters (see Match the form to the failure).
