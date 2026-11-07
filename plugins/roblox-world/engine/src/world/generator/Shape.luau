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

local prepared = setmetatable({}, { __mode = "k" })

local function prepare(plan)
	local P = prepared[plan]
	if P then
		return P
	end
	P = { mountains = {}, mesas = {}, valleys = {}, caves = {}, rivers = {}, lakes = plan.lakes or {} }
	for _, rv in ipairs(plan.rivers) do
		local route = Route.points(rv)
		P.rivers[rv.id] = { def = rv, route = route, poly = Geo.polyline2(route), width = Route.width(rv), depth = Route.depth(rv) }
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
			table.insert(P.valleys, {
				def = r,
				river = river,
				carveReach = carveReach,
				carveLimit = math.min(r.halfWidth, carveReach),
				effectReach = if banks then carveReach + Bank.smooth(banks) else edge * 1.5,
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

-- How far one River lowers the valley floor at this spot, then its half width there and how far out
-- its water can reach. `d` and `s` are the spot's distance to the River's line and along it.
local function bedCarve(v, d: number, s: number, x: number, z: number): (number, number, number)
	local def, rv = v.def, v.river
	local hw = rv.width.at(s) * (1 + WIDTH_NOISE * Noise.perlin(s / 120, 0.5, def.seed + 1))
	local banks = rv.def.banks
	if banks then
		local inside = hw - d
		local shore = Bank.shoreAt(banks, def.seed, x, z)
		local aboveWater = def.floorY - rv.def.waterLevel
		local waterTo = math.max(hw * 1.5, hw + shore)
		if inside > 0 then
			local deepest = math.max(1, rv.def.waterLevel - bedAt(v, s, x, z))
			return aboveWater + Bank.depth(banks, def.seed, x, z, inside, hw, deepest), hw, waterTo
		end
		return aboveWater * (1 - smoothstep(0, shore, -inside)), hw, hw + shore
	end
	local bed = bedAt(v, s, x, z)
	local c = 1 - smoothstep(hw * 0.4, hw, d)
	-- The banks and the water's edge come from the first BOWL_FROM studs. Anything deeper is a bowl
	-- under them, deepest on the River's line, so a shallow River keeps its shape.
	local shelf = rv.def.waterLevel - BOWL_FROM
	return c * (def.floorY - math.max(bed, shelf)) + (1 - smoothstep(0, hw, d)) * math.max(0, shelf - bed), hw, hw * 1.5
end

-- One River's carve at a spot, then how far its water reaches there, relative to the nearest pass.
-- A River with banks takes the deepest of every pass near the spot: going by the nearest pass alone,
-- width and depth would jump halfway between two passes, and that step reads as a cliff.
local function riverCarve(v, d: number, s: number, x: number, z: number): (number, number, number)
	local depth, hw, waterTo = bedCarve(v, d, s, x, z)
	local banks = v.river.def.banks
	if banks then
		local reach = v.river.width.widest * (1 + WIDTH_NOISE) + Bank.widestShore(banks)
		local found = Geo.stretches2(v.river.poly, x, z, reach)
		for i = 1, #found, 2 do
			-- The nearest pass is one of these, and its depth is already known.
			if found[i] ~= d or found[i + 1] ~= s then
				depth = math.max(depth, (bedCarve(v, found[i], found[i + 1], x, z)))
			end
		end
	end
	return depth, hw, waterTo
end

-- The deepest carve at a spot `moved` studs from the column, whose distance to each River is in `v.d`,
-- so the spot lies at least v.d - moved from that River.
local function carveAt(P, x: number, z: number, moved: number): number
	local carve = 0
	for _, v in ipairs(P.valleys) do
		if v.d - moved < v.carveReach then
			local d, s = Geo.dist2(v.river.poly, x, z, v.carveLimit)
			if d < v.carveLimit then
				carve = math.max(carve, (riverCarve(v, d, s, x, z)))
			end
		end
	end
	return carve
end

local RIDGE_AXES = { { 1, 0 }, { 0, 1 }, { 0.7071, 0.7071 }, { 0.7071, -0.7071 } }

-- Where water runs close to itself or to another River, each stretch digs towards its own line and a
-- thin crest stands between them. A spot on a crest has deeper ground on both opposite sides, and a
-- spot on a plain wall never does, so this fills crests and leaves walls and shores where they are.
-- Only a fill deeper than `carve` counts, so an axis that cannot beat it skips its other side.
local function fillRidge(P, x: number, z: number, reach: number, carve: number): number
	local filled = carve
	for _, axis in ipairs(RIDGE_AXES) do
		local a = carveAt(P, x + axis[1] * reach, z + axis[2] * reach, reach)
		if a > filled then
			filled = math.max(filled, math.min(a, carveAt(P, x - axis[1] * reach, z - axis[2] * reach, reach)))
		end
	end
	return filled
end

-- Returns ground height at (x, z), then: mesa parameter (0 outside, 1 on the top),
-- distance to the nearest River's sand band centre line or lake water, and the water level over this column (0 = dry).
function Shape.height(plan, x: number, z: number): (number, number, number, number)
	local P = prepare(plan)
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

	-- Valleys: flatten toward each floor first, and only then carve the River beds, so that a
	-- branch's valley cannot fill the bed of the River it leaves.
	local riverD, waterLevel = math.huge, 0
	for _, v in ipairs(P.valleys) do
		local def, rv = v.def, v.river
		local d, s = Geo.dist2(rv.poly, x, z)
		v.d, v.s = d, s
		if d >= def.halfWidth then
			riverD = math.min(riverD, d)
		else
			local width = rv.width.at(s)
			local banks = rv.def.banks
			-- Past BANK_WIDTH the sand band moves out with the bank, or it would end under the water.
			-- On a shore, sand covers about half of it, so that grass comes down towards the water.
			local sandOut = math.max(0, width - BANK_WIDTH) + (if banks then Bank.shoreAt(banks, def.seed, x, z) * 0.5 else 0)
			riverD = math.min(riverD, math.max(0, d - sandOut))
			local flatTo = if banks then width * (1 + WIDTH_NOISE) + math.max(20, Bank.widestShore(banks)) else width + 20
			local w = 1 - smoothstep(flatTo, def.halfWidth, d)
			local bump = 2 * Noise.perlin(x / 50, z / 50, def.seed)
			-- A bump on a gentle shore would leave puddles, so it fades out towards the water.
			local floor = def.floorY + (if banks then bump * smoothstep(width, flatTo, d) else bump)
			h += (floor - h) * w
		end
	end
	-- Where beds overlap, the deepest one counts, so that they meet without digging a pit.
	local carve, smooth, smoothLevel = 0, 0, 0
	for _, v in ipairs(P.valleys) do
		local def, rv = v.def, v.river
		local d, s = v.d, v.s
		if d < def.halfWidth and d < v.effectReach then
			local depth, hw, waterTo = riverCarve(v, d, s, x, z)
			carve = math.max(carve, depth)
			if h - depth < rv.def.waterLevel and d < waterTo then
				waterLevel = rv.def.waterLevel
			end
			local banks = rv.def.banks
			if banks and d < waterTo + Bank.smooth(banks) and Bank.smooth(banks) > smooth then
				smooth, smoothLevel = Bank.smooth(banks), rv.def.waterLevel
			end
		end
	end
	if smooth > 0 then
		local filled = fillRidge(P, x, z, smooth, carve)
		if filled > carve then
			carve = filled
			if h - carve < smoothLevel then
				waterLevel = smoothLevel
			end
		end
	end
	h -= carve

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
				local beach = def.waterLevel + 3
				local deep = smoothstep(0, 1, math.clamp((def.radius - d) / (def.radius * 0.4), 0, 1))
				local bed = def.waterLevel - Bank.pools(def.waterLevel - def.bedY, def.depthVary, def.seed, x, z)
				if def.bedRough then
					bed += def.bedRough * math.clamp(Noise.perlin(x / BED_SCALE, z / BED_SCALE, def.seed + 2) * 2, -1, 1)
				end
				local target = beach + (bed - beach) * deep
				if def.banks then
					local inside = def.radius - d
					if inside > 0 then
						local deepest = math.max(1, def.waterLevel - bed)
						target = def.waterLevel - Bank.depth(def.banks, def.seed, x, z, inside, def.radius, deepest)
					else
						-- Rises clearly away from the water, or the waterline breaks into puddles.
						target = def.waterLevel + 8 * math.clamp(-inside / (def.shore * 0.25), 0, 1)
					end
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
