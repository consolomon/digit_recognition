# StageCard

A landing-page card introducing one stage: label, heading, a short description with the grid size highlighted, and a "Try Stage N" button. Three cards sit in one row.

## Variants
| Variant | Use when |
|---|---|
| Stage card | one per stage on the landing page |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| label | text | — | `Stage 0N` (`.label-accent`) |
| heading | `h2` | — | stage name |
| body | `p` with `<strong>` | — | the grid size is set in `--ink` |
| action | `a.btn` | — | link to `/stageN/` |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | black, **1px white border** (the frame at half weight), square, padding 32/28 | — |

## Accessibility
- Heading level 2 under the page's h1. The action is a real link.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep the white border for stage cards only | Give panels or the footer a white border |
| Keep all three cards in one row (`auto-fill, minmax(260px, 1fr)`) | Let the row wrap on desktop |

## Code Example
```html
<div class="stage-card">
  <span class="label label-accent">Stage 01</span>
  <h2>Binary Classification</h2>
  <p>Classify a zero or one drawn on a <strong>3×3 pixel grid</strong> — the simplest form of image recognition.</p>
  <a href="/stage1/" class="btn">Try Stage 1</a>
</div>
```

