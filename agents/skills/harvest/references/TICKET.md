# Ticket draft

One file per ticket at `<task-dir>/harvest/tickets/<slug>.md`. The first line is the summary; `scripts/jira-create` reads it as the Jira summary and the rest as the description.

```markdown
# <summary: the observable problem or the change, under 80 chars>

## Why

One to three sentences on what was observed, where, and when: the failure, the cost, the evidence. Name environments, tenants and dates where they change what the reader checks.

## What

The behaviour or structure that should exist afterwards. Behaviour, not files.

## Evidence

- Links or identifiers a reader can chase: pipeline, job, log group and time window, Rollbar item, MR.

## Out of scope

What this ticket deliberately leaves alone, if anything.
```

Rules:

- Written for a teammate who was not in the session: no "we noticed", no session-relative time.
- No code snippets or file paths; they go stale. A reader opens the repo for those.
- One ticket per problem. Two friction entries with one cause are one ticket.
