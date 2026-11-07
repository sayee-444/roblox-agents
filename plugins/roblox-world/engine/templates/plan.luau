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
	floorY = 0, -- ground stops here, and goes lower only under deep water or a cave

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
			halfWidth = 130, -- at least 1.3 times the River's widest half width plus 20
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
			curve = 1, -- 0 follows straight legs between the points, 1 a smooth curve through them
			meander = 40, -- largest swing away from that line, in studs. It fades to nothing at each point
			halfWidth = 20, -- or widths = { 14, 20, 32, 40 }, half widths, one per point, changing gradually between them
			bendWiden = 0.5, -- widens by this fraction at a 90 degree bend, and in proportion at gentler ones. 0 turns it off
			-- For a bend close to a circle, on the leg between points 2 and 3. A turn of 180 is a semicircle, 290 leaves a neck, 360 closes with an island:
			-- loops = { { leg = 2, radius = 110, turn = 290, side = "right" } },
			bedY = 10, -- or depths = { 8, 14, 30, 12 }, below the water, one per point, changing gradually between them
			bedRough = 3, -- largest rise or fall of the bed, in studs. Keep it below the shallowest depth
			waterLevel = 20, -- multiple of the voxel size, so the surface meets a voxel boundary
		},
		-- A fork is a second River whose first point is one of this River's route points:
		-- { id = "fork", points = { { <that x>, <that z> }, { <x>, <z> }, { <x>, <z> } }, curve = 1, meander = 30, bendWiden = 0.5, halfWidth = 14, bedY = 10, bedRough = 3, waterLevel = 20 },
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
		bedSand = 6, -- a bed is sand under water this shallow, and earth comes through it below
		bedDeep = 14, -- from this depth down, a bed is earth with gravel and a little sand
		mesaRiser = 1.1,
	},
}
