# Next steps

## Goal

One agent, `world`, that creates a world, edits it and recovers its context, through the engine it ships with, with less context and time on each run. `docs/functions.md` lists what it can do, and `docs/benchmark.md` how to measure it. Earlier plans and measurements, up to plugin 0.11.0, are in `docs/archive/next-steps-2026-11-06.md`.

## Order

Pending work lives in GitHub issues, each with its spec: `gh issue list`. The developer chooses what follows, and on 2026-11-06 left this order:

1. #43: water depth does not read as an edited bed, from `docs/bugs/water-depth.md`. Beds now change material with depth on plugin 0.27.0, and it waits for the developer to judge the look.
2. #32: Lakes that are not round.
3. #30: the cave system, one delivery at a time, each only on the developer's order. It closes #22.

Not yet placed in that order: #33, the detail layer, which the developer chose earlier the same day, and #34, measuring the agent on the current plugin and proving an install.

## Waiting on the developer

- **`memory: user`.** Measured on 2026-11-06 with `--label no-memory`, 3 runs against 3 on plugin 0.13.0. Without the field, the starting context falls from 15,588 to 11,366 tokens (27%), and `recover` sends 25% fewer tokens at about the same cost, because cached tokens are cheap. The agent's memory holds 3 lines, and removing the field ends its memory across sessions.
- **The place for #34.** `create`, `edit`, `engine` and `check` write terrain, so they need a disposable place.

## Speed of a new world

The developer wants fewer tokens so that generations run faster and more of them fit, with automatic tests, and not to pay less. Measured on 2026-11-06 with `agent create-fork` in Place4, 3 runs each, medians:

| Plugin | Seconds | Requests | Tokens sent | Passed |
|---|---|---|---|---|
| 0.13.0 | 70 | 9 | 187,043 | 1 of 3 |
| 0.14.0: `new` prints a template, `run` prints heights | 68 | 8 | 167,159 | 3 of 3 |
| 0.15.0: points shown as arrays, plan and `run` sent together | 38 | 3 | 54,620 | 2 of 3 |
| 0.18.0: `new --landforms` composes the plan from the seed, on a plainer prompt | 27 | 3 | 51,596 | 3 of 3 |

Plugin 0.14.0 gained little because its template let every run write points the engine rejects, so each ran the cycle 3 times. A 0.15.0 run still spends about 16 s in Studio, of which `test`, `borders` and `regenerate` take about 11 s, so these are the next place to look.

`edit` on 0.18.0, 3 runs: 47 s, 6 requests, 117,551 tokens, 3 of 3 passed. Plugin 0.13.0 passed 2 of 3 at about 124,000 tokens, and its time was not kept. The one-pass rule first made 2 of 3 `edit` runs skip `world-history`, which 0.18.0 fixed by loading it before the plan is edited. `recover` was run once, on 0.17.0, and passed.

## Open defects

- **Water depth:** the developer found the bed did not look edited, while voxels hold the depth. Beds now change material with depth, and the developer has not judged it. Evidence in `docs/bugs/water-depth.md` and #43.
- **Open cave:** a cave stays carved as an open trench after the ground over it moves, and nothing reports it. Evidence in `docs/bugs/open-cave.md` and #22, design in #30.
- **Empty listing of places:** Studio lists no place for about 3 s when a command starts right after another ends, in 14 of 14 such runs on 2026-11-06, and the cause is unknown. `world.js` waits it out, for up to about 20 s, so a command with Studio closed takes that long to fail.
- **River widths:** measured in tests, borders and cost on `test-map-x2`, and the developer approved its curves on 2026-11-07. New worlds start with `bendWiden` 0.5, which each River can change, and a plan that leaves it out gets 0.
- **Lake:** measured in voxels and tests on `exam-4`, and not yet judged by eye. A River's valley keeps its width up to the shore.
- **Worlds the agent places by hand look alike:** on plugin 0.15.0, 3 of 3 put the range in the north, the River running west to east and the mesa in the east. `new --landforms` avoids this, and a request with chosen positions or a cave still goes through the template.
- **Composed layouts:** seen as text and by tests only. Whether they look good is the developer's call, and the range favours the south over the north, 651 to 351 of 2,000 seeds.
- **Mesa:** the top is blotchy and still rounded.
- **Rendering:** water that looks cut in a capture is rendering, as the developer has settled, so it is not investigated. A dark rectangle hid part of the main River in the test world, while its voxels were correct, and has not been checked since `capture` began rebuilding the render. `hills-above` shows a dark crack.
- **Mouse:** in one place the mouse stopped working in the 3D view, with the keyboard fine. Cause unknown.
- **Guard off Windows:** where `powershell.exe` is missing, the hook fails to start and blocks nothing. Read in the docs and not tested. `onFailure: "block"` would close it.
- **Transcript format:** `tools/measure-run.js` reads a format documented as internal, so a Claude Code update can break it.
- **Cell count:** `CountCells` gave 5,248,872 while a voxel count found 5,338,011 solid cells, and this was not explained.
- **Capture camera:** `capture` leaves the camera where it is, so a rewritten Chunk far from it can look broken.
- **Setup and `new`:** `world-project-setup` writes `docs/world/rules.md`, and `new` refuses to run if that file exists. Read in the code, and not run.

## Not built

- A shell of ground that follows the surface: mountains stay solid down to `floorY`. See ADR 0008.
- Cenotes: designed in #30, not built. A River or Lake has its own depth today.

- Removing one Chunk: only wiping all terrain exists.
- A command for `Describe.impact`: it exists and is tested in the Generator, and no command reaches it, so `describe` is read before a change instead.
- Detecting hand edits: the developer says which Chunks they touched. Designed in #30.
- Routes that follow the relief: a River curves through points placed by hand and holds one water level.
- Sites and the World Limit: the World Plan has fields for them, and no code generates them.
- Composing a Lake: `new --landforms` does not place one, so a Lake is written into the World Plan.
- Biomes, Decoration, Structures, Gates, Themes, Zones, Seasons, weather and Graphics Profiles: designed only, in `docs/designs/world-systems.md`, which also holds their terms.

## Not verified

Nothing has walked or dug on ground with `floorY` at 0, or seen the underside of a map from below. Place file size, streaming, play mode and phones. What the render rebuild does to a place with scripts, since Play runs them. An agent run on plugins 0.20.0 to 0.22.0, which were measured piece by piece. A character walking a cave. The tests under Lute. Any system other than Windows. The guard's approval window in an interactive session. Whether plugin hooks run under `--setting-sources project`, which the benchmark uses.

## Ideas held for later

Each has a verdict in `docs/research/tooling-and-reasoning.md`, part E.

| Idea | Verdict | What would settle it |
|---|---|---|
| Seed hunting | Partly: seeds have no locality, so search is random, and the score is the hard part | Measure a score's spread over 1,000 seeds, and whether it agrees with the developer's picks among 20 finalists |
| Fractal Rivers | Partly: a fork rule on a declared map inverts the method, which derives terrain from the network | A three-order network that carves its own valleys, judged in Studio |
| Circular agents | Partly: files and a stop condition are sound, and a circle of many agents is weak today | Written look principles that one evaluator grades in agreement with the developer |
| Parameters for Biomes | Not researched | Build when the developer asks, from `docs/designs/world-systems.md` |

Create a new agent only when its work exists, and 3D modeling costs money per use, so look for cheaper techniques first.
