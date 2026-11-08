-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -5..6 give 12 x 12 Chunks (6,144 x 6,144 studs), x and z from -2,816 to 3,328.
-- Started as a doubled side of the engine's own plan, same World Seed, and doubled again for larger water.

return {
	worldSeed = 12345,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -5, maxX = 6, minZ = -5, maxZ = 6 }, -- inclusive Chunk indices
	floorY = 0, -- ground stops here, and goes lower only under deep water or a cave
	rockUnder = 8, -- a thin wall of rock under a deep bed, so that the bowl is open water and not a solid bulge

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	regions = {
		{
			-- Range across the north, west to east.
			id = "range",
			kind = "mountain",
			seed = 7001,
			points = { { -2456, -1856 }, { -1456, -2056 }, { -456, -1776 }, { 644, -2056 }, { 1744, -1816 }, { 2744, -2016 } },
			halfWidth = 300,
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			-- Mesa in the east, south of the range.
			id = "mesa",
			kind = "mesa",
			seed = 7002,
			center = { 2344, -456 },
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
			halfWidth = 700,
			floorY = 28,
			sides = { 0.12, 0.12, 0.15, 0.9, 0.7, 1.2 },
		},
		{
			id = "forkValley",
			kind = "valley",
			seed = 7005,
			riverId = "fork",
			halfWidth = 500,
			floorY = 28,
			sides = { 0.12, 0.12, 0.12, 0.3, 1.5 },
		},
		{
			id = "oxbowValleyA",
			kind = "valley",
			seed = 7008,
			riverId = "oxbowA",
			halfWidth = 300,
			floorY = 28,
			sides = { 0.1, 0.1, 1.5, 0.1, 0.1 },
		},
		{
			id = "oxbowValleyB",
			kind = "valley",
			seed = 7009,
			riverId = "oxbowB",
			halfWidth = 300,
			floorY = 28,
			sides = { 0.1, 0.1, 1.5, 0.1, 0.1 },
		},
		{
			id = "branchValley",
			kind = "valley",
			seed = 7007,
			riverId = "branch",
			halfWidth = 500,
			floorY = 28,
			sides = { 0.12, 0.12, 1.5, 0.12, 0.12 },
		},
		{
			-- Cave in the south-east, where the mesa stood before it moved.
			id = "cave",
			kind = "cave",
			seed = 7004,
			points = { { 1928, 60, 2244 }, { 2004, 60, 2244 }, { 2104, 60, 2268 }, { 2224, 60, 2244 } },
			radius = 14,
		},
	},

	rivers = {
		{
			id = "river",
			points = { { -2656, -556 }, { -1956, -356 }, { -1256, -56 }, { -556, -156 }, { 144, 244 }, { 644, 744 } },
			loops = { { leg = 4, radius = 220, turn = 290, side = "right" } },
			curve = 1,
			meander = 80,
			widths = { 30, 36, 44, 52, 64, 80 }, -- grows towards the Lake
			bendWiden = 0.5,
			depths = { 12, 34, 18, 60, 30, 90 }, -- below the water
			depthVary = 0.5,
			banks = { shore = 50, rough = 3, vary = 0.6, smooth = 48 },
			bedRough = 6,
			waterLevel = 20,
		},
		{
			-- Fork: leaves the River at (-500, 100) and also ends in the Lake.
			id = "fork",
			points = { { -1256, -56 }, { -1096, 644 }, { -456, 1344 }, { 244, 1504 }, { 584, 1264 } },
			loops = { { leg = 2, radius = 240, turn = 360, side = "right" } },
			curve = 1,
			meander = 60,
			widths = { 15, 25, 30, 35, 50 }, -- starts thin where it leaves the River
			bendWiden = 0.5,
			depths = { 8, 24, 12, 44, 90 }, -- below the water
			depthVary = 0.5,
			banks = { shore = 36, rough = 2.5, vary = 0.6, smooth = 40 },
			bedRough = 3,
			waterLevel = 20,
		},
		{
			-- Third branch: leaves the same point as the fork and runs off the west edge.
			id = "branch",
			points = { { -1256, -56 }, { -1656, 544 }, { -1856, 1144 }, { -2256, 1744 }, { -2796, 1944 } },
			curve = 1,
			meander = 60,
			widths = { 15, 25, 30, 35, 35 },
			bendWiden = 0.5,
			depths = { 8, 18, 60, 14, 22 }, -- below the water
			depthVary = 0.5,
			banks = { shore = 30, rough = 3, vary = 0.5, smooth = 40 },
			bedRough = 3,
			waterLevel = 20,
		},
		{
			-- Oxbow lake north of the River: a crescent connected to nothing.
			id = "oxbowA",
			points = { { -1722, -436 }, { -1618, -568 }, { -1448, -574 }, { -1336, -448 }, { -1360, -280 } },
			curve = 1,
			widths = { 14, 30, 40, 30, 14 },
			depths = { 6, 22, 60, 22, 6 }, -- below the water
			banks = { shore = 30, rough = 2, vary = 0.5 },
			bedRough = 2,
			waterLevel = 20,
		},
		{
			-- Oxbow lake south of the fork, more closed.
			id = "oxbowB",
			points = { { -268, 1510 }, { -304, 1666 }, { -186, 1774 }, { -34, 1728 }, { 2, 1572 } },
			curve = 1,
			widths = { 14, 26, 40, 26, 14 },
			depths = { 6, 18, 50, 18, 6 }, -- below the water
			banks = { shore = 30, rough = 2, vary = 0.5 },
			bedRough = 2,
			waterLevel = 20,
		},
	},
	lakes = {
		{ id = "lake", seed = 7006, center = { 744, 1044 }, radius = 425, shore = 40, warp = 40, elongate = 1.2, angle = 30, bedY = -90, bedRough = 10, depthVary = 0.4, banks = { rough = 6, vary = 0.6 }, waterLevel = 20 },
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
