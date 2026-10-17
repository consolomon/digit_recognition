# Architecture — Digit Recognition

The app's design record and its guardrails. **Read before touching a
stage's model code, its weights, a route contract, or the shared UI.**
Workflow policy lives in `CLAUDE.md`; this file holds what the app *is*.

---

## What it is

An educational Flask app that walks from the simplest neuron to MNIST digit
recognition in three stages. Pure Python + NumPy networks (no ML framework),
HTML/CSS/vanilla JS front end, one Docker service behind nginx in
production.

| Stage | Input | Model | Code |
|---|---|---|---|
| 1 — Binary classification | 3×3 grid (9 × 0/1) | one hand-weighted neuron: 0 vs 1 | `app/stage1/model1.py` |
| 2 — Digit recognition | 5×3 grid (15 × 0/1) | 10 sigmoid neurons, trained in-app on 19 patterns | `app/stage2/` |
| 3 — MNIST recognition | 280×280 canvas → 28×28 grey | multi-layer net (leaky ReLU hidden, sigmoid output), trained offline on EMNIST-MNIST | `app/stage3/` |

Plus `/history/` — a React + Recharts dashboard of MNIST error-rate
milestones (`app/static/history.js`, libraries from unpkg).

## Routes and contracts

| Route | Method | Request | Response |
|---|---|---|---|
| `/` | GET | — | landing page |
| `/stage1/` | GET | — | page |
| `/stage1/recognize` | POST | `{"pixels": [9 × 0/1]}` row-major | `{"probabilities": [p0, p1]}` |
| `/stage2/` | GET | — | page |
| `/stage2/recognize` | POST | `{"pixels": [15 × 0/1]}` row-major | `{"status": "success", "digit": 0–9, "probability": float}` or `{"status": "error", "message": str}` |
| `/stage2/learn` | POST | — | `{"generations": int, "error": "0.0049"}` — **overwrites `stage2/weights.data`** |
| `/stage3/` | GET | — | page |
| `/stage3/recognize` | POST | `{"image": "data:image/png;base64,…"}` (white on black) | `{"status": "success", "digit": 0–9, "message": ""}` or `{"status": "error", "message": …}` |
| `/history/` | GET | — | page |

The page scripts (`app/static/stageN.js`) depend on exactly these shapes;
`tests/test_app_smoke.py` pins them.

## Files

| Path | Role |
|---|---|
| `app/app.py` | Flask app, all routes; puts its own dir on `sys.path` |
| `app/stage2/weights.data` | pickled `list[stage2.neuron.Neuron]` |
| `app/stage3/weights.data` | pickled `list[NeuronLayer]` (7.3 MB) |
| `app/stage3/emnist-mnist-*-ubyte` | EMNIST-MNIST train/test sets (53 MB), **training only** — kept in git, kept out of the image (`app/.dockerignore`) |
| `app/templates/`, `app/static/` | pages; `style.css` shared, one `stageN.js` per stage |

## Guardrails

### Pickled weights are bound to module paths

`weights.data` files are plain `pickle` dumps; unpickling imports the
classes by the module path recorded at save time:

| File | Recorded classes |
|---|---|
| `stage2/weights.data` | `stage2.neuron.Neuron` |
| `stage3/weights.data` | **top-level** `neuron.Neuron`, `neuron_layer.NeuronLayer`, `numpy._core.multiarray` |

Therefore, without re-training and re-pickling:
- never rename or move `app/stage2/neuron.py`, `app/stage3/neuron.py`,
  `app/stage3/neuron_layer.py`, nor the classes in them;
- never drop the `sys.path` insert in `app/stage3/__init__.py` (it makes
  the top-level `neuron` / `neuron_layer` names importable);
- NumPy must stay **≥ 2** (`numpy._core`).

A change that breaks one of these ships together with freshly pickled
weights, or not at all. Only unpickle files from this repo — `pickle` runs
code on load.

### UI

- **JetBrains Mono** is the font on every page, loaded once in the shared
  `app/static/style.css` (Google Fonts import, `body` font stack
  `'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace`). Never
  introduce another font family without the owner's approval.
- Every page `{% extends 'base.html' %}`. The base template carries the
  page shell: the fixed white frame, the scroll window, the navbar
  (brand + Stage 1/2/3/History tabs, `active` + `aria-current` on the
  current one) and the partners footer (`partials/_partners.html`). Never
  copy the navbar or footer into a page.
- The visual language is the **"Signal on Black"** design system
  (`DESIGN_SYSTEM.md`):
  - a black field, grey steps, and a **single accent `#38bdf8`**
    (categorical colours only in the History chart, no pink);
  - only the tokens on `:root` in `style.css`;
  - new components are added through `DESIGN_SYSTEM.md` §"Extending".
- Redesigns are visual only. Stage scripts find their elements by id
  (`grid`, `recognizeBtn`, `result`, …), so ids and the `#result` contract
  stay. `PagesTest.test_page_script_hooks` guards them.

---

## Decisions log

| ID | Date | Decision |
|---|---|---|
| ARCH-1 | 2026-10-17 | Training data stays in git but out of the Docker image (`.dockerignore`); the image carries only what recognition needs. |
| ARCH-2 | 2026-10-17 | Pickle guardrail above made explicit (module paths, NumPy ≥ 2). |
| ARCH-3 | 2026-10-17 | JetBrains Mono rule moved from Claude's memory into this file. |
| ARCH-4 | 2026-10-17 | B-10: the "Signal on Black" design system replaces the navy 1.0 UI. Owner's choices: keep the `#38bdf8` accent and JetBrains Mono; pure black field with the poster's network image (background A, over the generated SVG B); a fixed frame with the content scrolling inside; partners footer on every page; History keeps categorical colours (pink → lime). Templates moved to `base.html` + partials. Spec: `DESIGN_SYSTEM.md`. |
