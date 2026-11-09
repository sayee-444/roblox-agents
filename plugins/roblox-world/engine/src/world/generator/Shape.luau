--!nonstrict
-- The pure terrain function: height(x, z) from the World Plan and seeds, plus the cave's
-- signed distance. Chunk borders agree because every Chunk evaluates the same function.

local Noise = require("./Noise")
local Geo = require("./Geo")
local Route = require("./Route")
local Bank = require("./Bank")

local Shape = {}
local smoothstep = Geo.smoothstep

local WIDTH_NOISE = 0.15 -- how far a bank wanders from a River's width, as a fraction of it
local BANK_WIDTH = 20 -- the half width whose bank the sand band of Materials is measured for
local ROCK_UNDER = 16 -- studs of rock kept under any ground that goes below the plan's floor
local BOWL_FROM = 10 -- depth below the water where a River's bed stops being flat and becomes a bowl
local BED_SCALE = 45 -- studs for one swell of a rough bed
local FLOOR_BUMP = 2 -- studs a valley's floor rises and falls in bumps
local DEFAULT_SIDES = 0.3 -- medium Valley Sides, rise over run at the water's edge
local PASS_FADE = 40 -- studs over which another pass of a River fades out at the edge of its reach
local PASS_SPREAD = 0.5 -- further studs of that fade per stud from the nearest pass, so away from the water it is gentle
local RING = 32 -- spots on the ground around a Lake where its slope is measured
local GENTLEST = 0.02 -- the gentlest ground that comes down to a Lake, rise over run
-- How deep a Lake with no `bedY` may get, from its size. lab's Lake, of radius 425, reached 110 studs, about
-- a quarter of its radius, and the developer chose that as the measure, growing as the natural log past it,
-- up to twice that Lake's depth.
local DEPTH_SHARE = 0.25 -- of the radius, up to DEPTH_BEND
local DEPTH_BEND = 425 -- radius past which the depth grows as its natural log, with no break in its growth
local DEPTH_CAP = 220 -- studs, the most it may reach unless the World Plan gives `depthCap`
local DEPTH_VARY = 0.4 -- its pools and shallows unless the World Plan gives `depthVary`, as lab's Lake
local BAR_GAIN = 2 -- how far a bend moves the deepest line out, as a fraction of the half width, per unit of half width over radius
local BAR_MOST = 0.45 -- the furthest a bend moves the deepest line out, as a fraction of the half width
local BAR_SAND = 2 -- studs of sand a Point Bar adds beside the water, per stud the deepest line moved
-- The lowest height any bed or cave floor may take unless the World Plan gives `depthLimit`: the developer's
-- standard, 500 studs above the Destroy Height of -4,000 they chose for their places.
local DEPTH_LIMIT = -3500
-- An Ocean's depth takes the Lake's shape from the distance to the coast, with its own numbers, which the developer
-- chose on 2026-11-08 so that a very wide Ocean reaches 800 to 1,200 and a medium one about 400: a quarter of the
-- distance up to OCEAN_BEND, about 400 at 3 Chunks out, then the natural log, meeting OCEAN_CAP about 13 Chunks out.
local OCEAN_SLOPE = 0.25 -- rise over run of the bed from the coast, unless the World Plan gives `slope`
local OCEAN_BEND = 2400 -- studs from the coast past which it grows as the natural log, unless the World Plan gives `bend`
local OCEAN_CAP = 1200 -- studs, the most it may reach unless the World Plan gives `depthCap`
local CAVE_SWELL = 0.15 -- how far a cave's radius swells along it, as a fraction of the radius
-- A Trench's defaults, for the fields its World Plan leaves out. Not yet judged by the developer in Studio.
local TRENCH_HALF_WIDTH = 800 -- studs from its route to the top of its walls
local TRENCH_WALLS = 1.5 -- rise over run of its walls, about 56 degrees
local TRENCH_ROUGH = 40 -- studs its Region Seed narrows its walls and raises its floor, at most
local WALL_SCALE = 160 -- studs for one swell of a Trench's walls
local FLOOR_SCALE = 90 -- studs for one swell of a Trench's floor

local prepared = setmetatable({}, { __mode = "k" })

