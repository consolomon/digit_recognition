# Design system — "Signal on Black"

The app's visual language since B-10 (`feature/page-visual-redesign`,
1.1.x). It merges the lecture poster
`resources/design/Math_is_everywhere_artificial_neural_networks.psd`
(achromatic field, white monospace type, particle network, inset white frame)
with the app 1.0 UI (JetBrains Mono, one sky-blue accent). Its
philosophy is in `resources/design/reference/PHILOSOPHY.md`, and the data
extracted from the poster is in `resources/design/reference/design_reference.json`.

**Status: draft 0.1. Built to grow.** It covers the five current pages. New
elements go in through §"Extending" without breaking anything already
here.

| Where | What |
|---|---|
| `app/static/style.css` | The implementation: tokens on `:root`, then the shell, components and page sections, in that order |
| `app/templates/base.html` | Page shell: frame, scroll window, navbar, `{% block content %}`, partners footer, `{% block scripts %}` |
| `app/templates/partials/_partners.html` | Partners footer (all pages) |
| `app/static/img/` | `network_bg.webp` (background A), `partners/*.png` (64×64 logos) |
| `resources/design/reference/` | Poster dataset, layer PNGs, `network.svg` (background B, not used) |
| `resources/code_sandbox/design_canvas/` | Sources of the approved draft canvas (claude.ai artifact `GY9774sSb7xLYRKXCWbFNN`) |
| Figma / Miro | See §"Mirrors" |

---

## Principles

1. **One signal.** `--accent` `#38bdf8` is the only hue in the UI chrome. It
   marks what is alive right now: the active tab, the primary action, a
   section or stage label, a fresh result. If two unrelated things are blue,
   one of them is wrong. Categorical colours are allowed **only** in data
   visualisation (History), where the colours are the data.
2. **Light, not paint.** Depth comes from grey steps on pure black, never
   from shadows, gradients, blur or radius.
3. **Monospace as instrument.** JetBrains Mono only, regular and medium
   weights (600 only for the primary button), on a 1.25 scale. Headings are
   regular weight. An underline means "this leads somewhere".
4. **Frame and network.** A fixed 2px white frame holds the viewport, and
   the content scrolls inside it, clipped at the frame line. The poster's
   network sits anchored at the bottom of the window, under the content.
5. **Tokens or nothing.** New CSS uses `var(--…)`. A raw hex or px in a new
   rule is a review finding. The exceptions are fixed-unit geometry
   (`60px` tiles, the `280` canvas) and the inline styles in `history.js`.

## Tokens

### Colour

| Token | Value | Role | On black |
|---|---|---|---|
| `--bg` | `#000000` | page field, panel fill | — |
| `--field` | `#0d0d0d` | tile off, raised panel (History open row) | — |
| `--g1` | `#171717` | hover fill | — |
| `--line` | `#303030` | hairlines, panel borders | decorative |
| `--line-strong` | `#4c4c4c` | button, grid, canvas borders | decorative |
| `--g4` | `#616161` | decorative only | 3.4:1, never text |
| `--muted` | `#8f8f8f` | secondary text, labels | 6.6:1 |
| `--soft` | `#c7c7c7` | body text | 12.6:1 |
| `--bright` | `#e0e0e0` | body text over the network | 15.4:1 |
| `--ink` | `#ffffff` | headings, tile on, frame, stage-card border | 21:1 |
| `--accent` | `#38bdf8` | the signal | 10.0:1 |
| `--accent-hover` | `#7dd3fc` | primary-button hover | — |
| `--accent-dim` | `rgba(56,189,248,.12)` | selected fills (reserved) | — |

**Data-viz palette (History only):**
- `#38bdf8`, `#a78bfa`, `#818cf8`, `#0ea5e9`, `#f59e0b`, `#10b981`, `#ef4444` (also the human-level line), `#f97316`, `#a3e635`, `#06b6d4`.
- **No pink or magenta.** The owner removed `#ec4899` on 2026-10-17.

**Stage 3 canvas pixels** (white on black) are model input, not UI. They live in `stage3.js` and are outside this system.

