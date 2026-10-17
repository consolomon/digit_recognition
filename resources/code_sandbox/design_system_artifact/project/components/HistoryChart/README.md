# HistoryChart

The History page dashboard: a Recharts error-rate line chart, expandable milestone rows, a key-insight box and a sources line. It is built by `history.js` with inline styles that follow the tokens.

## Variants
| Part | Use |
|---|---|
| Chart panel | black, 1px `#303030` border, square; grid `rgba(255,255,255,.08)`; axes `#4c4c4c` |
| Line + dots | line `#38bdf8` 3px; dots r7 in the milestone colour, 2px white stroke; active dot r10 |
| Human-level line | dashed `#ef4444`, label inside the plot, top right |
| Tooltip | `#0d0d0d`, 2px border in the milestone colour, square |
| Milestone row | black with a `#303030` border; open: `#0d0d0d` with a border in the milestone colour |
| Badge | error % outlined in the milestone colour; "Origin" outlined in accent |
| Source link | in the milestone colour, faint border, opens a new tab |
| Key insight | black, 1px accent border |

## Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `#dashboard-root` | id | — | React mount: never rename |
| `milestones[].color` | hex | — | data-viz palette only (no pink) |

## States
| State | Visual | Behavior |
|---|---|---|
| Row closed | dot, year, label, badge | click opens |
| Row open | method, detail, source link | click closes; link click doesn't toggle |
| Chart hover | tooltip | — |

## Accessibility
- **Known gap:** the rows are clickable `div`s, so not keyboard-operable. Making them `<button>`s is a follow-up change to `history.js`.
- Links open with `rel="noopener noreferrer"`.

## Do's and Don'ts
| ✅ Do | ❌ Don't |
|---|---|
| Keep categorical colours inside the chart and rows | Use categorical colours in page chrome |

## Code Example
```js
e(ReferenceLine, { y: 0.2, stroke: "#ef4444", strokeDasharray: "6 4",
  label: { value: "≈ Human level (0.2%)", position: "insideTopRight", fill: "#ef4444" } })
```
