-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so this extent spans -768 to 768 on x and z. Choose every <...> for this world, stay within
-- 740 of the centre, keep Landforms apart, and delete what was not asked for. The seeds are
-- already chosen for this world.

return {
	worldSeed = {{worldSeed}},
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -1, maxX = 1, minZ = -1, maxZ = 1 }, -- inclusive Chunk indices
	floorY = -64, -- ground is at least 64 studs thick everywhere

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	-- Landform Regions. Each has its own Region Seed and a bounded blend margin.
	regions = {
		{
			id = "range",
			kind = "mountain",
			seed = {{regionSeed}},
			points = { { <x>, <z> }, { <x>, <z> }, { <x>, <z> }, { <x>, <z> } }, -- the crest, 4 to 6 points
			halfWidth = 170, -- blend margin included: nothing of it reaches beyond this distance
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			id = "mesa",
			kind = "mesa",
			seed = {{regionSeed}},
			center = { <x>, <z> },
			radius = 60, -- flat top
			margin = 150, -- flank, from the top radius out to the foot
			levels = 5,
			height = 100,
			warp = 40, -- largest shift of the outline, in studs
			elongate = 1.3, -- length over width of the footprint
			angle = <degrees>, -- direction of its long axis
			gully = 8, -- how far gullies bite into the flank, in studs
		},
		{
			id = "valley",
			kind = "valley",
			seed = {{regionSeed}},
			riverId = "river",
			halfWidth = 130, -- at least 1.3 times the River's halfWidth plus 20
			floorY = 24, -- above the water level
		},
		-- For a forked River, a valley for the branch:
		-- { id = "forkValley", kind = "valley", seed = {{regionSeed}}, riverId = "fork", halfWidth = 90, floorY = 24 },
		-- For a cave, a path of { x, y, z } points, one radius above the ground that `height` reports:
		-- { id = "cave", kind = "cave", seed = {{regionSeed}}, points = { { <x>, <y>, <z> }, { <x>, <y>, <z> }, { <x>, <y>, <z> } }, radius = 14 },
	},

	-- A River follows its route points; the still water sits at a constant level.
	rivers = {
		{
			id = "river",
			points = { { <x>, <z> }, { <x>, <z> }, { <x>, <z> }, { <x>, <z> } }, -- edge to edge, 4 to 6 points
			halfWidth = 20,
			bedY = 10,
			waterLevel = 20, -- multiple of the voxel size, so the surface meets a voxel boundary
		},
		-- A fork is a second River whose first point is one of this River's route points:
		-- { id = "fork", points = { { <that x>, <that z> }, { <x>, <z> }, { <x>, <z> } }, halfWidth = 14, bedY = 10, waterLevel = 20 },
	},
	lakes = {},
	-- For a lake, with any River ending in it holding the same waterLevel:
	-- lakes = { { id = "lake", seed = {{regionSeed}}, center = { <x>, <z> }, radius = 170, shore = 60, warp = 20, elongate = 1.2, angle = <degrees>, bedY = 6, waterLevel = 20 } },
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