### Type

| Token | Size | Weight | Use |
|---|---|---|---|
| `--fs-display` | 49px (36 on phones) | 400 | landing hero title |
| `--fs-title` | 31px (25 on phones) | 400 | page titles |
| `--fs-heading` | 20px | 500 | card headings |
| `--fs-body` | 16px | 400 | body, output, partners |
| `--fs-ui` | 14px | 400 / 500 | buttons, tabs, brand, card text |
| `--fs-label` | 12px | 500, `0.14em`, uppercase | `.label` |

The font loads once, in the `@import` at the top of `style.css`. The stack is `var(--font)`.

### Space, layout, shape

| Token | Value | Use |
|---|---|---|
| `--s1`…`--s9` | 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96 | every gap and padding |
| `--column` | 1120px | content column, including gutters (`.container`) |
| `--gutter` | 56px (20 on phones) | column side padding |
| `--frame-inset` / `--frame-width` | 20px (8 on phones) / 2px | the frame |
| `--nav-height` | 64px | navbar |
| `--control-h` | 44px | buttons (touch target) |
| `--radius-btn` | 2px | buttons; everything else is square |

The phone breakpoint is `max-width: 640px`. It overrides tokens, and
stacks `.panel`s full width.

## Patterns

### Page shell (`base.html`)
```
body (black + network_bg.webp at the bottom, overflow hidden)
├── .frame       fixed, inset --frame-inset, 2px --ink, aria-hidden
└── .viewport    fixed inside the frame, overflow-y auto, flex column,
                 scrollbar hidden, tabindex="-1" + autofocus (keyboard scrolling)
    ├── .navbar  sticky top, brand + 4 tabs
    ├── {% block content %}          (.container sections / main)
    └── .partners                    (margin-top: auto → standard bottom footer)
{% block scripts %}
```
- Pages `{% extends 'base.html' %}`, set `{% set active_page = 'stage1' %}` (`stage2`, `stage3`, `history`, or none on the landing page), and fill `title` / `content` / `scripts`.
- The navbar marks the active tab with `.active` plus `aria-current="page"`.
- The tests in `tests/test_app_smoke.py::PagesTest` guard the shell and every element id the scripts use.
- **The scroll window's scrollbar is hidden permanently** (owner, 2026-10-17, after the manual test).
  - It's hidden in every engine: `scrollbar-width: none`, `-ms-overflow-style`, and `::-webkit-scrollbar`.
  - Wheel, touch and keyboard scrolling still work. `tabindex="-1" autofocus` routes Page Down, Space and the arrow keys to the window from the start, without a first click.
  - Don't add a visible scrollbar back to the shell.