local function prepare(plan)
	local P = prepared[plan]
	if P then
		return P
	end
	P = { mountains = {}, mesas = {}, valleys = {}, caves = {}, trenches = {}, rivers = {}, lakes = plan.lakes or {}, lakeSlopes = {}, oceans = plan.oceans or {}, oceanChunks = {}, coastsNear = {}, trenchesIn = {} }
	-- Which Ocean holds each Chunk, and the Chunks of land the coast runs along: those of the extent beside an Ocean
	-- Chunk, diagonals included. The nearest land to any spot of an Ocean lies on one of them.
	local e = plan.extent
	for _, def in ipairs(P.oceans) do
		for _, r in ipairs(def.chunks) do
			for i = math.max(r[1], e.minX), math.min(r[3], e.maxX) do
				for j = math.max(r[2], e.minZ), math.min(r[4], e.maxZ) do
					P.oceanChunks[i .. "," .. j] = P.oceanChunks[i .. "," .. j] or def
				end
			end
		end
	end
	P.coastChunks = {}
	if #P.oceans > 0 then
		local s = plan.chunkSize
		for i = e.minX, e.maxX do
			for j = e.minZ, e.maxZ do
				local beside = false
				for di = -1, 1 do
					for dj = -1, 1 do
						beside = beside or P.oceanChunks[(i + di) .. "," .. (j + dj)] ~= nil
					end
				end
				if beside and not P.oceanChunks[i .. "," .. j] then
					table.insert(P.coastChunks, { i * s - s / 2, j * s - s / 2, i * s + s / 2, j * s + s / 2 })
				end
			end
		end
	end
	for _, rv in ipairs(plan.rivers) do
		local route = Route.points(rv)
		P.rivers[rv.id] = { def = rv, route = route, poly = Geo.polyline2(route), width = Route.width(rv), depth = Route.depth(rv), bend = if rv.banks then Route.bend(rv) else nil }
	end
	for _, r in ipairs(plan.regions) do
		if r.kind == "mountain" then
			table.insert(P.mountains, { def = r, poly = Geo.polyline2(r.points) })
		elseif r.kind == "mesa" then
			-- Rock beds of uneven thickness, as fractions of the mesa's height.
			local rng = Noise.newRng(r.seed)
			local beds, total = {}, 0
			for k = 1, r.levels do
				beds[k] = 0.7 + 0.6 * rng:next()
				total += beds[k]
			end
			local edges, sum = { 0 }, 0
			for k = 1, r.levels do
				sum += beds[k] / total
				edges[k + 1] = sum
			end
			edges[r.levels + 1] = 1
			table.insert(P.mesas, { def = r, edges = edges })
		elseif r.kind == "valley" then
			-- Past carveReach the River digs nothing, and past effectReach it has no effect at all, so the
			-- costly part of the height runs only nearer than these. Both are ceilings, never estimates:
			-- the widest the River can get with its noise, and the widest its shore can get.
			local river = P.rivers[r.riverId]
			local banks = river.def.banks
			local edge = river.width.ceiling * (1 + WIDTH_NOISE)
			local carveReach = if banks then edge + math.max(1, Bank.widestShore(banks)) else edge
			local sides = r.sides or DEFAULT_SIDES
			table.insert(P.valleys, {
				def = r,
				river = river,
				carveReach = carveReach,
				carveLimit = math.min(r.halfWidth, carveReach),
				effectReach = if banks then carveReach + Bank.smooth(banks) else edge * 1.5,
				-- Another pass of the River counts within this, past its water and its Shore.
				passReach = if banks then river.width.widest * (1 + WIDTH_NOISE) + Bank.widestShore(banks) + PASS_FADE else nil,
				sides = if type(sides) == "table" then Route.along(river.def, sides) else function()
					return sides
				end,
			})
		elseif r.kind == "cave" then
			local rng = Noise.newRng(r.seed)
			local x0, x1, z0, z1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
			local pad = r.radius * 1.4 + 10
			for _, p in ipairs(r.points) do
				x0, x1 = math.min(x0, p[1] - pad), math.max(x1, p[1] + pad)
				y0, y1 = math.min(y0, p[2] - pad), math.max(y1, p[2] + pad)
				z0, z1 = math.min(z0, p[3] - pad), math.max(z1, p[3] + pad)
			end
			table.insert(P.caves, {
				def = r,
				poly = Geo.polyline3(r.points),
				offset = rng:next() * 100,
				box = { x0, x1, y0, y1, z0, z1 },
			})
		elseif r.kind == "trench" then
			local hw = Shape.trenchHalfWidth(r)
			local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
			for _, p in ipairs(r.points) do
				x0, z0, x1, z1 = math.min(x0, p[1] - hw), math.min(z0, p[2] - hw), math.max(x1, p[1] + hw), math.max(z1, p[2] + hw)
			end
			table.insert(P.trenches, {
				def = r,
				poly = Geo.polyline2(r.points),
				halfWidth = hw,
				walls = Shape.trenchWalls(r),
				rough = Shape.trenchRough(r),
				box = { x0, z0, x1, z1 },
			})
		end
	end
	prepared[plan] = P
	return P
end

-- A River's bed at a spot. A spot on a shore never needs it.
local function bedAt(v, s: number, x: number, z: number): number
	local def, rv = v.def, v.river
	local bed = rv.def.waterLevel - Bank.pools(rv.depth.at(s), rv.def.depthVary, def.seed, s, 80)
	if rv.def.bedRough then
		bed += rv.def.bedRough * math.clamp(Noise.perlin(x / BED_SCALE, z / BED_SCALE, def.seed + 2) * 2, -1, 1)
	end
	return bed
end

-- One River's half width at a spot along it, with the noise that makes its banks wander.
local function halfWidthAt(v, s: number): number
	return v.river.width.at(s) * (1 + WIDTH_NOISE * Noise.perlin(s / 120, 0.5, v.def.seed + 1))
end

-- How far a River without banks lowers the valley floor at this spot, then how far out its water can
-- reach. `d` and `s` are the spot's distance to the River's line and along it.
local function bedCarve(v, d: number, s: number, x: number, z: number): (number, number)
	local def, rv = v.def, v.river
	local hw = halfWidthAt(v, s)
	local bed = bedAt(v, s, x, z)
	local c = 1 - smoothstep(hw * 0.4, hw, d)
	-- The banks and the water's edge come from the first BOWL_FROM studs. Anything deeper is a bowl
	-- under them, deepest on the River's line, so a shallow River keeps its shape.
	local shelf = rv.def.waterLevel - BOWL_FROM
	return c * (def.floorY - math.max(bed, shelf)) + (1 - smoothstep(0, hw, d)) * math.max(0, shelf - bed), hw * 1.5
end

