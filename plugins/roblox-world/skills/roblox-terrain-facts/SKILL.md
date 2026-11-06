---
name: roblox-terrain-facts
description: Verified Roblox terrain limits and generation techniques, with sources. Use before writing Studio terrain code or relying on an engine limit.
---

Read 2026-11-05 against the linked sources. Recheck anything that matters, because the platform changes quickly. Terrain write speed and place file size have not been measured here, so measure them on your project before committing to a map size.

| Fact | What to do about it | Source |
|---|---|---|
| Voxels are 4 x 4 x 4 studs, with no finer resolution | Align Chunks to the 4-stud grid | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| One read or write handles at most 4,194,304 voxels | A 512-stud Chunk fits up to 1,024 studs of height in one call | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| `Terrain` cannot be created, so there is only one | A Chunk is a rectangle of voxels, never an instance | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| Terrain writes are not allowed in Parallel Luau | Write on the main thread and call `task.wait()` between batches | [Multithreading](https://create.roblox.com/docs/scripting/multithreading) |
| `math.noise` has no seed parameter, and `Random` documents no algorithm | Write your own noise and random number generator, so that an engine update cannot break seams | [math](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/libraries/math.yaml), [Random](https://create.roblox.com/docs/reference/engine/datatypes/Random) |
| Places are supported up to 100 MB; beyond that, saving and publishing might fail. Standard terrain counts toward this | Measure the file size of a generated sample | [Place files](https://create.roblox.com/docs/projects/place-files) |
| Undo is not reliable for very large terrain writes | Have the developer save a copy before a large overwrite | [Release post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620) |
| On Expanded Terrain, features under 64 studs thick might disappear on clients with streaming on. Not established for standard terrain | As a precaution, keep ground at least 64 studs thick | [Release post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620) |
| Parts do not simulate or render properly at a great distance | Keep the world centred on the origin | [Workspace](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) |
| A client that owns its character can bypass physical obstacles | Back a World Limit barrier with a server check | [Network ownership](https://create.roblox.com/docs/scripting/security/network-ownership) |
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

## Expanded Terrain and external tools

- Expanded Terrain offers up to 62 editable materials, with its own 200 MB limit according to a [staff post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620/145). Before adopting it, recheck three risks: painting depends on the undocumented `SolidMaterialIndex` channel, client optimizations were temporarily off in published games, and [Rojo and Lune lose its voxels](https://github.com/rojo-rbx/rbx-dom/pull/672).
- The earlier terrain limit was 16K x 16K studs, and 64K is [still in the works](https://devforum.roblox.com/t/creator-roadmap-2025-rdc-update/3961527). No source says what enforces it, so measure before planning near it.
- Rust has no supported way to write voxels into a place file. A Studio plugin [can reach `127.0.0.1`](https://create.roblox.com/docs/cloud-services/http-service.md), which is the documented route if Rust is ever added.
- Meshes are limited to [20,000 triangles](https://create.roblox.com/docs/art/modeling/specifications), and swimming requires terrain water, so the ground stays voxel terrain.
- For automatic River routing, see [Priority-Flood](https://ar5iv.labs.arxiv.org/html/1511.04463).
- Check the licence of any 3D generator first. [Hunyuan 3D's](https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2.1/main/LICENSE) excludes the EU, the UK and South Korea, and it produces objects, not terrain.
