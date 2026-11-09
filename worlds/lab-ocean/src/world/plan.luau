-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -11..12 give 24 x 24 Chunks (12,288 x 12,288 studs), x and z from -5,888 to 6,400.
-- A pure Ocean, to measure what one costs to generate and save (issue #69). It holds no land yet.

return {
	worldSeed = 12345,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -11, maxX = 12, minZ = -11, maxZ = 12 }, -- inclusive Chunk indices
	floorY = 0, -- ground stops here, and goes lower only under deep water or a cave
	depthLimit = -3500, -- no bed or cave floor may lie below this, a multiple of 4
	destroyHeight = -4000, -- Roblox removes what falls below this; run and generate set it in the place, below depthLimit
	rockUnder = 8, -- a thin wall of rock under a deep bed

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	seaLevel = 20, -- one level for every Ocean, a multiple of 4
	-- An Ocean holds whole Chunks, as rectangles { i0, j0, i1, j1 } of Chunk indices, inclusive.
	oceans = {
		-- Everything except two Landmasses: A at i -6..1, j -4..4 and B at i 3..6, j -2..2.
		-- The channel at i = 2 is part of the Ocean.
		{
			id = "ocean",
			seed = 8001,
			chunks = {
				{ -11, -11, -7, 12 }, -- west of A
				{ 7, -11, 12, 12 }, -- east of B
				{ -6, -11, 6, -5 }, -- north strip
				{ -6, 5, 6, 12 }, -- south strip
				{ 2, -4, 2, 4 }, -- channel between A and B
				{ 3, -4, 6, -3 }, -- beside B, one side
				{ 3, 3, 6, 4 }, -- beside B, other side
			},
		},
	},

	-- An abyss in the open Ocean south of Landmass A: a short route makes a round pit.
	regions = {
		{ id = "abyss", kind = "trench", seed = 9101, points = { { 0, 4608 }, { 0, 4612 } }, floors = { -3000, -3000 }, halfWidth = 1024, walls = 4 },
		-- A long Trench west of the large Landmass, running north to south.
		{ id = "western", kind = "trench", seed = 9102, points = { { -4600, -4000 }, { -4800, 0 }, { -4500, 4000 } }, floors = { -2000, -2800, -3400 }, halfWidth = 980, walls = 5 },
	},
	rivers = {},
	lakes = {},
	sites = {},
	worldLimit = nil, -- not requested yet

	-- Material thresholds.
	materials = {
		snowLine = 205,
		snowBlend = 30,
		snowMaxSlope = 1.4,
		steep = 0.85, -- rise over run above which ground is bare rock
		rockLine = 140,
		bankDist = 26, -- sand within this distance of the route: a band, not a road
		bankHeight = 28,
		bedSand = 6, -- a bed is sand under water this shallow, and earth comes through it below
		bedDeep = 14, -- from this depth down, a bed is earth with patches of rock and a little sand
		mesaRiser = 1.1,
	},
}
