# Digit Recognition — web design documentation

The complete design documentation of the Digit Recognition web app, in the
`/design-system document` format. It covers the foundations, the patterns,
11 components and all 5 pages.

| | |
|---|---|
| System | **Signal on Black**, draft 0.1 |
| App version | shipped in **1.1.11** (backlog B-10); `master`, `dev` and `deploy` at 1.1.12 |
| Source of truth | `app/static/style.css`, `app/templates/` and `resources/documentation/DESIGN_SYSTEM.md` in `consolomon/digit_recognition` |
| Mirrors | the claude.ai Design System "Signal on Black", the Figma file `LgSD9laDEX1zwWGnhwmIUd`, the Miro board "Sandbox", the Claude Design project "Signal on Black — Digit Recognition" |
| Written | 2026-10-17 |

When this document and the code disagree, the code wins. Re-sync the
mirrors after every change to the design.

---

## 1. Principles

1. **One signal.** `--accent` `#38bdf8` is the only hue in the interface
   chrome. It marks what is alive right now: the active tab, the page's
   single primary action, stage and section labels, and a filled output.
   - If two unrelated things are blue, one of them is wrong.
   - Categorical colour appears only in data visualisation (the History
     chart). Pink and magenta are never used.
2. **Light, not paint.** Depth comes from grey steps on pure black. There
   are no shadows, gradients, blur or rounded cards.
3. **Monospace as instrument.**
   - The only typeface is JetBrains Mono, in regular and medium weights on
     a 1.25 type scale.
   - Headings use regular weight, as on the poster.
   - An underline means "this leads somewhere".
4. **Frame and network.**
   - A fixed 2px white frame holds the viewport.
   - The page scrolls inside the frame, clipped at the frame line, with
     its scrollbar hidden.
   - The poster's particle network sits anchored at the bottom of the
     window, beneath all content.
5. **Visual only.** A redesign never changes behaviour. Element ids, button
   roles and the `#result` output contract stay intact.

Origin: the lecture poster *Math is everywhere: artificial neural networks*
(`resources/design/`) merged with the app 1.0 UI. The philosophy behind
the system is in `resources/design/reference/PHILOSOPHY.md`.

---

## 2. Foundations

### 2.1 Colour

| Token | Value | Role | Contrast on `bg` |
|---|---|---|---|
| `--bg` | `#000000` | page field, panel fill | — |
| `--field` | `#0d0d0d` | tile off, raised panels, open History row | — |
| `--g1` | `#171717` | hover fill | — |
| `--line` | `#303030` | hairlines, panel and output borders, navbar rule | decorative |
| `--line-strong` | `#4c4c4c` | button, grid and canvas borders; inactive tab underline | decorative |
| `--g4` | `#616161` | decorative grey | 3.4:1, never used for text |
| `--muted` | `#8f8f8f` | secondary text, labels, ghost buttons, placeholders | 6.6:1 |
| `--soft` | `#c7c7c7` | body text, inactive tabs, handles | 12.6:1 |
| `--bright` | `#e0e0e0` | body text over the network background | 15.4:1 |
| `--ink` | `#ffffff` | headings, tile on, frame, stage-card border | 21:1 |
| `--accent` | `#38bdf8` | the signal | 10.0:1 |
| `--accent-hover` | `#7dd3fc` | primary button hover | — |
| `--accent-dim` | `rgba(56,189,248,.12)` | selected fills (reserved) | — |

**Data-viz palette (History only).**
- Colours: `#38bdf8`, `#a78bfa`, `#818cf8`, `#0ea5e9`, `#f59e0b`, `#10b981`, `#ef4444`, `#f97316`, `#a3e635`, `#06b6d4`.
- Red (`#ef4444`) is also used for the human-level line.
- No pink: the owner replaced `#ec4899` with lime on 2026-10-17.

**Model input, not UI.** The Stage 3 canvas pixels (white strokes on black)
follow MNIST conventions and are set in `stage3.js`. They are not part of
this palette.

