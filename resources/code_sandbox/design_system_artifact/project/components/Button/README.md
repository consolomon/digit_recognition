# Button

The action control: 44px tall, square-ish with a 2px radius, in monospace. It is used for recognition actions, resets and "Try Stage N" links.

## Variants
| Variant | Use when |
|---|---|
| `.btn` (Default) | ordinary actions: Recognize (stages 1–2), Learn, Clear, Upload Image, Try Stage N |
| `.btn-primary` | the **one** main action of a page (Stage 3 Recognize) |
| `.btn-ghost` | reset or secondary actions (Refresh) |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| element | `<button>` / `<a>` | — | `<a>` only for navigation |
| `id` | string | — | script hook (`recognizeBtn`, `refreshBtn`, `learnBtn`, `clearBtn`, `uploadBtn`): never rename |
| `.recognize-btn` / `.refresh-btn` | class | — | legacy hooks kept from 1.0 (no styling) |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | black, 1px `--line-strong` border, `--ink` label | — |
| Hover | `--accent` border and label (primary: `--accent-hover` fill) | 0.12s |
| Focus | 2px accent outline | — |
| Active | browser default press | — |
| Disabled | not designed yet | add `.btn[disabled]` when needed |
| Loading | not designed yet; progress shows in the output panel | — |

## Accessibility
- **Role:** button, or link for `<a>`.
- **Keyboard:** Tab, then Enter or Space.
- **Screen reader:** reads the visible label.
- **Touch target:** at least 44px.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Use at most one `.btn-primary` per page | Use the primary button for every action |
| Use ghost for resets | Style a ghost button with a border |

## Code Example
```html
<button class="btn btn-primary recognize-btn" id="recognizeBtn">Recognize</button>
<button class="btn btn-ghost refresh-btn" id="refreshBtn">Refresh</button>
```

