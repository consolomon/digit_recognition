# NavTab

An underlined text tab in the sticky navbar, linking to a stage or to History. It lives only in `base.html`.

## Variants
| Variant | Use when |
|---|---|
| Default | any page that isn't the current one |
| Active (`.active`) | the current page |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `href` | URL | — | `/stage1/`, `/stage2/`, `/stage3/`, `/history/` |
| `.active` | class | off | set by `active_page` |
| `aria-current` | attr | — | `page` on the active tab |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | `--soft` text, 1px `--line-strong` underline at 7px offset | — |
| Hover | `--ink` text and underline | 0.12s transition |
| Active | `--accent` text, 2px `--accent` underline | — |
| Focus | 2px accent outline, 2px offset | — |

## Accessibility
- **Role:** link inside `<nav class="navbar">`.
- **Keyboard:** Tab and Enter.
- **Screen reader:** "Stage 2, link, current page" on the active tab.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Mark exactly one tab active | Use filled pills or backgrounds for the active tab |
| Keep the brand on the left as the home link | Add icons to tabs |

## Code Example
```html
<a href="/stage2/" class="nav-tab active" aria-current="page">Stage 2</a>
```