### 2.2 Typography

All text uses one family: `var(--font)` = `'JetBrains Mono', 'Fira Code',
'Cascadia Code', monospace`. It is loaded once, by `@import` from Google
Fonts at the top of `style.css`.

| Token | Desktop | Phone (≤ 640px) | Weight | Line height | Use |
|---|---|---|---|---|---|
| `--fs-display` | 49px | 36px | 400 | 1.15, tracking −0.01em | landing hero title |
| `--fs-title` | 31px | 25px | 400 | 1.2 | page titles |
| `--fs-heading` | 20px | 20px | 500 | 1.3 | card headings |
| `--fs-body` | 16px | 16px | 400 | 1.7–1.75 | body, output, partners |
| `--fs-ui` | 14px | 14px | 400 / 500 | 1.5 | buttons, tabs, brand, card text |
| `--fs-label` | 12px | 12px | 500 | 1.4, tracking 0.14em, UPPERCASE | `.label` |

Weight 600 is used only for the primary button label. Never use bold
display type.

### 2.3 Space, layout and shape

| Token | Value | Use |
|---|---|---|
| `--s1` … `--s9` | 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96 | every gap and padding |
| `--column` | 1120px | content column including gutters (`.container`) |
| `--gutter` | 56px (20 on phones) | column side padding |
| `--frame-inset` | 20px (8 on phones) | distance of the frame from the viewport edge |
| `--frame-width` | 2px | frame stroke (stage cards use 1px) |
| `--nav-height` | 64px | navbar minimum height |
| `--control-h` | 44px | button height, the minimum touch target |
| `--radius-btn` | 2px | buttons; every other surface is square |

The single breakpoint is `@media (max-width: 640px)`. It overrides the
tokens above and stacks `.panel`s full width.

### 2.4 Background

- **Background A (shipped):** `static/img/network_bg.webp`.
  - The poster's particle network, levelled to pure black and cropped to the lower 700px (1920×700, 86 KB).
  - CSS: `body { background: var(--bg) url('img/network_bg.webp') no-repeat center bottom / max(100%, 960px) auto; }`.
- **Background B (alternative, not shipped):** `resources/design/reference/network.svg`.
  - A generated SVG network (505 nodes, seed 28, 49 KB).
  - Swapping backgrounds means changing one `url()`.
- **Readability:** surfaces that sit over the background use a `--bg` fill, never transparency.

### 2.5 Motion

Motion is minimal by design.
- **Colour and border transitions:** 0.12s on tabs and buttons, 0.1s on tiles.
- **History rows:** `all 0.2s ease`.
- **Chart:** Recharts' default draw-in animation.
- There is no other motion. There are no motion tokens yet; add them before introducing new motion.

---

## 3. Patterns

### 3.1 Page shell (`base.html`)

```
body                         black + network background, overflow hidden
├── .frame                   fixed, inset --frame-inset, 2px --ink border, aria-hidden, z 20
└── .viewport                fixed inside the frame (inset = frame-inset + frame-width),
    │                        overflow-y auto, flex column, scrollbar hidden,
    │                        tabindex="-1" autofocus
    ├── .navbar              sticky top
    ├── {% block content %}  page sections (.container)
    └── .partners            footer; margin-top: auto (bottom of short pages)
{% block scripts %}
```

- **Using the shell:** a page sets `{% set active_page = 'stage1' %}` (or `stage2`, `stage3`, `history`; nothing on the landing page) and fills the `title`, `content` and `scripts` blocks.
- **Hidden scrollbar:** owner's rule from 1.1.11, set with `scrollbar-width: none`, `-ms-overflow-style: none` and `::-webkit-scrollbar { display: none }`. Wheel, touch and keyboard still scroll; `autofocus` routes Page Down, Space and the arrow keys from page load. Never add a visible scrollbar back.
- **Guarded by:** `tests/test_app_smoke.py::PagesTest.test_page_shell`.