-- The ground of one pass of a River with banks at a spot. Its Valley Side falls from `around`, the ground
-- around the spot, through the Shore and across the waterline at one slope, then curves into the deepest
-- line, so how steep the side is decides how deep the water gets. `side` says which side of the line the
-- spot lies on, and `varied` how much the banks change here. A bend moves the deepest line towards its
-- outside, so the outside is a Cut Bank, steeper and deeper, and the inside a Point Bar, gentle and shallow.
-- Returns the height, how far out the water can reach, and the studs of sand a Point Bar adds here.
local function valleySide(v, d: number, s: number, side: number, x: number, z: number, around: number, varied: number): (number, number, number)
	local def, rv = v.def, v.river
	local banks, level = rv.def.banks, rv.def.waterLevel
	local hw = halfWidthAt(v, s)
	local slope = v.sides(s) * varied
	local across = side * d
	-- Where the deepest line lies across the water, on the side the line turns away from.
	local deepLine = -hw * math.clamp(BAR_GAIN * hw * rv.bend.at(s), -BAR_MOST, BAR_MOST)
	local bar = if across * deepLine < 0 then BAR_SAND * math.abs(deepLine) else 0
	local inside, reach
	if across >= deepLine then
		inside, reach = hw - across, hw - deepLine
	else
		inside, reach = hw + across, hw + deepLine
	end
	local waterTo = math.max(hw * 1.5, hw + Bank.shoreAt(banks, varied))
	if inside > 0 then
		local asked = rv.depth.at(s)
		local deepest, power = Bank.deepest(slope, hw, asked, (level - bedAt(v, s, x, z)) / asked)
		return level - Bank.depth(banks, def.seed, x, z, inside, reach, deepest, power), waterTo, bar
	end
	local above = Bank.rise(-inside, Bank.edgeSlope(slope, hw, reach), around - level)
	-- A bump of the valley floor fades out towards the water, or it would leave puddles.
	return level + above + FLOOR_BUMP * Noise.perlin(x / 50, z / 50, def.seed) * smoothstep(0, 8, above), waterTo, bar
end

-- The ground of a River with banks at a spot, the lowest of every pass near it: going by the nearest pass
-- alone, width, depth and steepness would jump halfway between two passes, and that step reads as a cliff.
-- Another pass fades out towards the edge of its reach, rising to the nearest pass's ground, `nearest`,
-- so it joins without a step. Near the water the fade lies past the widest shore, and away from it, it
-- starts at the nearest pass and widens with the distance, where a short one would make a ramp.
local function riverGround(v, d: number, s: number, x: number, z: number, around: number, varied: number, nearest: number): number
	local from = math.max(v.passReach - PASS_FADE, d)
	local reach = math.max(v.passReach, d + PASS_FADE + d * PASS_SPREAD)
	local found = Geo.stretches2(v.river.poly, x, z, reach)
	local low = nearest
	for i = 1, #found, 3 do
		-- The nearest pass is one of these, and its ground is already known.
		if found[i] ~= d or found[i + 1] ~= s then
			local ground = valleySide(v, found[i], found[i + 1], found[i + 2], x, z, around, varied)
			low = math.min(low, ground + math.max(0, nearest - ground) * smoothstep(from, reach, found[i]))
		end
	end
	return low
end

-- The lowest ground of the Rivers with banks at a spot `moved` studs from the column, whose distance to
-- each River is in `v.d`, so the spot lies at least v.d - moved from that River. `around` is the ground
-- around the column, near enough to the ground around a spot this close. math.huge where none reaches.
local function groundAt(P, x: number, z: number, moved: number, around: number): number
	local low = math.huge
	for _, v in ipairs(P.valleys) do
		local banks = v.river.def.banks
		if banks and v.d - moved < v.carveReach then
			local d, s, side = Geo.dist2(v.river.poly, x, z, v.carveLimit)
			if d < v.carveLimit then
				local here = math.max(around, v.def.floorY)
				local varied = Bank.varied(banks, v.def.seed, x, z)
				low = math.min(low, riverGround(v, d, s, x, z, here, varied, (valleySide(v, d, s, side, x, z, here, varied))))
			end
		end
	end
	return low
end

local RIDGE_AXES = { { 1, 0 }, { 0, 1 }, { 0.7071, 0.7071 }, { 0.7071, -0.7071 } }

-- Where water runs close to itself or to another River, each stretch digs towards its own line and a
-- thin crest stands between them. A spot on a crest has lower ground on both opposite sides, and a
-- spot on a plain wall never does, so this fills crests and leaves walls and shores where they are.
-- Only a fill lower than `ground` counts, so an axis that cannot beat it skips its other side.
local function fillRidge(P, x: number, z: number, reach: number, ground: number, around: number): number
	local filled = ground
	for _, axis in ipairs(RIDGE_AXES) do
		local a = groundAt(P, x + axis[1] * reach, z + axis[2] * reach, reach, around)
		if a < filled then
			filled = math.min(filled, math.max(a, groundAt(P, x - axis[1] * reach, z - axis[2] * reach, reach, around)))
		end
	end
	return filled
end

