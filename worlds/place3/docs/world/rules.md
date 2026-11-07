# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place3 |
| World Seed | 987654 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place3 --project .` loads the engine, tests it, describes the plan, generates, verifies and writes captures to `docs/captures/run/`. Run it with a Bash timeout of 600000 ms. Its header lists the single steps.

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-06: new layout on seed 987654: range runs north to south on the west side, mesa in the north-east, river and valley in the south-east, cave in the mesa's west flank (mouth ground about y 51, axis y 65). Chosen so this map differs from the engine's test map.
