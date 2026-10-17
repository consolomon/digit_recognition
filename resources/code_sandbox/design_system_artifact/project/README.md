# Signal on Black

The design system of **Digit Recognition**, a Flask teaching app that walks
from a 3×3 binary classifier to full MNIST recognition. It merges the lecture
poster *Math is everywhere: artificial neural networks* with the app's
original UI:
- from the poster: a pure-black field, white monospace type, the particle
  network, and a thin white frame;
- from the app: JetBrains Mono and one sky-blue accent.

Source of truth: `app/static/style.css` and
`resources/documentation/DESIGN_SYSTEM.md` in `consolomon/digit_recognition`.

## Principles

1. **One signal.** `accent` (#38bdf8) is the only hue in the interface. It
   marks what is alive right now: the active tab, the page's one primary
   action, a stage or section label, a filled output. If two unrelated
   things are blue, one of them is wrong. Categorical colour exists only in
   data visualisation (the History chart), and never as pink or magenta.
2. **Light, not paint.** Depth is made from grey steps on `bg`: `field`,
   `g1`, `line`, `line-strong`. No shadows, gradients, blur or rounded cards.
3. **Monospace as instrument.** JetBrains Mono everywhere, regular and
   medium weights. Headings are regular weight, as on the poster. An
   underline means "this leads somewhere".
4. **Frame and network.** A fixed 2px `ink` frame holds the viewport, and
   the page scrolls inside it, clipped at the frame line. The poster's
   network image sits anchored at the bottom of the window, under all content.

## Colour

Usage notes are on every token. Text is at least 4.5:1 on `bg`: `muted`
(6.6:1) is the lowest text grey. `g4`, `line` and `line-strong` are
never text. Surfaces that sit over the network background are filled with
`bg`, never transparent, so text stays readable.

## Typography

One family: `mono` (JetBrains Mono, from Google Fonts). The scale has a
ratio of 1.25: `display` 49, `title` 31, `heading` 20, `body` 16, `ui` 14,
`label` 12 (uppercase, tracking 0.14em). Phones drop `display` to 36 and
`title` to 25. Never bold display type; 600 is reserved for the primary
button's label.

## Layout

- **Column:** `column` 1120px including `gutter` 56px.
- **Spacing:** every gap comes from `s1`–`s9` (4 → 96).
- **Corners:** square everywhere except buttons (`radius-btn` 2px).
- **Page shell:** the frame is inset by `frame-inset` (20px; 8px on phones),
  and a scroll window sits inside it holding:
  - the sticky navbar (`nav-height` 64);
  - the page content;
  - the partners footer, pushed to the bottom on short pages.
- **Stage pages:** use a wrapping workspace row: input panel, controls
  panel, output panel. Each takes the full width on phones (≤ 640px).

## Background

- **Background A, the poster network** (`assets/Backgrounds/network_bg.webp`):
  the PSD layer levelled to pure black, cropped to its lower 700px, 86 KB.
  It's sized `max(100%, 960px)` at the bottom of the window.
- **Background B, a generated SVG network** (`assets/Backgrounds/network.svg`, seed 28): the
  documented alternative, not shipped.

## Iconography

None by design. Affordance is carried by underline (links, tabs, ghost
buttons) and by the accent (active state). The two partner logos are the
only images besides the background.

## Components

These are CSS components (class names from the app); there is no JS bundle.

| Component | Classes |
|---|---|
| NavTabs | `.navbar` `.nav-brand` `.nav-tab` `.active` |
| Button | `.btn` `.btn-primary` `.btn-ghost` |
| StageCard | `.stage-card` (1px `ink` border) |
| TileGrid | `.grid` `.tile` `.on` |
| OutputPanel | `.output` `.label` `.result-box` |
| PartnersFooter | `.partners` `.partners-list` `.partner` |
| PageShell | `.frame` `.viewport` `.container` |

### Adding a component
1. Extend an existing one with a modifier class before inventing a new one.
2. Write its spec (variants, states, tokens, accessibility) in
   `DESIGN_SYSTEM.md`.
3. If a value is missing, add a token.
4. Implement it in `style.css` using `var(--token)` only.
5. Mirror it here (a component README and preview), in Figma and on Miro.

## Not synced
- **No JS bundle:** the app's components are plain CSS classes, so every
  preview is a **static rendition** styled by `components/bundle.css` (a
  copy of the app's component rules).
- **Phone overrides:** the app's 640px breakpoint token overrides (`gutter`,
  `frame-inset`, `fs-display`, `fs-title`) aren't representable as
  tokens. They're described above.
- **Shell rules left out:** the fixed-frame shell rules (`body` overflow,
  `.frame`, `.viewport`) stay out of `bundle.css` so previews render.
  PageShell's preview draws the frame statically.
