# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place4 |
| World Seed | 831117573 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place4 --project .` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run `generate <i> <j> ...` for the Chunks it touched instead. `node <engine>/tools/world.js help` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-06: composed by new from seed 831117573: a range about north, height 194; a mesa at -400, 270, height 110; a River from 740, 102 to -740, -96; a fork from 7, -49 to -740, -301.
