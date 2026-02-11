---
name: commit
description: Create a well-formatted conventional commit
allowed-tools: Bash, Read, Grep
---

Create a git commit following conventional commit format:
- Analyze staged changes with `git diff --cached`
- Determine commit type (feat, fix, refactor, chore, docs, test)
- Write concise subject line (<50 chars)
- Add body only if changes need explanation
- NEVER add Co-Authored-By, Signed-off-by, or any trailers
