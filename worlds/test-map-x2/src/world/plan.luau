-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -2..3 give 6 x 6 Chunks (3,072 x 3,072 studs), x and z from -1,280 to 1,792.
-- Doubled side of the engine's test map, same World Seed.

return {
	worldSeed = 12345,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -2, maxX = 3, minZ = -2, maxZ = 3 }, -- inclusive Chunk indices
	floorY = -64, -- ground is at least 64 studs thick everywhere (lowest ground is ~10)

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	regions = {
		{
			-- Range across the north, west to east.
			id = "range",
			kind = "mountain",
			seed = 7001,
			points = { { -1100, -800 }, { -600, -900 }, { -100, -760 }, { 450, -900 }, { 1000, -780 }, { 1500, -880 } },
			halfWidth = 170,
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			-- Mesa in the east, south of the range.
			id = "mesa",
			kind = "mesa",
			seed = 7002,
			center = { 1300, -100 },
			radius = 60,
			margin = 150,
			levels = 5,
			height = 100,
			warp = 40,
			elongate = 1.3,
			angle = 90,
			gully = 8,
		},
		{
			id = "valley",
			kind = "valley",
			seed = 7003,
			riverId = "river",
			halfWidth = 130,
			floorY = 24,
		},
		{
			id = "forkValley",
			kind = "valley",
			seed = 7005,
			riverId = "fork",
			halfWidth = 90,
			floorY = 24,
		},
		{
			id = "oxbowValleyA",
			kind = "valley",
			seed = 7008,
			riverId = "oxbowA",
			halfWidth = 60,
			floorY = 24,
		},
		{
			id = "oxbowValleyB",
			kind = "valley",
			seed = 7009,
			riverId = "oxbowB",
			halfWidth = 60,
			floorY = 24,
		},
		{
			id = "branchValley",
			kind = "valley",
			seed = 7007,
			riverId = "branch",
			halfWidth = 90,
			floorY = 24,
		},
		{
			-- Cave in the south-east, where the mesa stood before it moved.
			id = "cave",
			kind = "cave",
			seed = 7004,
			points = { { 1092, 60, 1250 }, { 1130, 60, 1250 }, { 1180, 60, 1262 }, { 1240, 60, 1250 } },
			radius = 14,
		},
	},

	rivers = {
		{
			id = "river",
			points = { { -1200, -150 }, { -850, -50 }, { -500, 100 }, { -150, 50 }, { 200, 250 }, { 450, 500 } },
			loops = { { leg = 4, radius = 110, turn = 290, side = "right" } },
			curve = 1,
			meander = 40,
			widths = { 14, 16, 18, 20, 26, 34 }, -- grows towards the Lake
			bendWiden = 0.5,
			bedY = 10,
			waterLevel = 20,
		},
		{
			-- Fork: leaves the River at (-500, 100) and also ends in the Lake.
			id = "fork",
			points = { { -500, 100 }, { -420, 450 }, { -100, 800 }, { 250, 880 }, { 420, 760 } },
			loops = { { leg = 2, radius = 120, turn = 360, side = "right" } },
			curve = 1,
			meander = 30,
			widths = { 6, 10, 12, 14, 20 }, -- starts thin where it leaves the River
			bendWiden = 0.5,
			bedY = 10,
			waterLevel = 20,
		},
		{
			-- Third branch: leaves the same point as the fork and runs off the west edge.
			id = "branch",
			points = { { -500, 100 }, { -700, 400 }, { -800, 700 }, { -1000, 1000 }, { -1270, 1100 } },
			curve = 1,
			meander = 30,
			widths = { 6, 10, 12, 14, 14 },
			bendWiden = 0.5,
			bedY = 10,
			waterLevel = 20,
		},
		{
			-- Oxbow lake north of the River: a crescent connected to nothing.
			id = "oxbowA",
			points = { { -733, -90 }, { -681, -156 }, { -596, -159 }, { -540, -96 }, { -552, -12 } },
			curve = 1,
			widths = { 6, 14, 18, 14, 6 },
			bedY = 12,
			waterLevel = 20,
		},
		{
			-- Oxbow lake south of the fork, more closed.
			id = "oxbowB",
			points = { { -6, 883 }, { -24, 961 }, { 35, 1015 }, { 111, 992 }, { 129, 914 } },
			curve = 1,
			widths = { 6, 10, 14, 10, 6 },
			bedY = 12,
			waterLevel = 20,
		},
	},
	lakes = {
		{ id = "lake", seed = 7006, center = { 500, 650 }, radius = 170, shore = 60, warp = 20, elongate = 1.2, angle = 30, bedY = 6, waterLevel = 20 },
	},
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
		mesaRiser = 1.1,
	},
}
