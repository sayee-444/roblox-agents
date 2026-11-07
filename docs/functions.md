# Function map

Everything the `world` agent can do today, grouped by the job it serves, so that the developer and the agent use the same words. What does not exist yet is in `docs/next-steps.md`. `tests/docs.test.js` fails when a skill or an engine command is missing from this file.

## The pieces

| Piece | What it is | Who starts it |
|---|---|---|
| Agent | `world`: the worker, with its rules and its tools | The developer, with `claude --agent roblox-world:world` |
| Skill | Instructions the agent reads only when its task needs them | The agent, by the table in `agents/world.md`, or the developer by name |
| Command | One action of the engine, run with `node <engine>/tools/world.js <command>`. It needs no model, and it gives the same result each time | The agent, or anyone in a terminal |
| Hook | `guard.ps1`: a check that runs before a tool call and can block it, whatever the model decides | Claude Code, by itself |
| World Plan | The file declaring what exists where. Every change to the map starts here | The agent edits it |

## Status

- **Measured:** run in Studio or by a test, with a recorded result.
- **Built:** exists, and has not been measured as the agent uses it.

## Create

| Ask for | What runs | Status |
|---|---|---|
| A new world the engine composes | `new --landforms range,mesa,river,fork`, then `run` | Measured |
| A new world with chosen positions | `new`, writing the World Plan from the template it prints, then `run` | Measured |
| Set up a project with no world context | `world-project-setup` | Measured |
| The whole cycle again | `run`: `load`, `test`, `describe`, `generate`, `borders`, `regenerate`, `heights` | Measured |

## Edit

| Ask for | What runs | Status |
|---|---|---|
| Add, change or remove a Landform, River or Lake | `world-generation`, `world-history`, then `generate <i> <j>` | Built. In 2 of 2 runs the agent rewrote everything with `run` instead |
| Restore something removed | `world-history` | Measured |
| Write a single Chunk | `generate <i> <j>` | Measured |
| Prove a Chunk regenerates identically | `regenerate <i> <j>` | Measured |
| A new shape the engine lacks | `world-generation` and `terrain-techniques`, then a change to the engine | Built |
| Protect a Chunk edited by hand | Say which Chunks you touched, and the agent marks them Locked | Built |

## Recover context

| Ask for | What answers | Status |
|---|---|---|
| What exists now | `describe`, the World Plan and the generation state | Measured |
| What changed, and why | `docs/world/history.md`, through `world-history` | Measured |
| How high the ground is at one spot | `height <x> <z>` | Measured |
| How high each Landform and River is | `heights` | Measured |
| The project's rules and decisions | `docs/world/rules.md` | Measured |
| Lessons from other projects | The agent's memory | Built |

## Check and debug

Debugging runs last, and only when a check fails or the developer reports a wrong view or asks for it. Any other odd view goes in the final report.

| Ask for | What runs | Status |
|---|---|---|
| Debug | `world-debug`, starting from `check`, and stopping after one `refresh` | Built |
| Check without writing terrain | `check`: `load`, `test`, `describe`, `borders` | Built |
| Run the engine's tests | `test` | Measured |
| Make Studio hold the current code | `load` | Measured |
| Compare the Chunk borders | `borders <i> <j> ...` for the Chunks a change wrote, or `borders` for all | Measured |

## Look

These move the developer's camera, so they run only on request or when the developer is away.

| Ask for | What runs | Status |
|---|---|---|
| A picture of named views | `capture <view> ...`. After a write or a far view it rebuilds the render first, unless `--no-refresh`, since Play runs the place's scripts | Measured |
| A picture from a chosen position | `shot <name> <x y z> <x y z>`, with the same rebuild | Measured |
| Clear a rendering glitch | `refresh`: Play then Stop, and a wait of 5 s | Measured |

## Dangerous

| Ask for | What protects it | Status |
|---|---|---|
| Delete all terrain | `wipe` warns and stops, a new message from the developer confirms it, and the guard asks for approval | Measured, except the approval window |
| Publish to Roblox | The guard blocks it, because it belongs to the developer | Measured by `tests/guard-tests.ps1` |
| Rewrite a place with Rojo | The guard blocks it | Measured by `tests/guard-tests.ps1` |

## Knowledge to consult

| Skill | Holds | Status |
|---|---|---|
| `world-generation` | The method: how the map works and how to change it | Measured |
| `terrain-techniques` | Recipes for Landforms and materials, and how to judge a result | Built |
| `roblox-terrain-facts` | Engine limits, with sources | Built |

## Measure and prove

These live in this repository, and an installed plugin does not carry them.

| Ask for | What runs | Status |
|---|---|---|
| Benchmark | `/benchmark`, or `tools/benchmark.js`: see `docs/benchmark.md` | Measured |
| Proof of what a run did | `tools/measure-run.js <transcript>`: time, tokens, skills loaded and engine commands | Measured |
| Every check a merge needs | `tools/check.js` | Measured |

Also from the engine, `help` lists every command.

## Proving a function ran

The transcript of a session is the record. A skill that loaded and an engine command that ran both appear in it, and `measure-run.js` lists them under `Skills loaded` and `Engine commands`. A scenario in `benchmarks/scenarios.json` can then require or forbid them, so a function that stops being used fails the benchmark.
