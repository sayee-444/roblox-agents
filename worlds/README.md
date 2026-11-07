# Test worlds

Where the `world` agent and its engine get tried. These maps belong to no game, and exist as examples and evidence.

Each folder holds a World Plan and generation state in `src/world/`, and rules and history in `docs/world/`. Some also hold captures in `docs/captures/`. The terrain itself lives in the Studio place named in `rules.md`, and the Generator can rebuild it from the plan.

| World | What it tries |
|---|---|
| `test-map-x2` | The current test map: curved Rivers with widths, a near-closed loop, a ring with an island, a third branch and oxbow lakes |
| `exam-4` | A world composed by `new --landforms`, later extended with Rivers ending in a Lake |
| `exam-1`, `exam-2`, `exam-3` | Benchmark runs by a clean agent session |
| `place3`, `place4` | Early tests, and the `create-fork` benchmark |

Run the engine against one from the repository root:

```
node plugins/roblox-world/engine/tools/world.js run --place <name> --project worlds/test-map-x2
```

Older worlds may need a plan edit to pass today's validation, since they were written on earlier plugin versions.
