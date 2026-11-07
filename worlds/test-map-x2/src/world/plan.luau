-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -11..12 give 24 x 24 Chunks (12,288 x 12,288 studs), x and z from -5,888 to 6,400.
-- Started as a doubled side of the engine's test map, same World Seed, and doubled twice more.

return {
	worldSeed = 12345,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -11, maxX = 12, minZ = -11, maxZ = 12 }, -- inclusive Chunk indices
	floorY = 0, -- ground stops here, and goes lower only under deep water or a cave
	rockUnder = 8, -- a thin wall of rock under a deep bed, so that the bowl is open water and not a solid bulge

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 104, amp = 68, scale = 520, octaves = 6, warpScale = 600, warpAmp = 120 },

	regions = {
		{
			-- Range across the north, west to east.
			id = "range",
			kind = "mountain",
			seed = 7001,
			points = { { -5168, -3968 }, { -3168, -4368 }, { -1168, -3808 }, { 1032, -4368 }, { 3232, -3888 }, { 5232, -4288 } },
			halfWidth = 600,
			height = 500,
			ridgeScale = 300,
			crestScale = 440,
		},
		{
			-- Mesa in the east, south of the range.
			id = "mesa",
			kind = "mesa",
			seed = 7002,
			center = { 4432, -1168 },
			radius = 120,
			margin = 300,
			levels = 5,
			height = 200,
			warp = 80,
			elongate = 1.3,
			angle = 90,
			gully = 16,
		},
		{
			id = "valley",
			kind = "valley",
			seed = 7003,
			riverId = "river",
			halfWidth = 1400,
			floorY = 56,
		},
		{
			id = "forkValley",
			kind = "valley",
			seed = 7005,
			riverId = "fork",
			halfWidth = 1000,
			floorY = 56,
		},
		{
			id = "oxbowValleyA",
			kind = "valley",
			seed = 7008,
			riverId = "oxbowA",
			halfWidth = 600,
			floorY = 56,
		},
		{
			id = "oxbowValleyB",
			kind = "valley",
			seed = 7009,
			riverId = "oxbowB",
			halfWidth = 600,
			floorY = 56,
		},
		{
			id = "branchValley",
			kind = "valley",
			seed = 7007,
			riverId = "branch",
			halfWidth = 1000,
			floorY = 56,
		},
		{
			-- Cave in the south-east, where the mesa stood before it moved.
			id = "cave",
			kind = "cave",
			seed = 7004,
			points = { { 3600, 120, 4232 }, { 3752, 120, 4232 }, { 3952, 120, 4280 }, { 4192, 120, 4232 } },
			radius = 28,
		},
	},

	rivers = {
		{
			id = "river",
			points = { { -5568, -1368 }, { -4168, -968 }, { -2768, -368 }, { -1368, -568 }, { 32, 232 }, { 1032, 1232 } },
			loops = { { leg = 4, radius = 440, turn = 290, side = "right" } },
			curve = 1,
			meander = 160,
			widths = { 60, 72, 88, 104, 128, 160 }, -- grows towards the Lake
			bendWiden = 0.5,
			depths = { 24, 68, 36, 120, 60, 180 }, -- below the water
			depthVary = 0.5,
			banks = { shore = 100, shallows = 60, shallowDepth = 8, bedFlat = 0.2, steep = 1.6, rough = 6, vary = 0.6, smooth = 96 },
			bedRough = 12,
			waterLevel = 40,
		},
		{
			-- Fork: leaves the River and also ends in the Lake.
			id = "fork",
			points = { { -2768, -368 }, { -2448, 1032 }, { -1168, 2432 }, { 232, 2752 }, { 912, 2272 } },
			loops = { { leg = 2, radius = 480, turn = 360, side = "right" } },
			curve = 1,
			meander = 120,
			widths = { 30, 50, 60, 70, 100 }, -- starts thin where it leaves the River
			bendWiden = 0.5,
			depths = { 16, 48, 24, 88, 140 }, -- below the water
			depthVary = 0.5,
			banks = { shore = 72, shallows = 40, shallowDepth = 6, bedFlat = 0.2, steep = 1.4, rough = 5, vary = 0.6, smooth = 80 },
			bedRough = 6,
			waterLevel = 40,
		},
		{
			-- Third branch: leaves the same point as the fork and runs off the west edge.
			id = "branch",
			points = { { -2768, -368 }, { -3568, 832 }, { -3968, 2032 }, { -4768, 3232 }, { -5848, 3632 } },
			curve = 1,
			meander = 120,
			widths = { 30, 50, 60, 70, 70 },
			bendWiden = 0.5,
			depths = { 16, 36, 80, 28, 44 }, -- below the water
			depthVary = 0.5,
			banks = { shore = 60, shallows = 24, shallowDepth = 4, bedFlat = 0.3, steep = 2, rough = 6, vary = 0.5, smooth = 80 },
			bedRough = 6,
			waterLevel = 40,
		},
		{
			-- Oxbow lake north of the River: a crescent connected to nothing.
			id = "oxbowA",
			points = { { -3700, -1128 }, { -3492, -1392 }, { -3152, -1404 }, { -2928, -1152 }, { -2976, -816 } },
			curve = 1,
			widths = { 28, 60, 80, 60, 28 },
			depths = { 12, 44, 80, 44, 12 }, -- below the water
			banks = { shore = 60, shallows = 32, shallowDepth = 6, bedFlat = 0.4, steep = 1.3, rough = 4, vary = 0.5 },
			bedRough = 4,
			waterLevel = 40,
		},
		{
			-- Oxbow lake south of the fork, more closed.
			id = "oxbowB",
			points = { { -792, 2764 }, { -864, 3076 }, { -628, 3292 }, { -324, 3200 }, { -252, 2888 } },
			curve = 1,
			widths = { 28, 44, 60, 44, 28 },
			depths = { 12, 36, 60, 36, 12 }, -- below the water
			banks = { shore = 60, shallows = 32, shallowDepth = 6, bedFlat = 0.3, steep = 1.3, rough = 4, vary = 0.5 },
			bedRough = 4,
			waterLevel = 40,
		},
	},
	lakes = {
		{ id = "lake", seed = 7006, center = { 1232, 1832 }, radius = 680, shore = 480, warp = 80, elongate = 1.2, angle = 30, bedY = -180, bedRough = 20, depthVary = 0.4, banks = { shallows = 100, shallowDepth = 12, bedFlat = 0.25, steep = 1.3, rough = 12, vary = 0.6 }, waterLevel = 40 },
	},
	sites = {},
	worldLimit = nil, -- not requested yet

	-- Material thresholds.
	materials = {
		snowLine = 410,
		snowBlend = 60,
		snowMaxSlope = 1.4,
		steep = 0.85, -- rise over run above which ground is bare rock
		rockLine = 280,
		bankDist = 52, -- sand within this distance of the route: a band, not a road
		bankHeight = 56,
		bedDeep = 28, -- from this depth down, a bed is earth with patches of rock and a little sand
		mesaRiser = 1.1,
	},
}
