# Accessibility
- Text contrast is at least 4.5:1 on black; `--g4` and darker are never used for text.
- Controls are real `<button>` and `<a>` elements. `:focus-visible` draws a 2px accent outline.
- Navigation: `aria-current` marks the active tab; `aria-live` is set on outputs.
- The frame is `aria-hidden`; logos have `alt` text.
- Buttons are at least 44px; tiles are 60px.
- **Keyboard scrolling:** works without a click (the window has `autofocus`).
- **Known gaps:**
  - tiles and History rows aren't keyboard-operable (each needs a script change);
  - there are no disabled or loading button states yet.