-- The ground at (x, z) before any Lake lowers it, with what Shape.height returns after it.
local function land(P, plan, x: number, z: number): (number, number, number, number)
	local b = plan.base
	local seed = plan.worldSeed

	-- Base hills, with the sample position distorted by other noise (domain warping).
	local wx = x + Noise.fbm(x / b.warpScale, z / b.warpScale, seed + 11, 3) * b.warpAmp
	local wz = z + Noise.fbm(x / b.warpScale + 5.2, z / b.warpScale + 1.3, seed + 12, 3) * b.warpAmp
	local h = b.mean + Noise.fbm(wx / b.scale, wz / b.scale, seed, b.octaves) * b.amp

	-- Mountain ranges: ridged noise times a falloff from the distance to the polyline.
	for _, m in ipairs(P.mountains) do
		local def = m.def
		local d, s = Geo.dist2(m.poly, x, z)
		if d < def.halfWidth then
			local f = 1 - d / def.halfWidth
			f = f * f * (3 - 2 * f)
			local rr = Noise.ridged(x / def.ridgeScale, z / def.ridgeScale, def.seed, 5)
			local crest = 0.75 + 0.25 * Noise.perlin(s / def.crestScale, 0.5, def.seed + 5)
			h += f * def.height * (0.3 + 0.7 * rr) * crest
		end
	end

	-- Mesas: a flat-topped hill with an irregular outline and gullies, cut by horizontal rock
	-- beds whose ledges fade in and out. Reach is bounded by radius + margin + warp.
	local mesaP = 0
	for _, m in ipairs(P.mesas) do
		local def = m.def
		local dx, dz = x - def.center[1], z - def.center[2]
		local outer = def.radius + def.margin
		local stretch = def.elongate or 1
		if math.sqrt(dx * dx + dz * dz) < (outer + def.warp) * stretch then
			-- Measure distance in a frame squeezed along the long axis, so the footprint is an oval.
			local angle = math.rad(def.angle or 0)
			local along = dx * math.cos(angle) + dz * math.sin(angle)
			local across = dz * math.cos(angle) - dx * math.sin(angle)
			local d = math.sqrt((along / stretch) ^ 2 + (across * stretch) ^ 2)
			local outline = math.clamp(Noise.fbm(x / 240, z / 240, def.seed, 2) * 2, -1, 1) * def.warp
			local gully = Noise.ridged(x / 90, z / 90, def.seed + 9, 2) ^ 2 * (def.gully or 0)
			d += outline + gully
			local p = math.clamp((outer - d) / def.margin, 0, 1)
			local e = smoothstep(0, 0.85, p)
			local edges = m.edges
			local k = 1
			while k < def.levels and e >= edges[k + 1] do
				k += 1
			end
			local lo, hi = edges[k], edges[k + 1]
			local stepped = lo + (hi - lo) * smoothstep(0.2, 1, (e - lo) / (hi - lo))
			local ledge = math.clamp(0.6 + 1.2 * Noise.perlin(x / 85, z / 85, def.seed + 7), 0.2, 1)
			local rough = 2 * Noise.fbm(x / 40, z / 40, def.seed + 3, 2) * smoothstep(0, 0.15, p)
			h += def.height * (e + (stepped - e) * ledge) + rough
			mesaP = math.max(mesaP, p)
		end
	end

	-- Valleys. One whose River has no banks flattens toward its floor first, and only then are the
	-- River beds carved, so that a branch's valley cannot fill the bed of the River it leaves.
	local riverD, waterLevel = math.huge, 0
	for _, v in ipairs(P.valleys) do
		local def, rv = v.def, v.river
		local d, s, side = Geo.dist2(rv.poly, x, z)
		v.d, v.s, v.side = d, s, side
		if d >= def.halfWidth then
			riverD = math.min(riverD, d)
		elseif not rv.def.banks then
			local width = rv.width.at(s)
			-- Past BANK_WIDTH the sand band moves out with the bank, or it would end under the water.
			riverD = math.min(riverD, math.max(0, d - math.max(0, width - BANK_WIDTH)))
			local w = 1 - smoothstep(width + 20, def.halfWidth, d)
			h += (def.floorY + FLOOR_BUMP * Noise.perlin(x / 50, z / 50, def.seed) - h) * w
		end
	end
	-- A valley whose River has banks is its Valley Sides, which fall from the ground around towards the
	-- River and on under its water, and meet the ground around at the valley's edge. Where such valleys
	-- overlap, the lowest ground counts. A valley floor still lifts any ground below it.
	local around, sided = h, math.huge
	for _, v in ipairs(P.valleys) do
		local def, rv = v.def, v.river
		local banks = rv.def.banks
		if banks and v.d < def.halfWidth then
			local d, s = v.d, v.s
			local width = rv.width.at(s)
			v.varied = Bank.varied(banks, def.seed, x, z)
			v.around = math.max(around, def.floorY)
			local bar
			local nearest
			nearest, v.waterTo, bar = valleySide(v, d, s, v.side, x, z, v.around, v.varied)
			v.ground = riverGround(v, d, s, x, z, v.around, v.varied, nearest)
			-- On a shore, sand covers about half of it, so that grass comes down towards the water, and a
			-- Point Bar is sand.
			riverD = math.min(riverD, math.max(0, d - math.max(0, width - BANK_WIDTH) - Bank.shoreAt(banks, v.varied) * 0.5 - bar))
			-- From the widest the River gets, since a width taken here would change between two passes.
			local flatTo = rv.width.widest * (1 + WIDTH_NOISE) + math.max(20, Bank.widestShore(banks))
			sided = math.min(sided, around + (v.ground - around) * (1 - smoothstep(flatTo, def.halfWidth, d)))
		end
	end
	if sided < math.huge then
		h = sided
	end
	-- Where beds overlap, the deepest one counts, so that they meet without digging a pit.
	local carve, low, smooth, smoothLevel = 0, math.huge, 0, 0
	for _, v in ipairs(P.valleys) do
		local def, rv = v.def, v.river
		local d, s = v.d, v.s
		if d < def.halfWidth and d < v.effectReach then
			local banks = rv.def.banks
			if banks then
				local ground = v.ground
				low = math.min(low, ground)
				if ground < rv.def.waterLevel and d < v.waterTo then
					waterLevel = rv.def.waterLevel
				end
				if d < v.waterTo + Bank.smooth(banks) and Bank.smooth(banks) > smooth then
					smooth, smoothLevel = Bank.smooth(banks), rv.def.waterLevel
				end
			else
				local depth, waterTo = bedCarve(v, d, s, x, z)
				carve = math.max(carve, depth)
				if h - depth < rv.def.waterLevel and d < waterTo then
					waterLevel = rv.def.waterLevel
				end
			end
		end
	end
	if smooth > 0 then
		local filled = fillRidge(P, x, z, smooth, low, around)
		if filled < low then
			low = filled
			if low < smoothLevel then
				waterLevel = smoothLevel
			end
		end
	end
	return math.min(h - carve, low), mesaP, riverD, waterLevel