### 3.2 Navigation

A sticky navbar holds the brand (a home link) and four underlined tabs.
Exactly one tab is active on a stage or History page; none is active on the
landing page.

### 3.3 Workspace (stage pages)

`.workspace` is a wrapping flex row with a `--s5` gap. It holds:
1. `.panel` (the input);
2. `.panel.controls` (the buttons, bottom-aligned, under a `Controls` label);
3. `.output` (the result).

Stage 1 puts its two buttons inside the input panel instead (`.button-row`).
On phones every panel takes the full width.

### 3.4 Feedback

The output panel is the only feedback surface. It shows everything the page
script writes:
- progress (`Recognizing…`, `Learning…`);
- results;
- errors (`Error: …`).

The panel's border and label turn accent whenever it has content. There
are no toasts or modals.

### 3.5 Footer

`partials/_partners.html` sits on every page as the last block of the
scroll window. It is a solid black panel with no border and no label.

---

## 4. Components

## Component: PageShell

### Description
The frame every page lives in: a fixed white frame around the viewport and
a scroll window inside it, so content never crosses the frame line. Use it
for every page by extending `base.html`; never rebuild it in a page.

### Variants
| Variant | Use when |
|---|---|
| Desktop | viewport > 640px: frame inset 20px |
| Phone | viewport ≤ 640px: frame inset 8px, gutter 20px |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `active_page` | Jinja var | `''` | `stage1`, `stage2`, `stage3`, `history`; marks the active tab |
| `title` block | Jinja block | `Digit Recognition` | page `<title>` |
| `content` block | Jinja block | — | page sections |
| `scripts` block | Jinja block | — | page scripts, after the shell |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | frame + window, no scrollbar | wheel/touch/keyboard scroll the window |
| Short page | footer pushed to the window bottom | — |
| Focused window | no outline (`.viewport:focus`) | receives keyboard scroll from load |

### Accessibility
- **Role:** structural; the frame is `aria-hidden="true"`.
- **Keyboard:** the window is `tabindex="-1" autofocus`, so Page Down, Space and the arrow keys scroll it without a click. Tab order is unaffected.
- **Screen reader:** reads the navbar, the content and the footer in document order.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Extend `base.html` | Copy the navbar or footer into a page |
| Keep surfaces over the background filled with `--bg` | Make panels transparent over the network |
| Keep the scrollbar hidden | Re-enable a visible scrollbar on `.viewport` |

### Code Example
```jinja
{% extends 'base.html' %}
{% set active_page = 'stage1' %}
{% block title %}Stage 1 — Binary Classification{% endblock %}
{% block content %}<main class="stage-main container">…</main>{% endblock %}
{% block scripts %}<script src="{{ url_for('static', filename='stage1.js') }}"></script>{% endblock %}
```

## Component: NavTab

### Description
An underlined text tab in the sticky navbar, linking to a stage or to
History. It lives only in `base.html`.

### Variants
| Variant | Use when |
|---|---|
| Default | any page that isn't the current one |
| Active (`.active`) | the current page |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `href` | URL | — | `/stage1/`, `/stage2/`, `/stage3/`, `/history/` |
| `.active` | class | off | set by `active_page` |
| `aria-current` | attr | — | `page` on the active tab |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | `--soft` text, 1px `--line-strong` underline at 7px offset | — |
| Hover | `--ink` text and underline | 0.12s transition |
| Active | `--accent` text, 2px `--accent` underline | — |
| Focus | 2px accent outline, 2px offset | — |

### Accessibility
- **Role:** link inside `<nav class="navbar">`.
- **Keyboard:** Tab and Enter.
- **Screen reader:** "Stage 2, link, current page" on the active tab.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Mark exactly one tab active | Use filled pills or backgrounds for the active tab |
| Keep the brand on the left as the home link | Add icons to tabs |

### Code Example
```html
<a href="/stage2/" class="nav-tab active" aria-current="page">Stage 2</a>
```

