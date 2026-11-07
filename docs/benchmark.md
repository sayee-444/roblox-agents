# Benchmark

`tools/benchmark.js` measures the plugin and keeps every result in `benchmarks/results.jsonl`, stamped with its commit and plugin version, so that a version or a technique can be compared with the one before it. In a session on this repository, `/benchmark` runs it.

## Three prices

| Command | Spends | Needs | Answers |
|---|---|---|---|
| `node tools/benchmark.js cost` | Nothing | Nothing | How much context does the plugin add? |
| `node tools/benchmark.js engine --place <name>` | No tokens | Studio | How long does each engine step take? |
| `node tools/benchmark.js agent <scenario> [--place <name>]` | Tokens | Studio, except `start` and `recover` | Does the agent do the job, and at what cost? |
| `node tools/benchmark.js report` | Nothing | Nothing | What changed against the version before? |

Fewer tokens serve speed here: a faster run leaves room for more generations and automatic tests, so a change that saves no money can still be worth making. `--runs <n>` runs a scenario n times with nobody watching.

Run `cost` on every change to the agent or a skill, and `agent start` to see the real context, for about 2 cents. Run the other scenarios when a change should alter what the agent does.

## Testing a change

1. Before the change, run `agent start --runs 3` and any scenario it affects, if the current version has no results yet.
2. Make the change. A plugin change bumps the version, which opens a new group of results.
3. Run the same commands. Each scenario prints the median of the new group against the latest version before it.

To try a technique before deciding on it, add `--label <name>`. Its runs form a group of their own, judged against the version they were tried on, and later versions are never compared with them. Undo the technique afterwards if you are not shipping it.

## What it measures

| Measure | Means | Exact? |
|---|---|---|
| `durationSec`, `requests` | How long the run took and how many requests it made, the first measures to judge, since the aim is faster runs | Yes |
| `contextStart`, `contextEnd` | Tokens in the first and last request | Yes |
| `tokensSent` | Tokens sent across all requests, the best single measure of a run's size | Yes |
| `output`, `thinking` | Tokens the model wrote, and how many of them were reasoning | Yes |
| `costUsd` | Claude Code's estimate. It swings with what is already cached: three equal runs cost 3 to 8 cents | Estimate |
| `context.*` | The first request, split into parts | Estimate, at 4 characters per token |

Measured on 2026-11-07: across 26 recorded agent runs, `durationSec` follows `output` most closely (R² 0.851), then `requests` (0.734), `tokensSent` (0.733), `thinking` (0.637) and `contextStart` (0.562). Over 49 requests of one Opus session, model time was 111 output tokens per second plus 1.11 s per request (R² 0.957), and context size explained none of it (R² 0.001). So a faster run comes mostly from the model writing and reasoning less. Whether a smaller context makes it write less was not measured.

The parts show where to cut:

| Part | Is | Who controls it |
|---|---|---|
| `agent` | The body of `agents/world.md` | This plugin |
| `memoryRules` | Claude Code's own rules for `memory: user` | This plugin, by keeping that field or not |
| `memoryFile` | The agent's `MEMORY.md` | The agent |
| `tools` | Every tool's definition. `startTools` in the results lists each one | This plugin, through `tools:` |
| `pluginSkills` | This plugin's skill descriptions | This plugin |
| `otherSkills` | Claude Code's built-in skills | Nobody here |
| `attachments` | Date, environment and similar | Nobody here |
| `unattributed` | The rest. Mostly the gap between 4 characters per token and the real count | Nobody here |

Each result also holds `growth`: what the run added afterwards, by skill, file read and tool result. Read it in `benchmarks/results.jsonl`, or for any session with `node tools/measure-run.js <transcript.jsonl>`.

Compare a part with itself across versions. Its absolute size is only an estimate.

## Scenarios

They live in `benchmarks/scenarios.json`. `start` measures the context alone, and the others are the three things the agent is for.