end

-- How much a Lake's `banks` vary on its shore in the direction (dx, dz) from its centre. Taken at the shore
-- rather than at the spot itself, it changes along the shore and stays the same towards the middle.
local function shoreVaried(def, dx: number, dz: number): number
	local far = math.sqrt(dx * dx + dz * dz)
	if far < 1 then
		return 1
	end
	return Bank.varied(def.banks, def.seed, def.center[1] + dx / far * def.radius, def.center[2] + dz / far * def.radius)
end

-- How steeply the ground comes down to a Lake: from the mean ground on a ring at the outer edge of its
-- shore, before the Lake lowers it, down to its water, across the shore.
local function lakeSlope(P, plan, def): number
	local outer = def.radius + def.shore
	local stretch = def.elongate or 1
	local angle = math.rad(def.angle or 0)
	local total = 0
	for k = 1, RING do
		local a = 2 * math.pi * k / RING
		local along, across = outer * stretch * math.cos(a), outer / stretch * math.sin(a)
		total += (land(P, plan, def.center[1] + along * math.cos(angle) - across * math.sin(angle), def.center[2] + along * math.sin(angle) + across * math.cos(angle)))
	end
	return math.max(GENTLEST, (total / RING - def.waterLevel) / def.shore)
end

-- How deep under its water a Lake may get: from `bedY`, or else from its radius, up to its `depthCap`.
-- Then whether the depth came from its size, and whether its cap cut it.
function Shape.lakeDepth(def): (number, boolean, boolean)
	if def.bedY ~= nil then
		return def.waterLevel - def.bedY, false, false
	end
	local r = def.radius
	local depth = if r <= DEPTH_BEND then r * DEPTH_SHARE else DEPTH_BEND * DEPTH_SHARE * (1 + math.log(r / DEPTH_BEND))
	local cap = if def.depthCap == nil then DEPTH_CAP else def.depthCap
	if cap and depth > cap then
		return cap, true, true
	end
	return depth, true, false
end

-- How far a Lake's pools and shallows move its depth, as a fraction of it, or nil for none.
function Shape.lakeVary(def): number?
	local _, fromSize = Shape.lakeDepth(def)
	return if def.depthVary == nil and fromSize then DEPTH_VARY else def.depthVary
end

-- The lowest height any bed or cave floor of this world may take.
function Shape.depthLimit(plan): number
	return plan.depthLimit or DEPTH_LIMIT
end

-- The lowest surface one declared thing may reach: its id, its kind ("ocean", "lake", "river", "cave" or "trench") and the height.
export type Surface = { id: string, kind: string, y: number }

-- The lowest surface each declared thing may reach, from the plan alone: every asked depth taken as a ceiling,
-- as the slope decides how much of it is reached, deepened by the most its pools and roughness can add. A Lake's
-- depth from its size stays its deepest, since its pools only make shallows there (ADR 0011). The rock kept
-- under a bed is left out, since nothing stands on it. Only for a plan that passes validation otherwise.
function Shape.lowestSurfaces(plan): { Surface }
	local out = {}
	for _, oc in ipairs(plan.oceans or {}) do
		table.insert(out, { id = oc.id, kind = "ocean", y = plan.seaLevel - Shape.oceanCeiling(plan, oc) })
	end
	for _, lk in ipairs(plan.lakes or {}) do
		local asked, fromSize = Shape.lakeDepth(lk)
		local vary = if fromSize then 0 else Shape.lakeVary(lk) or 0
		table.insert(out, { id = lk.id, kind = "lake", y = lk.waterLevel - asked * (1 + vary) - (lk.bedRough or 0) })
	end
	for _, rv in ipairs(plan.rivers or {}) do
		local depth = Route.depth(rv).deepest * (1 + (rv.depthVary or 0)) + (rv.bedRough or 0)
		table.insert(out, { id = rv.id, kind = "river", y = rv.waterLevel - depth })
	end
	for _, r in ipairs(plan.regions or {}) do
		if r.kind == "cave" then
			local low = math.huge
			for _, p in ipairs(r.points) do
				low = math.min(low, p[2])
			end
			table.insert(out, { id = r.id, kind = "cave", y = low - r.radius * (1 + CAVE_SWELL) })
		elseif r.kind == "trench" then
			-- Its floor eases in a straight line between its points, and its Region Seed only raises it.
			table.insert(out, { id = r.id, kind = "trench", y = math.min(table.unpack(r.floors)) })
		end
	end
	return out
end

-- The Ocean holding (x, z), or nil. An Ocean holds whole Chunks, each rectangle { i0, j0, i1, j1 } of
-- Chunk indices, inclusive.
function Shape.oceanAt(plan, x: number, z: number)
	local P = prepare(plan)
	if #P.oceans == 0 then
		return nil
	end
	local s = plan.chunkSize
	return P.oceanChunks[math.floor((x + s / 2) / s) .. "," .. math.floor((z + s / 2) / s)]
end

-- The most an Ocean may reach under the sea level, or nil when its World Plan removes the cap with `depthCap = false`.
function Shape.oceanCap(def): number?
	if def.depthCap == false then
		return nil
	end
	return def.depthCap or OCEAN_CAP
