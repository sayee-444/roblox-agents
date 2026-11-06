---
name: world-systems
description: Design for what sits on top of terrain, namely Biomes, Decoration, Structures, Gates, Themes, Zones, Seasons, weather, day and night, and Graphics Profiles. Use when the developer asks for any of them.
---

These systems are designed and not yet built or measured. Build one only when the developer asks, and start with a visual test on the target devices.

Terrain generation runs in Studio. Themes, weather and Graphics Profiles run in the live game, so keep them in separate modules from the Generator.

## Terms

| Term | Meaning |
|---|---|
| Biome | A ground treatment, its Decoration parameters and its default Theme. It never defines a shape, which is a Landform |
| Decoration | A static object placed from Biome parameters, such as a tree, rock or bush. Its density can be zero |
| Structure | A building placed on purpose, on a Site the Generator prepares and preserves |
| Gate | A per-player barrier, decided by the server, that opens with that player's progress |
| Theme | Ambience: sky and light colour, atmosphere, music and sound. It never changes the ground |
| Standard Theme | The placeholder Theme used until a place in the world has a real one |
| Zone | A named area, such as a graveyard, that activates a Theme on entry. It never changes the ground or Decoration |
| Season | A temporary change to how Biomes look and what falls from the sky. It never changes the terrain's shape |
| Graphics Profile | A quality level, from Low to Ultra, that changes what a device draws and never anything a player can collide with |

## Ground and objects

- Declare Biomes as data, so that adding one touches no Generator logic. One Biome can cover meadow and forest through tree density.
- A snow Biome can write ice instead of water.
- Decoration comes from Biome parameters. A per-Chunk override can swap one model for another at the same positions, leaving hand-placed objects untouched.
- Decoration is static and collides, except bushes and the like, which can be walked through.
- Take models from an approved catalog, checked for hidden scripts. A catalog entry can keep the prompt used to generate the model, once the generator's commercial terms have been checked.

## Ambience

- Build Themes from reusable parts: colours, a music pool played at random, and sounds.
- One Theme is active at a time. The innermost Zone wins, then the outer Zone, the Biome's Theme and the Standard Theme.
- Transition gradually by position, across a band of about 200 studs.
- A Zone is a group of Chunks or a free shape.
- Seasons change materials, models and what falls from the sky. Freezing a lake rewrites the water of its Chunks.

## Weather and time

- Wind, clouds, day and night, and rain or snow form one module, loaded only by places that need them.
- Each server picks a weather seed at startup, and each client derives time and weather from `GetServerTimeNow`, which avoids constant replication. That inference is unproven.
- Precipitation is server-wide, and what falls depends on the Biome where the player is.
- If clouds do not shadow the ground, darken the ambience under overcast skies.

## Graphics Profiles

Share one set of profiles across every area, including menus. Low-end phones are the baseline, and the developer tests real phones.

## Engine facts

Read 2026-11-05. Recheck before relying on them.

| Fact | Source |
|---|---|
| Clouds move with `Workspace.GlobalWind`, and have only Color, Cover, Density and Enabled | [Clouds](https://create.roblox.com/docs/environment/clouds) |
| No Roblox source states that clouds shadow the ground | [Thread](https://devforum.roblox.com/t/869476/894.json) |
| Shadows turn off below quality level 4 | [Performance](https://create.roblox.com/docs/performance-optimization/improve) |
| `LightingStyle` cannot be changed by script, so a Graphics Profile cannot switch lighting technology | [Light sources](https://github.com/Roblox/creator-docs/blob/main/content/en-us/effects/light-sources.md) |
| No weather API was found. `weather-island` is the official MIT sample; its defaults reach about 50,000 particles by our count, unmeasured on phones | [weather-island](https://github.com/Roblox/resources/tree/main/experiences/weather-island) |
| Emitters are limited to 100 particles per second on mobile | [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) |
| Most typical players use Android, many with 2 to 4 GB of RAM | [Test on hardware](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/test-on-hardware.md) |
| Terrain and water colours apply to the whole place, so regional colour on one material needs Expanded Terrain | [Custom materials](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/custom-terrain-materials.md) |

Not yet proven: that client writes to `Lighting` stay local to that client. Test it with two clients first.