| Scenario | The agent must | Fails when |
|---|---|---|
| `start` | Answer without doing any work | It calls a tool |
| `recover` | Say what exists and what changed last, from the project's files | Its answer misses the facts, or it writes or generates |
| `create` | Build a new world from an empty folder | `new` or `run` did not run, or it captured |
| `create-fork` | Build a new world with a forked River, on a new seed and a layout of its own | Same as `create`, or the plan keeps the template's seed, range, mesa or Region Seeds. Whether the River forks is read by hand in the kept plan. Its prompt stopped asking for a placement unlike the template on plugin 0.17.0, so earlier runs had a harder prompt |
| `edit` | Remove a River and write only the Chunks it touched | `remove` did not run, `run` did, the history holds no entry, or the River stayed in the plan. Up to 0.33.0 it required `generate` and `world-history` in place of `remove` |

A failure names what was missing. Each scenario also sets a limit on tool calls, errors and captures. Scenarios grade what the agent produced, with one deliberate exception: `edit` requires `remove`, since writing few Chunks with no model writing the plan is the point of that job.

Add a scenario when a real run fails in a new way, up to about five for now.

## How a run is kept apart

Each agent run starts in a new temporary folder, on `sonnet`, with a budget limit of 2 dollars unless `--budget` says otherwise. The folder is deleted afterwards, unless `--keep <dir>` copies the world there first, for a map worth keeping. It loads only this checkout's plugin, with `--setting-sources project`, so other plugins installed on the computer add no cost. `--bare` is avoided, because it needs an API key and skips plugin hooks.

The agent's memory still loads, because `memory: user` is part of what it is. Each result records the memory's size and the Claude Code version, so a change in either can be told apart from a change in the plugin.

## Baselines

What the next run is compared against. `agent create-fork`, 3 runs each, medians, on 2026-11-06:

| Plugin | Seconds | Requests | Tokens sent | Passed |
|---|---|---|---|---|
| 0.13.0 | 70 | 9 | 187,043 | 1 of 3 |
| 0.14.0: `new` prints a template, `run` prints heights | 68 | 8 | 167,159 | 3 of 3 |
| 0.15.0: points shown as arrays, plan and `run` sent together | 38 | 3 | 54,620 | 2 of 3 |
| 0.18.0: `new --landforms` composes the plan from the seed, on a plainer prompt | 27 | 3 | 51,596 | 3 of 3 |
| 0.33.0: the baseline of #53 | 24 | 3 | 51,562 | 3 of 3 |

`edit`, 3 runs each:

| Plugin | Seconds | Requests | Tokens sent | Output | Passed |
|---|---|---|---|---|---|
| 0.18.0 | 47 | 6 | 117,551 | 2,074 | 3 of 3 |
| 0.33.0 | 36 | 8 | 171,089 | 2,392 | 0 of 3 |

On 0.33.0 one `edit` passed its limit of 12 tool calls, and two lost a call to `python`, which this computer does not have. Each run wrote the River's block twice by hand, once to take it out of the plan and once into the history.

The other scenarios on 0.33.0, 3 runs each, all passed: `start` 1 s and 16,087 tokens, `recover` 6 s and 51,096 tokens, `create` 21 s and 33,555 tokens. `engine` on the test map: 10.2 s, of which `test` 4.9 s and `generate` 4.3 s. `cost`: 462 tokens always on, 10,860 on invoke.

All of these ran on `sonnet`, whose default `effort` is `medium` and which reasoned for almost nothing: 74 tokens in the median `edit`. So they say little about a session on another model or a higher `effort`.

## Reading a result

- **Compare with three runs.** One run of an agent says little, so use `--runs 3` when comparing two versions.
- **The look is not measured.** A passing run says the agent did its job, and only the developer can say the terrain looks natural.
- **Use a disposable place.** `engine`, `create` and `edit` overwrite the terrain of `--place`.
- **Earlier numbers do not carry over.** The measurements up to plugin 0.11.0, now only in Git's history, used other prompts, included other plugins' context and counted less of the context.
- **A sudden failure after an update may be the tool.** `measure-run.js` reads a transcript format documented as internal, so refresh `tests/fixtures/run.jsonl` if Claude Code changes it.
