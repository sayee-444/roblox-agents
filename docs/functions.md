# Function map

Everything the `world` agent can do today, grouped by the job it serves, so that the developer and the agent use the same words. What does not exist yet, and what has not been verified, is at the end of this file. `tests/docs.test.js` fails when a skill or an engine command is missing from this file.

## The pieces

| Piece | What it is | Who starts it |
|---|---|---|
| Agent | `world`: the worker, with its rules and its tools | The developer, with `claude --agent roblox-world:world --model sonnet` |
| Skill | Instructions the agent reads only when its task needs them | The agent, by the table in `agents/world.md`, or the developer by name |
| Command | One action of the engine, run with `node <engine>/tools/world.js <command>`. It needs no model, and it gives the same result each time | The agent, or anyone in a terminal |
| Hook | `guard.ps1`: a check that runs before a tool call and can block it, whatever the model decides | Claude Code, by itself |
| World Plan | The file declaring what exists where. Every change to the map starts here | The agent edits it |

## Status

- **Measured:** run in Studio or by a test, with a recorded result.
- **Built:** exists, and has not been measured as the agent uses it.

## Create

| Ask for | What runs | Status |
|---|---|---|
| A new world the engine composes | `new --landforms range,mesa,river,fork`, then `run` | Measured |
| A new world with chosen positions | `new`, writing the World Plan from the template it prints, then `run` | Measured |
| Set up a project with no world context | `world-project-setup` | Measured |
| The whole cycle again | `run`: `sync`, `test`, `describe`, `generate`, `verify`, `heights`. `generate` sends 48 Chunks per call to Studio, since one call of 576 Ocean Chunks made it stop answering, and when Studio stops answering a batch it waits until the batch is written and sends again only what is missing: measured once on `lab-ocean`, on batch 11 of 12 | Measured, also on the 144 Chunks of `lab` in one call: 3 of 3 |
| The same world at another size | `scale <factor>`, then `run`. It multiplies the extent, positions, lengths and heights and keeps the seeds. Writes no terrain | Measured: `scale 2` gave the 160 lines of a double written by hand, apart from one field that double added, and `run` passed after `scale 2` and `scale 0.5` on the test map |
| An Ocean | `oceans` in the World Plan, each the Chunks it holds as rectangles, with its own `seed`, under one `seaLevel`, then `run`. Land is every other Chunk. Its depth grows with the distance to the Coast, the edge of the nearest Chunk of land: `slope` 0.25 studs per stud, then the natural log past `bend` 2,400, up to `depthCap` 1,200 or `false` for none. See ADR 0013. Past the cap's reach a Chunk is a flat bed of three plain blocks, and nearer it is written column by column. Validation refuses numbers out of range and two Oceans that share a border. `heights` names each Ocean's sea level, its deepest point and whether its cap cut it | The depth, the one level across touching Chunks, a channel 20 studs wide at 2.5 deep and the refusals by the tests alone. A Chunk beside the Coast wrote in 0.12 to 0.34 s in Studio. On `lab-ocean`, two Landmasses and a channel 1 Chunk wide in an Ocean of 484 Chunks: 575 Chunks written in 333 s, from 0.38 to 37.67 s each, its deepest point -1,126.7 by `heights`, Chunk 0,-8 identical by `verify`, and a plan that made Chunk 0,0 of land into water stopped with nothing written. Seen from the coast: the land ends in a straight cliff along the Chunk edge, until #71. A pure Ocean: 576 Chunks in 29 s on an empty place, saved under 0.1 MB. See `docs/benchmark.md` |
| Keep every bed above where Roblox removes a character | `depthLimit` in the World Plan, -3,500 when left out, and `destroyHeight`, the place's Destroy Height. Validation refuses any Ocean, Lake, River or Cave that may reach below the Depth Limit, naming it and by how much. `run` and `generate` set a declared Destroy Height in the place and say from what to what. With none declared, a world deeper than the place's value writes nothing. Each write clears its Chunk down to the Depth Limit, so no old bed stays hidden under a shallower one. See ADR 0012 | Measured on `Place1`: the engine set the Destroy Height from -500 to -4,000, stopped a world at -580 that declared none, and a Chunk written 400 deep then 40 deep kept no voxel under its new ground. The `world` agent declared both on `lab-ocean` and ran it: 576 Chunks in 29.4 s, against 29 s before the deeper clearing, and it reported the change from -500 to -4,000. Validation measured by the tests alone |
| Keep a new world off terrain it did not write | `run` and `generate` stop before any step when the world has written nothing and the place holds terrain. `--over-terrain` writes over it, on the developer's word. A world that has written Chunks is not checked, since the terrain may be its own | Measured: asked for a world with no word about the terrain, the agent stopped and asked in 3 of 3, in 7 s, with the place's cells unchanged. Told the terrain may go, `create` and `create-fork` passed 3 of 3 with no extra request |
| Keep written land from turning into water | `run` and `generate` compare the plan with what each written Chunk recorded when it was written, at 64 spots, and stop before writing when a Lake or Ocean would cover its land, naming those Chunks and every written Chunk whose terrain would change. `--over-land` writes the water, on the developer's word. Locked Chunks are named and left as they are, and a write that leaves out written Chunks whose terrain changes names them | By the tests alone, through the fake Studio and `Describe.waterChange`. A Chunk written before plugin 0.44.0 holds no record, so it is not compared until it is written again |

