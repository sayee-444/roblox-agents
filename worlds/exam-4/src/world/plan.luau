-- World Plan: declares what exists where. It wins over the seeds. Composed by new from the World Seed.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256).

return {
	worldSeed = 831117573,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -2, maxX = 1, minZ = -1, maxZ = 1 }, -- inclusive Chunk indices
	floorY = -64, -- ground is at least 64 studs thick everywhere

	-- Gentle hills everywhere: mean height, amplitude, feature size and domain warp.
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },

	regions = {
		{ id = "range", kind = "mountain", seed = 92682, points = { { -737, -531 }, { -370, -541 }, { -3, -526 }, { 364, -533 }, { 731, -531 } }, halfWidth = 175, height = 194, ridgeScale = 172, crestScale = 237 },
		{ id = "mesa", kind = "mesa", seed = 10601, center = { -400, 270 }, radius = 49, margin = 168, levels = 4, height = 110, warp = 33, elongate = 1.11, angle = 67, gully = 7 },
		{ id = "valley", kind = "valley", seed = 18520, riverId = "river", halfWidth = 130, floorY = 24 },
		{ id = "forkValley", kind = "valley", seed = 26439, riverId = "fork", halfWidth = 90, floorY = 24 },
	},

	rivers = {
		{ id = "river", points = { { 740, 102 }, { 369, 59 }, { 7, -49 }, { -365, -84 }, { -740, -96 }, { -860, -125 }, { -990, -170 } }, halfWidth = 24, bedY = 10, waterLevel = 20 },
		{ id = "fork", points = { { 7, -49 }, { -241, -135 }, { -474, -266 }, { -740, -301 }, { -860, -280 }, { -990, -210 } }, halfWidth = 14, bedY = 10, waterLevel = 20 },
	},
	lakes = {
		{ id = "lake", seed = 34358, center = { -1000, -190 }, radius = 150, shore = 55, warp = 20, elongate = 1.15, angle = 20, bedY = 6, waterLevel = 20 },
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
