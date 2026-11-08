# World systems

The design for what sits on top of terrain. None of it is built or measured, and nothing loads it into the agent. Build a system only when the developer asks, starting with a visual test on the target devices, then move what became real into a skill and its terms into `GLOSSARY.md`.

Terrain generation runs in Studio. Whatever must run while people play, such as Themes, weather, Gates, Graphics Profiles and the World Limit check, is a separate module in the game. The game's server decides a player's progress, and a Gate only reads it.

## Terms

| Term | Meaning | Avoid |
|---|---|---|
| World Limit | The impassable edge shared by every player, whose shape is declared in the World Plan: an invisible barrier and a server check | wall, border |
| Gate | A per-player barrier, decided by the server, that opens with that player's progress | lock, World Limit |
| Biome | A ground treatment, its Decoration parameters and its default Theme | using it for a shape (Landform) or for ambience alone (Theme) |
| Decoration | A static object placed from Biome parameters, such as a tree, rock or bush. It never simulates physics, and its density can be zero | prop, scatter |
| Structure | A building placed on purpose, such as a castle | landmark, prefab |
| Site | The place reserved in the World Plan for a Structure, with size and slope limits, whose ground the Generator prepares and preserves | pad, plot |
| Season | A temporary change to how Biomes look and what falls from the sky, which never changes the shape of the terrain | event skin, holiday mode |
| Theme | What a player perceives as ambience: sky and light colour, atmosphere, music and sound. It never changes the ground, and only one is active at a time, outside a transition | mood, ambience, environment |
| Standard Theme | The placeholder Theme used until a place in the world has a real one | normal biome, and "default theme" for this fallback, since that phrase means a Biome's own Theme |
| Zone | A named area placed on purpose that activates a Theme when a player enters it, such as a graveyard. It never changes the ground or Decoration | region, area |
| Graphics Profile | A named quality level, from Low to Ultra, that changes what a device draws but never anything a player can collide with | quality preset, graphics mode |

## Ground and objects

- Declare Biomes as data, so that adding one touches no Generator logic. One Biome can cover meadow and forest through tree density.
- A snow Biome can write ice instead of water.
- Pending, asked by the developer on 2026-11-08: a Biome sets by default how rough and peaked the beds of its water are, through a River's or Lake's `bedRough`, `banks.rough` and `banks.vary`, so a mountain Biome's beds have more peaks and a plain's fewer. The World Plan can still set them.
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

## Caves

Designed, with the delivery order, in [#30](https://github.com/sayee-444/roblox-agents/issues/30). See ADR 0007.

| Term | Meaning |
|---|---|
| **Cave** | An underground passage declared in the World Plan |
| **Branch** | A route that leaves another route of the same Cave |
| **Mouth** | A place where a Cave opens to the outside |
| **Breach** | A place where the ground no longer covers a Cave |
| **Dormant Section** | A stretch of a Cave's route with no cover, kept in the plan and not carved, which returns if the ground returns |
| **Sealed Cave** | A Cave with no Mouth, which is valid |
| **World Floor** | The height above which the ground decides whether a Cave exists |
| **Deep Rock** | Rock created only where something goes below the floor of the World Plan: under deep water, or around a Cave |
| **Cavern** | A chamber in the shape of half a spheroid |
| **Sinkhole** | A dry opening in the roof of a Cave or Cavern, which does not remove it |
| **Cenote** | A Sinkhole filled with water up to a chosen part of its depth, which acts as a natural body of water |
| **Aquatic Cave** | A flooded Cave that leaves a River, Lake or Cenote underwater, and takes its water level |
| **Water Vault** | The Cavern that joins an Aquatic Cave to a dry route, with air above the water |

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
