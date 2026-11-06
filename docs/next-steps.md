# Next steps

## Goal

An agent that generates worlds, Structures and complex, detailed terrain on request, with less context and less time on each run. Other specialized agents follow later, each with its own skills and tools. Scripts in any language are welcome when they save context.

## Where the work stands

Plugin 0.8.1, on 2026-11-06. A new world is a World Plan run through `plugins/roblox-world/engine/tools/world.js`, which reaches Studio without the model. A Chunk can be generated on its own, and a River can fork.

The developer's test world is Place3, unsaved, with its plan and captures in `../roblox-world-generator/worlds/place3`. They like the generation so far, and these remain open:

- **Mesa:** the top is blotchy and still rounded. The developer set this aside until the token work is done.
- **Rendering:** a dark rectangle hides part of the main River in Place3, while its voxels are correct.
- **Mouse:** in Place2 the mouse stopped working in the 3D view, with the keyboard fine. Cause unknown, and Place3 has not been reported on.

## Next: where the tokens go

This is the next session's only focus. One turn added a River fork, and it measured 10.8 minutes to its last tool call:

| Part | Measure |
|---|---|
| Building the fork, fixing a dam and a pit, verifying | 4.9 minutes |
| Chasing the dark rectangle, which was not a map defect | 5.5 minutes |
| Recording and publishing | 0.4 minutes |
| Waits of 40 to 75 s, included above | 5.7 minutes |
| Output tokens | 24,066 |
| Cache read tokens | 5.68 million, over 17 requests |
| Context at the end | About 350k, against 47k in the agent's clean run |

Most of the token count came from rereading a long session's context on each request, and a clean session avoids it.

Proposed, none of it tried yet:

1. **Refresh with Play.** The developer sees render glitches clear after pressing Play, stopping and looking again. Test it once in Place3, measure it, and check what it does to `shared.World`. If it works, `world.js` should do this before capturing instead of waiting 45 s, and the render fact in `roblox-terrain-facts` should be corrected. Whether Studio's MCP causes the glitches is unknown.
2. **Bound the check.** When voxels are correct, a hole is only rendering: refresh once, and report it if it stays.
3. **Plan edits through the Edit tool.** A throwaway script put a valley inside a comment and cost one run.
4. **Captures only when needed.** The developer watches Studio while the agent works, so captures can be fewer when they are present.

## Final exam

After the token work, ask the agent for a new world for a new game in a clean session, from an empty folder and a new place, and measure it with `tools/measure-run.js`.

The agent has not been tried with a real `docs/world/rules.md` question flow since 0.5.0, and an install from the marketplace has not been tried either.

## Hand edits

The engine does not detect hand edits. The developer says which Chunks they touched, and the agent marks them Locked. Otherwise the next generation overwrites them. Comparing a Chunk's voxels with the Generator could detect them, and this is not built.

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

## Applied changes

Plugin 0.5.0 holds the instructions. The Generator holds the named operations, the checksum check and the capture set.

1. The agent reuses a Generator declared in `docs/world/rules.md`.
2. The loader compares checksums, and only modules that differ are pasted.
3. A fixed set of 11 views is taken one at a time, after a wait in its own call.
4. Lower effort was tried and not adopted, as explained below.
5. Skills load by branch, and `Ops` returns exact facts for generation and verification.

## Measured after the changes

Same map and verifications on `sonnet` on 2026-11-06, one run each, through `--plugin-dir` on a copy of the Generator. These runs start from existing code, so they measure reuse and are not a like-for-like match for the baseline, which wrote the Generator. Their prompt also asked to report an artificial look without redesigning it.

| Measure | Baseline | Generator loaded | Loaded, `--effort low` | Fresh Studio session |
|---|---|---|---|---|
| Duration, minutes | 32.9 | 3.3 | 2.9 | 6.9 |
| Model and overhead, minutes | 23.3 | 2.0 | 1.6 | 5.1 |
| Output tokens | 192,619 | 11,533 | 10,480 | 47,362 |
| Cache read tokens, millions | 13.9 | 1.07 | 0.90 | 2.96 |
| Context at the end | 268k | 51k | 50k | 121k |
| Tool calls | 141 | 30 | 28 | 64 |
| Errors | 14 | 0 | 0 | 0 |
| Captures | 35 | 12 | 11 | 11 |
| `execute_luau` input characters | 103,694 | 3,704 | 3,348 | 73,635 |