end

-- How deep an Ocean gets `d` studs from its coast, then whether its cap cut that.
function Shape.oceanDepth(def, d: number): (number, boolean)
	local slope, bend = def.slope or OCEAN_SLOPE, def.bend or OCEAN_BEND
	local depth = if d <= bend then d * slope else bend * slope * (1 + math.log(d / bend))
	local cap = Shape.oceanCap(def)
	if cap and depth >= cap then
		return cap, true
	end
	return depth, false
end

-- How far from its coast an Ocean meets its cap, or math.huge with none.
function Shape.oceanReach(def): number
	local cap = Shape.oceanCap(def)
	if not cap then
		return math.huge
	end
	local slope, bend = def.slope or OCEAN_SLOPE, def.bend or OCEAN_BEND
	return if cap <= bend * slope then cap / slope else bend * math.exp(cap / (bend * slope) - 1)
end

-- Studs from a box { x0, z0, x1, z1 } to the spot (x, z), 0 inside it.
local function boxDistance(b, x: number, z: number): number
	local dx = math.max(b[1] - x, 0, x - b[3])
	local dz = math.max(b[2] - z, 0, z - b[4])
	return math.sqrt(dx * dx + dz * dz)
end

-- Studs between two boxes.
local function boxesApart(a, b): number
	local dx = math.max(a[1] - b[3], 0, b[1] - a[3])
	local dz = math.max(a[2] - b[4], 0, b[2] - a[4])
	return math.sqrt(dx * dx + dz * dz)
end

-- The Chunks of land along the coast within reach of the Ocean in Chunk (ci, cj), with the nearest one's distance to the Chunk.
local function coastsNear(P, plan, ci: number, cj: number)
	local key = ci .. "," .. cj
	local near = P.coastsNear[key]
	if near then
		return near
	end
	local s = plan.chunkSize
	local box = { ci * s - s / 2, cj * s - s / 2, ci * s + s / 2, cj * s + s / 2 }
	local reach = Shape.oceanReach(P.oceanChunks[key])
	near = { nearest = math.huge }
	for _, b in ipairs(P.coastChunks) do
		local apart = boxesApart(box, b)
		if apart < reach then
			table.insert(near, b)
		end
		near.nearest = math.min(near.nearest, apart)
	end
	P.coastsNear[key] = near
	return near
end

-- Studs from (x, z), in an Ocean, to its nearest coast: the edge of the nearest Chunk of land in the extent. Past the
-- extent lies no land, so an Ocean reaches on to the edge of the world. math.huge when no coast is within its reach.
function Shape.coastDistance(plan, x: number, z: number): number
	local P = prepare(plan)
	local s = plan.chunkSize
	local best = math.huge
	for _, b in ipairs(coastsNear(P, plan, math.floor((x + s / 2) / s), math.floor((z + s / 2) / s))) do
		best = math.min(best, boxDistance(b, x, z))
	end
	return best
end

-- The most an Ocean may reach from the plan alone: its cap, or with none, its depth at the farthest any of its Chunks'
-- spots may lie from the coast, math.huge when the world holds no land.
function Shape.oceanCeiling(plan, def): number
	local cap = Shape.oceanCap(def)
	if cap then
		return cap
	end
	local P = prepare(plan)
	local s = plan.chunkSize
	local farthest = 0
	for key, of in pairs(P.oceanChunks) do
		if of == def then
			local ci, cj = string.match(key, "^(-?%d+),(-?%d+)$")
			farthest = math.max(farthest, coastsNear(P, plan, tonumber(ci), tonumber(cj)).nearest + s * math.sqrt(2))
		end
	end
	return (Shape.oceanDepth(def, farthest))
end

-- Whether every spot of the Ocean Chunk (ci, cj) lies far enough from the coast to sit at its cap, so that it is a flat bed.
function Shape.oceanOpen(plan, ci: number, cj: number): boolean
	local P = prepare(plan)
	local def = P.oceanChunks[ci .. "," .. cj]
	return def ~= nil and Shape.oceanCap(def) ~= nil and coastsNear(P, plan, ci, cj).nearest >= Shape.oceanReach(def)
end

-- The Ocean's bed at (x, z), in an Ocean, before any Trench lowers it.
function Shape.oceanBed(plan, x: number, z: number): number
	local ocean = Shape.oceanAt(plan, x, z)
	return plan.seaLevel - (Shape.oceanDepth(ocean, Shape.coastDistance(plan, x, z)))
end

-- A Trench's half width, its walls included.
function Shape.trenchHalfWidth(def): number
	return def.halfWidth or TRENCH_HALF_WIDTH
end

-- A Trench's walls, as rise over run.
function Shape.trenchWalls(def): number
	return def.walls or TRENCH_WALLS
end

-- The most a Trench's Region Seed narrows its walls and raises its floor, in studs.
function Shape.trenchRough(def): number
	return def.rough or TRENCH_ROUGH
end

-- A Trench's floor `s` studs along its route, eased in a straight line between the floors of its points.
function Shape.trenchFloor(def, s: number): number
	local segs = Geo.polyline2(def.points).segs
	for k, seg in ipairs(segs) do
		if s <= seg[7] + seg[6] or k == #segs then
			local f = math.clamp((s - seg[7]) / seg[6], 0, 1)
			return def.floors[k] + (def.floors[k + 1] - def.floors[k]) * f
		end
	end
	return def.floors[1]
end

