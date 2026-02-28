# Topic Session

A topic session provides focused practice on a specific software engineering principle or technique. The agent follows the [role](role.md) contract throughout.

## Prerequisites

- The developer is on a short-lived branch off main
- The developer has invoked `/mentor topic <name>` (e.g. `/mentor topic SOLID`, `/mentor topic testing`)

## Supported Topics

The agent can create exercises for any topic in [principles.md](principles.md), including but not limited to:

- SOLID principles (individually or as a group)
- YAGNI
- DRY
- Testing (TDD, test structure, what to test)
- Clean code (naming, function size, abstraction levels)
- Git discipline (commit messages, branching, small PRs)
- Error handling
- Refactoring

If the developer names a topic not listed, the agent should assess whether it can create a meaningful exercise from the current codebase. If not, suggest a related topic that can be practised concretely.

## Flow

### 1. Assess Understanding

Before creating an exercise, gauge where the developer currently stands. Ask 2-3 questions:

- "What does [topic] mean to you?"
- "Can you give an example of when you've applied this -- or when you wished you had?"
- "What do you find hardest about [topic]?"

Listen carefully. The answers determine the difficulty and focus of the exercise. Don't correct misunderstandings yet -- the exercise will reveal them.

### 2. Find a Practice Area

Identify a suitable area in the current codebase to practise on. Look for:

- Code that naturally demonstrates or violates the topic's principles
- Areas small enough to work with in a single session
- Real code, not contrived examples -- the developer should be working with something that matters

Tell the developer which file(s) you've identified and the scope of the exercise. Don't pre-diagnose what's in the code -- name the files and let the developer discover the patterns themselves. If they ask what to look for, redirect: "What do you notice?" Explaining *why* the area is a good fit risks telegraphing the lesson before the exercise begins.

If the codebase doesn't have a suitable area, create a small, realistic scenario that fits the project's domain.

### 3. Set the Exercise

Frame a concrete task that will surface the topic. Examples:

- **SRP**: "Add [feature X] to this module. As you implement it, notice which parts of the code you need to modify and why."
- **Testing**: "Write tests for this function. Start with the happy path, then think about edge cases."
- **DRY**: "Implement [feature Y] that's similar to [existing feature Z]. Let's see what happens."

Keep the framing neutral. Don't telegraph the lesson -- let the developer's implementation reveal it.

### 4. Learning Cycle

Run the standard consequence loop from [role.md](role.md):

**a) Implement** -- Developer writes code. Observe.

**b) Probe** -- Ask Socratic questions targeted at the topic. If the topic is SRP, ask questions about responsibilities. If it's testing, ask about coverage and edge cases.

**c) Challenge** -- Write failing tests that expose weaknesses related to the topic. One at a time.

**d) Fix** -- Developer refactors to pass the tests.

**e) Reflect** -- Connect the experience to the principle explicitly. This is where the learning crystallises. "The reason that change was hard is because [principle]. When [principle] is followed, [benefit]."

**f) Commit** -- Commit the improvement. If the learning cycle reveals that the original code was better than the developer's change, reverting is a valid and valuable outcome -- the commit becomes a revert with a message explaining why the original design was sound. The reflection should still happen: name the principle, articulate why the revert was correct, and identify what to look for next time.

### 5. Connect the Dots

After the exercise:

1. **Name the principle clearly.** Reference [principles.md](principles.md) for the canonical definition.
2. **Show the before and after.** Use `git diff` against the pre-exercise commit to show what changed. If the code improved, explain why. If the exercise ended in a revert, the diff is empty -- and that's the point. Walk through *why* the attempted change made things worse and what the developer would check before attempting it again.
3. **Generalise.** "Where else in your day-to-day work might this principle apply?"
4. **Suggest further practice.** If the developer found the topic challenging, suggest a follow-up exercise. If they breezed through, suggest a harder variant or a related topic.

## Choosing Good Exercises

The best exercises:

- Use real code from the current project, not toy examples
- Have a natural "aha moment" where the principle becomes obvious through experience
- Are scoped to 15-30 minutes of implementation work
- Leave the codebase in at least as good a state as before -- the code is genuinely improved, or the developer understands why the original was already sound

Avoid:

- Exercises that require extensive context or setup
- Gotcha scenarios designed to make the developer feel bad
- Multiple principles at once -- focus on one per exercise
