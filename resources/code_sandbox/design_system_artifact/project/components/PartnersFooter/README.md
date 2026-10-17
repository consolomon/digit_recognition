# PartnersFooter

The footer on every page: partner lock-ups (logo, name, handle) on a solid black panel. Entries share the row equally, each centred.

## Variants
| Variant | Use when |
|---|---|
| 1 row | up to 3–4 partners at desktop width |
| Wrapped | more partners or phone width: new centred rows |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `.partner` | `<li>` | — | one partner |
| logo | `<img>` 64×64 | — | `static/img/partners/*.png`, with `alt` |
| name / handle | text | — | the handle is `--soft`, underlined |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | black panel, padding 28, **no border, no label** | `margin-top: auto` (bottom of short pages) |

## Accessibility
- `<ul>`/`<li>` list; the logos carry `alt` text. Handles are text, not links.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Add a partner as one more `<li>` | Add a "Partners" heading or a border |

## Code Example
```html
<li class="partner">
  <img src="{{ url_for('static', filename='img/partners/tech_prosvet.png') }}" alt="Tech.ProSvet logo" width="64" height="64">
  <div class="partner-text"><span>Tech.ProSvet</span><span class="partner-handle">@tech_illumination</span></div>
</li>
```