## Edit

| Ask for | What runs | Status |
|---|---|---|
| Remove a Landform, River, Lake or Ocean | `remove <id>`: takes it out of the plan, a River with its valley, writes only the generated Chunks it touched and records the exact block | Measured: `verify` identical on its 4 Chunks and 2 others, and `edit` passed 3 of 3 |
| Add or change a Landform, River or Lake | `world-generation`, `world-history`, then `generate <i> <j>` | Built. In 2 of 2 runs the agent rewrote everything with `run` instead |
| Restore something removed | `world-history` | Measured |
| Write a single Chunk | `generate <i> <j>` | Measured |
| Prove a Chunk rewrites identically | `verify <i> <j>` | Measured |
| A new shape the engine lacks | `world-generation` and `terrain-techniques`, then a change to the engine | Built |
| Protect a Chunk edited by hand | Say which Chunks you touched, and the agent marks them Locked | Built |

## Recover context

| Ask for | What answers | Status |
|---|---|---|
| Load a Test World | Open the World Snapshot its `docs/world/history.md` names, which generates nothing. `docs/world/rules.md` says what to do when there is none | Built |
| Where a world stands | `status`: what the plan holds, Chunks generated and Locked, the last change, the places open with their terrain and Destroy Height. Changes nothing, and answers from the files with Studio closed | Measured |
| Which Chunks each thing touches | `describe` | Measured |
| What changed, and why | `docs/world/history.md`, through `world-history` | Measured |
| How high the ground is at one spot | `height <x> <z>` | Measured |
| How high each Landform and River is, how deep each River and Lake got next to the depth asked, or a Lake's depth from its size, and the deepest bed against the Depth Limit | `heights` | Measured |
| The project's rules and decisions | `docs/world/rules.md` | Measured |

## Check and debug

Debugging runs last, and only when a check fails or the developer reports a wrong view or asks for it. Any other odd view goes in the final report.

| Ask for | What runs | Status |
|---|---|---|
| Debug | `world-debug`, starting from `check`, and stopping after one `refresh` | Built |
| Check without writing terrain | `check`: `sync`, `test`, `describe` | Built |
| Run the engine's tests | `test` | Measured |
| Make Studio hold the current code | `sync` | Measured |
| Compare the Chunk borders, only when the agent gives a reason and the developer agrees | `borders <i> <j> ...` for chosen Chunks, or `borders` for all | Measured |

## Look

These move the developer's camera, so they run only on request or when the developer is away.

| Ask for | What runs | Status |
|---|---|---|
| A picture of named views | `capture <view> ...`. After a write or a far view it rebuilds the render first, unless `--no-refresh`, since Play runs the place's scripts | Measured |
| A picture from a chosen position | `shot <name> <x y z> <x y z>`, with the same rebuild | Measured |
| Clear a rendering glitch | `refresh`: Play then Stop, and a wait of 5 s | Measured |

## Dangerous

| Ask for | What protects it | Status |
|---|---|---|
| Delete all terrain | `wipe` warns and stops, a new message from the developer confirms it, and the guard asks for approval | Measured, except the approval window |
| Publish to Roblox | The guard blocks it, because it belongs to the developer | Measured by `tests/guard-tests.ps1` |
| Rewrite a place with Rojo | The guard blocks it | Measured by `tests/guard-tests.ps1` |

## Knowledge to consult

| Skill | Holds | Status |
|---|---|---|
| `world-generation` | The method: how the map works and how to change it | Measured |
| `terrain-techniques` | Recipes for Landforms and materials, and how to judge a result | Built |
| `roblox-terrain-facts` | Engine limits, with sources | Built |

