---
name: world-generation
description: Method for deterministic Roblox terrain generation from a World Plan, written Chunk by Chunk. Use when designing, changing or debugging a world Generator, or setting up world context in a project.
---

## How the map works

The map is the output of one pure function: terrain at a world position comes from the World Plan, the seeds and that position. Chunks are only the unit in which that output is written. Two neighbouring Chunks agree on their border because both evaluate the same function at the same world coordinates. A change to the function's output breaks this guarantee, so write every unlocked Chunk again.

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
| River | Water declared in the World Plan, following a straight or curved route through its points, with `halfWidth` or `widths` per point, `bendWiden` to open its bends, `loops` for bends close to a circle, `bedY` or `depths` per point with `bedRough` and `depthVary` for its bed, and `banks` for how it meets the land. A fork is a River that leaves a point, and a point can take any number of them |
| Lake | Still water declared in the World Plan, where Rivers end at the same water level |

## Layout

Keep the World Plan and generation state in Git under `src/world/`, the Generator in `src/world/generator/` and the Studio writer in `src/world/studio/`. Generation runs in Studio only and never reaches players.

`world.js test` runs the pure tests inside Studio without writing terrain, and they have never run outside it. Tests cover determinism (same input, same output) and seam agreement (two Chunks computing the same values along their shared border).

## Reusing a Generator

The Generator is an engine driven by parameters, and it ships in this plugin under `engine/`. A new world is a new World Plan, and a project keeps only that plan and its generation state. Every character sent through `execute_luau` is text the model must generate, so a script does that work:

1. Run the engine's command-line tool. It reaches Studio through Studio's MCP server, pastes what differs, and returns exact facts.
2. To get a new shape, add a parameter or a Landform kind to the engine, so that every later world can use it.
3. When you write a verification twice, move it into the tool.

## The `describe` report

The Generator validates the World Plan and answers these questions, so planning rests on facts:

- Which Chunks are generated, and which are Locked.
- Which Landform Regions and Rivers exist, and which Chunks each one touches.
- How much of the maximum extent is free, meaning Chunks not yet generated.

## Changing the map

1. Run `describe` before you edit, because something removed no longer appears in it. The Chunks listed for what you are changing are the ones to rewrite, except any Locked Chunk, which you report. A World Seed or Generator change touches every unlocked Chunk.
2. Edit the World Plan, a seed or the Generator.
3. Write only those Chunks with `generate <i> <j> ...`.
4. Ask the developer how it looks in Studio.

To change a shape, change the World Plan or a Region Seed. A Region Seed change alters that Landform Region and its blend margin.

## Design decisions

Supersede these only with the developer's agreement, recording why in the project's decisions.

| Decision | Why |
|---|---|
| Terrain is generated only in Studio and saved in the place | Generation can be heavy without affecting play, and the map stays editable Chunk by Chunk. New terrain reaches players only through a published update |
| The World Plan overrides the seeds | A required mountain range never depends on finding a lucky seed |
| The maximum extent is fixed up front, and only requested Chunks are generated | A shape can reach far beyond one Chunk, so the whole extent has to be known first |
| The World Seed stays fixed after the first publication | Changing it would alter every unlocked Chunk. Later changes go through the World Plan and Region Seeds |
| Chunks are squares | `Terrain` is written through axis-aligned boxes. A hexagon wastes about 25% of its write box and needs a merge with its neighbours |
| The Generator is pure Luau and returns Chunk data | No official way to run Rust on Roblox servers was found, and the final write stays serial in Studio |
| Code reaches Studio through MCP | Rojo adds a process nothing needs yet, and rewriting a place with it can lose terrain voxels |
| The Generator is our own, with no Creator Store plugin as its base | None reviewed offers scripted control, forced Landforms and per-Chunk writes that respect hand edits |

## Hand edits

The engine does not report hand edits, so the developer says which Chunks they touched, and you mark those Chunks as Locked. Neighbouring Chunks generate as usual, and any seam against a Locked Chunk is fixed by hand.

## Where knowledge lives

| Home | Holds | Scope |
|---|---|---|
| `docs/world/rules.md` | The Development Place, target map and decisions | This project, in Git |
| `GLOSSARY.md` | Canonical terms | This project, in Git |
| World Plan and generation state | What exists where now, and which Chunks are Locked | This project, in Git |
| `docs/world/history.md` | What changed on the map, and what was removed, through `world-history` | This project, in Git |
| Your agent memory | Lessons that hold in any Roblox project: measured engine behaviour, failures and their fixes, each with its date and evidence | All projects, on this computer |

Your memory travels between projects, so it holds only reusable lessons. Map details, game design and credentials stay in the project. When a lesson has held in two projects, propose adding it to the `roblox-terrain-facts` skill.
