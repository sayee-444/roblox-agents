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
How a River or Lake meets the land, from the ground around it down to its deepest line, falling as one curve with no break at the waterline: its Shore and its Shallows.
_Avoid_: edges, walls

**Shore**:
The dry ground between the water and the ground around it.
_Avoid_: beach, border

**Shallows**:
The strip of shallow water just inside a Shore, wide where the ground comes down gently.
_Avoid_: shelf, ford

**Valley Side**:
The ground of a valley that falls from its edge towards its River and keeps falling under the water. How steep it is decides how deep the River gets.
_Avoid_: hillside, flank

**Cut Bank**:
The outside of a River's bend, where the bank is steep and the water deepest.
_Avoid_: outer bank

**Point Bar**:
The inside of a River's bend, where gentle sand runs down into shallow water.
_Avoid_: inner bank, sandbar

**Generator**:
The tool that turns the World Plan and the seeds into terrain. It is written and operated by the World agent, which does not shape terrain by eye.
_Avoid_: agent (the agent is not the Generator)

**Chunk**:
The unit in which the world is generated, added to a place and updated.
_Avoid_: tile, section, cell

**Locked Chunk**:
A Chunk edited by hand, which the Generator overwrites only when explicitly forced.
_Avoid_: frozen chunk, manual chunk

**Extent**:
How many Chunks a world spans along each side, as the World Plan declares.
_Avoid_: dimensions, map size

**Generate**:
To calculate Chunks from the World Plan and the seeds and write them to a place, whether they exist there already or not.
_Avoid_: regenerate, rebuild

### Places

**Development Place**:
The private place holding every Chunk and experiment, which players never join.
_Avoid_: sandbox

**Game Place**:
The place players join, which holds only Chunks approved for release.
_Avoid_: live map, production map

### Working on the agent

**Test World**:
A world that belongs to no game, kept to try the agent and to compare Implementations. `lab` is the one meant when no name is given.
_Avoid_: test map

**World Snapshot**:
A place file the developer saved, holding a world's terrain as it stood at one point in its history.
_Avoid_: backup, saved copy

**Load**:
To open a World Snapshot, which generates nothing.
_Avoid_: restore, sync

**Implementation**:
One issue, or one finished change to the agent, its skills, its engine or its tools. It is what the developer approves, and what a map change is compared against.
_Avoid_: feature, task

### Ground

**Landform**:
The shape of the ground, such as plain, mountain, mesa, valley or mountain range.
_Avoid_: structure, terrain type, biome
