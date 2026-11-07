# World

Worlds and terrain: how they are planned and generated. Players only ever experience the published result. Terms for systems that are designed and not built are in `docs/designs/world-systems.md`.

## Language

### Planning and generation

**World Plan**:
The versioned declaration of what exists where: the maximum extent, the general layout, and every Landform Region and River placed on purpose.
_Avoid_: map config, layout file

**World Seed**:
The single fixed number that supplies natural detail.
_Avoid_: map seed, global seed

**Landform Region**:
A stretch of the world that the World Plan assigns one Landform, whose exact shape comes from its Region Seed.
_Avoid_: feature, stamp

**Region Seed**:
The number that decides the exact shape inside one Landform Region, so that it can be changed without altering the rest of the world.
_Avoid_: local seed, sub-seed

**River**:
A watercourse of still water whose route passes through points declared in the World Plan, in straight legs or a curve, with a width that can change along it.
_Avoid_: stream, flow

**Lake**:
A body of still water declared in the World Plan, where Rivers end.
_Avoid_: ocean, sea

**Banks**:
How a River or Lake meets the land, across from the ground around it down to its deepest line: its Shore, its Shallows and the wall below them.
_Avoid_: edges, sides

**Shore**:
The gentle dry ground between the water and the ground around it.
_Avoid_: beach, border

**Shallows**:
The strip of shallow water just inside a Shore, before the wall falls.
_Avoid_: shelf, ford

**Generator**:
The tool that turns the World Plan and the seeds into terrain. It is written and operated by the World agent, which does not shape terrain by eye.
_Avoid_: agent (the agent is not the Generator)

**Chunk**:
The unit in which the world is generated, added to a place and updated.
_Avoid_: tile, section, cell

**Locked Chunk**:
A Chunk edited by hand, which the Generator overwrites only when explicitly forced.
_Avoid_: frozen chunk, manual chunk

### Places

**Development Place**:
The private place holding every Chunk and experiment, which players never join.
_Avoid_: test map, sandbox

**Game Place**:
The place players join, which holds only Chunks approved for release.
_Avoid_: live map, production map

### Ground

**Landform**:
The shape of the ground, such as plain, mountain, mesa, valley or mountain range.
_Avoid_: structure, terrain type, biome
