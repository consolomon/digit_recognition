# DrawCanvas

The Stage 3 drawing surface: a 280×280 canvas (downsampled to 28×28 for the model) with a caption. It accepts drawing or an uploaded image.

## Variants
| Variant | Use when |
|---|---|
| Canvas | Stage 3 only |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#drawCanvas` | id | — | script hook |
| `width`/`height` | attr | 280 | drawing resolution (model input), never change |
| `#fileInput` | hidden file input | — | opened by `#uploadBtn` |

## States
| State | Visual | Behavior |
|---|---|---|
| Empty | black, 1px `--line-strong` outline | crosshair cursor |
| Drawn | white strokes (20px, round) | mouse and touch drawing |
| Phone | `max-width: 100%`, height auto | `stage3.js` maps the pointer through the CSS size |

## Accessibility
- Pointer-only drawing. The upload path (`Upload Image`) is the keyboard-accessible alternative.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep the canvas pixels white on black | Restyle stroke or fill colours (they are model input) |

## Code Example
```html
<canvas id="drawCanvas" class="draw-canvas" width="280" height="280"></canvas>
<span class="canvas-note">280 × 280 → 28 × 28 · white on black (MNIST)</span>
```

