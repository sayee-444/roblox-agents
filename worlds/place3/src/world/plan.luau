-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -1..1 give 3 x 3 Chunks centred on the origin (1,536 x 1,536 studs).

return {
	worldSeed = 987654,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -1, maxX = 1, minZ = -1, maxZ = 2 }, -- inclusive Chunk indices
	floorY = -64, -- ground is at least 64 studs thick everywhere (lowest ground is ~10)

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	-- Landform Regions. Each has its own Region Seed and a bounded blend margin.
	regions = {
		{
			id = "range",
			kind = "mountain",
			seed = 7001,
			-- Polyline crossing the map north to south on the west side: touches the Chunk rows -1, 0 and 1.
			points = { { -500, -740 }, { -440, -300 }, { -540, 120 }, { -460, 450 }, { -520, 740 } },
			halfWidth = 170, -- blend margin included: nothing of it reaches beyond this distance
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			id = "mesa",
			kind = "mesa",
			seed = 7002,
			center = { 420, -420 },
			radius = 60, -- flat top
			margin = 150, -- flank, from the top radius out to the foot
			levels = 5,
			height = 100,
			warp = 40, -- largest shift of the outline, in studs
			elongate = 1.35, -- length over width of the footprint
			angle = 25, -- direction of its long axis, in degrees
			gully = 8, -- how far gullies bite into the flank, in studs
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
			-- Cave a player can walk into: path in world coordinates {x, y, z}. The mouth
			-- opens on flat ground (y 55) at the western foot of the mesa and runs east into
			-- it. The axis is one radius above the ground, so the tunnel floor is the ground.
			id = "cave",
			kind = "cave",
			seed = 7004,
			points = { { 205, 67, -420 }, { 250, 67, -420 }, { 300, 67, -408 }, { 355, 67, -420 } },
			radius = 14,
		},
	},

	-- A River follows its route points; the still water sits at a constant level.
	rivers = {
		{
			id = "river",
			points = { { 740, 60 }, { 540, 160 }, { 360, 230 }, { 200, 380 }, { 160, 560 }, { 260, 740 }, { 360, 900 }, { 300, 1080 }, { 440, 1270 } },
			halfWidth = 20,
			bedY = 10,
			waterLevel = 20, -- multiple of the voxel size, so the surface meets a voxel boundary
		},
		{
			id = "fork", -- leaves the main River at its route point 360, 900
			points = { { 360, 900 }, { 470, 960 }, { 560, 1070 }, { 690, 1190 } },
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
