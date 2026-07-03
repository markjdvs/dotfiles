---
name: prd-to-plan
description: Turn a PRD into a multi-phase implementation plan using tracer-bullet vertical slices, saved as a local Markdown file in .context/. Use when user wants to break down a PRD, create an implementation plan, plan phases from a PRD, or mentions "tracer bullets".
---

# PRD to Plan

Break a PRD into a phased implementation plan using vertical slices (tracer bullets). Output is a Markdown file in `.context/`.

## Process

### 1. Confirm the PRD is in context

The PRD should already be in the conversation. If it isn't, ask the user to paste it or point you to the file.

### 2. Explore the codebase

If you have not already explored the codebase, do so to understand the current architecture, existing patterns, and integration layers.

### 3. Identify durable architectural decisions

Before slicing, identify high-level decisions that are unlikely to change throughout implementation:

- Route structures / URL patterns
- Database schema shape
- Key data models
- Authentication / authorization approach
- Third-party service boundaries

These go in the plan header so every phase can reference them.

### 4. Draft vertical slices

Break the PRD into **tracer bullet** phases. Each phase is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Do NOT include specific file names, function names, or implementation details that are likely to change as later phases are built
- DO include durable decisions: route paths, schema shapes, data model names
</vertical-slice-rules>

### 5. Quiz the user

Present the proposed breakdown as a numbered list. For each phase show:

- **Title**: short descriptive name
- **User stories covered**: which user stories from the PRD this addresses

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Should any phases be merged or split further?

Iterate until the user approves the breakdown.

### 6. Write the plan file

Write the plan as a Markdown file named after the feature, prefixed with `plan-` (e.g. `.context/plan-user-onboarding.md`). Use the [plan template](assets/plan-template.md).

Every phase must carry:

- **Acceptance criteria as observable behaviours** — each checkbox describes
  something watchable from outside the code ("Running X produces Y", "Given
  state C, doing D results in E"), never implementation facts ("X is
  implemented"). The plan is an executable spec: a criterion is verified by
  observing it, then its checkbox is ticked.
- **A Verification section** — the exact commands to run and what to observe
  to prove the phase end-to-end, including the executable acceptance test
  that should now exist and pass.
