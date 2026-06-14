# SYNC

Pull the latest changes before starting work:

```
git pull
```

# DISCOVERY

Read the files in `.context/` to find the PRD and plan for this project. These contain your task list and requirements.

Review the last few git commits to understand what work has been done:

```
git log -n 5 --format="%H%n%ad%n%B---" --date=short
```

If there are no more tasks to complete, output <promise>NO MORE TASKS</promise>.

# EXPLORATION

Explore the repo to understand the codebase.

# IMPLEMENTATION

Complete the next incomplete task from the plan.

# FEEDBACK LOOPS

Before committing, run the feedback loops:

- `pnpm run test` to run the tests
- `pnpm run typecheck` to run the type checker

# COMMIT AND PUSH

Make a git commit. The commit message must:

1. Include key decisions made
2. Include files changed
3. Blockers or notes for next iteration

After committing, push to the remote:

```
git push
```

# FINAL RULES

ONLY WORK ON A SINGLE TASK.
