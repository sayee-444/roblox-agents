--!nonstrict
-- The cross-section of water, from the ground around it down to its deepest line. Rivers and Lakes
-- share it. The ground comes down to the water at a slope, keeps that slope across the waterline and
-- curves into the deepest line, so the slope decides how deep the water gets, up to a ceiling.
-- A River or Lake with `banks` gets this shape, and one without keeps the shape it always had,
-- so an older world regenerates the same. What varies comes from the seed and the world position.

local Noise = require("./Noise")

local Bank = {}

local DEFAULT_SHORE = 20
local DEFAULT_SMOOTH = 24
-- Studs of water over the deepest line, however gentle the slope: two voxels, past the depth where a bed
-- turns to sand (materials.bedSand), since shallower water barely shows and reads as a wide sand flat.
local MIN_DEPTH = 8
local VARY_SCALE = 80 -- studs for one change of the banks, short enough that two sides of a River differ
local ROUGH_SCALE = 18 -- studs for one small slope under the water
local DEPTH_SCALE = 160 -- studs for one pool or shallow

-- Perlin noise rarely passes 0.5, so this spreads it over the whole range.
local function wave(u: number, v: number, seed: number): number
	return math.clamp(Noise.fbm(u, v, seed, 2) * 2, -1, 1)
end

-- How much `banks` change at this spot, as a multiple of what the plan declares.
function Bank.varied(banks, seed: number, x: number, z: number): number
	return 1 + (banks.vary or 0) * wave(x / VARY_SCALE, z / VARY_SCALE, seed + 4)
end

function Bank.shore(banks): number
	return banks.shore or DEFAULT_SHORE
end

-- Studs of reach for filling thin crests between stretches of water. 0 turns it off.
function Bank.smooth(banks): number
	return banks.smooth or DEFAULT_SMOOTH
end

-- The widest the shore can get, which a Valley must leave room for.
function Bank.widestShore(banks): number
	return Bank.shore(banks) * (1 + (banks.vary or 0))
end

-- Studs of Shore at a spot whose banks vary by `varied`.
function Bank.shoreAt(banks, varied: number): number
	return math.max(1, Bank.shore(banks) * varied)
end

-- Studs the ground would fall across `span` at `slope`, never so few that the water has no depth.
local function fall(slope: number, span: number): number
	return math.max(2 * MIN_DEPTH, slope * span)
end

-- How deep the deepest line gets, and the power of the curve that falls to it. The ground meets the
-- water at `slope`, rise over run, and the deepest line lies `span` studs in, so a gentle slope reaches
-- only so deep. `moved` moves that depth by the pools and rough bed the World Plan asks for, as a
-- multiple of it, and `ceiling`, the depth the World Plan asks for, is the most it may reach, even when
-- it asks for less than MIN_DEPTH.
function Bank.deepest(slope: number, span: number, ceiling: number, moved: number): (number, number)
	local drop = fall(slope, span)
	-- Never past `drop` either, or the curve would come to a point at the deepest line.
	local deepest = math.max(math.min(MIN_DEPTH, ceiling), math.min(ceiling, drop / 2 * moved, drop))
	return deepest, drop / deepest
end

-- The power of a curve that falls to a deepest line `deepest` studs down and leaves the water's edge at
-- `slope` across `span`. Never below 1, or the curve would come to a point at the deepest line, so an
-- edge gentler than that depth needs comes down a little steeper.
function Bank.power(slope: number, span: number, deepest: number): number
	return math.max(fall(slope, span), deepest) / deepest
end

-- The slope at the water's edge of a half of the water whose deepest line lies `reach` studs in, where
-- the water as a whole meets its ground at `slope` across `span`. Equal to the curve's own slope there,
-- also when `deepest`, a depth set apart from `slope`, steepens the curve as Bank.power does.
function Bank.edgeSlope(slope: number, span: number, reach: number, deepest: number?): number
	return math.max(fall(slope, span), deepest or 0) / reach
end

-- Studs under the water `inside` studs in from its edge, on a half that reaches its deepest line, `deepest`
-- studs down, `reach` studs in. The curve keeps the slope of the ground at the edge and flattens into the
-- deepest line, and `rough` adds small slopes that leave both ends alone and never pass the deepest.
function Bank.depth(banks, seed: number, x: number, z: number, inside: number, reach: number, deepest: number, power: number): number
	local f = math.clamp(inside / reach, 0, 1)
	local depth = deepest * (1 - (1 - f) ^ power)
	if banks.rough then
		local rough = math.min(banks.rough, deepest * 0.5)
		depth += rough * wave(x / ROUGH_SCALE, z / ROUGH_SCALE, seed + 5) * 16 * f * f * (1 - f) * (1 - f)
	end
	return math.min(depth, deepest)
end

-- Studs above the water `out` studs from its edge, where the ground leaves the water at `edgeSlope` and
-- levels out `height` studs up, at the ground around.
function Bank.rise(out: number, edgeSlope: number, height: number): number
	return height * (1 - math.exp(-edgeSlope * out / height))
end

local function poolWave(seed: number, u: number, v: number): number
	return wave(u / DEPTH_SCALE, v / DEPTH_SCALE, seed + 3)
end

-- A depth moved by `vary`, a fraction of itself, into pools and shallows. `u` and `v` are positions
-- in units of DEPTH_SCALE's noise: along the line for a River, across the water for a Lake.
function Bank.pools(depth: number, vary: number?, seed: number, u: number, v: number): number
	if not vary then
		return depth
	end
	return depth * (1 + vary * poolWave(seed, u, v))
end

-- The same pools and shallows reaching down to `depth` at most, so it stays the deepest: it is a ceiling,
-- and a ceiling that pools lower in their shallows lets them show on ground steep enough to reach it.
function Bank.poolsUpTo(depth: number, vary: number?, seed: number, u: number, v: number): number
	if not vary then
		return depth
	end
	return depth * (1 - vary * (1 - poolWave(seed, u, v)) / 2)
end

return Bank
