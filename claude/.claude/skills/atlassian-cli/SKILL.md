---
name: atlassian-cli
description: Use when the user asks to fetch, retrieve, or look up a Jira ticket, issue, or work item by key (e.g. PAC-755) using the Atlassian CLI. Covers acli verification, authentication, read-only scope safety, and structured ticket fetching with optional comments and linked issues.
---

# Atlassian CLI — Jira Ticket Fetching

Read-only Jira ticket fetching via the official Atlassian CLI (`acli`).

**NEVER run write commands** — `create`, `edit`, `transition`, `assign`, `delete`, `comment-create`, `archive`, `unarchive`, `clone`, or `create-bulk`. This skill is fetch-only.

## Phase 1: Verify

Run in order. **Fail fast** — stop and surface the error if any check fails.

**1. Check `acli` is installed:**

```bash
which acli
```

Not found → direct user to: https://developer.atlassian.com/cloud/acli/guides/quick-start-guide/

**2. Check authentication:**

```bash
acli jira auth status
```

Not authenticated → `acli jira auth login`

**3. Scope safety check:**

Tell the user: "Please confirm your `acli` API token has only `read:jira-work` scope. Tokens that also include `write:jira-work` can modify issues. The CLI cannot programmatically verify scopes — this must be confirmed at token setup time."

If the user is unsure, ask them to verify before continuing.

## Phase 2: Fetch Core

Always use `--json` for structured output:

```bash
acli jira workitem view KEY-123 --json
```

Default fields returned: `key`, `issuetype`, `summary`, `status`, `assignee`, `description`.

Present a structured summary:

- **Key**: PAC-755
- **Type**: Story / Bug / Task
- **Status**: In Progress
- **Assignee**: Name
- **Summary**: one-liner
- **Description**: full text

## Phase 3: Optional Content

After presenting core fields, ask:

> "Do you also want: **(A)** comments, **(B)** linked issues, **(C)** both, or **(D)** neither?"

Default: **neither**. Only fetch if the user explicitly requests it.

**Comments:**

```bash
acli jira workitem comment list --key KEY-123 --json
```

**Linked issues:**

```bash
acli jira workitem link list --key KEY-123 --json
```

## Remediation

| Problem | Fix |
|---------|-----|
| `acli` not found | Install: https://developer.atlassian.com/cloud/acli/guides/quick-start-guide/ |
| Not authenticated | `acli jira auth login` |
| Auth error on fetch | `acli jira auth status` → re-login or `acli jira auth switch` |
| Permission denied on ticket | User lacks access to that Jira project |
