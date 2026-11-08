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

local prepared = setmetatable({}, { __mode = "k" })

local function prepare(plan)
	local P = prepared[plan]
	if P then
		return P
	end
	P = { mountains = {}, mesas = {}, valleys = {}, caves = {}, rivers = {}, lakes = plan.lakes or {}, lakeSlopes = {}, oceans = plan.oceans or {} }
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

-- The Ocean holding (x, z), or nil. An Ocean holds whole Chunks, each rectangle { i0, j0, i1, j1 } of
-- Chunk indices, inclusive.
function Shape.oceanAt(plan, x: number, z: number)
	local oceans = prepare(plan).oceans
	if #oceans == 0 then
		return nil
	end
	local s = plan.chunkSize
	local ci, cj = math.floor((x + s / 2) / s), math.floor((z + s / 2) / s)
	for _, def in ipairs(oceans) do
		for _, r in ipairs(def.chunks) do
			if ci >= r[1] and ci <= r[3] and cj >= r[2] and cj <= r[4] then
				return def
			end
		end
	end
	return nil
end

-- How deep an Ocean is under the sea level. With no coast yet (#70), all of it is open Ocean at its cap.
function Shape.oceanDepth(def): number
	return def.depthCap or DEPTH_CAP
end

-- Returns ground height at (x, z), then: mesa parameter (0 outside, 1 on the top),
-- distance to the nearest River's sand band centre line, lake or ocean water, and the water level over this column (0 = dry).
function Shape.height(plan, x: number, z: number): (number, number, number, number)
	local P = prepare(plan)
	local ocean = Shape.oceanAt(plan, x, z)
	if ocean then
		return plan.seaLevel - Shape.oceanDepth(ocean), 0, 0, plan.seaLevel
	end
	local h, mesaP, riverD, waterLevel = land(P, plan, x, z)

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
				local vary = if def.depthVary == nil and fromSize then DEPTH_VARY else def.depthVary
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
					waterLevel = def.waterLevel
				end
			end
		end
	end

	return h, mesaP, riverD, waterLevel
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
			local r = c.def.radius * (1 + 0.15 * Noise.perlin(s / 40 + c.offset, 0.5, c.def.seed))
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
