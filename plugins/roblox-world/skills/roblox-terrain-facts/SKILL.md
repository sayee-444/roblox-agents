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
| Water does not flow, and no public current simulation was found | A River is still water in a bed, with flat or stepped stretches | [WaterForce](https://create.roblox.com/docs/reference/engine/enums/WaterForce) |

## Techniques

- Terrain from noise, calculated independently at each position: [Red Blob Games](https://www.redblobgames.com/maps/terrain-from-noise/).
- Blending shapes with a bounded radius: [smooth minimum](https://iquilezles.org/articles/smin/).
- Natural-looking distortion: [domain warping](https://iquilezles.org/articles/warp/).
- Terrain from primitives with limited influence: [Genevaux et al. 2013](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf).
- Test third-party Studio plugins only in a disposable place, since a [backdoored plugin](https://devforum.roblox.com/t/backdoor-found-in-a-circulating-roblox-studio-plugin/4486846) has been reported.