## Component: Button

### Description
The action control: 44px tall, square-ish with a 2px radius, in monospace.
It is used for recognition actions, resets and "Try Stage N" links.

### Variants
| Variant | Use when |
|---|---|
| `.btn` (Default) | ordinary actions: Recognize (stages 1–2), Learn, Clear, Upload Image, Try Stage N |
| `.btn-primary` | the **one** main action of a page (Stage 3 Recognize) |
| `.btn-ghost` | reset or secondary actions (Refresh) |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| element | `<button>` / `<a>` | — | `<a>` only for navigation |
| `id` | string | — | script hook (`recognizeBtn`, `refreshBtn`, `learnBtn`, `clearBtn`, `uploadBtn`): never rename |
| `.recognize-btn` / `.refresh-btn` | class | — | legacy hooks kept from 1.0 (no styling) |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | black, 1px `--line-strong` border, `--ink` label | — |
| Hover | `--accent` border and label (primary: `--accent-hover` fill) | 0.12s |
| Focus | 2px accent outline | — |
| Active | browser default press | — |
| Disabled | not designed yet | add `.btn[disabled]` when needed |
| Loading | not designed yet; progress shows in the output panel | — |

### Accessibility
- **Role:** button, or link for `<a>`.
- **Keyboard:** Tab, then Enter or Space.
- **Screen reader:** reads the visible label.
- **Touch target:** at least 44px.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Use at most one `.btn-primary` per page | Use the primary button for every action |
| Use ghost for resets | Style a ghost button with a border |

### Code Example
```html
<button class="btn btn-primary recognize-btn" id="recognizeBtn">Recognize</button>
<button class="btn btn-ghost refresh-btn" id="refreshBtn">Refresh</button>
```

## Component: Label

### Description
A small uppercase eyebrow above headings and inside panels ("STAGE 01",
"OUTPUT", "CONTROLS", "THREE STAGES").

### Variants
| Variant | Use when |
|---|---|
| `.label` | neutral panel labels (Controls, Output when empty) |
| `.label.label-accent` | stage numbers and section names |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| class | `.label` (+ `.label-accent`) | — | 12px / 500 / 0.14em / uppercase |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | `--muted` (or `--accent`) | — |
| In a filled output | turns `--accent` | via `.output:has(...)` |

### Accessibility
- Plain text with no role. Keep the label's words meaningful when read aloud.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Use the label for short category words | Put sentences in a label |

### Code Example
```html
<span class="label label-accent">Stage 01</span>
```

## Component: StageCard

### Description
A landing-page card introducing one stage: label, heading, a short
description with the grid size highlighted, and a "Try Stage N" button.
Three cards sit in one row.

### Variants
| Variant | Use when |
|---|---|
| Stage card | one per stage on the landing page |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| label | text | — | `Stage 0N` (`.label-accent`) |
| heading | `h2` | — | stage name |
| body | `p` with `<strong>` | — | the grid size is set in `--ink` |
| action | `a.btn` | — | link to `/stageN/` |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | black, **1px white border** (the frame at half weight), square, padding 32/28 | — |

### Accessibility
- Heading level 2 under the page's h1. The action is a real link.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep the white border for stage cards only | Give panels or the footer a white border |
| Keep all three cards in one row (`auto-fill, minmax(260px, 1fr)`) | Let the row wrap on desktop |

### Code Example
```html
<div class="stage-card">
  <span class="label label-accent">Stage 01</span>
  <h2>Binary Classification</h2>
  <p>Classify a zero or one drawn on a <strong>3×3 pixel grid</strong> — the simplest form of image recognition.</p>
  <a href="/stage1/" class="btn">Try Stage 1</a>
</div>
```

## Component: TileGrid

### Description
The pixel grid of stages 1 and 2. It is made of 60px square tiles that
toggle on click. The page script builds the tiles; the template provides
only `#grid`.

