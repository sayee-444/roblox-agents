# roblox-agents

Specialized [Claude Code](https://code.claude.com/docs) agents and skills for Roblox development, distributed as a plugin marketplace.

| Plugin | Agent | What it does |
|---|---|---|
| `roblox-world` | `world` | Creates a world in Roblox Studio, edits it and recovers its context, through the engine it ships with |

The map is always the output of a program: the agent changes a declared World Plan and runs the engine, instead of shaping terrain by hand. Terrain is generated in Studio and saved in the place, so players get static terrain.

## Requirements

- Claude Code.
- [Roblox Studio MCP](https://create.roblox.com/docs/studio/mcp), with the server registered under the name `Roblox_Studio`, because the agent's tool list and the guard depend on that name. A server added with local scope exists only in its own project, so add it at user scope to reach every project. On Windows:

  ```text
  claude mcp add --scope user Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
  ```

- Windows, for the guard hook and the engine's command line. Neither has been tested elsewhere, and where `powershell.exe` is missing the guard blocks nothing.

## Install

```text
claude plugin marketplace add sayee-444/roblox-agents
claude plugin install roblox-world@roblox-agents
```

Then start it from your project folder:

```text
claude --agent roblox-world:world
```

On its first task in a project, the agent asks about your map and writes `docs/world/rules.md`. A new world needs only a World Plan, because the plugin includes the Generator engine. Installing from the marketplace has not been tested yet: every measured run loaded the plugin from a checkout.

## What it can do

[`docs/functions.md`](docs/functions.md) lists every function by job, what to ask for and whether it has been measured.

| Job | Ask for | Mainly runs |
|---|---|---|
| Create | A new world with these Landforms | `new`, then `run` |
| Edit | Add, change, remove or restore something | `generate <i> <j>` and `world-history` |
| Recover context | What exists, what changed and why | `describe` and `docs/world/history.md` |
| Check | Debug | `world-debug`, starting from `check` |
| Look | A capture of this view | `capture <view>`, only on request |

The agent needs your explicit order to publish to Roblox, overwrite a hand-edited Chunk, change the World Seed or delete all terrain. Saving the place is always yours, because no tool lets it save.

## Skills

Each skill is a set of instructions the agent reads only when its task needs them.

| Skill | Holds |
|---|---|
| `world-generation` | The method: World Plan, Chunks, `describe`, hand edits and design decisions |
| `world-history` | The log of past map changes, and how to restore what was removed |
| `world-debug` | Debug mode, loaded when a check fails or when you ask for it |
| `terrain-techniques` | Recipes for complex Landforms, materials and Studio writes |
| `world-systems` | The design for Biomes, Decoration, Structures, Themes, Zones, Seasons, weather and Graphics Profiles |
| `roblox-terrain-facts` | Engine limits, with sources |
| `world-project-setup` | How to create a project's world context |

## Where the agent keeps its context

| Place | Holds | Travels with |
|---|---|---|
| This plugin | The Generator engine, the method and verified engine facts | Every installation |
| `~/.claude/agent-memory/roblox-world-world/` | Lessons learned in any Roblox project | This computer. Copy the folder to move it |
| The project's Git repository | The World Plan, its rules, its decisions and its map history | The project |

## Guard

While the plugin is enabled, a hook applies to the whole Claude Code session, including sessions outside this agent. It blocks agent attempts to publish a place and to run `rojo build`, `rojo upload` or `rojo syncback`, and it asks before a confirmed wipe. It catches mistakes, and it is not a security boundary.

## Working on this repository

| Command | Does |
|---|---|
| `node tools/check.js` | Every check a merge depends on |
| `node tools/benchmark.js cost` | Free measure of the plugin's context, with more in [`docs/benchmark.md`](docs/benchmark.md) |
| `node tools/measure-run.js <transcript.jsonl>` | Time, tokens and what a run actually did |

Where the work stands is in [`docs/next-steps.md`](docs/next-steps.md), the vocabulary in [`GLOSSARY.md`](GLOSSARY.md) and the recorded decisions in [`docs/adr/`](docs/adr/).

## License

[MIT](LICENSE).
