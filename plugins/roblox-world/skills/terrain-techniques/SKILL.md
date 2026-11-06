---
name: terrain-techniques
description: Recipes for complex Roblox terrain, such as mountain ranges, mesas, valleys, rivers, caves, overhangs and material painting. Use when designing a Landform or choosing how the Generator represents and writes terrain.
---

These recipes come from the linked sources and our own reasoning. Each is **unmeasured in Studio** until `roblox-terrain-facts` says otherwise, so judge the result from a capture, and tune the numbers there.

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
| Mountain range | Ridged noise multiplied by a falloff from the distance to a polyline in the World Plan |
| Mesa | Quantize part of the height with `round(e * levels) / levels`, inside a plateau mask |
| Valley | Subtract a smooth profile of the distance to a polyline |
| River | Carve the bed from the distance to its route points, keeping the bed below a stretch's constant water level |
| Natural distortion | Offset the sample position with other noise before evaluating: [domain warping](https://iquilezles.org/articles/warp/) |
| Joining shapes | Blend with a bounded radius, so each Landform Region reaches only its margin: [smooth minimum](https://iquilezles.org/articles/smin/) |
| Cave or arch | In the density function, subtract tunnels around a 3D path or where 3D noise passes a threshold |

## Materials

Choose each voxel's material from height, slope and noise. Calculate slope from height differences at neighbouring world positions, never from Chunk data, so that it agrees across borders. Typical start: grass on gentle ground, rock on steep ground, snow above a height, sand beside water, with noise breaking up the lines between them.

## Writing to Studio

- Use `WriteVoxelChannels` or `WriteVoxels`, with arrays that exactly match a region aligned to the 4-stud grid.
- Set the surface voxel's occupancy from how far the height reaches into it: `clamp((height - voxelBottomY) / 4, 0, 1)`. This is what makes slopes smooth instead of stepped.
- Write water through the `LiquidOccupancy` channel.
- Limit each Chunk's vertical range to its lowest and highest values, because empty layers cost time and memory.
- Measure seconds per Chunk on a small sample before generating at scale, and record the number as a lesson.

## Judging the result

Capture from the ground and from above, with a sun angle that shows relief. Check for visible repetition, straight lines at Chunk borders, floating fragments and water leaking past the river bed.