### Variants
| Variant | Use when |
|---|---|
| 3×3 | Stage 1 (default `.grid` template) |
| 3×5 | Stage 2 (`stage2.js` sets the template) |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#grid` | id | — | script hook: never rename |
| `.tile` | class (JS-created div) | — | one pixel |
| `.on` | class | off | pixel set; read by `getGridState()` |

### States
| State | Visual | Behavior |
|---|---|---|
| Off | `--field` fill with a `--line` border | click toggles |
| Hover (off) | `--g1` | 0.1s |
| On | `--ink` | click toggles |

### Accessibility
- The tiles are `div`s created by the stage scripts and are mouse/touch only. A known gap: a keyboard-operable version (buttons with `aria-pressed`) is follow-up work that needs a script change.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep on = white, off = near-black (it mirrors the model input) | Colour tiles with the accent |

### Code Example
```html
<div class="grid" id="grid"></div>  <!-- tiles appended by stage1.js / stage2.js -->
```

## Component: DrawCanvas

### Description
The Stage 3 drawing surface: a 280×280 canvas (downsampled to 28×28 for
the model) with a caption. It accepts drawing or an uploaded image.

### Variants
| Variant | Use when |
|---|---|
| Canvas | Stage 3 only |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#drawCanvas` | id | — | script hook |
| `width`/`height` | attr | 280 | drawing resolution (model input), never change |
| `#fileInput` | hidden file input | — | opened by `#uploadBtn` |

### States
| State | Visual | Behavior |
|---|---|---|
| Empty | black, 1px `--line-strong` outline | crosshair cursor |
| Drawn | white strokes (20px, round) | mouse and touch drawing |
| Phone | `max-width: 100%`, height auto | `stage3.js` maps the pointer through the CSS size |

### Accessibility
- Pointer-only drawing. The upload path (`Upload Image`) is the keyboard-accessible alternative.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep the canvas pixels white on black | Restyle stroke or fill colours (they are model input) |

### Code Example
```html
<canvas id="drawCanvas" class="draw-canvas" width="280" height="280"></canvas>
<span class="canvas-note">280 × 280 → 28 × 28 · white on black (MNIST)</span>
```

## Component: ControlsPanel

### Description
The stage-page panel that holds the action buttons, bottom-aligned under a
`Controls` label (stages 2 and 3).

### Variants
| Variant | Use when |
|---|---|
| `.panel.controls` | stages 2–3 |
| `.button-row` inside the input panel | Stage 1 (two buttons only) |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `.side-menu` | class | — | legacy hook kept from 1.0 |
| min-width | — | 200px | — |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | black panel, 1px `--line` border, padding 28 | — |

### Accessibility
- Contains real buttons in DOM order (Learn → Recognize → Refresh; Clear → Upload → Recognize).

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Put the primary action last (nearest the output) | Mix navigation links into controls |

### Code Example
```html
<div class="panel controls side-menu">
  <span class="label">Controls</span>
  <button class="btn recognize-btn" id="learnBtn">Learn</button>
  <button class="btn recognize-btn" id="recognizeBtn">Recognize</button>
  <button class="btn btn-ghost refresh-btn" id="refreshBtn">Refresh</button>
</div>
```

## Component: OutputPanel

### Description
The stage result surface. The page script writes text or HTML into
`#result`; the panel shows a placeholder while empty and turns accent
when filled.

### Variants
| Variant | Use when |
|---|---|
| Output | every stage page |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#result` (`.result-box`) | id | — | script hook: the JS writes here |
| `.result-row` | class (in JS output) | — | tabular `--ink` numbers |

### States
| State | Visual | Behavior |
|---|---|---|
| Empty | `--line` border, `--muted` label, "awaiting input" (CSS `::before`) | — |
| Progress / result / error | `--accent` border and label | `:has(.result-box:not(:empty))` |

