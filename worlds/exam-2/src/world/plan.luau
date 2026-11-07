-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -1..1 give 3 x 3 Chunks centred on the origin (1,536 x 1,536 studs).

return {
	worldSeed = 431870259,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -1, maxX = 1, minZ = -1, maxZ = 1 }, -- inclusive Chunk indices
	floorY = -64, -- ground is at least 64 studs thick everywhere (lowest ground is ~10)

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	-- Landform Regions. Each has its own Region Seed and a bounded blend margin.
	regions = {
		{
			id = "range",
			kind = "mountain",
			seed = 35182,
			-- Polyline running north to south along the east side: touches the Chunk rows -1, 0 and 1.
			points = { { 560, -720 }, { 480, -300 }, { 560, 100 }, { 470, 450 }, { 560, 740 } },
			halfWidth = 150, -- blend margin included: nothing of it reaches beyond this distance
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			id = "mesa",
			kind = "mesa",
			seed = 62907,
			center = { -480, -420 },
			radius = 60, -- flat top
			margin = 150, -- flank, from the top radius out to the foot
			levels = 5,
			height = 100,
			warp = 40, -- largest shift of the outline, in studs
			elongate = 1.3, -- length over width of the footprint
			angle = 20, -- direction of its long axis, in degrees
			gully = 8, -- how far gullies bite into the flank, in studs
		},
		{
			id = "valley",
			kind = "valley",
			seed = 80416,
			riverId = "river",
			halfWidth = 130,
			floorY = 24,
		},
		{
			id = "eastValley",
			kind = "valley",
			seed = 19273,
			riverId = "eastBranch",
			halfWidth = 90,
			floorY = 24,
		},
	},

	-- A River follows its route points; the still water sits at a constant level.
	rivers = {
		{
			id = "river",
			points = { { -60, -740 }, { -120, -480 }, { -40, -250 }, { -40, 0 }, { -250, 300 }, { -330, 740 } },
			halfWidth = 20,
			bedY = 10,
			waterLevel = 20, -- multiple of the voxel size, so the surface meets a voxel boundary
		},
		{
			-- Fork: leaves the main River at its fourth route point and runs south-east.
			id = "eastBranch",
			points = { { -40, 0 }, { 120, 280 }, { 190, 500 }, { 180, 740 } },
			halfWidth = 14,
			bedY = 10,
			waterLevel = 20,
		},
	},
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
		mesaRiser = 1.1,
	},
}
