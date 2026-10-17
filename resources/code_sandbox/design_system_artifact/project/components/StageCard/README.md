# StageCard

A landing-page card that introduces one stage. It's black, with a 1px `ink` border (the frame's line at half weight) and square corners.

- **Contents:** an accent label ("Stage 0N"), a `heading`, a muted description with the grid size in `ink`, and a `.btn` link.
- **Row:** cards sit in `.stages-overview`, a grid of `minmax(260px, 1fr)`, so three fit the column.
- **Rule:** the white border is reserved for stage cards; other panels use `line`.
