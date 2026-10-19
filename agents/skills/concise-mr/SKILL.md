---
name: concise-mr
description: Drafts a concise GitLab merge request description from the repository's MR template, describing behaviour rather than files. Use when the user asks for an MR description, an MR body, or to open a merge request.
---

# Concise MR

A merge request description is read by a reviewer deciding whether the change
is safe to merge. It answers why the change exists, what now behaves
differently, and what is deliberately left out. It never retells the diff.

## 1. Gather context

Run `scripts/mr-context` from inside the project. It prints the branch, the
ticket key, the commits since main, the changed files, and the repository's MR
template. The changed files are for your understanding only; they do not
appear in the description.

Done when: you can say in one sentence what a user or pipeline sees differently
after the merge.

## 2. Fill the template

Keep every heading, quick action and the `Closes` line from the template
verbatim. Fill each section with these contents, in this order:

| Section | Contents |
|---|---|
| Why | At most three bullets. Each is one sentence naming the observable problem: what failed, what was missing, what forced the change. The solution does not appear here. |
| What | At most four bullets. Each is one behaviour the change introduces, stated as what now happens. Name a library only when choosing it is itself the point. |
| Demo | The evidence that it works: what ran, against what, when. A video or screenshot only if one exists. |
| Testing | What was verified and how, one bullet per kind. If QE did no exploratory testing, say so. |
| Missing | What is deliberately not in this change, and the observable event that triggers the follow-up. |

Wording rules for every section:

- Bullets are one sentence, about twenty words, with a verb.
- Behaviour, not files: no file names, function names, or paths. A reviewer
  who wants those opens the diff.
- Environments, tenants and account names appear where they change what the
  reviewer must check.

Done when: every template section has content or an explicit "None", and no
bullet names a file.

## 3. Title and output

The title is the branch's commit subject with the ticket key in parentheses.

Save the body to `<task-dir>/MR-DESCRIPTION.md` and show it in full. Create
the merge request only when asked:

```bash
glab mr create --source-branch <branch> --target-branch main \
  --title "<title>" --description "$(cat ../MR-DESCRIPTION.md)" --yes
```

Then confirm the quick actions were consumed: the assignee is set and the
reviewers are populated.

Done when: the user has the full body and, if asked, the MR URL.

A complete example is in [references/example.md](references/example.md).
It governs shape only. Every date, environment, count and name in your draft
comes from this branch and this session, never from the example.
