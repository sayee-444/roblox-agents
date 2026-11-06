# World

Worlds, terrain and their ambience: how they are planned, generated and themed. Players only ever experience the published result.

## Language

### Planning and generation

**World Plan**:
The versioned declaration of what exists where: the maximum extent, the general layout, and every Landform Region, River, Lake, Zone and Site placed on purpose.
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
A watercourse of still water whose route is declared by points in the World Plan.
_Avoid_: stream, flow

**Lake**:
A body of still water declared in the World Plan, where Rivers end.
_Avoid_: ocean, sea

**Generator**:
The tool that turns the World Plan and the seeds into terrain. It is written and operated by the World agent, which does not shape terrain by eye.
_Avoid_: agent (the agent is not the Generator)

**Chunk**:
The unit in which the world is generated, added to a place and updated.
_Avoid_: tile, section, cell

**Locked Chunk**:
A Chunk edited by hand, which the Generator overwrites only when explicitly forced.
_Avoid_: frozen chunk, manual chunk

### Places and limits

**Development Place**:
The private place holding every Chunk and experiment, which players never join.
_Avoid_: test map, sandbox

**Game Place**:
The place players join, which holds only Chunks approved for release.
_Avoid_: live map, production map

**World Limit**:
The impassable edge shared by every player, whose shape is declared in the World Plan.
_Avoid_: wall, border

**Gate**:
A per-player barrier, decided by the server, that opens with that player's progress.
_Avoid_: lock, World Limit

### Ground and objects

**Landform**:
The shape of the ground, such as plain, mountain, mesa, valley or mountain range.
_Avoid_: structure, terrain type, biome

**Biome**:
A ground treatment, its Decoration parameters and its default Theme.
_Avoid_: using it for a shape (Landform) or for ambience alone (Theme)

**Decoration**:
A static object placed from Biome parameters, such as a tree, rock or bush. It never simulates physics, and its density can be zero.
_Avoid_: prop, scatter

**Structure**:
A building placed on purpose, such as a castle.
_Avoid_: landmark, prefab

**Site**:
The place reserved in the World Plan for a Structure, whose ground the Generator prepares and preserves.
_Avoid_: pad, plot

**Season**:
A temporary change to how Biomes look and what falls from the sky, which never changes the shape of the terrain.
_Avoid_: event skin, holiday mode

### Ambience

**Theme**:
What a player perceives as ambience: sky and light colour, atmosphere, music and sound. It never changes the ground, and only one is active at a time, outside a transition.
_Avoid_: mood, ambience, environment

**Standard Theme**:
The placeholder Theme used until a place in the world has a real one.
_Avoid_: normal biome, and "default theme" for this fallback, since that phrase means a Biome's own Theme

**Zone**:
A named area placed on purpose that activates a Theme when a player enters it, such as the Graveyard. It never changes the ground or Decoration.
_Avoid_: region, area

### Player device

**Graphics Profile**:
A named quality level, from Low to Ultra, that changes what a device draws but never anything a player can collide with.
_Avoid_: quality preset, graphics mode
