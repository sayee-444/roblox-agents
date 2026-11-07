# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place3 |
| World Seed | 958090369 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place3 --project .` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. Its header lists the single steps, among them `capture`, which writes to `docs/captures/run/`.

## Target map

Values marked (default) were chosen by the agent and the developer can change them.

| Element | Target |
|---|---|
| Maximum extent | 3 x 3 Chunks, 1,536 x 1,536 studs (default) |
| Chunk | 512 x 512 studs |
| Landform Regions | `range` (mountain, north, west to east), `mesa` (south-east), `valley` (along the River) |
| Rivers and Lakes | River `river` (west to south); no Lakes |
| Sites | none |
| World Limit | none yet |

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-06: restored the River `river` and its `valley` Region at the developer's request; see `history.md`.
- 2026-11-06: removed the River and its `valley` Region at the developer's request; see `history.md`.
- 2026-11-06: started from the engine's template plan with its cave removed, because the developer asked only for a mountain range, a mesa and a river. The extent and every Landform number are defaults.
