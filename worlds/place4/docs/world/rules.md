# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place4 |
| World Seed | 699832641 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place4 --project .` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run `generate <i> <j> ...` for the Chunks it touched instead. `node <engine>/tools/world.js help` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-06: New world on random World Seed 699832641: a mountain range (north, seed 48213), a mesa (south-east, seed 91537) and a River whose `eastBranch` forks off its third route point, each branch with its own valley (seeds 26804 and 73659). The template's cave was dropped because it was not requested.
