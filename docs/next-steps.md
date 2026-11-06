# Next steps

## Goal

One agent, `world`, that creates a world, edits it and recovers its context, through the engine it ships with, with less context and time on each run. `docs/functions.md` lists what it can do, and `docs/benchmark.md` how to measure it. Earlier plans and measurements, up to plugin 0.11.0, are in `docs/archive/next-steps-2026-11-06.md`.

## Order

The developer chooses what follows. They chose the detail layer as the next feature on 2026-11-06.

1. **Baseline in Studio.** Run `benchmark agent create` and `edit`, and `benchmark engine`, in a disposable place, and run `world.js check`, which has not yet run in Studio.
2. **Detail layer.** Noise and materials over the base shape, set by World Plan parameters. See "Natural look" below.
3. **Install test.** Install from the marketplace once, and confirm that `${CLAUDE_PLUGIN_ROOT}` expands there. Every measured run used `--plugin-dir`.
4. **Final exam.** A new world for a new game in a clean session, with a real `docs/world/rules.md` question flow, which has not been tried since plugin 0.5.0.

## Waiting on the developer

- **`memory: user`.** Measured on 2026-11-06 with `--label no-memory`, 3 runs against 3 on plugin 0.13.0. Without the field, the starting context falls from 15,588 to 11,366 tokens (27%), and `recover` sends 25% fewer tokens at about the same cost, because cached tokens are cheap. The agent's memory holds 3 lines, and removing the field ends its memory across sessions.
- **The place for step 1.** `create`, `edit`, `engine` and `check` write terrain, so they need a disposable place.

## Natural look

Research says a detail layer is necessary and not enough alone (`docs/research/tooling-and-reasoning.md`, item 14). Detail added evenly can make it worse, because real slopes are smooth below hillslope length, so rough ridges and smooth valley floors should differ. Try these in order, and let the developer judge each in Studio:

1. Domain warping, ridges, and materials driven by slope and height.
2. A local erosion-like filter, which keeps terrain a pure function of position.
3. A whole-map bake, only if the first two fall short, since one Chunk would stop regenerating cheaply.

Cheap measures such as the slope spread and pits with no outflow can catch regressions against a map's own earlier version, and they never replace the developer's eye.

## Open defects

- **Mesa:** the top is blotchy and still rounded.
- **Rendering:** a dark rectangle hides part of the main River in the test world, while its voxels are correct. `hills-above` shows a dark crack.
- **Mouse:** in one place the mouse stopped working in the 3D view, with the keyboard fine. Cause unknown.
- **Guard off Windows:** where `powershell.exe` is missing, the hook fails to start and blocks nothing. Read in the docs and not tested. `onFailure: "block"` would close it.
- **Transcript format:** `tools/measure-run.js` reads a format documented as internal, so a Claude Code update can break it.
- **Cell count:** `CountCells` gave 5,248,872 while a voxel count found 5,338,011 solid cells, and this was not explained.
- **Capture camera:** `capture` leaves the camera where it is, so a rewritten Chunk far from it can look broken.
- **Setup and `new`:** `world-project-setup` writes `docs/world/rules.md`, and `new` refuses to run if that file exists. Read in the code, and not run.

## Not built

- Removing one Chunk: only wiping all terrain exists.
- A command for `Describe.impact`: it exists and is tested in the Generator, and no command reaches it, so `describe` is read before a change instead.
- Detecting hand edits: the developer says which Chunks they touched.
- Routes that follow the relief: a River is placed by hand and holds one water level.
- Lakes, Sites and the World Limit: the World Plan has fields for them, and no code generates them.
- Biomes, Decoration, Structures, Gates, Themes, Zones, Seasons, weather and Graphics Profiles: designed only, in `docs/designs/world-systems.md`, which also holds their terms.

## Not verified

Place file size, streaming, play mode and phones. A map larger than 9 Chunks. A character walking a cave. The tests under Lute. Any system other than Windows. The guard's approval window in an interactive session. Whether plugin hooks run under `--setting-sources project`, which the benchmark uses.

## Ideas held for later

Each has a verdict in `docs/research/tooling-and-reasoning.md`, part E.

| Idea | Verdict | What would settle it |
|---|---|---|
| Seed hunting | Partly: seeds have no locality, so search is random, and the score is the hard part | Measure a score's spread over 1,000 seeds, and whether it agrees with the developer's picks among 20 finalists |
| Fractal Rivers | Partly: a fork rule on a declared map inverts the method, which derives terrain from the network | A three-order network that carves its own valleys, judged in Studio |
| Circular agents | Partly: files and a stop condition are sound, and a circle of many agents is weak today | Written look principles that one evaluator grades in agreement with the developer |
| Parameters for Biomes | Not researched | Build when the developer asks, from `docs/designs/world-systems.md` |

Create a new agent only when its work exists, and 3D modeling costs money per use, so look for cheaper techniques first.