### Background
- **A, the poster network image** (owner's choice, 2026-10-17): the PSD layer "Слой 10", levelled so `#0d0d0d` becomes `#000`, cropped to the lower 700px, WebP 86 KB. It's sized `max(100%, 960px)`, so phones keep the detail.
- **B, the generated SVG** (`resources/design/reference/network.svg`, generator `resources/code_sandbox/gen_network.py`, seed 28): kept as the alternative and not shipped. Swapping is one `url()` in `body`.

### Workspace (stage pages)
`.workspace` is a wrapping flex row: `.panel` (the input) · `.panel.controls` (the buttons, bottom-aligned, with a `Controls` label) · `.output`. On phones each panel takes the full width.

## Components

### Navbar tab `.nav-tab`

| State | Visual |
|---|---|
| Default | `--soft` text, 1px `--line-strong` underline, offset 7px |
| Hover | `--ink` text, `--ink` underline |
| Active (`.active`) | `--accent` text, 2px `--accent` underline, `aria-current="page"` |

### Button `.btn`

| Variant | Use when | Default | Hover |
|---|---|---|---|
| `.btn` | ordinary actions (Recognize on stages 1–2, Learn, Clear, Upload, Try Stage N) | black, 1px `--line-strong`, `--ink` text | `--accent` border and text |
| `.btn-primary` | the **one** main action of a page (Stage 3 Recognize) | `--accent` fill, black 600 text | `--accent-hover` fill |
| `.btn-ghost` | reset/secondary actions (Refresh) | no border, `--muted` underlined text | `--ink` |

All buttons:
- 44px tall, radius 2px, `:focus-visible` drawn as a 2px accent outline;
- real `<button>` elements, or `<a>` elements for navigation.

Disabled and loading states aren't designed yet: add them when a page needs them, following §"Extending".

### Stage card `.stage-card`
- Black fill, a **1px white border** (the frame's line at half weight; owner, 2026-10-17), square corners.
- Contents: `.label.label-accent` "Stage 0N", then the `h2` heading, the text, and a `.btn`.
- The row is `.stages-overview`: `auto-fill, minmax(260px, 1fr)`, so 3 cards fit in the column.
- The white border is reserved for stage cards. Panels use `--line`.

### Tile grid `.grid` + `.tile`
- 60px squares. Off: `--field` with a `--line` border. Hover: `--g1`. On: `--ink`.
- The outer border is `--line-strong`.
- `stage2.js` overrides the template to 3×5. Tiles are created by JS (`div.tile`, toggled with the `on` class).

### Draw canvas `.draw-canvas`
- 280×280, outlined with `--line-strong`.
- `max-width: 100%`: `stage3.js` maps pointer coordinates through `getBoundingClientRect`, so CSS scaling is safe.
- `.canvas-note` caption under it.

### Output panel `.output` > `.label` + `.result-box#result`
| State | Visual |
|---|---|
| Empty | `--line` border, `--muted` label, placeholder "awaiting input" (CSS `:empty::before`) |
| Filled (any text the JS writes: progress, result, error) | `--accent` border and label (`:has(.result-box:not(:empty))`) |

- `aria-live="polite"`.
- Stage scripts keep writing plain text or HTML into `#result`, including `.result-row`. No JS change was needed.

### Partners footer `.partners` > `.partners-list` > `.partner`
- Solid black panel, no border, no label (owner, 2026-10-17).
- Entries share the row equally (`flex: 1 1 260px`), each centred, and wrap to new centred rows.
- Each entry: a 64×64 logo, the name, and an underlined handle.
- To add a partner, add an `<li>` in `_partners.html` and put its logo in `static/img/partners/`.

### History chart chrome (`history.js`, inline styles)
- Chart panel: black with a `#303030` border, square.
- Tooltip: `#0d0d0d`, with a 2px border in the milestone's colour.
- Milestone rows: black, `#303030` border. The open row is `#0d0d0d` with a border in its milestone colour.
- Badges: outlined in the milestone colour, square.
- Key-insight box: black with an accent border.
- The "≈ Human level" label sits inside the plot, top right.
- Data, chart logic and interactions are unchanged.

## Accessibility baseline
- Text is at least 4.5:1 on black, so `--g4` and darker are never used for text.
- Real `<button>` and `<a>` elements, a visible `:focus-visible` outline, `aria-current` on the active tab, and `aria-live` on outputs.
- The frame is `aria-hidden`.
- Every partner logo has `alt` text.
- Touch targets are at least 44px (buttons). Tiles are 60px.

## Do / Don't

| ✅ Do | ❌ Don't |
|---|---|
| Use one `.btn-primary` per page, at most | Use the accent for decoration |
| Build new surfaces as black + `--line` panels | Add shadows, gradients, radius > 2px |
| Use regular-weight headings and an uppercase `.label` above them | Use bold display type (800) |
| Put new pages in `base.html` (frame, navbar, footer come free) | Copy the navbar or footer markup into a page |
| Use categorical colour only in charts | Use pink or magenta, anywhere |

## Extending

Extending means adding a component or pattern in the next task. Steps:
1. **Look here first.** Can an existing component plus a variant express it? Prefer a modifier class (`.btn-…`, `.panel-…`) over a new component.
2. **Spec it** in the `/design-system extend` shape: problem, related components, variants, states (default, hover, focus, disabled, loading as needed), the tokens used, and accessibility. Add the spec under §"Components" in this file.
3. **Tokens first.** If a new value is really needed, add a token on `:root` (and in this file's tables) before using it. Never write raw values.
4. **Implement** in `style.css`, in its section order (tokens → shell → navbar → buttons → helpers → page sections → components). If JS needs a hook, keep or add an `id`, and add it to `test_page_script_hooks`.
5. **Mirror** it in Figma and Miro when they're in use (§"Mirrors"). Note the version in the change log below.

## Mirrors
All mirrors are copies. When they disagree, `style.css` and this file win.
Re-sync the mirrors after a change.

- **Draft canvas** (approved 2026-10-17): https://claude.ai/artifact/GY9774sSb7xLYRKXCWbFNN (private).
  Sources: `resources/code_sandbox/design_canvas/`.
- **claude.ai Design System "Signal on Black":** https://claude.ai/artifact/EHD45xHkB1LCXPGWc3Pa9D (private).
  - Contents: tokens, a README, 7 components with static previews, the partner and background assets, and a cover.
  - Future Design canvases install it from there.
  - Sources: `resources/code_sandbox/design_system_artifact/`.
- **Figma:** https://www.figma.com/design/LgSD9laDEX1zwWGnhwmIUd ("Digit Recognition — Signal on Black", Starter team).
  - **Components page:** the variables (Color: 12, Spacing: 9, Layout: 7, with `var(--…)` code syntax), 6 text styles (`SoB/…`), and the component sets Button, NavTab, Tile and OutputPanel, plus StageCard and PartnersFooter.
  - **Templates page:** pixel-perfect captures of the 5 pages.
  - **Limits:** the captures lack the body's network background, since Figma's capture can't grab CSS body backgrounds. JetBrains Mono has no SemiBold in Figma, so the primary button label is Bold.
  - **Read quota:** the account has a View seat (20 rate-limited MCP reads a month), so batch `use_figma` work.
- **Miro "Sandbox" board:** https://miro.com/app/board/uXjVMmieAJ4=/. Four frames at x 0…7360, y 7000…8400, below all earlier content: "Signal on Black: overview", "Tokens", "Components", "Shell and how to extend".
- **Claude Design (standalone)** project "Signal on Black — Digit Recognition" (id `5c656a4e-c822-4851-bf37-569df64bc807`):
  - Contents: `README.md`, the full `WEB_DESIGN.md` (every component, pattern and page in the `/design-system document` format), `tokens.json`, `styles/signal-on-black.css`, and 7 self-contained preview cards.
  - Bundle sources: `resources/code_sandbox/claude_design_project/`.
  - Access: through `/design-login`. Standalone Claude Design closes by 2026-12-14.
  - A local copy of `WEB_DESIGN.md` is in `~/Documents/Code_sandbox/Digit_recognition/`.
- **Adobe Express sheet:** `resources/code_sandbox/adobe_express_sheet.html`. It was not exported: Express import and Adobe Fonts are blocked for the account's region.

## Change log

| Version | Change |
|---|---|
| 1.1.14 | Full web-design documentation (`WEB_DESIGN.md`): foundations, patterns, 11 components, 5 pages. Published as a new Claude Design project; the claude.ai Design System was not republished (owner's choice). |
| 1.1.13 | Mirrors re-synced to 1.1.12: the shell's hidden scrollbar and the shipped status. Updated in the claude.ai Design System (README, PageShell, `tokens.json` ref `master@54d715a`), on the Figma library header and Templates note, and on the Miro Sandbox (PageShell, shell diagram, Status, overview card). Standalone Claude Design (`DesignSync`) not checked: it needs `/design-login` first. |
| 1.1.11 | Scroll window scrollbar hidden permanently; `tabindex="-1" autofocus` for keyboard scrolling (owner, after the manual test). |
| 1.1.x (B-10) | Draft 0.1: tokens, shell (frame + scroll window + network A), navbar tabs, buttons (3 variants), stage card, tile grid, draw canvas, controls panel, output panel, partners footer, History chrome. The owner's 6 correction rounds on the draft canvas are folded in. |
