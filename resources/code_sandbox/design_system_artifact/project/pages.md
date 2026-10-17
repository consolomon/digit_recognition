# Pages

| Page | Route | Template | Script | Active tab |
|---|---|---|---|---|
| Landing | `/` | `index.html` | — | none |
| Stage 1 — Binary Classification | `/stage1/` | `stage1.html` | `stage1.js` | Stage 1 |
| Stage 2 — Digit Recognition | `/stage2/` | `stage2.html` | `stage2.js` | Stage 2 |
| Stage 3 — MNIST Recognition | `/stage3/` | `stage3.html` | `stage3.js` | Stage 3 |
| History — MNIST Milestones | `/history/` | `history.html` | `history.js` (React 18 + Recharts 2 from unpkg) | History |

## 5.1 Landing
1. **Hero:** an h1 in display type ("Neural Networks & / Digit Recognition"), then two paragraphs, the first in `--ink` and the second in `--bright` (owner: both must read clearly over the network).
2. **"Three Stages":** a section head (accent label plus a hairline rule), then three StageCards in one row.
3. **PartnersFooter.**

## 5.2 Stage 1
- Header: the "Stage 01" label, h1, and a description with *Recognize* underlined.
- Workspace: a panel holding the 3×3 TileGrid and the Recognize + Refresh button row, then the OutputPanel.
- I/O: `POST /stage1/recognize {pixels: [9 × 0/1]}` → `{probabilities: [p0, p1]}`. Shown as "This is: 0: N% 1: N%".

## 5.3 Stage 2
- Workspace: a panel with the 3×5 TileGrid; a ControlsPanel with Learn, Recognize and Refresh; the OutputPanel.
- I/O:
  - `POST /stage2/recognize {pixels: [15]}` → `{status, digit, probability}`.
  - `POST /stage2/learn` → `{generations, error}`, with a 120 s client timeout.

## 5.4 Stage 3
- Workspace: a panel with the DrawCanvas and caption; a ControlsPanel with Clear, Upload Image and Recognize (**primary**); the OutputPanel.
- I/O: `POST /stage3/recognize {image: dataURL 280×280 PNG}` → `{status, digit}`. Shown as "Recognized digit is: N".

## 5.5 History
- Contents: the title and lead paragraph, the HistoryChart panel, the milestone rows, the key insight and the sources line. All of it renders into `#dashboard-root`, which sits in a 1012px column.
