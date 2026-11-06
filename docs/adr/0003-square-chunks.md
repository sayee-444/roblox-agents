# Chunks are square, not hexagonal

Chunks are 512 x 512 stud squares, even though the developer proposed hexagons, because Terrain is a single object written through axis-aligned boxes. On that grid a hexagon wastes about 25% of its write box and forces a read, merge and write against its neighbours, and it offers players nothing since Chunks exist only during development. This is a design judgement, not a Roblox rule. Landforms live in world coordinates and can have any shape, so a hexagonal planning layer could still be added on top.