### Accessibility
- **Role:** `section` with `aria-live="polite"`, so results are announced.
- The placeholder is CSS content and is not announced as a result.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Write all progress, results and errors into `#result` | Add toasts or alerts for results |

### Code Example
```html
<section class="output" aria-live="polite">
  <span class="label">Output</span>
  <div class="result-box" id="result"></div>
</section>
```

## Component: PartnersFooter

### Description
The footer on every page: partner lock-ups (logo, name, handle) on a solid
black panel. Entries share the row equally, each centred.

### Variants
| Variant | Use when |
|---|---|
| 1 row | up to 3–4 partners at desktop width |
| Wrapped | more partners or phone width: new centred rows |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `.partner` | `<li>` | — | one partner |
| logo | `<img>` 64×64 | — | `static/img/partners/*.png`, with `alt` |
| name / handle | text | — | the handle is `--soft`, underlined |

### States
| State | Visual | Behavior |
|---|---|---|
| Default | black panel, padding 28, **no border, no label** | `margin-top: auto` (bottom of short pages) |

### Accessibility
- `<ul>`/`<li>` list; the logos carry `alt` text. Handles are text, not links.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Add a partner as one more `<li>` | Add a "Partners" heading or a border |

### Code Example
```html
<li class="partner">
  <img src="{{ url_for('static', filename='img/partners/tech_prosvet.png') }}" alt="Tech.ProSvet logo" width="64" height="64">
  <div class="partner-text"><span>Tech.ProSvet</span><span class="partner-handle">@tech_illumination</span></div>
</li>
```

## Component: HistoryChart

### Description
The History page dashboard: a Recharts error-rate line chart, expandable
milestone rows, a key-insight box and a sources line. It is built by
`history.js` with inline styles that follow the tokens.

### Variants
| Part | Use |
|---|---|
| Chart panel | black, 1px `#303030` border, square; grid `rgba(255,255,255,.08)`; axes `#4c4c4c` |
| Line + dots | line `#38bdf8` 3px; dots r7 in the milestone colour, 2px white stroke; active dot r10 |
| Human-level line | dashed `#ef4444`, label inside the plot, top right |
| Tooltip | `#0d0d0d`, 2px border in the milestone colour, square |
| Milestone row | black with a `#303030` border; open: `#0d0d0d` with a border in the milestone colour |
| Badge | error % outlined in the milestone colour; "Origin" outlined in accent |
| Source link | in the milestone colour, faint border, opens a new tab |
| Key insight | black, 1px accent border |

### Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#dashboard-root` | id | — | React mount: never rename |
| `milestones[].color` | hex | — | data-viz palette only (no pink) |

### States
| State | Visual | Behavior |
|---|---|---|
| Row closed | dot, year, label, badge | click opens |
| Row open | method, detail, source link | click closes; link click doesn't toggle |
| Chart hover | tooltip | — |

### Accessibility
- **Known gap:** the rows are clickable `div`s, so not keyboard-operable. Making them `<button>`s is a follow-up change to `history.js`.
- Links open with `rel="noopener noreferrer"`.

### Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep categorical colours inside the chart and rows | Use categorical colours in page chrome |

### Code Example
```js
e(ReferenceLine, { y: 0.2, stroke: "#ef4444", strokeDasharray: "6 4",
  label: { value: "≈ Human level (0.2%)", position: "insideTopRight", fill: "#ef4444" } })
```

---

## 5. Pages

| Page | Route | Template | Script | Active tab |
|---|---|---|---|---|
| Landing | `/` | `index.html` | — | none |
| Stage 1 — Binary Classification | `/stage1/` | `stage1.html` | `stage1.js` | Stage 1 |
| Stage 2 — Digit Recognition | `/stage2/` | `stage2.html` | `stage2.js` | Stage 2 |
| Stage 3 — MNIST Recognition | `/stage3/` | `stage3.html` | `stage3.js` | Stage 3 |
| History — MNIST Milestones | `/history/` | `history.html` | `history.js` (React 18 + Recharts 2 from unpkg) | History |

