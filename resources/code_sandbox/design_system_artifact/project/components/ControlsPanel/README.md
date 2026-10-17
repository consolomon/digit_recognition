# ControlsPanel

The stage-page panel that holds the action buttons, bottom-aligned under a `Controls` label (stages 2 and 3).

## Variants
| Variant | Use when |
|---|---|
| `.panel.controls` | stages 2–3 |
| `.button-row` inside the input panel | Stage 1 (two buttons only) |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `.side-menu` | class | — | legacy hook kept from 1.0 |
| min-width | — | 200px | — |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | black panel, 1px `--line` border, padding 28 | — |

## Accessibility
- Contains real buttons in DOM order (Learn → Recognize → Refresh; Clear → Upload → Recognize).

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Put the primary action last (nearest the output) | Mix navigation links into controls |

## Code Example
```html
<div class="panel controls side-menu">
  <span class="label">Controls</span>
  <button class="btn recognize-btn" id="learnBtn">Learn</button>
  <button class="btn recognize-btn" id="recognizeBtn">Recognize</button>
  <button class="btn btn-ghost refresh-btn" id="refreshBtn">Refresh</button>
</div>
```

