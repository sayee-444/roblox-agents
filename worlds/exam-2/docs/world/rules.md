# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place4 |
| World Seed | 431870259 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place4 --project .` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run `generate <i> <j> ...` for the Chunks it touched instead. `node <engine>/tools/world.js help` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-06: New world on World Seed 431870259, unused by the other worlds. Layout differs from them: a mountain range running north to south on the east side (seed 35182), a mesa in the north-west (seed 62907) and a River entering from the north whose `eastBranch` forks off its fourth route point (-40, 0), each branch with its own valley (seeds 80416 and 19273). The template's cave was dropped because it was not requested.
