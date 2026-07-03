# Test Layer Selection

The first decision in every TDD cycle: which layer should this test live in?

## Layers

### Unit tests (`*.spec.ts`)

Pure logic, schema validation, calculations, utility functions. No I/O, no providers, fast.

**Use when:** behavior is self-contained within a single module.

```typescript
test("projection calculates compound growth correctly", () => {
  const result = compoundGrowth({ principal: 50000, rate: 0.05, years: 32 });
  expect(result).toBeCloseTo(211588.

, 0);
});
```

### Integration tests (`*.integration.spec.ts`)

Real middleware, real database (emulated), real routing. Exercises the full code path from HTTP request to persistence and back.

**Use when:** behavior crosses module boundaries or touches persistence.

```typescript
test("GET /v1/users/:id returns onboarded user", async () => {
  await UserEntity.create({ id: userId, status: "ONBOARDED" }).go();

  const { status, body } = await request(app).get(`/api/v1/users/${userId}`);

  expect(status).toBe(200);
  expect(body.status).toBe("ONBOARDED");
});
```

### API/contract tests (Cucumber/BDD)

Verify API contracts against business requirements. Written in Gherkin, readable by non-engineers.

**Use when:** behavior maps directly to acceptance criteria or business rules that stakeholders care about.

```gherkin
Scenario: User retrieves their retirement projection
  Given a user with £50,000 pension pot
  And monthly contributions of £500
  When they request their retirement projection
  Then the projected annual income is returned
  And the projection assumes retirement at state pension age
```

## Decision Heuristic

Start at the **lowest layer** that can verify the behavior. Push up only when the lower layer can't exercise the real code path.

```
Can a unit test verify this?
  YES → write a unit test
  NO  → write an integration test
```

Rule of thumb: if you're mocking more than the system boundary to make a unit test work, you probably need an integration test instead.
