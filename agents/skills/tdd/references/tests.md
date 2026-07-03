# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can project retirement income with defined contributions", async () => {
  const user = createUser({ age: 35, retirementAge: 67 });
  const plan = buildPlan(user, { monthlyContribution: 500, existingPot: 50000 });
  const projection = await getRetirementProjection(plan);
  expect(projection.annualIncome).toBeGreaterThan(0);
  expect(projection.retirementAge).toBe(67);
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: Tests implementation details
test("projection calls growthCalculator.compound", async () => {
  const mockGrowth = jest.mock(growthCalculator);
  await getRetirementProjection(plan);
  expect(mockGrowth.compound).toHaveBeenCalledWith(plan.pot, 0.05, 32);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("onboardUser saves to database", async () => {
  await onboardUser({ id: "user-123", status: "ONBOARDED" });
  const row = await db.query("SELECT * FROM users WHERE id = ?", ["user-123"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("onboarded user is retrievable", async () => {
  const user = await onboardUser({ name: "Alice", age: 45 });
  const retrieved = await getUser(user.id);
  expect(retrieved.status).toBe("ONBOARDED");
  expect(retrieved.name).toBe("Alice");
});
```

## Parameterized Tests

Use `it.each` when the same behavior must hold across a known set of inputs. The assertion logic is identical — only the data varies.

```typescript
// Test behavior across tenant configurations
it.each(['turo', 'ww', 'gilbert'])(
  'should calculate state pension age for %s tenant',
  async (tenant) => {
    const config = loadConfig(tenant);
    const user = createUser({ dateOfBirth: '1990-06-15' });
    const result = getStatePensionAge(user, config);
    expect(result).toBeGreaterThanOrEqual(66);
  },
);

// Test schema boundary values
it.each([
  ['empty string', '', false],
  ['valid uuid', '753abd85-0252-43a9-b72d-3cb15c746f03', true],
  ['malformed', 'not-a-uuid', false],
])('should validate user ID: %s', (_, input, expected) => {
  expect(zUserIdentifier.safeParse(input).success).toBe(expected);
});
```

**When to parameterize:** When the same behavior must hold across a known set of inputs (tenants, roles, formats, boundary values).

**When NOT to parameterize:** When each case has meaningfully different setup or assertions — write separate tests instead.
