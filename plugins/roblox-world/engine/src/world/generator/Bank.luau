--!nonstrict
-- The cross-section of water, from its edge down to its deepest line. Rivers and Lakes share it.
-- A River or Lake with `banks` gets this shape, and one without keeps the shape it always had,
-- so an older world regenerates the same. What varies comes from the seed and the world position.

local Noise = require("./Noise")
local Geo = require("./Geo")

local Bank = {}
local smoothstep = Geo.smoothstep

local DEFAULT_SHORE = 20
local DEFAULT_SHALLOW_DEPTH = 3
local DEFAULT_BED_FLAT = 0.3
local VARY_SCALE = 80 -- studs for one change of the banks, short enough that two sides of a River differ
local ROUGH_SCALE = 18 -- studs for one small slope in a wall
local DEPTH_SCALE = 160 -- studs for one pool or shallow

-- Perlin noise rarely passes 0.5, so this spreads it over the whole range.
local function wave(u: number, v: number, seed: number): number
	return math.clamp(Noise.fbm(u, v, seed, 2) * 2, -1, 1)
end

-- How much `banks` change at this spot, as a multiple of what the plan declares.
local function varied(banks, seed: number, x: number, z: number): number
	return 1 + (banks.vary or 0) * wave(x / VARY_SCALE, z / VARY_SCALE, seed + 4)
end

function Bank.shore(banks): number
	return banks.shore or DEFAULT_SHORE
end

-- The widest the shore can get, which a Valley must leave room for.
function Bank.widestShore(banks): number
	return Bank.shore(banks) * (1 + (banks.vary or 0))
end

-- Studs of shore at this spot, between the water's edge and the ground around it.
function Bank.shoreAt(banks, seed: number, x: number, z: number): number
	return math.max(1, Bank.shore(banks) * varied(banks, seed, x, z))
end

-- Studs under the water at this spot. `inside` is how far in from the edge, above 0, `reach` the
-- distance from the edge to the deepest line, and `deepest` the depth there.
function Bank.depth(banks, seed: number, x: number, z: number, inside: number, reach: number, deepest: number): number
	local v = varied(banks, seed, x, z)
	local shallows = math.min((banks.shallows or 0) * v, reach * 0.5)
	local shallowDepth = if shallows > 0 then math.min(banks.shallowDepth or DEFAULT_SHALLOW_DEPTH, deepest) else 0
	if inside < shallows then
		return math.max(0.5, shallowDepth * inside / shallows)
	end
	local wall = math.max(reach * (1 - (banks.bedFlat or DEFAULT_BED_FLAT)) - shallows, 4)
	local f = math.clamp((inside - shallows) / wall, 0, 1)
	local fall = 1 - (1 - smoothstep(0, 1, f)) ^ ((banks.steep or 1) * v)
	local depth = shallowDepth + (deepest - shallowDepth) * fall
	if banks.rough then
		depth += banks.rough * wave(x / ROUGH_SCALE, z / ROUGH_SCALE, seed + 5) * 4 * f * (1 - f)
	end
	return math.max(0.5, depth)
end

-- A depth moved by `vary`, a fraction of itself, into pools and shallows. `u` and `v` are positions
-- in units of DEPTH_SCALE's noise: along the line for a River, across the water for a Lake.
function Bank.pools(depth: number, vary: number?, seed: number, u: number, v: number): number
	if not vary then
		return depth
	end
	return depth * (1 + vary * wave(u / DEPTH_SCALE, v / DEPTH_SCALE, seed + 3))
end

return Bank
