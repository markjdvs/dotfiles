# When to Mock

Mock at **system boundaries** only:

- External APIs (income tax service, state pension lookup, etc.)
- Databases (sometimes - prefer local emulator like jest-dynalite)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function calculateNetIncome(grossIncome, taxClient) {
  return taxClient.getIncomeTax(grossIncome);
}

// Hard to mock
function calculateNetIncome(grossIncome) {
  const client = new IncomeTaxServiceClient(process.env.TAX_SERVICE_URL);
  return client.getIncomeTax(grossIncome);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/v1/users/${id}`),
  getProjection: (userId) => fetch(`/v1/users/${userId}/projection`),
  updateContributions: (userId, data) =>
    fetch(`/v1/users/${userId}/contributions`, { method: 'PUT', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint

## Common Boundary Mocks

### Cloud SDK clients

Use SDK-specific mock libraries rather than generic `jest.mock`. They give type-safe setup and assertion helpers.

```typescript
import { mockClient } from 'aws-sdk-client-mock';
import { PublishCommand, SNSClient } from '@aws-sdk/client-sns';

const snsMock = mockClient(SNSClient);

beforeEach(() => snsMock.reset());

it('should publish event on user creation', async () => {
  snsMock.on(PublishCommand).resolves({});

  await createUser({ id: uuid(), status: 'ONBOARDED' });

  expect(snsMock).toHaveReceivedCommandWith(PublishCommand, {
    TopicArn: expect.stringContaining('user-events'),
  });
});
```

### Environment variables

Mock the env module, not `process.env` directly. This keeps the mock co-located with the boundary it represents.

```typescript
jest.mock('@/api/shared/env', () => ({
  env: {
    DYNAMODB_ENDPOINT: process.env.MOCK_DYNAMODB_ENDPOINT,
    DYNAMODB_REGION: 'eu-west-1',
    INCOME_TAX_SERVICE_URL: 'https://test.com/income-tax-service',
  },
}));
```

### Auth/session providers

Mock at the provider level, not inside components.

```typescript
jest.mock('next-auth/react', () => ({
  useSession: () => ({ data: { user: { id: 'test-user' } }, status: 'authenticated' }),
}));
```

### Routers/navigation

Use router mock libraries that simulate navigation without a real browser.

```typescript
import mockRouter from 'next-router-mock';

jest.mock('next/router', () => require('next-router-mock'));

beforeEach(() => mockRouter.setCurrentUrl('/planner/contributions'));
```

### Time

Freeze time in tests that depend on dates. Retirement projections are date-sensitive — flaky tests often trace back to unfrozen time.

```typescript
import timekeeper from 'timekeeper';

beforeAll(() => timekeeper.freeze(new Date('2025-01-01')));
afterAll(() => timekeeper.reset());
```
