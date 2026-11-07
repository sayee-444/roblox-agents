-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so this extent spans -768 to 768 on x and z.

return {
	worldSeed = 82165555,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -1, maxX = 1, minZ = -1, maxZ = 1 }, -- inclusive Chunk indices
	floorY = -64, -- ground is at least 64 studs thick everywhere

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	regions = {
		{
			id = "range",
			kind = "mountain",
			seed = 41907,
			points = { { -600, -480 }, { -380, -560 }, { -140, -540 }, { 40, -590 } },
			halfWidth = 170,
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			id = "mesa",
			kind = "mesa",
			seed = 53318,
			center = { 480, -330 },
			radius = 60,
			margin = 150,
			levels = 5,
			height = 100,
			warp = 40,
			elongate = 1.3,
			angle = 35,
			gully = 8,
		},
		{
			id = "valley",
			kind = "valley",
			seed = 27664,
			riverId = "river",
			halfWidth = 130,
			floorY = 24,
		},
		{ id = "forkValley", kind = "valley", seed = 61452, riverId = "fork", halfWidth = 90, floorY = 24 },
	},

	rivers = {
		{
			id = "river",
			points = { { -740, 100 }, { -350, 180 }, { 0, 120 }, { 350, 200 }, { 740, 160 } },
			halfWidth = 20,
			bedY = 10,
			waterLevel = 20,
		},
		{ id = "fork", points = { { 0, 120 }, { 120, 400 }, { 300, 740 } }, halfWidth = 14, bedY = 10, waterLevel = 20 },
	},
	lakes = {},
	sites = {},
	worldLimit = nil, -- not requested yet

	materials = {
		snowLine = 205,
		snowBlend = 30,
		snowMaxSlope = 1.4,
		steep = 0.85,
		rockLine = 140,
		bankDist = 26,
		bankHeight = 28,
		mesaRiser = 1.1,
	},
}