The aim of under 10 minutes and 15 captures was met in all three runs.

- **Effort:** low saved about 10% in one run, which is within what one run cannot separate from noise. These runs wrote no terrain code, so they could not show whether lower effort harms the terrain. Repeat the trial on a run that changes the Generator before setting it in the agent.
- **Fresh session:** pasting the Generator through the model is now the largest cost, at about 74,000 characters and four times the output tokens.
- **Blank captures:** an earlier run took 3.4 minutes with 5 blank captures, so it is excluded. They came from a minimized Studio window. Restored but not in the foreground, Studio captured normally. A fully covered window was not tested.
- **Crack in the ground:** `hills-ground` shows a dark crack, and `range-ground` a straight line near x 0. Each run called them render artifacts, since raycasts and voxel reads found no hole. The cause is not proven.

## A new world from a World Plan

Plugin 0.6.0 treats a new world as a new World Plan. The engine's `tools/world.js` reaches Studio through its MCP server, so the model pastes no modules and writes no Luau. One command loads, tests, describes, generates, verifies and writes captures, with views derived from the plan.

One run on `sonnet` on 2026-11-06, from an empty folder with nothing loaded in Studio, on a new layout and seed. The agent found the engine through its memory.

| Measure | Baseline, wrote the Generator | New World Plan, engine reused |
|---|---|---|
| Duration, minutes | 32.9 | 3.1 |
| Output tokens | 192,619 | 8,626 |
| Cache read tokens, millions | 13.9 | 0.45 |
| Context at the end | 268k | 47k |
| Tool calls | 141 | 26 |
| Errors | 14 | 2 |

The tool itself took 62 s of that, most of it the wait for the render mesh and the captures. Generating took 3.85 s.

- **What this does not measure:** the engine's cost was paid in the baseline, and a shape the engine lacks still needs code.
- **Captures:** the agent read 8 of the 11 views, and said so.
- **Reach:** since plugin 0.7.0 the engine ships in the plugin, so a public install can use this path. It has been tested only on Windows, and an install from the marketplace has not been tried.

## Natural look

Developer feedback on the first map: decent for a first test, but artificial and clumsy.

- **Ground:** relief with cracks and irregular elevations.
- **Mesa:** it looks artificial.
- **Caves:** a cave takes advantage of the existing terrain, so that the player ends up inside it. A tube drilled into one Landform is not what was meant.

The developer recalls an earlier, more natural generation. Show them the `before-*` captures in the Generator repository and ask whether it was one of those. Conversations from 2026-11-05 may hold its algorithm.

## Developer ideas

Collected from the developer on 2026-11-06. None is built yet.

- **Parameters over code:** a new world should change parameters, and writing code should be the rare case. Also asked for Biomes, whose objects and density are edited by parameters.
- **Seed hunting:** try thousands of seeds by brute force and keep the best, instead of building shapes by hand. Score each seed from heights on a coarse grid, which needs no graphics, then capture only the finalists for the developer to judge. A seed chooses among shapes the engine can already produce, so this works within the World Plan and adds no new shapes.
- **Finding a seed from a screenshot:** the developer recalled this from Minecraft, where it is called seed cracking. It recovers the seed of an existing world, so seed hunting fits this project better.
- **Fractal Rivers:** Rivers that branch, from a short rule that divides a channel into thinner ones. This needs a new engine capability, and the developer set it aside until after the speed work.

## Known gaps

The `capture` step of `tools/world.js` waits but leaves the camera where it is, so a rewritten Chunk far from the camera can look broken. It should settle the camera near each view first.

A River is still placed by hand and holds one water level. A fork works as a second River and valley leaving a route point. Routes that follow the relief are not built.


The tests have never run under Lute. Place file size, streaming, play mode and phones are unmeasured. The cave has not been walked by a character.

## Later agents

Create an agent only when its work exists, because multi-agent systems use many more tokens. 3D modeling costs money per use, so look for cheaper techniques first. No other agent is planned in detail yet.
