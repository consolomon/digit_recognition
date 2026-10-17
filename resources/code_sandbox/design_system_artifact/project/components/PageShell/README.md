# PageShell

The frame every page lives in: a fixed white frame around the viewport and a scroll window inside it, so content never crosses the frame line. Use it for every page by extending `base.html`; never rebuild it in a page.

## Variants
| Variant | Use when |
|---|---|
| Desktop | viewport > 640px: frame inset 20px |
| Phone | viewport ≤ 640px: frame inset 8px, gutter 20px |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `active_page` | Jinja var | `''` | `stage1`, `stage2`, `stage3`, `history`; marks the active tab |
| `title` block | Jinja block | `Digit Recognition` | page `<title>` |
| `content` block | Jinja block | — | page sections |
| `scripts` block | Jinja block | — | page scripts, after the shell |

## States
| State | Visual | Behavior |
|---|---|---|
| Default | frame + window, no scrollbar | wheel/touch/keyboard scroll the window |
| Short page | footer pushed to the window bottom | — |
| Focused window | no outline (`.viewport:focus`) | receives keyboard scroll from load |

## Accessibility
- **Role:** structural; the frame is `aria-hidden="true"`.
- **Keyboard:** the window is `tabindex="-1" autofocus`, so Page Down, Space and the arrow keys scroll it without a click. Tab order is unaffected.
- **Screen reader:** reads the navbar, the content and the footer in document order.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Extend `base.html` | Copy the navbar or footer into a page |
| Keep surfaces over the background filled with `--bg` | Make panels transparent over the network |
| Keep the scrollbar hidden | Re-enable a visible scrollbar on `.viewport` |

## Code Example
```jinja
{% extends 'base.html' %}
{% set active_page = 'stage1' %}
{% block title %}Stage 1 — Binary Classification{% endblock %}
{% block content %}<main class="stage-main container">…</main>{% endblock %}
{% block scripts %}<script src="{{ url_for('static', filename='stage1.js') }}"></script>{% endblock %}
```

