---
name: benchmark
description: Measures the world agent and compares it with the previous run.
disable-model-invocation: true
argument-hint: "cost | engine | agent <start|recover|create|edit|all> [--label name] | report"
---

Follow `docs/benchmark.md`.

1. With no arguments, run `node tools/benchmark.js cost`, then `node tools/benchmark.js report`.
2. Before `engine`, `agent create`, `agent edit` or `agent all`, ask the developer which disposable place is open, because they overwrite its terrain. Pass it as `--place <name>`.
3. Run the command with a Bash timeout of 600000 ms.

Done when you have told the developer, in plain words, what got better, what got worse and what failed, and you have said how many runs each comparison rests on.
