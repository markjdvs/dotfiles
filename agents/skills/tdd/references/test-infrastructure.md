# Test Infrastructure

Where most TDD friction lives. Good test infrastructure makes the red-green loop fast and natural.

## Provider Wrapping

Modern React apps require wrapping components in providers (theme, auth, routing, query client, config). Build a `renderWithProviders` utility that assembles the full stack with sensible defaults and per-test overrides.

```typescript
function renderWithProviders(ui, options = {}) {
  const {
    session = defaultSession,
    config = defaultConfig,
    router = createMockRouter(),
    queryClient = new QueryClient(),
  } = options;

  return render(
    <SessionProvider session={session}>
      <ConfigProvider config={config}>
        <QueryClientProvider client={queryClient}>
          <RouterContext.Provider value={router}>
            {ui}
          </RouterContext.Provider>
        </QueryClientProvider>
      </ConfigProvider>
    </SessionProvider>
  );
}
```

**Key principles:**
- Every provider has a sensible default so most tests don't need to specify options
- Individual providers are overridable for tests that need specific state
- One utility covers both `render` and `renderHook` variants

## Local Database Emulators

Use an emulator to run a real database locally. The only mock is redirecting the connection endpoint — everything else (ORM, queries, entities) runs for real.

```typescript
// jest-dynalite-config.js — defines table schemas
module.exports = {
  tables: [{
    TableName: 'local-table',
    KeySchema: [
      { AttributeName: 'PK', KeyType: 'HASH' },
      { AttributeName: 'SK', KeyType: 'RANGE' },
    ],
    AttributeDefinitions: [
      { AttributeName: 'PK', AttributeType: 'S' },
      { AttributeName: 'SK', AttributeType: 'S' },
    ],
  }],
};

// In test file — one import enables local DynamoDB
import 'jest-dynalite/withDb';

// Mock only the endpoint, not the data layer
jest.mock('@/api/shared/env', () => ({
  env: {
    DYNAMODB_ENDPOINT: process.env.MOCK_DYNAMODB_ENDPOINT,
    DYNAMODB_REGION: 'eu-west-1',
  },
}));
```

**Key elements:**
- Config file defines table schemas
- Setup hook bootstraps the emulator before tests
- Automatic cleanup between tests (each test gets a clean slate)
- Environment variable bridge connects app code to local instance
- No manual teardown needed

This is the highest-value integration test pattern because it catches real data access bugs that mocking would hide.

## Fixture Builders

Create factory functions that produce valid test data with sensible defaults and per-field overrides. Avoid raw object literals scattered across test files — they drift out of sync with the schema.

```typescript
const createUser = (overrides = {}) => ({
  id: uuid(),
  status: 'ONBOARDED',
  age: 35,
  retirementAge: 67,
  createdAt: new Date().toISOString(),
  ...overrides,
});

const createPlan = (overrides = {}) => ({
  userId: uuid(),
  monthlyContribution: 500,
  existingPot: 50000,
  riskProfile: 'moderate',
  ...overrides,
});
```

**Benefits:**
- Tests only specify what's relevant to the behavior under test
- Schema changes require updating one factory, not dozens of test files
- Defaults always produce valid data — tests that need invalid data override explicitly

## Test Utility Organization

Place shared test helpers in a dedicated location. Group by concern:

```
src/utils/
├── test/             # Shared fixtures, builders
├── ui/test/          # renderWithProviders, form models
└── api/test/         # API test helpers, request builders
```

## Event-Driven / Handler Testing

Lambda handlers and event-driven functions need event fixtures — the serverless equivalent of HTTP request builders.

### Event fixtures

Build factory functions for event shapes:

```typescript
const createDynamoDBStreamEvent = (userData) => ({
  Records: [{
    eventName: 'INSERT',
    dynamodb: { NewImage: marshall(userData) },
  }],
});

const createAPIGatewayEvent = (overrides = {}) => ({
  httpMethod: 'GET',
  path: '/v1/users',
  headers: { Authorization: `Bearer ${testToken}` },
  ...overrides,
});
```

### Handler-level testing

Test the handler function directly with constructed events — no HTTP server needed:

```typescript
it('should publish user creation event to SNS', async () => {
  snsMock.on(PublishCommand).resolves({});
  const event = createDynamoDBStreamEvent({ id: uuid(), status: 'ONBOARDED' });

  await handler(event);

  expect(snsMock).toHaveReceivedCommandWith(PublishCommand, {
    TopicArn: expect.stringContaining('user-events'),
  });
});
```

### Mock external side effects

Mock SNS publish, SQS send, external API calls. Assert the handler produced the right side effects for a given event. Use SDK-specific mock libraries (`aws-sdk-client-mock`) for type safety and clean assertion syntax.
