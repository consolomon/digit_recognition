# OutputPanel

Where a stage shows its answer: an `Output` label above `#result`, which the page script fills.

- **Empty:** a `line` border and the placeholder "awaiting input", drawn by CSS `:empty::before`.
- **Filled:** any text (progress, result or error) turns the border and label `accent`, via `:has(.result-box:not(:empty))`.
- **Accessibility:** `aria-live="polite"`.
- **Consumer:** writes text or HTML into `#result`; `.result-row` sets numbers in tabular `ink`.
