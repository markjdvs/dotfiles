---
name: writing-infrastructure
description: Use when building AWS infrastructure with SST v3 — covers project setup, key component patterns, resource linking, accessing outputs, and common gotchas
---

# Writing Infrastructure (SST v3)

## Overview

Build AWS infrastructure using SST v3 (Ion). SST v3 uses Pulumi under the hood with a TypeScript-first config. Resources are defined in `sst.config.ts` at the project root.

**Announce at start:** "I'm using the writing-infrastructure skill."

---

## Project Setup

### `package.json` requirements

```json
{
  "type": "module",
  "scripts": {
    "deploy": "sst deploy",
    "remove": "sst remove"
  }
}
```

`"type": "module"` is required — SST v3 config is ESM.

### Install SST

```bash
pnpm add -D sst
pnpm sst install   # downloads .sst/platform — run once, gitignore .sst/
```

Add to `.gitignore`:
```
.sst/
```

### `sst.config.ts` skeleton

```typescript
/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "my-app",
      removal: input?.stage === "production" ? "retain" : "remove",
      home: "aws",
    };
  },
  async run() {
    // define resources here
    return {
      // key-value outputs printed after deploy
    };
  },
});
```

The triple-slash reference will show a TypeScript error until `sst install` has been run. This is expected — run `sst install` first.

---

## Key Component Patterns

### EventBridge Custom Bus

```typescript
const bus = new sst.aws.Bus("MyBus");
// Outputs: bus.name, bus.arn
```

Return from `run()` to expose as deploy outputs:
```typescript
return { busName: bus.name, busArn: bus.arn };
```

### API Gateway HTTP API

```typescript
const api = new sst.aws.ApiGatewayV2("MyApi");
api.route("POST /events", {
  handler: "functions/handler.handler",
});
// Outputs: api.url
```

### Lambda Handler (API Gateway v2)

```typescript
import type { APIGatewayProxyHandlerV2 } from "aws-lambda";

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const body = event.isBase64Encoded
    ? Buffer.from(event.body ?? "", "base64").toString()
    : event.body ?? "";

  return { statusCode: 200, body: JSON.stringify({ ok: true }) };
};
```

Install the type: `pnpm add -D @types/aws-lambda`

---

## Resource Linking

Link a resource to a Lambda to grant IAM permissions and inject the `Resource` object:

```typescript
// sst.config.ts
api.route("POST /events", {
  handler: "functions/handler.handler",
  link: [bus],
});
```

Inside the Lambda handler:

```typescript
import { Resource } from "sst";

const busName = Resource.MyBus.name; // typesafe, matches logical name "MyBus"
const busArn = Resource.MyBus.arn;
```

`Resource` only works inside SST-managed processes (Lambda, SST dev). Do not use it in local scripts.

---

## Accessing Outputs from Local Scripts

After `sst deploy`, outputs are printed to stdout. Capture them and pass as env vars to local scripts:

```bash
# Deploy and note printed outputs, then:
API_URL=https://xxx.execute-api.eu-west-1.amazonaws.com \
BUS_NAME=my-app-dev-MyBusBus-xxxx \
npx tsx run.ts
```

Read in the script:
```typescript
const apiUrl = process.env.API_URL;
const busName = process.env.BUS_NAME;
```

Never import `Resource` from `sst` in local scripts — it requires the SST runtime context.

---

## SST Commands

```bash
pnpm sst install              # first-time setup, downloads .sst/platform
pnpm sst deploy --stage dev   # deploy to AWS
pnpm sst remove --stage dev   # tear down all resources
pnpm sst dev                  # local dev / Lambda Live Reloading
```

---

## Common Gotchas

### 1. pnpm strict dependency resolution

pnpm does not expose transitive dependencies to the workspace root. If you `import` from a package that is only a transitive dependency (e.g. `@smithy/protocol-http` pulled in by `@smithy/node-http-handler`), pnpm will fail to resolve it. Always add such packages as explicit direct dependencies.

### 2. SST resource names include a random suffix

Deployed resource names follow the pattern `{app}-{stage}-{LogicalName}Bus-{randomSuffix}`. Do not hardcode expected resource names in tests or scripts — always read from SST deploy outputs.

### 3. URL concatenation safety

SST output URLs may or may not have a trailing slash. Always normalize before appending paths:

```typescript
const base = apiUrl.replace(/\/$/, "");
const endpoint = `${base}/events`;
```

### 4. `tsx` belongs in devDependencies

SST uses esbuild to bundle Lambda handlers — `tsx` is never bundled. Keep it in `devDependencies` only to avoid inflating Lambda packages.

### 5. Bus linking is for Lambda-side usage

When a Lambda needs to PUT events to the bus, link the bus to the route. When a local script needs to PUT events using its own AWS credentials, no linking is needed — just pass the bus name as an env var and use the AWS SDK directly.
