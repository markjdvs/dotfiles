# Import Aliases Reference

## vite

Add `resolve.alias` to `vite.config.ts` so Vite resolves `@` to `./src` at runtime.

```ts
import path from 'path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

---

## tsconfig

Add `baseUrl` and `paths` inside `compilerOptions` in `tsconfig.app.json` so TypeScript resolves the alias at compile time.

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

---

## usage

Use `@/` for all imports. Never use relative paths.

```ts
// correct
import { GameBoard } from '@/components/GameBoard'
import { compareHabitat } from '@/utils/traitComparison'
import type { Animal } from '@/types'

// never
import { GameBoard } from '../../components/GameBoard'
import type { Animal } from '../types'
```
