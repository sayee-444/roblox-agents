---
name: roblox-terrain-facts
description: Verified Roblox terrain limits and generation techniques, with sources. Use before writing Studio terrain code or relying on an engine limit.
---

Read 2026-11-05 against the linked sources, and measured where stated. Recheck anything that matters, because the platform changes quickly.

## Measured

Studio Edit mode, 2026-11-06, on one test map of 9 Chunks. Generating and writing took 3.6 s in total. Place file size, streaming, play mode and phones remain unmeasured, so measure them before committing to a map size.

| Fact | Evidence |
|---|---|
| A 512 x 512 Chunk of 52 to 85 layers takes 0.35 to 0.42 s to generate and write, most of it calculating heights | 9 Chunks timed |
| Repeated blocks of 2 to 3 s with no yield make `execute_luau` fail with `Target is not reachable`, and the code keeps running after the error, so yield every 0.25 s of work, as `Writer.breather` does, and send a failed call again only once its work has ended | `run` on `lab`, 144 Chunks in one call, failed on plugin 0.33.0 and passed 3 of 3 with the yields, on 2026-11-07 |
| `WriteVoxelChannels(Region3, 4, channels)` takes arrays indexed `[x][y][z]`, and `ReadVoxelChannels` returns the same layout plus `Size` | 9,224,192 voxels read back with 0 mismatches |
| A region not aligned to 4 studs returns the wrong array shape, so align before reading | Seen in the same test |
| Occupancy reads back in 8-bit steps, a maximum error of 0.0039, so compare with that tolerance | Same read-back |
| Studio builds the render mesh after a write. A grey rectangle once took 30 to 60 s to vanish, while later captures recovered within about 2 s | One Chunk rewritten, and 9 views right after Play then Stop, all complete |
| Play then Stop rebuilds the render from nothing in about 3 s, and leaves the terrain, `shared` and the camera as they were | Terrain fingerprint identical before and after |
| Studio builds that mesh near its real camera, and `screen_capture` moves the camera only for an instant. A Chunk rewritten far from the camera can stay missing or coarse in captures after minutes of waiting | A dark rectangle of 68,075 solid voxels stayed for over 3 minutes, and it shrank where `Camera.CFrame` was left for 40 s |
| A new place's `Workspace.FallenPartsDestroyHeight` is -500, so a bed or cave floor deeper than 520 studs under water at 20 lies below it | Read through Studio in a new place, 2026-11-08 |
| `FillBlock` with Air over a 512 x 512 Chunk clears 3,200 studs of rock in 0.14 s, and the same height of empty space in under 0.0001 s, so clearing deep under a Chunk costs time only where ground is left there | Timed on `Place1`, 2026-11-08, three times each over empty space |

## Documented

| Fact | What to do about it | Source |
|---|---|---|
| Voxels are 4 x 4 x 4 studs, with no finer resolution | Align Chunks to the 4-stud grid | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| One read or write handles at most 4,194,304 voxels | A 512-stud Chunk fits up to 1,024 studs of height in one call | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| `Terrain` cannot be created, so there is only one | A Chunk is a rectangle of voxels, never an instance | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| Terrain writes are not allowed in Parallel Luau | Write on the main thread and call `task.wait()` between batches | [Multithreading](https://create.roblox.com/docs/scripting/multithreading) |
| `math.noise` has no seed parameter, and `Random` documents no algorithm | Write your own noise and random number generator, so that an engine update cannot break seams | [math](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/libraries/math.yaml), [Random](https://create.roblox.com/docs/reference/engine/datatypes/Random) |
| Places are supported up to 100 MB; beyond that, saving and publishing might fail. Standard terrain counts toward this | Measure the file size of a generated sample | [Place files](https://create.roblox.com/docs/projects/place-files) |
| Undo is not reliable for very large terrain writes | Have the developer save a copy before a large overwrite | [Release post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620) |
| Parts do not simulate or render properly at a great distance | Keep the world centred on the origin | [Workspace](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) |
| The engine removes falling BaseParts below `Workspace.FallenPartsDestroyHeight`, which includes a character's parts, and removes any Model left with no part. The value is clamped between -50,000 and 50,000, and only plugins, the command bar and the Properties window can set it, never a script in a running game. Read 2026-11-08. Code sent through Studio's MCP server sets it: -500 to -4,000 read back, and -60,000 came back as -50,000, measured 2026-11-08 | Declare `destroyHeight` in the World Plan, which `run` and `generate` set in the place, and keep every bed and cave floor above the plan's `depthLimit` | [Workspace](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) |
| `SetMaterialColor` has no region argument, and water colour is global | Colour changes apply to the whole place | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| Voxel writes need arrays that exactly match a grid-aligned region, with resolution 4. Occupancy runs from 0 to 1 and morphs a cell with its neighbours | Use `Region3:ExpandToGrid()` and check array sizes before writing | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| In `WriteVoxelChannels`, `Enum.Material.Water` is not supported. A voxel holding only water is `SolidMaterial = Air` with `LiquidOccupancy` above 0 | Write water through that channel | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| A height map gives each column one height | Caves and overhangs need voxel writes | [Terrain guide](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/terrain.md) |
| Water does not flow, and no public current simulation was found | A River is still water in a bed, with flat or stepped stretches | [WaterForce](https://create.roblox.com/docs/reference/engine/enums/WaterForce) |

## Techniques

- Terrain from noise, calculated independently at each position: [Red Blob Games](https://www.redblobgames.com/maps/terrain-from-noise/).
- Blending shapes with a bounded radius: [smooth minimum](https://iquilezles.org/articles/smin/).
- Natural-looking distortion: [domain warping](https://iquilezles.org/articles/warp/).
- Terrain from primitives with limited influence: [Genevaux et al. 2013](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf).
- Test third-party Studio plugins only in a disposable place, since a [backdoored plugin](https://devforum.roblox.com/t/backdoor-found-in-a-circulating-roblox-studio-plugin/4486846) has been reported.
- The earlier terrain limit was 16K x 16K studs. No source says what enforces it, so measure before planning near it.
