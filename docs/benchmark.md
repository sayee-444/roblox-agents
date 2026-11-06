# Benchmark

`tools/benchmark.js` measures the plugin and keeps every result in `benchmarks/results.jsonl`, stamped with its commit and plugin version, so that each change can be compared with the run before it. In a session on this repository, `/benchmark` runs it.

## Three prices

| Command | Spends | Needs | Answers |
|---|---|---|---|
| `node tools/benchmark.js cost` | Nothing | Nothing | How much context does the plugin add? |
| `node tools/benchmark.js engine --place <name>` | No tokens | Studio | How long does each engine step take? |
| `node tools/benchmark.js agent <scenario> [--place <name>]` | Tokens | Studio, except `recover` | Does the agent do the job, and at what cost? |
| `node tools/benchmark.js report` | Nothing | Nothing | What changed since the run before? |

Run `cost` on every change to the agent or a skill. Run `agent` when a change should alter what the agent does.

## Scenarios

They live in `benchmarks/scenarios.json`, and they are the three things the agent is for.

| Scenario | The agent must | Fails when |
|---|---|---|
| `recover` | Say what exists and what changed last, from the project's files | Its answer misses the facts, or it writes or generates |
| `create` | Build a new world from an empty folder | `new` or `run` did not run, or it captured |
| `edit` | Remove a River and write only the Chunks it touched | `generate` did not run, `run` did, `world-history` did not load, or the River stayed in the plan |

A failure names what was missing. Each scenario also sets a limit on tool calls, errors and captures. Scenarios grade what the agent produced, with one deliberate exception: `edit` requires `generate`, since writing few Chunks is the point of that job.

Add a scenario when a real run fails in a new way, up to about five for now.

## How a run is kept apart

Each agent run starts in a new temporary folder, on `sonnet`, with a budget limit of 2 dollars unless `--budget` says otherwise. It loads only this checkout's plugin, with `--setting-sources project`, so other plugins installed on the computer add no cost. `--bare` is avoided, because it needs an API key and skips plugin hooks.

The agent's memory still loads, because `memory: user` is part of what it is. Each result records the memory's size and the Claude Code version, so a change in either can be told apart from a change in the plugin.

## Reading a result

- **Compare with three runs.** One run of an agent says little, so use `--runs 3` when comparing two versions. `report` compares only the last two results of a scenario, so read `benchmarks/results.jsonl` for the rest.
- **The look is not measured.** A passing run says the agent did its job, and only the developer can say the terrain looks natural.
- **Use a disposable place.** `engine`, `create` and `edit` overwrite the terrain of `--place`.
- **Earlier numbers do not carry over.** The measurements up to plugin 0.11.0, in `docs/archive/next-steps-2026-11-06.md`, used other prompts, included other plugins' context and counted less of the context.
- **A sudden failure after an update may be the tool.** `measure-run.js` reads a transcript format documented as internal, so refresh `tests/fixtures/run.jsonl` if Claude Code changes it.