-- The lowest ground the Trenches give at (x, z) over an Ocean's bed `bed`, and the id of the one that gives it, or nil.
-- Within its half width a Trench's walls fall from the bed at its steepness to its floor. Its Region Seed only
-- narrows its walls and raises its floor, each by up to its rough, so nothing beyond its half width changes and
-- no ground lies below its floor.
local function trenchGround(P, x: number, z: number, bed: number): (number, string?)
	local low, by = bed, nil
	for _, tr in ipairs(P.trenches) do
		local b = tr.box
		if x > b[1] and x < b[3] and z > b[2] and z < b[4] then
			local d, s = Geo.dist2(tr.poly, x, z, tr.halfWidth)
			if d < tr.halfWidth then
				local seed = tr.def.seed
				local wobble = 0.5 + 0.5 * math.clamp(Noise.fbm(x / WALL_SCALE, z / WALL_SCALE, seed, 3) * 2, -1, 1)
				local reach = tr.halfWidth - d - tr.rough * wobble
				if reach > 0 then
					local bump = 0.5 + 0.5 * math.clamp(Noise.fbm(x / FLOOR_SCALE, z / FLOOR_SCALE, seed + 3, 2) * 2, -1, 1)
					local ground = math.max(Shape.trenchFloor(tr.def, s) + tr.rough * bump, bed - tr.walls * reach)
					if ground < low then
						low, by = ground, tr.def.id
					end
				end
			end
		end
	end
	return low, by
end

-- Studs from the segment (ax, az) to (bx, bz) to the spot (px, pz).
local function pointToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local ex, ez = bx - ax, bz - az
	local t = math.clamp(((px - ax) * ex + (pz - az) * ez) / (ex * ex + ez * ez), 0, 1)
	local qx, qz = px - ax - t * ex, pz - az - t * ez
	return math.sqrt(qx * qx + qz * qz)
end

-- Whether the segments a-b and c-d cross.
local function crosses(a, b, c, d): boolean
	local function turn(p, q, r)
		return (q[1] - p[1]) * (r[2] - p[2]) - (q[2] - p[2]) * (r[1] - p[1])
	end
	return turn(a, b, c) * turn(a, b, d) < 0 and turn(c, d, a) * turn(c, d, b) < 0
end

-- Studs from a polyline's points to a box { x0, z0, x1, z1 }, 0 where it enters the box. Between two convex shapes
-- apart, the nearest pair has a corner of one, and a line whose ends both lie outside the box crosses one of its diagonals.
local function routeToBox(points, b): number
	local corners = { { b[1], b[2] }, { b[3], b[2] }, { b[3], b[4] }, { b[1], b[4] } }
	local best = math.huge
	for k = 1, #points - 1 do
		local p, q = points[k], points[k + 1]
		best = math.min(best, boxDistance(b, p[1], p[2]), boxDistance(b, q[1], q[2]))
		if crosses(p, q, corners[1], corners[3]) or crosses(p, q, corners[2], corners[4]) then
			return 0
		end
		for _, c in ipairs(corners) do
			best = math.min(best, pointToSegment(c[1], c[2], p[1], p[2], q[1], q[2]))
		end
	end
	return best
end

-- Whether the Trench `def`, of a plan, reaches Chunk (ci, cj): whether any of its half width lies on it.
function Shape.trenchReaches(plan, def, ci: number, cj: number): boolean
	local s = plan.chunkSize
	return routeToBox(def.points, { ci * s - s / 2, cj * s - s / 2, ci * s + s / 2, cj * s + s / 2 }) < Shape.trenchHalfWidth(def)
end

-- Whether any Trench reaches Chunk (ci, cj).
function Shape.trenched(plan, ci: number, cj: number): boolean
	local P = prepare(plan)
	local key = ci .. "," .. cj
	if P.trenchesIn[key] == nil then
		local found = false
		for _, tr in ipairs(P.trenches) do
			found = found or Shape.trenchReaches(plan, tr.def, ci, cj)
		end
		P.trenchesIn[key] = found
	end
	return P.trenchesIn[key]
end

