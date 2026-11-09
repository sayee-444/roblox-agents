# An Ocean takes its depth from the distance to its Coast, along its own numbers

An Ocean is declared as the Chunks it holds, and #68 chose to give it the shape of ADR 0011's curve applied to the distance to the nearest Coast. With the Lake's numbers, a quarter up to 425 studs and a cap of 220, 400 studs would come about 13 Chunks out and 1,000 only some 1.9 million studs out, beyond the 128,000 studs Terrain reaches, calculated and not measured. The developer wants a very wide Ocean to reach 800 to 1,200 and a medium one about 400. On 2026-11-08, for #70, they chose the same shape with the Ocean's own numbers: a quarter of a stud per stud up to 2,400 studs from the Coast, about 400 at 3 Chunks and 512 at 4, then the natural log, joined with no break, up to a cap of 1,200, met about 13 Chunks out. The World Plan changes each: `slope`, `bend` and `depthCap`, or removes the cap with `depthCap = false`. Per ADR 0010 it is still a ceiling, and per ADR 0012 validation refuses a cap that would take the bed below the Depth Limit.

Until the Coast gets a Region Seed in #71, it follows the edges of the Chunks no Ocean holds inside the extent. Past the extent lies no land, so an Ocean reaches on to the edge of the world. Past the distance where it meets its cap, an Ocean Chunk is a flat bed written as plain blocks.

## Considered Options

- The Lake's numbers. Rejected: the open Ocean would stay at 220.
- A flat bed at the cap everywhere, as #69 measured it. Rejected: a narrow channel between two Landmasses would be as deep as the open Ocean, and a Chunk beside land a wall as deep as its bed.

## Consequences

Every Ocean Chunk nearer the Coast than the cap's reach, about 13 Chunks with the defaults, changes when the Coast moves, so a change to an Ocean's Chunks rewrites far more than the Chunks it adds or takes away. Those Chunks are written column by column: one beside the Coast took 0.12 to 0.34 s in Studio, measured on 2026-11-09, against about 0.04 s for a flat one. The land beside the Coast keeps its own height until #71, so it stands as a cliff where it rises above the sea.
