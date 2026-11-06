# roblox-agents

A public plugin marketplace of Claude Code agents and skills for Roblox, reused across one developer's games. They want tools that last, so this comes before any game. The current work is one agent, `world`, which creates a world, edits it and recovers its context through the engine it ships with, and every change should also cut its context and its time.

Talk to the developer in Spanish, in plain words, because they are a beginner in game production. Write every repository artifact in English.

The agent writes and runs a Generator, and the map is always its output. It never shapes terrain by hand.

## Where to look

| Need | Read |
|---|---|
| What the agent can do, and the words for it | `docs/functions.md` |
| Where the work stands and what comes next | `docs/next-steps.md` |
| Measuring a change | `docs/benchmark.md` |
| How generation works, and why | The `world-generation` skill |
| Naming anything in the world domain | `GLOSSARY.md` |
| Changing a recorded decision | `docs/adr/`. Supersede an ADR with a new one and leave the old text |
| A source behind an engine fact or a tool | `docs/research/` |

## How it relates to games

The tool knows nothing about any one game, and a game uses it by installing the plugin.

| Lives in | Holds |
|---|---|
| This repository | The agent, its skills, its Generator engine, scripts, the method and verified engine facts |
| `../roblox-world-generator`, local Git with no remote | Test worlds and their captures |
| Each game's repository | Its World Plan, `docs/world/rules.md`, its game logic and its decisions |
| `.local/`, ignored by Git | Private research and backups |

A game receives terrain through its published place, and its servers never generate any.

Keep game designs and map details out of this repository, because it is public. The engine's test map is the one exception.

The developer judges the look in Studio or from captures, since passing measurements have not meant a natural result.

## Asking and reporting

- Edit files, including `.rbxl` places, without asking, and report what you did.
- Create branches, commit, push branches, open pull requests and merge them once the checks below pass, and report what you did. In `../roblox-world-generator`, commit locally only.
- Ask first, naming the exact action, for a force push, a history rewrite, deleting a branch or repository, creating a repository, and any other action that is not an edit.
- Look at what a file holds before overwriting it.
- Mark what was measured apart from what was only read, and record what was not verified.

## Working on an agent

- Run it from this checkout: `claude --plugin-dir plugins/roblox-world --agent roblox-world:world`.
- One agent writes to Studio at a time. Long Luau runs call `task.wait()` between batches.
- Prefer a skill. Add an agent only when the work needs its own tools, memory or context.

## Changing this repository

- Use one branch per change, Conventional Commits and a pull request. Commits use the GitHub noreply address set in the clone.
- Merge only when `node tools/check.js` exits 0, and make the merge depend on that exit code.

## Skills to load

- `mattpocock-skills:writing-for-agents`: editing an agent, a skill or this file.
- `mattpocock-skills:domain-modeling`: editing the glossary or an ADR.
- `mattpocock-skills:tdd`, `mattpocock-skills:diagnosing-bugs`, `mattpocock-skills:research`: building, debugging or researching.

## Reserved for the developer

These need the developer's explicit order every time: publishing to Roblox by any route, overwriting a Locked Chunk, changing the World Seed, and deleting all terrain in a place, which `world.js wipe` warns about first. Saving a place also falls to them, because no tool lets an agent save.

Before writing to Studio, confirm with the developer which place is open.
