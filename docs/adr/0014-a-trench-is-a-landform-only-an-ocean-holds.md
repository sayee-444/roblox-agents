# A Trench is a Landform only an Ocean holds, and its floor is a height

The developer wants places far deeper than an Ocean's cap of 1,200, such as a medium Sea holding a trench thousands of studs deeper than the water around it, placed where they choose and kept where they are when land is added later. On 2026-11-08, for #78, they chose a Landform, the Trench, declared in the World Plan's Landform Regions with its own Region Seed: a route of points, a half width that holds its walls, a floor at each point, the steepness of its walls and how far its Region Seed roughens them. An abyss is a Trench with a short route.

Its floors are heights, not depths below the Ocean's bed, so a change to the Ocean's cap or Coast moves the bed around a Trench and never its floor. A Trench only lowers the ground, as a Lake does: within its half width the ground is the lower of the Ocean's bed and walls that fall from that bed to its floor, and where two Trenches meet the deeper one counts. Its walls leave the bed as a ramp, steepening evenly from flat over a rim of 0.4 of its half width, since walls that turned from flat to a cliff at once read as a cone cut into a plain, seen by the developer on 2026-11-09. Its Region Seed only bends its outline inwards and raises its floor, by up to a fifth of its half width unless the plan gives `rough`, so a wide Trench is as irregular as a narrow one, nothing beyond its half width changes and its floor is its deepest point. Validation refuses a Trench any of whose half width lies on a Chunk no Ocean holds, which covers land, a Lake and the edge of the extent, and a plan that turns the Ocean under a Trench into land is refused by the same check. It also refuses a floor not below the Ocean's bed at a point, walls too gentle to reach the floor over the half width, and, per ADR 0012, a floor below the Depth Limit.

## Considered Options

- A Structure. Rejected: in the glossary a Structure is a building.
- Floors as depths below the Ocean's bed. Rejected: a change to the cap or the Coast would move every Trench and what was built around it.
- Walls that reach the floor whatever the half width, with the steepness left to follow. Rejected: the plan states the steepness, and a refusal that names the half width or walls needed tells the developer which to change.

## Consequences

A Chunk a Trench reaches is written column by column, and the open Ocean around it stays plain blocks. Under a Trench 3,000 deep a column holds some 750 voxels, most of them water, and such a Chunk still wrote in about 1 s: 21 Chunks of an abyss in 21.1 s and 68 of a Trench in 86.8 s, the slowest 12.01 s, measured on `lab-ocean` on 2026-11-09. So the writer keeps writing the water with the ground, voxel by voxel, rather than as a block of its own. One read of such a Chunk is too large for Roblox, so `verify` reads it in strips. Adding land near a Trench is refused until the Trench moves or goes, which keeps what was built around it from being cut in half.