-- Returns ground height at (x, z), then: mesa parameter (0 outside, 1 on the top),
-- distance to the nearest River's sand band centre line, lake or ocean water, the water level over this column (0 = dry),
-- the id of the Water Body, a Lake or an Ocean, whose water covers it, or nil, and the id of the Trench that lowers it, or nil.
function Shape.height(plan, x: number, z: number): (number, number, number, number, string?, string?)
	local P = prepare(plan)
	local ocean = Shape.oceanAt(plan, x, z)
	if ocean then
		local ground, trench = trenchGround(P, x, z, Shape.oceanBed(plan, x, z))
		return ground, 0, 0, plan.seaLevel, ocean.id, trench
	end
	local h, mesaP, riverD, waterLevel = land(P, plan, x, z)
	local body = nil

	-- Lakes come last and only lower the ground, so a River's bed stays open where it enters and
	-- no valley floor can rise inside the water. The radius is about where the water ends.
	for _, def in ipairs(P.lakes) do
		local dx, dz = x - def.center[1], z - def.center[2]
		local outer = def.radius + def.shore
		local stretch = def.elongate or 1
		if math.sqrt(dx * dx + dz * dz) < (outer + def.warp) * stretch then
			local angle = math.rad(def.angle or 0)
			local along = dx * math.cos(angle) + dz * math.sin(angle)
			local across = dz * math.cos(angle) - dx * math.sin(angle)
			local d = math.sqrt((along / stretch) ^ 2 + (across * stretch) ^ 2)
			d += math.clamp(Noise.fbm(x / 240, z / 240, def.seed, 2) * 2, -1, 1) * def.warp
			if d < outer then
				local asked, fromSize = Shape.lakeDepth(def)
				local vary = Shape.lakeVary(def)
				local bed = def.waterLevel - Bank.pools(asked, vary, def.seed, x, z)
				if def.bedRough then
					bed += def.bedRough * math.clamp(Noise.perlin(x / BED_SCALE, z / BED_SCALE, def.seed + 2) * 2, -1, 1)
				end
				local target
				if def.banks then
					-- The ground keeps the slope it comes down with under the water, and the depth asked is the deepest
					-- it may reach. How deep it gets comes from the mean slope, and `vary` changes only the slope along
					-- the shore, fading out towards the middle, so it gives steeper and gentler stretches of shore and no hills.
					local slopes = P.lakeSlopes
					slopes[def] = slopes[def] or lakeSlope(P, plan, def)
					local slope = slopes[def]
					local edge = slope * shoreVaried(def, dx, dz)
					-- On steep ground the whole bed reaches its ceiling and comes out even, so a depth from its size
					-- also lets its pools lower that ceiling. With `bedY` the ceiling stays as it was.
					local ceiling = if fromSize then Bank.poolsUpTo(asked, vary, def.seed, x, z) else asked
					local deepest = Bank.deepest(slope, def.radius, ceiling, (def.waterLevel - bed) / asked)
					local inside = def.radius - d
					if inside > 0 then
						local mean = Bank.power(slope, def.radius, deepest)
						local power = mean + (Bank.power(edge, def.radius, deepest) - mean) * (1 - inside / def.radius) ^ 2
						target = def.waterLevel - Bank.depth(def.banks, def.seed, x, z, inside, def.radius, deepest, power)
					else
						target = def.waterLevel + Bank.rise(-inside, Bank.edgeSlope(edge, def.radius, def.radius, deepest), math.max(1, h - def.waterLevel))
					end
				else
					local beach = def.waterLevel + 3
					local deep = smoothstep(0, 1, math.clamp((def.radius - d) / (def.radius * 0.4), 0, 1))
					target = beach + (bed - beach) * deep
				end
				if target < h then
					h += (target - h) * (1 - smoothstep(def.radius, outer, d))
				end
				riverD = math.min(riverD, math.max(0, d - def.radius))
				if h < def.waterLevel then
					waterLevel, body = def.waterLevel, def.id
				end
			end
		end
	end

	return h, mesaP, riverD, waterLevel, body
end

-- The lowest height this column holds ground, on the voxel grid. Ground stops at the plan's floor,
-- and goes below it only under what needs it: a deep bed or a cave, with rock under them.
-- `h` is the lowest ground of this column and those beside it, so a steep wall has no gap.
function Shape.bottom(plan, x: number, z: number, h: number): number
	local under = plan.rockUnder or ROCK_UNDER
	local low = math.min(plan.floorY, h - under)
	for _, c in ipairs(prepare(plan).caves) do
		local b = c.box
		if x > b[1] and x < b[2] and z > b[5] and z < b[6] then
			low = math.min(low, b[3] - under)
		end
	end
	return math.floor(low / 4) * 4
end

-- Signed distance to the nearest cave tunnel surface, positive in rock (solid), negative
-- inside the tunnel. math.huge when (x, y, z) is far from every cave.
function Shape.caveDistance(plan, x: number, y: number, z: number): number
	local best = math.huge
	for _, c in ipairs(prepare(plan).caves) do
		local bx = c.box
		if x > bx[1] and x < bx[2] and y > bx[3] and y < bx[4] and z > bx[5] and z < bx[6] then
			local d, s = Geo.dist3(c.poly, x, y, z)
			local r = c.def.radius * (1 + CAVE_SWELL * Noise.perlin(s / 40 + c.offset, 0.5, c.def.seed))
			best = math.min(best, d - r)
		end
	end
	return best
end

-- Axis-aligned bounds {x0, z0, x1, z1} of everything a Landform Region or River can change.
function Shape.bounds(plan, id: string)
	local P = prepare(plan)
	local function ofPoints(points, pad, zIndex)
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(points) do
			local pz = p[zIndex]
			x0, x1 = math.min(x0, p[1] - pad), math.max(x1, p[1] + pad)
			z0, z1 = math.min(z0, pz - pad), math.max(z1, pz + pad)
		end
		return { x0, z0, x1, z1 }
	end
	for _, m in ipairs(P.mountains) do
		if m.def.id == id then
			return ofPoints(m.def.points, m.def.halfWidth, 2)
		end
	end
	for _, m in ipairs(P.mesas) do
		if m.def.id == id then
			local c, e = m.def.center, (m.def.radius + m.def.margin + m.def.warp) * (m.def.elongate or 1)
			return { c[1] - e, c[2] - e, c[1] + e, c[2] + e }
		end
	end
	for _, v in ipairs(P.valleys) do
		if v.def.id == id then
			return ofPoints(v.river.route, v.def.halfWidth, 2)
		end
	end
	for _, c in ipairs(P.caves) do
		if c.def.id == id then
			return ofPoints(c.def.points, c.def.radius * 1.4 + 10, 3)
		end
	end
	for _, tr in ipairs(P.trenches) do
		if tr.def.id == id then
			return table.clone(tr.box)
		end
	end
	for _, def in ipairs(P.lakes) do
		if def.id == id then
			local c, e = def.center, (def.radius + def.shore + def.warp) * (def.elongate or 1)
			return { c[1] - e, c[2] - e, c[1] + e, c[2] + e }
		end
	end
	local rv = P.rivers[id]
	if rv then
		return ofPoints(rv.route, rv.width.widest * (1 + WIDTH_NOISE) * 1.5, 2)
	end
	return nil
end

return Shape
