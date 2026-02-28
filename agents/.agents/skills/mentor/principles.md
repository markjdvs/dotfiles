# Engineering Principles Reference

A concise reference for the agent to use when teaching. Each principle includes a definition, why it matters, and smells that indicate a violation.

---

## SOLID

### Single Responsibility Principle (SRP)

A module should have one, and only one, reason to change.

**Why it matters:** When a module has multiple responsibilities, a change to one responsibility risks breaking the other. This makes code fragile and hard to test in isolation.

**Smells:** Function or class descriptions that use "and" ("it validates and saves and notifies"). Files that change for unrelated reasons. Tests that require complex setup touching unrelated concerns.

### Open/Closed Principle (OCP)

Software entities should be open for extension but closed for modification.

**Why it matters:** Modifying existing, working code to add new behaviour risks introducing bugs. Well-designed code lets you add new behaviour by adding new code, not changing old code.

**Smells:** Growing switch statements or if/else chains. Adding a new variant requires editing existing functions. Fear of touching a file because "everything depends on it."

### Liskov Substitution Principle (LSP)

Subtypes must be substitutable for their base types without altering correctness.

**Why it matters:** If code that works with a base type breaks when given a subtype, polymorphism is violated. This leads to defensive type checks scattered through the codebase.

**Smells:** `instanceof` checks or type guards after receiving an interface. Subclasses that throw "not implemented" for inherited methods. Overrides that change the contract rather than specialise it.

### Interface Segregation Principle (ISP)

No client should be forced to depend on methods it does not use.

**Why it matters:** Fat interfaces create coupling. When a client depends on methods it doesn't use, changes to those methods can break the client for no reason.

**Smells:** Interfaces with methods that some implementations leave empty. Parameters that are objects where only one or two properties are used. "God objects" passed around because they happen to contain what's needed.

### Dependency Inversion Principle (DIP)

High-level modules should not depend on low-level modules. Both should depend on abstractions.

**Why it matters:** When high-level business logic depends directly on low-level details (databases, HTTP clients, file systems), it becomes impossible to test, reuse, or change infrastructure without rewriting business logic.

**Smells:** Import paths that reach deep into infrastructure from business logic. Test files that need to mock databases, APIs, or file systems to test simple logic. Changing a database requires editing business rules.

---

## YAGNI (You Aren't Gonna Need It)

Don't build it until you need it. Implement the simplest thing that works for the current requirement.

**Why it matters:** Speculative code has a cost: it must be understood, tested, maintained, and debugged -- even if it's never used. Most predictions about future requirements are wrong.

**Common temptations:**
- "We might need this to support multiple [X] later"
- "Let me add a configuration option just in case"
- "I'll make this generic so it's reusable"
- Building an abstraction before there are two concrete cases

**The test:** Can you point to a current requirement that needs this code? If not, delete it.

---

## DRY (Don't Repeat Yourself) -- The Rule of Three

Do not extract a shared abstraction until something is duplicated **three times**.

**Why it matters:** Premature abstraction creates the wrong abstraction. Two instances of similar code often diverge as requirements evolve. Three instances give you enough information to see the real pattern.

**The rule:**
1. First time -- just write it
2. Second time -- note the duplication, leave it
3. Third time -- now extract. You have enough data to know what the real abstraction is.

**Why not DRY everything immediately:** The cost of the wrong abstraction (coupling unrelated things, making future changes harder) is higher than the cost of a little duplication. Duplication is far cheaper than coupling.

---

## Consistency with Existing Patterns

Before writing new code, examine how the surrounding codebase handles the same concerns. Match the established conventions for i18n, styling, file structure, component composition, and error handling. Diverge only when you can articulate why the existing pattern doesn't fit.

**Why it matters:** Consistency reduces cognitive load. A developer reading the codebase builds a mental model of "how things work here." Code that breaks that model -- even if it's individually well-written -- forces readers to context-switch and wonder whether the difference is intentional. Inconsistency also makes automated refactoring harder and code review slower.

**How to apply it:**
1. Before creating a new pattern, look at neighbouring files. How do they handle translations, styling, state, routing?
2. If the existing pattern is adequate, follow it -- even if you'd prefer a different approach in isolation.
3. If you genuinely believe the existing pattern is wrong, fix it across the codebase rather than creating a second pattern alongside the first.

**Smells:** Hard-coded strings in a codebase that uses i18n. Inline styles next to components using CSS-in-JS. Raw HTML elements alongside design system components. A new file structure convention in one module that doesn't match the rest.

---

## Defensive Coding and Trust Boundaries

Don't trust data at the boundaries of your system -- even when the type system says you can. Validate at the point where data enters your code from an external source.

**Why it matters:** Type systems describe intent, not reality. An API can return `null` for a field typed as required. A parent component can pass `undefined` where the prop type says it's always present. A database row can be missing a column that the ORM type guarantees. When the type lies, code that trusts it crashes at runtime with no useful error.

