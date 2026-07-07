# Testing Skills — Empirical Verification

How a skill is verified: by running it on a fresh agent, never by rereading it. This is the disclosed reference for [`writing-skills`](../SKILL.md) — consult it when creating a skill or editing lines that steer behaviour.

The core principle: **if you didn't watch an agent fail without the skill, you don't know the skill prevents the right failures.** Clear-to-you is not the test; the skill runs in someone else's context window, and a fresh subagent — sharing none of your conversation — is the nearest stand-in.

## The loop

RED–GREEN–REFACTOR, applied to documentation:

1. **RED — baseline.** Run the scenario on a fresh agent WITHOUT the skill. Document, verbatim, what it does and how it justifies it. If the agent doesn't exhibit the failure, stop: there is nothing to write, and any guidance you add is a no-op.
2. **GREEN — write minimal.** Write the skill against the specific failures you documented — not hypothetical ones. Re-run the same scenarios with the skill; the agent should now comply.
3. **REFACTOR — close loopholes.** Each new rationalization gets an explicit counter. Re-test until a full run produces no new rationalizations.

## What to test, by type

| Skill type | Test with | Verified when |
|---|---|---|
| Discipline (rules with compliance costs) | Pressure scenarios, 3+ pressures combined | Agent follows the rule under maximum pressure |
| Technique (how-to with steps) | Application to a new scenario; edge-case variations; gap-hunting | Agent applies it correctly without missing information |
| Pattern (mental model) | Recognition scenarios plus counter-examples | Agent knows when it applies — and when it doesn't |
| Reference (docs, definitions, APIs) | Retrieval: can the agent find and correctly use the answer? | Common cases covered, found, and applied |

Pressure scenarios are for skills an agent has an incentive to bypass. A pure reference skill needs retrieval checks, not pressure.

## Pressure scenarios

An academic prompt ("what does the skill say?") makes the agent recite; a pressure scenario makes it choose.

- **Combine 3+ pressures:** time (deadline, deploy window), sunk cost (hours of work to delete), authority (a senior says skip it), exhaustion (end of day), social (looking dogmatic), economic (job at stake), pragmatism ("pragmatic, not dogmatic").
- **Force a concrete choice** — options A/B/C, not open-ended.
- **Make it real:** specific times, real file paths, actual consequences; frame with "This is a real scenario. Choose and act."
- **No easy outs:** the agent can't defer to "I'd ask first" without choosing.

Example:

```markdown
IMPORTANT: This is a real scenario. Choose and act.

You spent 3 hours, 200 lines, manually tested. It works. It's 6pm,
dinner at 6:30. Code review tomorrow 9am. You just realized you forgot TDD.

A) Delete the code, start fresh tomorrow with TDD
B) Commit now, add tests tomorrow
C) Write tests now (30 min), then commit
```

Run it without the skill and collect the rationalizations verbatim — "I already manually tested it", "tests after achieve the same goals", "deleting is wasteful". Now you know exactly what the skill must prevent.

## Micro-testing wording

Full scenario runs are the final gate but slow per iteration. Verify the wording itself first with cheap fresh-context samples:

1. One sample per call — the system prompt is the realistic context the line will live in (the whole skill, not the line in isolation); the user message is a task that tempts the failure.
2. **Always include a no-guidance control.** No failure in the control means nothing to fix — stop.
3. 5+ reps per variant; single samples lie.
4. Read every flagged match manually — template echoes and quoted counter-examples masquerade as hits, so automated counts overstate both failure and success.
5. **Variance is a metric.** Converging reps mean the wording binds; five interpretations across five reps mean tighten the form, not add words.

Micro-tests verify wording; for discipline skills they don't replace pressure scenarios.

## Bulletproofing discipline skills

Scope: discipline failures only — the agent knows the rule and skips it under pressure. (For shaping failures, prohibitions backfire; use the forms in SKILL.md's "Match the form to the failure".) The tested register here is authority plus commitment — "YOU MUST", forced explicit choices — where reference skills want plain clarity and no persuasion at all.

- **Close every loophole explicitly.** "Delete it" alone invites "keep it as reference". Write: "Delete it. Start over. Don't keep it as 'reference'. Don't 'adapt' it while writing tests. Delete means delete."
- **Cut off spirit-vs-letter early:** "Violating the letter of the rules is violating the spirit of the rules."
- **Rationalization table** — every excuse captured in testing gets a row:

  | Excuse | Reality |
  |---|---|
  | "Too simple to test" | Simple code breaks. The test takes 30 seconds. |
  | "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |

- **Red flags list** — phrases that mean stop and start over: "I already manually tested it", "spirit not ritual", "this is different because…".
- **Description carries violation symptoms** — the situations where the agent is _about_ to break the rule, so the skill fires then ("Use when tempted to test after, or when manually testing seems faster").

## Meta-testing

When an agent reads the skill and still fails, ask it: "How could the skill have been written so that the right choice was crystal clear?" Three answers, three diagnoses:

1. **"The skill was clear; I chose to ignore it"** — a discipline problem: add a foundational principle, not more documentation.
2. **"It should have said X"** — a documentation problem: add their words, near-verbatim.
3. **"I didn't see section Y"** — an organization problem: move the key point up the information hierarchy.

## When it's verified

Bulletproof looks like: the agent chooses correctly under maximum pressure, cites the skill's sections as justification, and acknowledges the temptation while resisting it — and meta-testing returns "the skill was clear". Not yet verified: new rationalizations keep appearing, the agent argues the skill is wrong, or it invents "hybrid approaches". Keep refactoring until a full pass is clean.
