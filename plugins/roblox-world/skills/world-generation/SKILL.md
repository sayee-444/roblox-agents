---
name: world-generation
description: Method for deterministic Roblox terrain generation from a World Plan, written Chunk by Chunk. Use when designing, changing or debugging a world Generator, or setting up world context in a project.
---

## How the map works

The map is the output of one pure function: terrain at a world position comes from the World Plan, the seeds and that position. Chunks are only the unit in which that output is written. Two neighbouring Chunks agree on their border because both evaluate the same function at the same world coordinates. A change to the function's output breaks this guarantee, so regenerate every unlocked Chunk.

| Term | Meaning |
|---|---|
| World Plan | Data declaring what exists where. It wins over the seeds |
| Generator | Pure Luau that turns the World Plan and seeds into terrain data, with its own noise and random number generator |
| Studio writer | The only code that touches `Terrain` |
| Generation state | Which Chunks exist and which are Locked |
| Chunk | A square of terrain, 512 x 512 studs by default |
| Locked Chunk | A hand-edited Chunk the Generator skips |
| World Seed | Supplies natural detail across the map |
| Landform Region | A declared shape, such as a mountain range or a mesa, with its own Region Seed and a bounded blend margin |
| River, Lake | Water declared in the World Plan; a River follows route points |
| Site | An area reserved for a future structure, with size and slope limits |
| World Limit | The declared edge where players stop: an invisible barrier and a server check |

## Layout

Keep the World Plan and generation state in Git under `src/world/`, the Generator in `src/world/generator/` and the Studio writer in `src/world/studio/`. Generation runs in Studio only and never reaches players.

Test the Generator outside Roblox with [Lute](https://github.com/luau-lang/lute). If it is missing, ask the developer whether to install it. Until then, or if nobody can answer, run the pure tests through `execute_luau` in Studio without writing terrain, and report that they ran only there. That thread cannot make network calls or parent a script, so keep a loader in `shared` that stores each module's source and runs it with `loadstring`. Tests cover determinism (same input, same output) and seam agreement (two Chunks computing the same values along their shared border).

## Reusing a Generator

`docs/world/rules.md` declares the Generator's location and its commands, and a run extends that code. Every character pasted through `execute_luau` is text the model must generate, so pasting is the costliest step of a run:

1. Compare the checksum of each local module with the one in `shared.World`. `shared` lasts until Studio closes, so an unchanged Generator needs no paste.
2. Paste only the modules that differ, and check the checksum the loader returns.
3. Run the operations the Generator already offers. When you write a verification twice, move it into the Generator and list it in the rules.

## The `describe` report

The Generator validates the World Plan and answers these questions, so planning rests on facts:

- Which Chunks are generated, and which are Locked.
- Which Landform Regions, Rivers, Lakes and Sites exist, and which Chunks each one touches.
- Which Chunks a proposed change would rewrite, and which Locked Chunks it reaches.
- How much of the maximum extent is free, meaning Chunks not yet generated.

## Changing the map

1. Edit the World Plan, a seed or the Generator.
2. Run the `describe` impact report.
3. Regenerate only the affected Chunks.
4. Run `describe` again, and check the result with a capture.

To change a shape, change the World Plan or a Region Seed. A Region Seed change alters that Landform Region and its blend margin.

## Design decisions

Supersede these only with the developer's agreement, recording why in the project's decisions.

| Decision | Why |
|---|---|
| Terrain is generated only in Studio and saved in the place | Generation can be heavy without affecting play, and the map stays editable Chunk by Chunk. New terrain reaches players only through a published update |
| The World Plan overrides the seeds | A required mountain range never depends on finding a lucky seed |
| The maximum extent is fixed up front, and only requested Chunks are generated | Automatically routed Rivers, if ever added, depend on terrain far beyond one Chunk |
| The World Seed stays fixed after the first publication | Changing it would alter every unlocked Chunk. Later changes go through the World Plan and Region Seeds |
| Chunks are squares | `Terrain` is written through axis-aligned boxes. A hexagon wastes about 25% of its write box and needs a merge with its neighbours. A hexagonal planning layer can still sit on top |
| The Generator is pure Luau and returns Chunk data | No official way to run Rust on Roblox servers was found, and the final write stays serial in Studio. Rust can join at this boundary if a measurement justifies it |
| Code reaches Studio through MCP | Rojo adds a process nothing needs yet, and rewriting a place with it can lose Expanded Terrain voxels. If adopted, Rojo manages code only and never rewrites a place holding terrain |
| The Generator is our own, with no Creator Store plugin as its base | None reviewed offers scripted control, forced Landforms and per-Chunk writes that respect hand edits |

## Hand edits

The engine does not report hand edits, so the developer says which Chunks they touched, and you mark those Chunks as Locked. Neighbouring Chunks generate as usual, and any seam against a Locked Chunk is fixed by hand.

## Where knowledge lives

| Home | Holds | Scope |
|---|---|---|
| `docs/world/rules.md` | The Development Place, target map and decisions | This project, in Git |
| `GLOSSARY.md` | Canonical terms | This project, in Git |
| World Plan and generation state | What exists where, and which Chunks are Locked | This project, in Git |
| Your agent memory | Lessons that hold in any Roblox project: measured engine behaviour, failures and their fixes, each with its date and evidence | All projects, on this computer |

Your memory travels between projects, so it holds only reusable lessons. Map details, game design and credentials stay in the project. When a lesson has held in two projects, propose adding it to the `roblox-terrain-facts` skill.