**Where boundaries exist:**
- API responses (the server can return anything regardless of your client-side types)
- Component props (the parent controls what's passed; the type only describes the contract)
- User input (never trust it, even after client-side validation)
- Environment variables (may be missing or malformed)
- Third-party library returns (version mismatches, undocumented edge cases)

**How to apply it:**
1. At trust boundaries, add runtime checks even when the type says the value is present.
2. When you find a type that doesn't match runtime reality, fix the type to be honest -- make nullability explicit rather than papering over it with defensive code alone.
3. Inside your own module, trust your own types. Defensive coding is for boundaries, not for every line.

**Smells:** A property access chain like `data.user.profile.name` with no guards on a value that came from an API. A component that crashes when a "required" prop is unexpectedly null. Optional chaining (`?.`) used inconsistently -- some consumers guard, others don't, because the type doesn't require it.

---

## Testing

### The Testing Pyramid

- **Unit tests** (many): Fast, isolated, test a single function or module. The foundation.
- **Integration tests** (some): Test that modules work together. Slower, but catch wiring bugs.
- **End-to-end tests** (few): Test the full system from user perspective. Slowest, most brittle, highest confidence.

### TDD: Red-Green-Refactor

1. **Red** -- Write a failing test that describes the desired behaviour
2. **Green** -- Write the minimum code to make the test pass
3. **Refactor** -- Improve the code's design while keeping tests green

**Why it matters:** Writing the test first forces you to think about the interface before the implementation. Tests written after often test implementation details rather than behaviour.

### What to Test

- **Behaviour, not implementation.** Test what the code does, not how it does it.
- **Edge cases.** Nulls, empty collections, boundary values, error paths.
- **Contracts.** If a function promises something (returns a sorted array, throws on invalid input), test that promise.

---

## Clean Code

### Naming

Names should reveal intent. A reader should understand what a variable, function, or class does from its name alone without reading the implementation.

**Smells:** Single-letter variables outside tiny loops. Names like `data`, `info`, `manager`, `handler` that say nothing. Abbreviations that require domain knowledge to decode.

### Functions

Functions should do one thing, do it well, and do it only. They should be short enough to hold in your head.

**Smells:** Functions longer than ~20 lines. More than 2-3 parameters. Functions that require reading to the bottom to understand what the top does. Boolean parameters that select between two behaviours (split into two functions).

### Single Level of Abstraction

Within a function, all statements should be at the same level of abstraction. Don't mix high-level intent with low-level mechanics.

**Smells:** A function that calls a business method, then manually iterates an array, then formats a string. Reading requires constant mental context-switching between "what" and "how."

---

## Semantic HTML and Accessibility

Use the right HTML element for the job. Semantic elements communicate meaning to browsers, screen readers, and keyboard users without extra work.

**Why it matters:** Assistive technologies rely on the semantic structure of the page. A `<button>` that navigates and a `<a>` that triggers an action both technically "work" for sighted mouse users, but they confuse screen readers, break keyboard navigation expectations, and prevent browser features like right-click "Open in new tab."

**Key distinctions:**
- **Links navigate** (`<a>`, Next.js `<Link>`). Use when the action takes the user to a new URL.
- **Buttons act** (`<button>`). Use when the action does something on the current page (submit, toggle, delete).
- **Headings structure** (`<h1>` through `<h6>`). Use sequentially to create a document outline. Don't skip levels for styling reasons.
- **Landmarks organise** (`<nav>`, `<main>`, `<aside>`, `<header>`, `<footer>`). Screen reader users navigate by landmarks, so they matter even when invisible.

**Smells:** A `<div>` with an `onClick` handler (should be a `<button>`). A `<button>` that sets `window.location.href` (should be a link). Headings chosen for font size rather than document hierarchy. Missing `alt` text on informational images, or non-empty `alt` on decorative ones.

**Reference:** [MDN Web Docs -- Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)

---

## Git Discipline

### Commit Messages

Follow the project's convention (often conventional commits). The subject line says *what*, the body explains *why*. A good commit message makes `git log` readable without opening files.

### Small Commits

Each commit should represent one logical change. If you can describe the commit with "and" ("added validation **and** updated the UI **and** fixed a typo"), it's too big. Smaller commits are easier to review, revert, and bisect.

### Incremental Delivery

When a task involves both structural changes and new behaviour, separate them into distinct commits. Refactor first (same behaviour, better structure), then add the feature on top of the clean foundation.

**Why it matters:** If a test fails after a combined refactor-and-feature commit, you can't tell which change caused it. Separating structural from behavioural changes makes failures easy to isolate, reverts safe, and code review focused. Each commit tells one story: "I moved things around" or "I added new behaviour" -- never both.

**The pattern:**
1. First commit: structural refactor -- narrow an interface, extract a function, reorganise files. Behaviour is identical. Existing tests still pass.
2. Second commit: new behaviour on top of the clean structure. New tests cover the new behaviour.

This also applies at a larger scale: fix the crash before building the feature; migrate the data before changing the schema; update the dependency before using its new API.

### Trunk-Based Development

Work on short-lived branches. A branch exists only to isolate work in progress -- it should merge to main promptly. Long-lived branches accumulate merge conflicts, drift from main, and delay feedback. Aim to merge at least daily when possible.
