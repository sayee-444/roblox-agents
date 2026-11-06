# roblox-world

An agent, `world`, that creates a Roblox world, edits it and recovers its context, through the Generator engine in `engine/`. The map is always the engine's output, driven by a World Plan.

Install, requirements and the list of skills are in the [repository README](https://github.com/sayee-444/roblox-agents#readme). Every function is listed in [`docs/functions.md`](https://github.com/sayee-444/roblox-agents/blob/main/docs/functions.md).

| Folder | Holds |
|---|---|
| `agents/` | The agent's rules, and which skill to load for which task |
| `skills/` | Instructions loaded only when a task needs them |
| `engine/` | The Generator and its command line. `node engine/tools/world.js help` lists every command |
| `hooks/` | The guard, which blocks publishing and asks before a confirmed wipe |
