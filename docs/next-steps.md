# Next steps

## Goal

An agent that generates worlds, Structures and complex, detailed terrain on request, with less context and less time on each run. Other specialized agents follow later, each with its own skills and tools. Scripts in any language are welcome when they save context.

## Baseline of the first test

One run on `sonnet` on 2026-11-06, from an empty folder to a verified map of 9 Chunks. `tools/measure-run.js` counts each tool call once, by id. An earlier count of 215 calls, 58 captures and 18 errors included repeated transcript lines.

| Measure | Value |
|---|---|
| Duration | 32.9 minutes |
| Tool busy, parallel calls merged | 9.6 minutes |
| Model and overhead | 23.3 minutes |
| Output tokens | 192,619 |
| Cache read tokens | 13.9 million, over 84 requests |
| Context | 15k at the start, 51k by minute 2.6, 268k at the end |
| Tool calls | 141, with 14 errors |
| Largest uses | 38 `execute_luau`, 35 `screen_capture`, 25 `Write` |
| Generation itself | 3.6 s |

The run had `blockReadsOutsideWorkingDirectories` on, and 8 of the 14 errors were permission refusals, 7 of them naming that block. It is now off, so later runs avoid those errors without any change to the agent.

## Findings

- Most of the run was the model, and much of that was writing the Generator between minutes 3 and 12.
- About 104,000 characters of Luau went through `execute_luau`, and the model generated each one.
- Tool arguments explain perhaps a third of the output tokens, as an estimate. The rest looks like reasoning, which the transcript does not show.
- Two captures sent beside a `task.wait(40)` timed out after about 340 s each, costing about 5 minutes. The cause is not proven.
- Context had tripled before any code was written, which fits the developer's sense that agents lose time collecting broad context.

From their definitions, untested in Studio: `search_game_tree` and `inspect_instance` work on instances and do not read voxels, and `screen_capture` has no async option for `wait_job_finished`. `multi_edit` may keep the Generator in the place as ModuleScripts. `character_navigation` can walk a cave in play mode.

## Planned changes

1. Reuse a declared Generator instead of rewriting it. The plugin holds only that instruction.
2. Compare a module's checksum in `shared.World` before pasting it, and paste only what differs.
3. Use a fixed capture set of one view from above and one from the ground per Landform, about 10 to 12. Repeat only those a fix affects, one at a time, never beside a wait.
4. Try a lower reasoning effort for the agent, and keep it only if captures do not get worse.
5. Give the agent narrow answers instead of broad reading: load skills by branch, and prefer scripts such as `describe` that return exact facts.

Then repeat the same map and verifications through `--plugin-dir`. That run starts from an existing Generator, so it measures reuse and not an empty folder. The aim is under 10 minutes and 15 captures.

## Natural look

Developer feedback on the first map: decent for a first test, but artificial and clumsy.

- **Ground:** relief with cracks and irregular elevations.
- **Mesa:** it looks artificial.
- **Caves:** a cave takes advantage of the existing terrain, so that the player ends up inside it. A tube drilled into one Landform is not what was meant.

The developer recalls an earlier, more natural generation. Show them the `before-*` captures in the Generator repository and ask whether it was one of those. Conversations from 2026-11-05 may hold its algorithm.

## Known gaps

The tests have never run under Lute. Place file size, streaming, play mode and phones are unmeasured. The cave has not been walked by a character.

## Later agents

Create an agent only when its work exists, because multi-agent systems use many more tokens. 3D modeling costs money per use, so look for cheaper techniques first. No other agent is planned in detail yet.
