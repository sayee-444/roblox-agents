# roblox-agents

A public plugin marketplace of Claude Code agents and skills for Roblox, reused across one developer's games. They want tools that last, so this comes before any game. The current work is one agent, `world`, which creates a world, edits it and recovers its context through the engine it ships with, and every change should also cut its context and its time.

Talk to the developer in Spanish, in plain words, because they are a beginner in game production. That includes the `description` of each tool call, which they read on permission buttons. Write every repository artifact in English.

The agent writes and runs a Generator, and the map is always its output. It never shapes terrain by hand.

## Where to look

| Need | Read |
|---|---|
| What the agent can do, and the words for it | `docs/functions.md` |
| Where the work stands and what comes next | `docs/next-steps.md` |
| Measuring a change | `docs/benchmark.md` |
| How generation works, and why | `plugins/roblox-world/skills/world-generation/SKILL.md` |
| Naming anything in the world domain, or what an order such as "load a map" means | `GLOSSARY.md` |
| Changing a recorded decision | `docs/adr/`. Supersede an ADR with a new one and leave the old text |
| A source behind an engine fact or a tool | `docs/research/` |

## How it relates to games

The tool knows nothing about any one game, and a game uses it by installing the plugin.

| Lives in | Holds |
|---|---|
| This repository | The agent, its skills, its Generator engine, scripts, the method and verified engine facts |
| `worlds/` in this repository | Test Worlds and their captures, public since they belong to no game |
| Each game's repository | Its World Plan, `docs/world/rules.md`, its game logic and its decisions |
| `.local/`, ignored by Git | Private research, backups and World Snapshots |

A game receives terrain through its published place, and its servers never generate any.

Keep game designs and the maps of real games out of this repository, because it is public.

The developer judges the look in Studio or from captures, since passing measurements have not meant a natural result.

## Asking and reporting

- Edit files, including `.rbxl` places, commit and push a work branch without asking, and report what you did.
- An Implementation ends with the developer. Say it looks finished and show the changes: they decide, and you ask permission to open its pull request and merge it.
- Propose any engine or plugin change the request did not ask for, and wait for the answer.
- Ask first, naming the exact action, for a force push, a history rewrite, deleting a branch or repository, creating a repository or an issue, and any other action not named above.
- Look at what a file holds before overwriting it.
- Mark what was measured apart from what was only read, and record what was not verified.

## Working on an agent

- Run it from this checkout: `claude --plugin-dir plugins/roblox-world --agent roblox-world:world`.
- One agent writes to Studio at a time. Long Luau runs call `task.wait()` between batches.
- Prefer a skill. Add an agent only when the work needs its own tools, memory or context.

## Changing a Test World

- From a development session, send map orders to the `world` agent, so each one also tests it. Start it in the world's folder: `claude -p --session-id <uuid> --plugin-dir ../../plugins/roblox-world --agent roblox-world:world --setting-sources project --strict-mcp-config --permission-mode bypassPermissions`. Relay any question it stops on, and send the answer with `--resume <uuid>` in place of `--session-id`. A new focus starts a new session.
- Write to whichever place is open, whatever its name. Stop and ask only if several are open, or it holds terrain this session did not write.
- Commit each map change on its own, in the branch of its Implementation. The pull request says which map changed and why, so the map can be compared against what changed in the agent.
- End an Implementation that changes the look with `capture overview`, and commit that one image. It moves the developer's camera once, and an Implementation that changes nothing visible skips it.

## Changing this repository

- Use one branch per change, Conventional Commits and a pull request. Commits use the GitHub noreply address set in the clone.
- Merge with `node tools/check.js && gh pr merge <number> --squash`, alone in its call, so the merge depends on that exit code. Its `description` says what enters `main` and why you ask. A hook in `.claude/settings.json` shows that to the developer on a button, with the facts from GitHub, and sends any other form back. In a headless session it denies the merge.

## Skills to load

- `mattpocock-skills:writing-for-agents`: editing an agent, a skill or this file.
- `mattpocock-skills:domain-modeling`: editing the glossary or an ADR.
- `mattpocock-skills:tdd`, `mattpocock-skills:diagnosing-bugs`, `mattpocock-skills:research`: building, debugging or researching.

## Reserved for the developer

These need the developer's explicit order every time: publishing to Roblox by any route, overwriting a Locked Chunk, changing the World Seed, and deleting all terrain in a place, which `world.js wipe` warns about first. Saving a place also falls to them, because no tool lets an agent save. A confirmed `wipe` is denied in a headless session, so run it from an interactive one.
