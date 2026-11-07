# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place4 |
| World Seed | 82165555 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place4 --project .` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run `generate <i> <j> ...` for the Chunks it touched instead. `node <engine>/tools/world.js help` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.
- 2026-11-06: Layout: mountain range along the north (z about -480 to -590, x -600 to 40); mesa at (480,-330); River west to east near z 100-200 with a fork branching at (0,120) to the south edge, each with its own valley. Region Seeds: range 41907, mesa 53318, valley 27664, forkValley 61452.
