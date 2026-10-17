# Label

A small uppercase eyebrow above headings and inside panels ("STAGE 01", "OUTPUT", "CONTROLS", "THREE STAGES").

## Variants
| Variant | Use when |
|---|---|
| `.label` | neutral panel labels (Controls, Output when empty) |
| `.label.label-accent` | stage numbers and section names |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| class | `.label` (+ `.label-accent`) | — | 12px / 500 / 0.14em / uppercase |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | `--muted` (or `--accent`) | — |
| In a filled output | turns `--accent` | via `.output:has(...)` |

## Accessibility
- Plain text with no role. Keep the label's words meaningful when read aloud.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Use the label for short category words | Put sentences in a label |

## Code Example
```html
<span class="label label-accent">Stage 01</span>
```

