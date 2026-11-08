# World rules

## Development Place

Whichever place is open in Studio, whatever its name, since this Test World belongs to no game. `node <engine>/tools/world.js describe --place __none__` fails and prints the names of the open places. Stop and ask only if several are open, or if the one open holds terrain this session did not write.

| Field | Value |
|---|---|
| World Seed | 12345 |

## Load

To load this world, open the World Snapshot named by the newest entry in `history.md`. Snapshots are in `.local/snapshots/` at the repository root. If that entry names none, or its file is missing, generate it with `run`: a pure Ocean of plain blocks writes all 576 Chunks in about 30 s.

## History

Each entry in `history.md` also names its Implementation, and the World Snapshot if the developer saved one. When a finished Implementation changes the map, ask the developer to save it with `File > Save to File As`, giving the whole path of `.local/snapshots/lab-ocean-issue-<n>.rbxl`, because `Ctrl+S` would overwrite the copy already open in Studio.

## Generator

The engine ships with the `roblox-world` plugin. This project holds only `src/world/plan.luau` and `src/world/state.luau`.

`node <engine>/tools/world.js run --place <open place> --project .` syncs the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run `generate <i> <j> ...` for the Chunks it touched instead. `node <engine>/tools/world.js help` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.

- 2026-11-08: 24 x 24 Chunks, extent -11..12, centred on the origin as `lab` is laid out, all of it one Ocean at sea level 20, because Oceans, Seas and channels need a place of their own to be tried, apart from `lab`, and issue #69 first measures what a pure Ocean costs. It reaches 6,400 studs from the origin. `floorY` 0 and `rockUnder` 8 as on `lab`. Land comes in with #70.
