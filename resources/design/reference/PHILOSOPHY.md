# Signal on Black — design philosophy

Distilled from `Math_is_everywhere_artificial_neural_networks.psd` (see
`design_reference.json`) and merged with the app's 1.0 UI. It guides the
B-10 redesign and the design system that grows from it.

**Darkness is the medium, not the absence of one.** The field is pure black,
and everything on it is a measured amount of light: hairlines at 19% white,
borders at 30%, secondary text at 56%, body at 78%, headings at full
white. Depth comes from those grey steps alone, never from shadows,
gradients or blur. Each value is placed with the patience of a plate
engraver; nothing is "roughly grey".

**One signal.** A single hue, sky blue `#38bdf8`, is reserved for what is
alive right now: the active tab, the primary action, a fresh result, a
section's name. If two things are blue, one of them is wrong. The data
visualisation on the History page is the only place where categorical
colour may speak, because there the colours *are* the data.

**Monospace as instrument.** One typeface, JetBrains Mono, in regular and
medium weights on a 1.25 ratio: type that reads like a lab notebook rather
than an advertisement. Headings are regular, not bold, as on the poster.
Hierarchy comes from size and light, and the underline is the poster's
gesture for "this leads somewhere".

**The frame and the network.** A thin white frame holds the whole viewport
like the poster's border holds its canvas: content lives inside a
deliberate edge. Beneath it lies the network of nodes and lines, the
subject itself, quietly dim and anchored to the bottom of the screen so the
work area above stays calm. Every alignment, gap and inset comes from one
spacing scale (4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96), painstakingly
consistent, so the result feels built rather than assembled.
