---
name: to-prd
description: Turn the current conversation context into a PRD and save it as a local markdown file in .context/. Use when user wants to create a PRD from the current context.
---

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already.

2. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

3. Write the PRD using the [PRD template](assets/prd-template.md) and save it as a markdown file in the `.context/` directory at the project root. Use the naming convention `prd-{description-of-work}.md` where `{description-of-work}` is a short kebab-case summary of the feature/work (e.g. `prd-user-authentication.md`, `prd-api-rate-limiting.md`). Create the `.context/` directory if it doesn't exist.

