# Button

The action control: 44px tall (`control-h`), radius `radius-btn`, with `ui` type.

- **Variants:**
  - `.btn` for ordinary actions;
  - `.btn-primary` for the one main action of a page (accent fill, black 600 label);
  - `.btn-ghost` for reset or secondary actions (no border, muted underlined text).
- **Hover:**
  - `.btn` turns its border and label `accent`;
  - primary takes the `accent-hover` fill;
  - ghost turns `ink`.
- **Focus:** a 2px `accent` outline.
- **Markup:** use a real `<button>`, or an `<a>` for navigation.
- **Not yet designed:** disabled and loading. Add them as modifiers when a page needs them.