## Measure and prove

These live in this repository, and an installed plugin does not carry them.

| Ask for | What runs | Status |
|---|---|---|
| Benchmark | `/benchmark`, or `tools/benchmark.js`: see `docs/benchmark.md` | Measured |
| Proof of what a run did | `tools/measure-run.js <transcript>`: time, tokens, skills loaded and engine commands | Measured |
| Every check a merge needs | `tools/check.js` | Measured |

Also from the engine, `help` lists every command.

## Proving a function ran

The transcript of a session is the record. A skill that loaded and an engine command that ran both appear in it, and `measure-run.js` lists them under `Skills loaded` and `Engine commands`. A scenario in `benchmarks/scenarios.json` can then require or forbid them, so a function that stops being used fails the benchmark.

## Not built

- A shell of ground that follows the surface: mountains stay solid down to `floorY`. See ADR 0008.
- Cenotes: designed in #30. A River or Lake has its own depth today.
- Removing one Chunk: only wiping all terrain exists.
- A command for what a change other than a removal would rewrite: `remove` is the only command that reaches `Describe.impact`, so `describe` is read before any other change.
- Detecting hand edits: the developer says which Chunks they touched. Designed in #30.
- Routes that follow the relief: a River curves through points placed by hand and holds one water level.
- Sites and the World Limit: the World Plan has fields for them, and no code generates them.
- A Coast with a Region Seed, bays and peninsulas: the Coast follows the Chunks' edges, and the land beside it keeps its own height, so it stands as a cliff where it rises above the sea. Designed in #71. `scale` does not handle an Ocean: it scales `depthCap` off the voxel grid, which validation then refuses, and leaves `chunks`, `seaLevel` and `bend` as they were.
- Trenches: designed in #78.
- Composing a Lake: `new --landforms` does not place one, so a Lake is written into the World Plan.
- Biomes, Decoration, Structures, Gates, Themes, Zones, Seasons, weather and Graphics Profiles: designed only, in `docs/designs/world-systems.md`, which also holds their terms.

## Not verified

Nothing has gone into deep water in Play or walked a Shore. Nothing has walked or dug on ground with `floorY` at 0, or seen the underside of a map from below. Streaming, play mode and phones. What the render rebuild does to a place with scripts, since Play runs them. A character walking a cave. The tests under Lute. Any system other than Windows. The guard's approval window in an interactive session. Opening a World Snapshot from a command.

Valley Sides are measured by the tests alone. Where two valleys with different `sides` meet, as at a fork, the ground meets in a crease, which no one has looked at. A Point Bar's sand was measured on one half circle of a test, and a Lake's slope only on a round Lake among even hills. That a Lake's `vary` raises fewer hills on its bed was counted on `lab`, 33 against 10, and its stretches of steeper and gentler shore have not been looked at. A Lake's depth from its size, with its pools and shallows, is measured by the tests alone, on round Lakes among even hills. That an Ocean's plain blocks hold the voxels `borders` expects was checked only by the tests, through `Chunk.slab`, and not in Studio. No saved `lab-ocean` was opened again. In Play on `Place1`, the developer fell from the bed at -380 through an emptied Chunk and was removed after more than 5 s, timed by eye, against about 1 s to the old -500, calculated. No place was saved and opened again to see that it keeps one the engine set. The lowest a River or a Lake with `bedY` may reach is worked out with the most its pools and roughness can add, so a plan near the Depth Limit may be refused for a depth the slope never reaches.

The guard that keeps written land from turning into water has stopped no real write yet: it ran in Studio only on changes that flood nothing, and its stops are measured through the fake Studio. It reads each Chunk at 64 spots, about 64 studs apart, so a Lake that grows by less may pass unseen. Land beside an Ocean that lies below its sea level stays dry, and a wall of water may stand at the Coast there: not looked at. `remove` when Studio fails partway has run only against the fake Studio of the tests. `scale` followed by `run` has run on the test map, and not on `lab`. A session's `effort` was measured on `edit` and `create-fork`, and not on a plan the model composes or on debugging.

Measured on 2026-11-07: `lab` at 144 Chunks saves to a place file of 4.66 MB. On Haiku, a headless agent resumed with `--resume` keeps its context and answered in 2.5 s, and plugin hooks run under `--setting-sources project`, since a headless agent's `world.js wipe --confirm` was denied there.
