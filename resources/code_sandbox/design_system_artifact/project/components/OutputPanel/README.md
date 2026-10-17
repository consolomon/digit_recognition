# OutputPanel

The stage result surface. The page script writes text or HTML into `#result`; the panel shows a placeholder while empty and turns accent when filled.

## Variants
| Variant | Use when |
|---|---|
| Output | every stage page |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#result` (`.result-box`) | id | — | script hook: the JS writes here |
| `.result-row` | class (in JS output) | — | tabular `--ink` numbers |

## States
| State | Visual | Behavior |
|---|---|---|
| Empty | `--line` border, `--muted` label, "awaiting input" (CSS `::before`) | — |
| Progress / result / error | `--accent` border and label | `:has(.result-box:not(:empty))` |

## Accessibility
- **Role:** `section` with `aria-live="polite"`, so results are announced.
- The placeholder is CSS content and is not announced as a result.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Write all progress, results and errors into `#result` | Add toasts or alerts for results |

## Code Example
```html
<section class="output" aria-live="polite">
  <span class="label">Output</span>
  <div class="result-box" id="result"></div>
</section>
```

