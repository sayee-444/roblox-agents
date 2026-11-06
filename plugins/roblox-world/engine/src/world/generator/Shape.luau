--!nonstrict
-- The pure terrain function: height(x, z) from the World Plan and seeds, plus the cave's
-- signed distance. Chunk borders agree because every Chunk evaluates the same function.

local Noise = require("./Noise")
local Geo = require("./Geo")

local Shape = {}
local smoothstep = Geo.smoothstep

local prepared = setmetatable({}, { __mode = "k" })

local function prepare(plan)
	local P = prepared[plan]
	if P then
		return P
	end
	P = { mountains = {}, mesas = {}, valleys = {}, caves = {}, rivers = {} }
	for _, rv in ipairs(plan.rivers) do
		P.rivers[rv.id] = { def = rv, poly = Geo.polyline2(rv.points) }
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
			table.insert(P.valleys, { def = r, river = P.rivers[r.riverId] })
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

-- Returns ground height at (x, z), then: mesa parameter (0 outside, 1 on the top),
-- distance to the nearest River route, and the water level over this column (0 = dry).
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
		riverD = math.min(riverD, d)
		if d < def.halfWidth then
			local w = 1 - smoothstep(rv.def.halfWidth + 20, def.halfWidth, d)
			local floor = def.floorY + 2 * Noise.perlin(x / 50, z / 50, def.seed)
			h += (floor - h) * w
		end
	end
	-- Where beds overlap, the deepest one counts, so that they meet without digging a pit.
	local carve = 0
	for _, v in ipairs(P.valleys) do
		local def, rv = v.def, v.river
		local d, s = v.d, v.s
		if d < def.halfWidth then
			local hw = rv.def.halfWidth * (1 + 0.3 * Noise.perlin(s / 120, 0.5, def.seed + 1))
			local c = 1 - smoothstep(hw * 0.4, hw, d)
			local depth = c * (def.floorY - rv.def.bedY)
			carve = math.max(carve, depth)
			if h - depth < rv.def.waterLevel and d < hw * 1.5 then
				waterLevel = rv.def.waterLevel
			end
		end
	end
	h -= carve

	return h, mesaP, riverD, waterLevel
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
			return ofPoints(v.river.def.points, v.def.halfWidth, 2)
		end
	end
	for _, c in ipairs(P.caves) do
		if c.def.id == id then
			return ofPoints(c.def.points, c.def.radius * 1.4 + 10, 3)
		end
	end
	local rv = P.rivers[id]
	if rv then
		return ofPoints(rv.def.points, rv.def.halfWidth * 1.5, 2)
	end
	return nil
end

return Shape
