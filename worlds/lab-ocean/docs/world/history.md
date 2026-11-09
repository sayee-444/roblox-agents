# World history

## 2026-11-09: Trenches enlarged and deepened

- **Why:** the developer wanted both Trenches about twice as large and deeper. Doubling does not fit, so each took the most validation allows: `abyss` stays centred and widens until its half width nearly meets the edge of the extent (z 6400); `western` keeps its line, is lengthened at both ends and widened until its half width nearly meets the west edge (x -5888). Walls unchanged.
- **Plan:** `abyss` halfWidth 1024 to 1784, floors -3000 to -3500. `western` halfWidth 980 to 1080, route extended along its own line from 3 to 5 points (about 8,000 to 10,200 studs), floors each lowered by 100, new ends at the south floor -3500 and the north floor -2100.
- **Chunks written:** the 166 the two Trenches reach (abyss 45, western 121); Locked 1,0 untouched. `generate` 189.3 s. Deepest: abyss -3422.4 at x -446 z 4612 (floor -3500), western -3500.0 at x -4445 z 4734.
- **Implementation:** #78
- **Snapshot:** `lab-ocean-issue-78.rbxl`, 20,578,431 bytes, saved by the developer, against 13,673,192 for `lab-ocean-issue-70.rbxl` before any Trench and before the Ocean's deep bed lost its spots of sand.
- **Restore:** set `abyss` to `floors = { -3000, -3000 }, halfWidth = 1024` and `western` to `points = { { -4600, -4000 }, { -4800, 0 }, { -4500, 4000 } }, floors = { -2000, -2800, -3400 }, halfWidth = 980`, then write the Chunks of both Trenches again.

## 2026-11-09: Trenches adapted to the new Generator (ramp walls, default roughness)

- **Why:** the Generator changed: a Trench's walls leave the Ocean's bed as a ramp over its rim, roughness defaults to a fifth of the half width, and the deep bed has new materials. The plan no longer validated, so `abyss` lost `rough = 0` (its Region Seed now bends its outline) and both got a wider half width, keeping routes and floors.
- **Plan:** `abyss` halfWidth 1000 to 1024; `western` halfWidth 700 to 980.
- **Chunks written:** 575, every unlocked Chunk; Locked 1,0 left alone. `generate` 389 s. Deepest: abyss -2934.0 at x 128 z 4608 (floor -3000), western -3390.4 at x -4503 z 3957 (floor -3393.5).
- **Restore:** set `abyss` to `halfWidth = 1000, walls = 4, rough = 0` and `western` to `halfWidth = 700`, then write every unlocked Chunk again (valid only with the previous Generator).

## 2026-11-09: Added Trench `western` to the Ocean

- **Why:** the developer wanted a long Trench in the Ocean west of the large Landmass, running north to south through x -4600 z -4000, x -4800 z 0 and x -4500 z 4000, its floor at -2000, -2800 and -3400. Default roughness; validation asked for a half width of at least 625 with walls at their maximum of 5, so it has 700.
- **Chunks written:** 68, those `describe` lists for `western` (i -11..-7, j -9..9). Deepest point -3388.5 at x -4456 z 3997.

## 2026-11-09: Added Trench `abyss` to the Ocean

- **Why:** the developer wanted an abyss in the open Ocean south of the large Landmass: a Trench with a short route at x 0, z 4608, floor at -3000 and walls of 4.
- **Chunks written:** -1,7 0,7 1,7 -2,8 -1,8 0,8 1,8 2,8 -2,9 -1,9 0,9 1,9 2,9 -2,10 -1,10 0,10 1,10 2,10 -1,11 0,11 1,11

## 2026-11-09: Two Landmasses carved out of the Ocean, and its depthCap removed

- **Why:** the developer wanted land in `lab-ocean`: a large Landmass at Chunks i -6..1, j -4..4 and a smaller one at i 3..6, j -2..2, with a one-Chunk Ocean channel at i = 2, and the Ocean taking its default depth from the coast instead of the cap of 400.
- **Chunks written:** all 576 except Locked 1,0, which lies inside the large Landmass and was not overwritten.
- **Restore:** replace the `ocean` entry in `oceans` with the block below, and write every unlocked Chunk again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 400 },
```

## 2026-11-09: Chunk 1,0 emptied by hand and Locked

- **Why:** the developer wanted a hole beside the spawn to fall into the void and see the Destroy Height of -4,000 work. They fell from the bed at -380 and were removed after more than 5 s, timed by eye, and chose to keep the hole.
- **Implementation:** #77
- **Chunks written:** 1,0, filled with Air from -3,500 to 1,024 by a one-off command in Studio, not by the Generator. It is Locked, so `run` and `generate` leave it empty.
- **Snapshot:** none yet, until the developer saves the place.
- **Restore:** set `locked = false` for `1,0` in `src/world/state.luau`, then `generate 1 0`.

## 2026-11-09: Declared Depth Limit -3500 and Destroy Height -4000

- **Why:** issue #77 added both to the World Plan. The Ocean bed at -380 lies 3,120 above the Depth Limit, and the Destroy Height sits below it.
- **Implementation:** #77
- **Chunks written:** all 576 (-11,-11 to 12,12), over the one test Chunk at 0,0 from the development session. `generate` 29.4 s, `run` 36.8 s in total.
- **Destroy Height:** Place1 went from -500 to -4000.
- **Restore:** delete `depthLimit` and `destroyHeight` from the World Plan, and set Place1's `Workspace.FallenPartsDestroyHeight` back to -500 in Studio's Properties window. The terrain does not change.

## 2026-11-08: Ocean `ocean` depthCap 40 to 400, kept as the result of #69

- **Why:** the developer looked at the Ocean at 220 and then at 400, and kept 400. The open Ocean of a very wide world is to reach 800 to 1,200 through #70.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12), at 220 and then at 400.
- **Result:** bed at -380, `generate` 58.8 s over the Ocean at 220. A shallower depth would leave the old bed hidden under the new one until #77, since a write clears only down to -256.
- **Snapshot:** `lab-ocean-issue-69.rbxl`, 89,813 bytes, saved by the developer.
- **Restore:** set `depthCap = 40` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 40 },
```

## 2026-11-08: Ocean `ocean` depthCap 100 to 40

- **Why:** the third depth measured for issue #69, at which the developer wanted the cost of a pure Ocean known.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Result:** bed at -20, `generate` 50.4 s over the Ocean at 100.
- **Snapshot:** `lab-ocean-depth-40.rbxl`, 87,395 bytes, saved by the developer.
- **Restore:** set `depthCap = 100` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 100 },
```

## 2026-11-08: Ocean `ocean` depthCap 220 to 100

- **Why:** the second depth measured for issue #69.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Result:** bed at -80, `generate` 49.1 s over the Ocean at 220.
- **Snapshot:** `lab-ocean-depth-100.rbxl`, 87,770 bytes, saved by the developer.
- **Restore:** set `depthCap = 220` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 220 },
```

## 2026-11-08: Created as a pure Ocean at depth 220

- **Why:** issue #69 measures what a pure Ocean costs to generate and save before Oceans get a coast, on a Test World of its own, apart from `lab`.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12), in an empty place where 4 of them had been written first to time them.
- **Result:** bed at -200, `generate` 29.2 s, `verify 0 0` identical.
- **Snapshot:** `lab-ocean-depth-220.rbxl`, 86,553 bytes, saved by the developer.
- **Restore:** none before it. This entry starts the world.
