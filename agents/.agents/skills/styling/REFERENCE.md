# CSS Modules Styling Reference

## file-structure

Co-locate each module file with its component.

```
src/components/
  GuessRow.tsx
  GuessRow.module.css
  TraitIcon.tsx
  TraitIcon.module.css
```

---

## module-usage

```tsx
// GuessRow.tsx
import styles from './GuessRow.module.css'

export function GuessRow({ animal, unlocked }: Props) {
  return (
    <div className={styles.row}>
      <span className={styles.name}>{animal.name}</span>
    </div>
  )
}
```

---

## conditional-classes

Use `clsx` or template literals for conditional class application.

```tsx
import clsx from 'clsx'
import styles from './Button.module.css'

<button className={clsx(styles.btn, isActive && styles.active)} />
```

---

## custom-properties

Define theme tokens in `src/index.css` as custom properties. Reference them in modules.

```css
/* src/index.css */
:root {
  --color-hot: oklch(65% 0.2 30);
  --color-cold: oklch(65% 0.15 260);
  --color-surface: oklch(98% 0 0);
  --space-sm: 0.5rem;
  --space-md: 1rem;
  --space-lg: 1.5rem;
  --radius: 0.375rem;
}
```

```css
/* Component.module.css */
.card {
  background: var(--color-surface);
  padding: var(--space-md);
  border-radius: var(--radius);
}
```

---

## modern-css

Prefer modern CSS features over older patterns.

```css
/* nesting */
.row {
  display: flex;

  & .name {
    font-weight: 600;
  }

  &:hover {
    background: color-mix(in oklch, var(--color-surface) 90%, black);
  }
}

/* fluid sizing */
.title {
  font-size: clamp(1rem, 2.5vw, 1.5rem);
}

/* logical properties */
.content {
  padding-inline: var(--space-md);
  margin-block: var(--space-lg);
}
```
