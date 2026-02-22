---
name: imports
description: Configure and enforce path alias imports in Vite + React + TypeScript projects
allowed-tools: Read, Edit, Write
---

Always use `@` path aliases — never relative paths. When working in a project:

- Ensure `vite.config.ts` has `resolve.alias` pointing `@` to `./src` (see REFERENCE.md#vite)
- Ensure `tsconfig.app.json` has `baseUrl` and `paths` set (see REFERENCE.md#tsconfig)
- All imports use `@/` prefix, e.g. `import { Foo } from '@/components/Foo'`
- If either config is missing the alias, add it before writing the import
