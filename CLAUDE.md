# roblox-agents

A public plugin marketplace of Claude Code agents and skills for Roblox, reused across one developer's games. The current work is one agent, `world`, focused on world generation. A later agent may direct it, and that gets designed when the developer asks.

Talk to the developer in Spanish, in plain words, because they are a beginner in game production. Write every repository artifact in English.

## How a world is generated

The agent writes and runs a Generator, and the map is always its output. It never shapes terrain by hand.

- Terrain comes from one pure function of the World Plan, the seeds and the world position, so Chunks agree at their borders.
- The World Plan declares what exists where, and seeds supply only natural detail.
- Generation runs in Studio and is saved in the place. Players get static terrain.
- A `describe` report lets the agent plan from facts, and hand-edited Chunks become Locked Chunks.

The `world-generation` skill holds the full method and the reason behind each decision.

## How it relates to games

The tool knows nothing about any one game, and a game uses it by installing the plugin.

| Lives in | Holds |
|---|---|
| This repository | The agent, its skills, the method and verified engine facts |
| `../roblox-world-generator`, private | Reusable Generator code, and `docs/next-steps.md` with the current priorities |
| Each game's repository | Its World Plan, `docs/world/rules.md`, its game logic and its decisions |

A game receives terrain through its published place, and its servers never generate any. Whatever must run while people play, such as Themes, weather, Gates and the World Limit check, is a separate module in the game. The game's server decides a player's progress, and a Gate only reads it.

Keep game designs, map details and Generator code out of this repository, because it is public.

## Priorities

Follow `docs/next-steps.md` in the private repository: make the agent faster and cheaper, then make terrain look natural. The developer judges the look from captures, since passing measurements have not meant a natural result.

## Changing this repository

- Use one branch per change, Conventional Commits and a pull request. Commits use the GitHub noreply address set in the clone.
- Merge only when these all exit 0, and make the merge depend on those exit codes:
  - `claude plugin validate .`
  - `claude plugin validate plugins/roblox-world`
  - `powershell -File tests/guard-tests.ps1`
- Bump `version` in `plugin.json` on every plugin change, since installed copies stay on that version until it changes.
- In skill frontmatter, avoid colons in unquoted values, because they break the YAML and the skill loads without its metadata.
- Prefer a skill. Add an agent only when the work needs its own tools, memory or context.
- Mark what was measured apart from what was only read, and record what was not verified.

## Reserved for the developer

These need the developer's explicit order every time: publishing to Roblox by any route, overwriting a Locked Chunk, and changing the World Seed. Saving a place also falls to them, because no tool lets an agent save.

Before writing to Studio, confirm with the developer which place is open.
