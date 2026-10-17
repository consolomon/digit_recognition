# TileGrid

The pixel grid of stages 1 and 2. It is made of 60px square tiles that toggle on click. The page script builds the tiles; the template provides only `#grid`.

## Variants
| Variant | Use when |
|---|---|
| 3×3 | Stage 1 (default `.grid` template) |
| 3×5 | Stage 2 (`stage2.js` sets the template) |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#grid` | id | — | script hook: never rename |
| `.tile` | class (JS-created div) | — | one pixel |
| `.on` | class | off | pixel set; read by `getGridState()` |

## States
| State | Visual | Behavior |
|---|---|---|
| Off | `--field` fill with a `--line` border | click toggles |
| Hover (off) | `--g1` | 0.1s |
| On | `--ink` | click toggles |

## Accessibility
- The tiles are `div`s created by the stage scripts and are mouse/touch only. A known gap: a keyboard-operable version (buttons with `aria-pressed`) is follow-up work that needs a script change.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep on = white, off = near-black (it mirrors the model input) | Colour tiles with the accent |

## Code Example
```html
<div class="grid" id="grid"></div>  <!-- tiles appended by stage1.js / stage2.js -->
```

