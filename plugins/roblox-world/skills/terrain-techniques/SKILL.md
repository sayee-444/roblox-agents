---
name: terrain-techniques
description: Recipes for complex Roblox terrain, such as mountain ranges, mesas, valleys, rivers, caves, overhangs and material painting. Use when designing a Landform or choosing how the Generator represents and writes terrain.
---

These recipes come from the linked sources and one test map of 9 Chunks, generated in Studio on 2026-11-06. That test ran a height field with one cave, and its results were functional rather than convincing. Judge every result from a capture, and tune the numbers there.

Every recipe stays a pure function of world position, the World Plan and the seeds, which keeps Chunk borders in agreement.

## Choose the representation

| Representation | Function | Gives | Cost per Chunk |
|---|---|---|---|
| Height field | `height(x, z)` | Hills, mountains, mesas, valleys, river beds | 128 x 128 evaluations |
| Density | `density(x, y, z)`, solid above 0 | Caves, overhangs, arches | One evaluation per voxel in the vertical range |

Start with the height field. Add density only inside the Landform Regions that need it, as a change applied on top of the height field within a bounded vertical range.

## Shape recipes

Noise below is `n(x, z)`, in the range 0 to 1, from the Generator's own noise. Combine recipes in this order: base shape, Landform Regions, carving, then material.

| Landform | Recipe |
|---|---|
| Natural hills | Sum octaves that double frequency and halve amplitude, then normalize ([Red Blob Games](https://www.redblobgames.com/maps/terrain-from-noise/)) |
| Flat lowlands with steep peaks | Redistribute the result: `e ^ exponent`, with an exponent above 1 |
| Sharp ridges | `2 * (0.5 - abs(0.5 - n))`, scaling higher octaves by the lower octave, so detail gathers on the mountains |
| Mountain range | Ridged noise multiplied by a falloff from the distance to a polyline in the World Plan. Vary its height along the line and add foothills, because an even crest with a sharp foot reads as a wall |
| Mesa | Quantize part of the height with `round(e * levels) / levels`, inside a plateau mask. Keep risers at or below about 3.6 rise over run, since 5.6 made needles. Warp the outline and vary the steps: evenly stacked rings looked like a tiered cake |
| Valley | Subtract a smooth profile of the distance to a polyline. When its River has `banks`, the valley is its Valley Sides, falling from the edge to the water at `sides`, rise over run: 0.1 a plain, 0.3 medium, 0.8 a mountain valley, or one per point of the River |
| River | Carve the bed from the distance to its route, keeping the bed below a stretch's constant water level. Use `curve` and `meander`, with `widths` per point and `bendWiden` for the bends, because even width on straight legs looked like a canal. `loops` draws a bend close to a circle, and any other shape comes from placing `points` by hand |
| Deep water | Use `depths` per point, or a Lake's `bedY`, with `bedRough` to vary the bed and `depthVary` for pools and shallows, placed by the seed. Any depth works: ground goes below `floorY` by itself, only under that water, with `rockUnder` studs of rock. Make the depths differ a lot between points, since 8 to 30 read as nearly even. With `banks`, a depth is the most the water reaches: a River gets about half of `sides` times its half width, and a Lake about half its radius times the slope of the ground around it, from that ground down to the water across `shore`. So deep water needs steep sides, and `heights` reports the depth reached next to the depth asked |
| Banks | Give a River or Lake `banks`: `shore`, `rough`, `vary` and `smooth`, whose comments are in the template. The ground then keeps its slope across the waterline and curves into the deepest line, and each bend gets a Cut Bank outside and a sandy Point Bar inside. Where a River passes close to itself, each pass digs towards its own line and needles stand between them: `smooth` fills crests, about 40 to 48 on a River 50 or more wide. Without them the water falls straight from a sand ledge. Keep the Valley's `floorY` about 8 above the water: at 4, a long shore broke the waterline into puddles and saw teeth |
| Hills around water | Widen the Valley's `halfWidth`, or a Lake's `shore`, so the land comes down over hundreds of studs. With 100 studs of Valley beside the water, hills stood around it like a rim |
| Oxbow lake | A short River in a crescent, connected to nothing, with its own Valley and thin `widths` at both ends, beside the River that left it |
| Natural distortion | Offset the sample position with other noise before evaluating: [domain warping](https://iquilezles.org/articles/warp/) |
| Joining shapes | Blend with a bounded radius, so each Landform Region reaches only its margin: [smooth minimum](https://iquilezles.org/articles/smin/) |
| Cave or arch | Start the entrance where the relief already offers one, such as a cliff foot or a gully, so that the player ends up inside. In the density function, subtract tunnels around a 3D path or where 3D noise passes a threshold. Use a radius of at least 14 studs, since 11 read as a hexagon. Vary the radius along the path, because a constant one looks drilled |
| Cracks and gullies | Carve narrow lines where ridged noise peaks, deepening them on steep ground so that they read as erosion. Evenly smooth ground looks artificial |

## Materials

Choose each voxel's material from height, slope and noise. Calculate slope from height differences at neighbouring world positions, never from Chunk data, so that it agrees across borders. Typical start: grass on gentle ground, rock on steep ground, snow above a height, sand beside water, with noise breaking up the lines between them. Sand renders near-white, so keep it to narrow bands: a 90-stud bank read as a road, and Sand on a mesa looked like snow. A bed chooses by the depth of its water: Sand, then Ground, then Ground with Rock, since Cobblestone reads as paving and Roblox has no gravel.

## Writing to Studio

- Use `WriteVoxelChannels` or `WriteVoxels`, with arrays that exactly match a region aligned to the 4-stud grid.
- Set the surface voxel's occupancy from how far the height reaches into it: `clamp((height - voxelBottomY) / 4 / sqrt(1 + slope^2), 0, 1)`, with `slope` the rise over run. This makes slopes smooth, and the slope term keeps steep ground from stepping.
- Write water through the `LiquidOccupancy` channel.
- Limit each Chunk's vertical range to its lowest and highest values, because empty layers cost time and memory.
- Measure seconds per Chunk on a small sample before generating at scale, and record the number as a lesson.
- Put the spawn on the generated ground, because the default template's spawn ends up buried.

## Judging the result

Ask the developer first, since they watch Studio. When captures are needed, use the views the engine derives from the World Plan, so each run compares the same ones.

Use `world.js capture <view> ...`, which repeats the first view until its size stops changing and takes the others once. After a fix, repeat only the views that fix affects. For a hole, a seam or a dark patch, load `world-debug` before you change anything.

Check for visible repetition, straight lines at Chunk borders, floating fragments and water leaking past the river bed.

Then ask whether someone would name the Landform without being told, and whether it looks natural. Report the answer plainly, even when every measurement passes.