### 5.1 Landing
1. **Hero:** an h1 in display type ("Neural Networks & / Digit Recognition"), then two paragraphs, the first in `--ink` and the second in `--bright` (owner: both must read clearly over the network).
2. **"Three Stages":** a section head (accent label plus a hairline rule), then three StageCards in one row.
3. **PartnersFooter.**

### 5.2 Stage 1
- Header: the "Stage 01" label, h1, and a description with *Recognize* underlined.
- Workspace: a panel holding the 3×3 TileGrid and the Recognize + Refresh button row, then the OutputPanel.
- I/O: `POST /stage1/recognize {pixels: [9 × 0/1]}` → `{probabilities: [p0, p1]}`. Shown as "This is: 0: N% 1: N%".

### 5.3 Stage 2
- Workspace: a panel with the 3×5 TileGrid; a ControlsPanel with Learn, Recognize and Refresh; the OutputPanel.
- I/O:
  - `POST /stage2/recognize {pixels: [15]}` → `{status, digit, probability}`.
  - `POST /stage2/learn` → `{generations, error}`, with a 120 s client timeout.

### 5.4 Stage 3
- Workspace: a panel with the DrawCanvas and caption; a ControlsPanel with Clear, Upload Image and Recognize (**primary**); the OutputPanel.
- I/O: `POST /stage3/recognize {image: dataURL 280×280 PNG}` → `{status, digit}`. Shown as "Recognized digit is: N".

### 5.5 History
- Contents: the title and lead paragraph, the HistoryChart panel, the milestone rows, the key insight and the sources line. All of it renders into `#dashboard-root`, which sits in a 1012px column.

---

## 6. Accessibility baseline
- Text contrast is at least 4.5:1 on black; `--g4` and darker are never used for text.
- Controls are real `<button>` and `<a>` elements. `:focus-visible` draws a 2px accent outline.
- Navigation: `aria-current` marks the active tab; `aria-live` is set on outputs.
- The frame is `aria-hidden`; logos have `alt` text.
- Buttons are at least 44px; tiles are 60px.
- **Keyboard scrolling:** works without a click (the window has `autofocus`).
- **Known gaps:**
  - tiles and History rows aren't keyboard-operable (each needs a script change);
  - there are no disabled or loading button states yet.

## 7. Extending the system
1. **Reuse first:** prefer a modifier class (`.btn-…`, `.panel-…`) over a new component.
2. **Spec it** in this format, then add it to `DESIGN_SYSTEM.md`.
3. **Tokens first:** a missing value becomes a `:root` token before it is used.
4. **Implement** in `style.css` with `var(--token)` only. Keep every id, and add new script hooks to `test_page_script_hooks`.
5. **Mirror** the change to the claude.ai Design System, Figma, the Miro Sandbox board and the Claude Design project, and log the version.

## 8. File map
| Path | Holds |
|---|---|
| `app/static/style.css` | tokens, shell, components, page sections |
| `app/templates/base.html` | page shell |
| `app/templates/partials/_partners.html` | footer |
| `app/templates/{index,stage1,stage2,stage3,history}.html` | pages |
| `app/static/stage{1,2,3}.js`, `history.js` | behaviour (do not restyle through JS, except the History chrome) |
| `app/static/img/` | `network_bg.webp`, `partners/*.png` |
| `resources/documentation/DESIGN_SYSTEM.md` | the system's rules and change log |
| `resources/design/reference/` | poster dataset, layers, philosophy, background B |
| `tests/test_app_smoke.py` | shell and id-hook tests |

## 9. Change log
| Version | Change |
|---|---|
| 1.1.11 | Signal on Black shipped (B-10): tokens, shell with fixed frame and hidden-scrollbar window, partners footer, network background, History chrome |
| 1.1.12 | B-10 closed; all branches at 1.1.12 |
| 1.1.13 | Mirrors re-synced; this full documentation added |
