# Test Worlds

Where the `world` agent and its engine get tried. These maps belong to no game, and exist as examples and evidence.

Each folder holds a World Plan and generation state in `src/world/`, and rules and history in `docs/world/`. Some also hold captures in `docs/captures/`. Terrain is not stored here: the Generator can rebuild it from the plan, and World Snapshots stay out of Git, in `.local/snapshots/`.

| World | What it tries |
|---|---|
| `lab` | The Test World under current work, meant whenever no name is given: curved Rivers with widths, a near-closed loop, a ring with an island, a third branch and oxbow lakes. Called `test-map-x2` until 2026-11-07 |
| `exam-4` | A world composed by `new --landforms`, later extended with Rivers ending in a Lake |
| `exam-1`, `exam-2`, `exam-3` | Benchmark runs by a clean agent session |
| `place3`, `place4` | Early tests, and the `create-fork` benchmark |

Run the engine against one from the repository root, in whichever place is open:

```
node plugins/roblox-world/engine/tools/world.js run --place <open place> --project worlds/lab
```

Older worlds may need a plan edit to pass today's validation, since they were written on earlier plugin versions.

## Comparing Implementations

Each map change is its own commit, in the branch of the Implementation it shows, and its entry in `docs/world/history.md` names that Implementation. So `git log -- worlds/lab` lists what changed on the map beside what changed in the agent, and a World Snapshot named in an entry opens that state without generating.
