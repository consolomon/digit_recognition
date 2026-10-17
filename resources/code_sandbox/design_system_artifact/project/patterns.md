# Patterns

## 3.1 Page shell (`base.html`)

```
body                         black + network background, overflow hidden
├── .frame                   fixed, inset --frame-inset, 2px --ink border, aria-hidden, z 20
└── .viewport                fixed inside the frame (inset = frame-inset + frame-width),
    │                        overflow-y auto, flex column, scrollbar hidden,
    │                        tabindex="-1" autofocus
    ├── .navbar              sticky top
    ├── {% block content %}  page sections (.container)
    └── .partners            footer; margin-top: auto (bottom of short pages)
{% block scripts %}
```

- **Using the shell:** a page sets `{% set active_page = 'stage1' %}` (or `stage2`, `stage3`, `history`; nothing on the landing page) and fills the `title`, `content` and `scripts` blocks.
- **Hidden scrollbar:** owner's rule from 1.1.11, set with `scrollbar-width: none`, `-ms-overflow-style: none` and `::-webkit-scrollbar { display: none }`. Wheel, touch and keyboard still scroll; `autofocus` routes Page Down, Space and the arrow keys from page load. Never add a visible scrollbar back.
- **Guarded by:** `tests/test_app_smoke.py::PagesTest.test_page_shell`.

## 3.2 Navigation

A sticky navbar holds the brand (a home link) and four underlined tabs.
Exactly one tab is active on a stage or History page; none is active on the
landing page.

## 3.3 Workspace (stage pages)

`.workspace` is a wrapping flex row with a `--s5` gap. It holds:
1. `.panel` (the input);
2. `.panel.controls` (the buttons, bottom-aligned, under a `Controls` label);
3. `.output` (the result).

Stage 1 puts its two buttons inside the input panel instead (`.button-row`).
On phones every panel takes the full width.

## 3.4 Feedback

The output panel is the only feedback surface. It shows everything the page
script writes:
- progress (`Recognizing…`, `Learning…`);
- results;
- errors (`Error: …`).

The panel's border and label turn accent whenever it has content. There
are no toasts or modals.

## 3.5 Footer

`partials/_partners.html` sits on every page as the last block of the
scroll window. It is a solid black panel with no border and no label.
