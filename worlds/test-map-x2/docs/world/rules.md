# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | Place1 |
| World Seed | 12345 |

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place Place1 --project .` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run `generate <i> <j> ...` for the Chunks it touched instead. `node <engine>/tools/world.js help` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-07: 12 x 12 Chunks, extent -5..6, with every Landform's position doubled and the River, its branches and the Lake about 2 to 2.5 times wider, because the River read as a deep stream. Depths now differ a lot along each River, all water has `banks`, and Valleys reach up to 700 studs so the land comes down gently. The cave moved with the rest, keeps its axis at y 60 and sits about 2 to 8 studs above the ground there.
- 2026-11-07: `floorY` 0, with depths declared per point on each River and the Lake's bed at -20, to try varied water with no slab under the map.
- 2026-11-06: mesa moved from (1300, 1250) to (1300, -100), closer to the range; the cave stayed where it was (see history.md).
- 2026-11-06: started as a doubled-side copy of the engine's test map, same World Seed 12345: extent -2..3 (6 x 6 Chunks, 3,072 studs), chunkSize 512. Holds hills, a range (north), a mesa (south-east) with a cave at its western foot, a River with its valley, a fork with its valley, and a Lake (waterLevel 20) where both Rivers end. Cave axis at y 60 because ground there is 46.9 (one radius, 14, above it). Place1 is disposable, confirmed by the developer.
