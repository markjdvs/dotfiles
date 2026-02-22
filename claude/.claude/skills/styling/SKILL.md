---
name: styling
description: Style React components using CSS Modules with modern CSS. Never use Tailwind or inline styles.
allowed-tools: Read, Edit, Write
---

Always use CSS Modules for component styling:

- Create a `ComponentName.module.css` file alongside each component
- Import as `import styles from './ComponentName.module.css'`
- Apply classes via `className={styles.foo}`
- Use CSS custom properties for theme values (colors, spacing, typography)
- Use modern CSS features: nesting, `color-mix()`, `clamp()`, logical properties
- Global styles (resets, custom properties) go in `src/index.css` only
- Never use Tailwind, inline styles, or style objects

See REFERENCE.md for patterns.
