# Ticket Session

A ticket session guides a developer through implementing real work from a ticket description. The agent follows the [role](role.md) contract throughout.

## Prerequisites

- The developer is on a short-lived branch off main
- The developer has the `/mentor ticket` command invoked

## Flow

### 1. Receive the Ticket

The developer pastes the ticket description (from Jira, Linear, or any tracker). Read it carefully.

### 2. Understand

Before any code is written, the agent asks clarifying questions -- one at a time:

- "What does 'done' look like for this ticket?"
- "What are the acceptance criteria?"
- "Are there any constraints or dependencies you're aware of?"
- "Which parts of the codebase do you think this will touch?"
- "Is there anything in this ticket that's ambiguous to you?"

The goal is twofold: ensure the developer understands the ticket fully, and build the habit of questioning requirements before coding. Don't proceed until the developer can articulate what they're building and why.

### 3. Decompose Incrementally

Don't ask for a full breakdown of the entire ticket upfront -- a long task list is overwhelming, especially for less experienced developers, and the later tasks often change once the early ones are done.

Instead, guide the developer to identify just the **first one or two tasks**:

- "What's the very first thing you'd need to build?"
- "What's the smallest piece of this you could implement and commit?"
- "Which part has the least dependencies?"

Get them started on those tasks immediately. After they've completed a task or two, circle back:

- "Now that you've built this, what feels like the natural next step?"
- "Has anything you've learned so far changed how you'd approach the rest?"

Repeat this cycle -- identify the next task or two, implement, circle back -- until the ticket is complete. The plan emerges as they build, which keeps momentum high and avoids analysis paralysis.

### 4. Implement (per task)

For each task:

**a) Plan the approach** -- Brief Socratic discussion. "How are you thinking about implementing this?" Listen, then ask one or two probing questions about the approach before they start coding. Don't prescribe a solution.

**b) Study existing patterns** -- Before any new code is written, ask the developer to find an existing implementation of something similar in the codebase. "Is there anything in the codebase that already does something like this? Let's look at it first." Walk through the reference together. This surfaces conventions, prevents copy-paste-without-adaptation, and gives the developer a concrete model to work from rather than inventing from scratch.

**c) Write code** -- The developer writes the implementation. Observe. You may ask clarifying questions about intent ("What's this variable tracking?") but don't steer the design at this stage.

**d) Probe** -- Once the developer has working code, ask Socratic questions targeting potential design weaknesses. See [role.md](role.md) for the consequence loop details.

**e) Challenge** -- Write failing tests that expose the weaknesses identified during probing. One test at a time.

**f) Fix** -- The developer refactors to pass the tests. Guide with questions, never with code.

**g) Reflect** -- Name the principle. Brief -- don't lecture.

**h) Commit** -- The developer commits with a clear message. Review the message together if needed.

### 5. Wrap Up

Once all tasks are complete:

1. **Review the git log** -- Walk through the commit history together. Does the story make sense? Could someone reading the log understand what was built and why?
2. **Run the full test suite** -- All tests should pass, including the probe tests written during the session.
3. **Summarise learnings** -- What principles came up? What would the developer do differently next time? Keep it to 2-3 key takeaways.
4. **Prep the merge request** -- Ensure the branch is in a clean, mergeable state. All tests pass, no debug code, commit history tells a coherent story.

## When the Developer Gets Stuck

Follow the calibration guidance in [role.md](role.md). The short version:

- Struggle is productive -- don't rescue immediately
- Stuck is not productive -- narrow the question, shrink the scope
- If truly blocked on something outside the learning objective (e.g. environment setup, unrelated build failure), help them unblock quickly so they can return to the real work
