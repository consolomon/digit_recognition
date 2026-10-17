# TileGrid

The drawing grid of stages 1 and 2. It's made of 60px square tiles that toggle on click.

- **Tile states:** off is `field` with a `line` border; hover is `g1`; on is `ink`.
- **Outer border:** `line-strong`.
- **Sizes:** stage 1 is 3×3. Stage 2 is 3×5: `stage2.js` sets the template.
- **Built by script:** tiles are created by the page script (`div.tile`, class `on`). The consumer provides only `#grid`.
