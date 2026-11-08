--!nonstrict
-- The `describe` report: validates the World Plan and answers, from facts, which Chunks
-- exist, what each Landform touches, and what a change would rewrite.

local Shape = require("./Shape")
local Geo = require("./Geo")
local Route = require("./Route")
local Bank = require("./Bank")
local Chunk = require("./Chunk")

local Describe = {}

local KINDS = { mountain = true, mesa = true, valley = true, cave = true }
local REACHED_STEP = 24 -- studs along a River between the places where `heights` measures its depth
local REACHED_ACROSS = 3 -- spots on each side of the line where it measures, out to 0.6 of the half width
local REACHED_GRID = 8 -- spots on each side of a Lake's centre where it measures

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function checkPoints(errors, label, points, dims)
	if type(points) ~= "table" or #points < 2 then
		table.insert(errors, label .. ": needs at least 2 route points")
		return
	end
	for i, p in ipairs(points) do
		for d = 1, dims do
			if not isNum(p[d]) then
				table.insert(errors, label .. ": point " .. i .. " needs " .. dims .. " numbers")
				return
			end
		end
	end
end

local function checkDepths(errors, label, rv)
	local shallowest = if isNum(rv.waterLevel) and isNum(rv.bedY) then rv.waterLevel - rv.bedY else nil
	if rv.depths ~= nil then
		if type(rv.depths) ~= "table" or type(rv.points) ~= "table" or #rv.depths ~= #rv.points then
			table.insert(errors, label .. ": depths needs one depth per point")
			return
		end
		shallowest = math.huge
		for i = 1, #rv.depths do
			if not (isNum(rv.depths[i]) and rv.depths[i] > 0) then
				table.insert(errors, label .. ": depth " .. i .. " must be above 0")
				return
			end
			shallowest = math.min(shallowest, rv.depths[i])
		end
	end
	if rv.bedRough ~= nil and not (isNum(rv.bedRough) and rv.bedRough >= 0 and shallowest and rv.bedRough < shallowest) then
		table.insert(errors, label .. ": bedRough must be from 0 to below the shallowest depth")
	end
end

local BANK_FIELDS = {
	shore = { 1, math.huge },
	rough = { 0, math.huge },
	vary = { 0, 0.9 },
	smooth = { 0, 100 },
}

-- Fields of the wall that the slope of the ground replaced on plugin 0.40.0, with what replaces each.
local REMOVED_BANK_FIELDS = {
	shallows = "the Shallows come from a gentle slope by themselves",
	shallowDepth = "the Shallows come from a gentle slope by themselves",
	bedFlat = "the bed curves into its deepest line",
	steep = "the ground keeps its slope under the water",
}

local SIDES = { 0.02, 1.5 } -- rise over run at the water's edge, from a near plain to about 56 degrees

local function checkBanks(errors, label, def, isLake)
	if def.depthVary ~= nil and not (isNum(def.depthVary) and def.depthVary >= 0 and def.depthVary <= 0.9) then
		table.insert(errors, label .. ": depthVary must be from 0 to 0.9")
	end
	local banks = def.banks
	if banks == nil then
		return
	end
	if type(banks) ~= "table" then
		table.insert(errors, label .. ": banks must be a table")
		return
	end
	for field, value in pairs(banks) do
		local range = BANK_FIELDS[field]
		local removed = REMOVED_BANK_FIELDS[field]
		if removed then
			local slope = if isLake then "the slope of the ground around it" else "the sides of its valley"
			table.insert(errors, string.format("%s: banks.%s was removed, since %s: how steep and deep the water gets comes from %s", label, field, removed, slope))
		elseif not range then
			table.insert(errors, label .. ": banks has no field " .. tostring(field))
		elseif not (isNum(value) and value >= range[1] and value <= range[2]) then
			table.insert(errors, label .. ": banks." .. field .. " must be from " .. range[1] .. " to " .. range[2])
		end
	end
	if isLake and banks.shore ~= nil then
		table.insert(errors, label .. ": a Lake's shore is its own field, not part of banks")
	end
end

-- How steep a valley's Valley Sides are: one number, or one per point of its River.
local function checkSides(errors, label, sides, rv)
	local range = string.format(" from %s to %s, as rise over run at the water's edge", SIDES[1], SIDES[2])
	if rv and rv.banks == nil then
		table.insert(errors, label .. ": sides shape only a River with banks, so give river " .. tostring(rv.id) .. " banks or leave sides out")
	end
	if type(sides) == "table" then
		if not rv or type(rv.points) ~= "table" or #sides ~= #rv.points then
			table.insert(errors, label .. ": sides needs one per point of its River, or one number")
			return
		end
		for i, value in ipairs(sides) do
			if not (isNum(value) and value >= SIDES[1] and value <= SIDES[2]) then
				table.insert(errors, label .. ": sides " .. i .. " must be" .. range)
				return
			end
		end
	elseif not (isNum(sides) and sides >= SIDES[1] and sides <= SIDES[2]) then
		table.insert(errors, label .. ": sides must be" .. range)
	end
end

-- What a Valley must leave beside its River's widest point.
local function shoreRoom(rv): number
	local banks = rv.banks
	if type(banks) ~= "table" or (banks.shore ~= nil and not isNum(banks.shore)) or (banks.vary ~= nil and not isNum(banks.vary)) then
		return 20
	end
	return math.max(20, Bank.widestShore(banks))
end

local function checkLoops(errors, label, rv)
	local loops = rv.loops
	if loops == nil then
		return
	end
	if type(loops) ~= "table" then
		table.insert(errors, label .. ": loops must be a list")
		return
	end
	if #loops > 0 and not (isNum(rv.curve) and rv.curve > 0) then
		table.insert(errors, label .. ": a loop needs a curve above 0, or it has corners")
	end
	local legs = if type(rv.points) == "table" then #rv.points - 1 else 0
	local taken = {}
	for i, loop in ipairs(loops) do
		local name = label .. ": loop " .. i
		if type(loop) ~= "table" then
			table.insert(errors, name .. " must be a table")
			return
		end
		if not (isNum(loop.leg) and loop.leg % 1 == 0 and loop.leg >= 1 and loop.leg <= legs) then
			table.insert(errors, name .. " needs a leg from 1 to " .. legs)
		elseif taken[loop.leg] then
			table.insert(errors, name .. " shares leg " .. loop.leg .. " with another loop")
		else
			taken[loop.leg] = true
		end
		if not (isNum(loop.radius) and loop.radius > 0) then
			table.insert(errors, name .. " needs a radius above 0")
		end
		if not (isNum(loop.turn) and loop.turn > 0 and loop.turn <= 360) then
			table.insert(errors, name .. " needs a turn above 0 and up to 360")
		end
		if loop.side ~= "left" and loop.side ~= "right" then
			table.insert(errors, name .. ' needs a side, "left" or "right"')
		end
		-- The River leaves the leg at a neck, and that neck has to fit on the leg.
		if taken[loop.leg] and isNum(loop.radius) and isNum(loop.turn) then
			local a, b = rv.points[loop.leg], rv.points[loop.leg + 1]
			local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			if 2 * loop.radius * math.sin(math.rad((360 - loop.turn) / 2)) >= length then
				table.insert(errors, name .. " has a neck wider than its leg")
			end
		end
	end
end

-- Returns a list of error strings; empty means the plan is valid.
function Describe.validate(plan): { string }
	local e = {}
	if not isNum(plan.worldSeed) then
		table.insert(e, "worldSeed must be a number")
	end
	if plan.voxel ~= 4 then
		table.insert(e, "voxel must be 4")
	end
	if not isNum(plan.chunkSize) or plan.chunkSize % 4 ~= 0 then
		table.insert(e, "chunkSize must be a multiple of 4")
	end
	if not isNum(plan.floorY) or plan.floorY % 4 ~= 0 then
		table.insert(e, "floorY must be a multiple of 4")
	end
	local x = plan.extent
	if type(x) ~= "table" or not (isNum(x.minX) and isNum(x.maxX) and isNum(x.minZ) and isNum(x.maxZ)) then
		table.insert(e, "extent needs minX, maxX, minZ, maxZ")
	elseif x.minX > x.maxX or x.minZ > x.maxZ then
		table.insert(e, "extent is empty")
	end
	local b = plan.base
	if type(b) ~= "table" or not (isNum(b.mean) and isNum(b.amp) and isNum(b.scale) and isNum(b.octaves)) then
		table.insert(e, "base needs mean, amp, scale, octaves")
	end

	local ids = {}
	local rivers = {}
	local widest = {}
	for _, rv in ipairs(plan.rivers or {}) do
		if ids[rv.id] then
			table.insert(e, "duplicate id " .. tostring(rv.id))
		end
		ids[rv.id] = true
		rivers[rv.id] = rv
		local before = #e
		checkPoints(e, "river " .. tostring(rv.id), rv.points, 2)
		if rv.widths ~= nil then
			if type(rv.widths) ~= "table" or type(rv.points) ~= "table" or #rv.widths ~= #rv.points then
				table.insert(e, "river " .. tostring(rv.id) .. ": widths needs one width per point")
			else
				for i = 1, #rv.widths do
					if not (isNum(rv.widths[i]) and rv.widths[i] > 0) then
						table.insert(e, "river " .. tostring(rv.id) .. ": width " .. i .. " must be above 0")
					end
				end
			end
		elseif not (isNum(rv.halfWidth) and rv.halfWidth > 0) then
			table.insert(e, "river " .. tostring(rv.id) .. ": needs halfWidth above 0, or widths")
		end
		if rv.bendWiden ~= nil and not (isNum(rv.bendWiden) and rv.bendWiden >= 0) then
			table.insert(e, "river " .. tostring(rv.id) .. ": bendWiden cannot be negative")
		end
		checkLoops(e, "river " .. tostring(rv.id), rv)
		if rv.curve ~= nil and not (isNum(rv.curve) and rv.curve >= 0 and rv.curve <= 1) then
			table.insert(e, "river " .. tostring(rv.id) .. ": curve must be from 0 to 1")
		end
		if rv.meander ~= nil and not (isNum(rv.meander) and rv.meander >= 0) then
			table.insert(e, "river " .. tostring(rv.id) .. ": meander cannot be negative")
		end
		if type(rv.points) == "table" then
			for i = 1, #rv.points - 1 do
				local a, b = rv.points[i], rv.points[i + 1]
				if a[1] == b[1] and a[2] == b[2] then
					table.insert(e, "river " .. tostring(rv.id) .. ": points " .. i .. " and " .. (i + 1) .. " are the same")
				end
			end
		end
		if not isNum(rv.waterLevel) or rv.waterLevel % 4 ~= 0 then
			table.insert(e, "river " .. tostring(rv.id) .. ": waterLevel must be a multiple of 4")
		elseif rv.depths == nil and not isNum(rv.bedY) then
			table.insert(e, "river " .. tostring(rv.id) .. ": needs bedY, or depths")
		elseif rv.depths == nil and rv.bedY >= rv.waterLevel then
			table.insert(e, "river " .. tostring(rv.id) .. ": bedY must be below waterLevel")
		end
		checkDepths(e, "river " .. tostring(rv.id), rv)
		checkBanks(e, "river " .. tostring(rv.id), rv, false)
		-- Any error here already refuses the plan, so only a sound River is measured.
		if #e == before then
			widest[rv.id] = Route.width(rv).widest
		end
	end
	for _, lk in ipairs(plan.lakes or {}) do
		local label = "lake " .. tostring(lk.id)
		checkBanks(e, label, lk, true)
		if ids[lk.id] then
			table.insert(e, "duplicate id " .. tostring(lk.id))
		end
		ids[lk.id] = true
		if not isNum(lk.seed) then
			table.insert(e, label .. ": needs a seed")
		end
		if not (type(lk.center) == "table" and isNum(lk.center[1]) and isNum(lk.center[2])) then
			table.insert(e, label .. ": needs a center")
		end
		if not (isNum(lk.radius) and lk.radius > 0 and isNum(lk.shore) and lk.shore > 0 and isNum(lk.warp)) then
			table.insert(e, label .. ": needs radius > 0, shore > 0 and warp")
		end
		if not isNum(lk.waterLevel) or lk.waterLevel % 4 ~= 0 then
			table.insert(e, label .. ": waterLevel must be a multiple of 4")
		elseif lk.bedY ~= nil and not isNum(lk.bedY) then
			table.insert(e, label .. ": bedY must be a number")
		elseif isNum(lk.bedY) and lk.bedY >= lk.waterLevel then
			table.insert(e, label .. ": bedY must be below waterLevel")
		end
		-- With no bedY, a Lake's depth comes from its size, and only banks can follow the ground to it.
		if lk.bedY == nil and lk.banks == nil then
			table.insert(e, label .. ": needs bedY, or banks to take its depth from its size")
		end
		local capSound = lk.depthCap == nil or lk.depthCap == false or (isNum(lk.depthCap) and lk.depthCap > 0)
		if lk.depthCap ~= nil and lk.bedY ~= nil then
			table.insert(e, label .. ": depthCap limits only a depth from its size, so leave it out or leave out bedY")
		elseif not capSound then
			table.insert(e, label .. ": depthCap must be above 0, or false for no cap")
		end
		local depth = if isNum(lk.waterLevel) and (isNum(lk.bedY) or (lk.bedY == nil and capSound and isNum(lk.radius) and lk.radius > 0)) then Shape.lakeDepth(lk) else nil
		if lk.bedRough ~= nil and not (isNum(lk.bedRough) and lk.bedRough >= 0 and depth and lk.bedRough < depth) then
			table.insert(e, label .. ": bedRough must be from 0 to below the lake's depth")
		end
		-- Still water holds one level, so a River ending in a lake must meet it.
		if type(lk.center) == "table" and isNum(lk.radius) then
			for _, rv in ipairs(plan.rivers or {}) do
				local last = rv.points and rv.points[#rv.points]
				if last and isNum(last[1]) and isNum(last[2]) then
					local reach = math.sqrt((last[1] - lk.center[1]) ^ 2 + (last[2] - lk.center[2]) ^ 2)
					if reach < lk.radius and rv.waterLevel ~= lk.waterLevel then
						table.insert(e, "river " .. tostring(rv.id) .. ": ends in " .. tostring(lk.id) .. ", so it needs the same waterLevel")
					end
				end
			end
		end
	end
	local oceans = plan.oceans or {}
	if #oceans > 0 and not (isNum(plan.seaLevel) and plan.seaLevel % 4 == 0) then
		table.insert(e, "seaLevel must be a multiple of 4, so the water meets a voxel boundary")
	end
	for _, oc in ipairs(oceans) do
		local label = "ocean " .. tostring(oc.id)
		if ids[oc.id] then
			table.insert(e, "duplicate id " .. tostring(oc.id))
		end
		ids[oc.id] = true
		if not isNum(oc.seed) then
			table.insert(e, label .. ": needs a seed")
		end
		if oc.depthCap ~= nil and not (isNum(oc.depthCap) and oc.depthCap > 0 and oc.depthCap % 4 == 0) then
			table.insert(e, label .. ": depthCap must be a multiple of 4 above 0, so the bed meets a voxel boundary")
		end
		local sound = type(oc.chunks) == "table" and #oc.chunks > 0
		for _, r in ipairs(if sound then oc.chunks else {}) do
			local whole = type(r) == "table" and #r == 4
			for k = 1, 4 do
				whole = whole and isNum(r[k]) and r[k] % 1 == 0
			end
			sound = sound and whole and r[1] <= r[3] and r[2] <= r[4]
		end
		if not sound then
			table.insert(e, label .. ": chunks needs rectangles of Chunk indices { i0, j0, i1, j1 }, with i0 <= i1 and j0 <= j1")
		elseif type(x) == "table" and isNum(x.minX) and isNum(x.maxX) and isNum(x.minZ) and isNum(x.maxZ) then
			for _, r in ipairs(oc.chunks) do
				if r[1] < x.minX or r[3] > x.maxX or r[2] < x.minZ or r[4] > x.maxZ then
					table.insert(e, label .. ": chunks must lie inside the extent, which only the developer's order changes")
					break
				end
			end
		end
	end
	for _, r in ipairs(plan.regions or {}) do
		local label = "region " .. tostring(r.id)
		if ids[r.id] then
			table.insert(e, "duplicate id " .. tostring(r.id))
		end
		ids[r.id] = true
		if not KINDS[r.kind] then
			table.insert(e, label .. ": unknown kind " .. tostring(r.kind))
		end
		if not isNum(r.seed) then
			table.insert(e, label .. ": needs a Region Seed")
		end
		if r.kind == "mountain" then
			checkPoints(e, label, r.points, 2)
			if not (isNum(r.halfWidth) and r.halfWidth > 0 and isNum(r.height)) then
				table.insert(e, label .. ": needs halfWidth > 0 and height")
			end
		elseif r.kind == "mesa" then
			if not (type(r.center) == "table" and isNum(r.radius) and isNum(r.margin) and r.margin > 0) then
				table.insert(e, label .. ": needs center, radius and margin > 0")
			end
			if not (isNum(r.levels) and r.levels >= 1) then
				table.insert(e, label .. ": needs levels >= 1")
			end
		elseif r.kind == "valley" then
			local rv = rivers[r.riverId]
			if not rv then
				table.insert(e, label .. ": unknown river " .. tostring(r.riverId))
			elseif isNum(r.halfWidth) and widest[r.riverId] and r.halfWidth < widest[r.riverId] * 1.3 + shoreRoom(rv) then
				table.insert(e, label .. string.format(": halfWidth too small for its river and shore, whose widest half width is %.1f", widest[r.riverId]))
			elseif isNum(r.floorY) and r.floorY <= rv.waterLevel + 1 then
				table.insert(e, label .. ": floorY must be above the water level")
			end
			if r.sides ~= nil then
				checkSides(e, label, r.sides, rv)
			end
		elseif r.kind == "cave" then
			checkPoints(e, label, r.points, 3)
			if not (isNum(r.radius) and r.radius >= 4) then
				table.insert(e, label .. ": needs radius >= 4")
			end
		end
	end
	return e
end

local function overlaps(b, cx0, cz0, size)
	return b[3] > cx0 and b[1] < cx0 + size and b[4] > cz0 and b[2] < cz0 + size
end

local function allChunks(plan)
	local list = {}
	local x = plan.extent
	for j = x.minZ, x.maxZ do
		for i = x.minX, x.maxX do
			table.insert(list, { i = i, j = j, key = Chunk.key(i, j) })
		end
	end
	return list
end

local function oceanOf(plan, id)
	for _, oc in ipairs(plan.oceans or {}) do
		if oc.id == id then
			return oc
		end
	end
	return nil
end

local function touching(plan, id)
	local out = {}
	-- An Ocean holds whole Chunks, which a bounding box would overstate for an L or a U.
	local ocean = oceanOf(plan, id)
	if ocean then
		for _, c in ipairs(allChunks(plan)) do
			local x0, z0 = Chunk.origin(plan, c.i, c.j)
			if Shape.oceanAt(plan, x0 + plan.chunkSize / 2, z0 + plan.chunkSize / 2) == ocean then
				table.insert(out, c.key)
			end
		end
		return out
	end
	local b = Shape.bounds(plan, id)
	for _, c in ipairs(allChunks(plan)) do
		local x0, z0 = Chunk.origin(plan, c.i, c.j)
		if b and overlaps(b, x0, z0, plan.chunkSize) then
			table.insert(out, c.key)
		end
	end
	return out
end

local function stateOf(state, key)
	local s = state.chunks and state.chunks[key]
	return s or { generated = false, locked = false }
end

-- Which Chunks exist, which are Locked, and what each Landform touches.
function Describe.report(plan, state)
	local r = { regions = {}, chunks = {}, extent = { total = 0, generated = 0, locked = 0, free = 0 } }
	local ids = {}
	for _, rv in ipairs(plan.rivers) do
		table.insert(ids, { rv.id, "river" })
	end
	for _, lk in ipairs(plan.lakes or {}) do
		table.insert(ids, { lk.id, "lake" })
	end
	for _, reg in ipairs(plan.regions) do
		table.insert(ids, { reg.id, reg.kind })
	end
	for _, oc in ipairs(plan.oceans or {}) do
		table.insert(ids, { oc.id, "ocean" })
	end
	for _, entry in ipairs(ids) do
		r.regions[entry[1]] = { kind = entry[2], chunks = touching(plan, entry[1]) }
	end
	for _, c in ipairs(allChunks(plan)) do
		local s = stateOf(state, c.key)
		local here = {}
		for id, info in pairs(r.regions) do
			for _, k in ipairs(info.chunks) do
				if k == c.key then
					table.insert(here, id)
				end
			end
		end
		table.sort(here)
		r.chunks[c.key] = { generated = s.generated, locked = s.locked, regions = here }
		r.extent.total += 1
		if s.generated then
			r.extent.generated += 1
		else
			r.extent.free += 1
		end
		if s.locked then
			r.extent.locked += 1
		end
	end
	r.sites = #(plan.sites or {})
	return r
end

-- Chunks a change would rewrite. change = { regionId = "mesa" }, { removedIds = { "river", "valley" } }
-- or { all = true } (a seed or Generator change). Locked Chunks are never rewritten but are reported.
-- With removedIds, only what is on the map now: each Chunk once, and only those already generated.
function Describe.impact(plan, state, change)
	local touched = {}
	if change.removedIds then
		local wanted = {}
		for _, id in ipairs(change.removedIds) do
			for _, key in ipairs(touching(plan, id)) do
				wanted[key] = true
			end
		end
		for _, c in ipairs(allChunks(plan)) do
			local s = stateOf(state, c.key)
			if wanted[c.key] and (s.generated or s.locked) then
				table.insert(touched, c.key)
			end
		end
	elseif change.all then
		for _, c in ipairs(allChunks(plan)) do
			table.insert(touched, c.key)
		end
	else
		touched = touching(plan, change.regionId)
	end
	local rewrite, lockedReached = {}, {}
	for _, key in ipairs(touched) do
		if stateOf(state, key).locked then
			table.insert(lockedReached, key)
		else
			table.insert(rewrite, key)
		end
	end
	return { rewrite = rewrite, lockedReached = lockedReached }
end

-- Each border between two generated Chunks, as { axis, ci, cj }, where (ci, cj) is the Chunk on its
-- lower side. With a list of { i, j }, only the borders that touch one of those Chunks.
function Describe.bordersOf(plan, state, list)
	local chosen
	if list then
		chosen = {}
		for _, c in ipairs(list) do
			chosen[Chunk.key(c[1], c[2])] = true
		end
	end
	local function generated(i, j)
		return stateOf(state, Chunk.key(i, j)).generated == true
	end
	local out = {}
	local e = plan.extent
	for cj = e.minZ, e.maxZ do
		for ci = e.minX, e.maxX do
			for _, axis in ipairs({ "x", "z" }) do
				local ni, nj = if axis == "x" then ci + 1 else ci, if axis == "z" then cj + 1 else cj
				local inside = ni <= e.maxX and nj <= e.maxZ
				local wanted = chosen == nil or chosen[Chunk.key(ci, cj)] or chosen[Chunk.key(ni, nj)]
				if inside and wanted and generated(ci, cj) and generated(ni, nj) then
					table.insert(out, { axis = axis, ci = ci, cj = cj })
				end
			end
		end
	end
	return out
end

-- The surface height of each Landform and River, one per line. A range reports its highest route
-- point or midpoint, a mesa its centre, a cave the ground at its mouth, a River both ends and a
-- lake its centre.
function Describe.heights(plan): string
	local lines = {}
	local function ground(x, z)
		return (Shape.height(plan, x, z))
	end
	for _, r in ipairs(plan.regions) do
		if r.kind == "mountain" then
			local crest, cx, cz = -math.huge, 0, 0
			local function sample(x, z)
				local h = ground(x, z)
				if h > crest then
					crest, cx, cz = h, x, z
				end
			end
			for i, p in ipairs(r.points) do
				sample(p[1], p[2])
				local q = r.points[i + 1]
				if q then
					sample((p[1] + q[1]) / 2, (p[2] + q[2]) / 2)
				end
			end
			table.insert(lines, string.format("%s: crest %.1f at %d %d", r.id, crest, cx, cz))
		elseif r.kind == "mesa" then
			table.insert(lines, string.format("%s: top %.1f at %d %d", r.id, ground(r.center[1], r.center[2]), r.center[1], r.center[2]))
		elseif r.kind == "cave" then
			local mouth = r.points[1]
			table.insert(lines, string.format("%s: ground %.1f at the mouth, axis y %d", r.id, ground(mouth[1], mouth[3]), mouth[2]))
		end
	end
	-- How deep the water over (x, z) is, 0 where it is dry or in a Lake.
	local function water(x, z)
		for _, lk in ipairs(plan.lakes or {}) do
			if math.sqrt((x - lk.center[1]) ^ 2 + (z - lk.center[2]) ^ 2) < lk.radius * (lk.elongate or 1) + lk.warp then
				return 0
			end
		end
		local h, _, _, level = Shape.height(plan, x, z)
		return if level > 0 then math.max(0, level - h) else 0
	end
	for _, rv in ipairs(plan.rivers) do
		local a, b = rv.points[1], rv.points[#rv.points]
		local poly = Geo.polyline2(Route.points(rv))
		local width = Route.width(rv)
		local depth = Route.depth(rv)
		local deepRange = if depth.shallowest == depth.deepest then tostring(depth.deepest) else depth.shallowest .. " to " .. depth.deepest
		local narrowest, widest = math.round(width.narrowest), math.round(width.widest)
		local span = if narrowest == widest then tostring(widest) else narrowest .. " to " .. widest
		-- The slope decides how deep the water gets, so the depth reached is measured across the water,
		-- every REACHED_STEP studs along its line, outside any Lake.
		local shallowest, deepest = math.huge, 0
		for _, seg in ipairs(poly.segs) do
			for u = 0, seg[6] - 1, REACHED_STEP do
				local px, pz = seg[1] + seg[3] * u / seg[6], seg[2] + seg[4] * u / seg[6]
				local nx, nz = -seg[4] / seg[6], seg[3] / seg[6]
				local hw = width.at(seg[7] + u)
				local here = 0
				for k = -REACHED_ACROSS, REACHED_ACROSS do
					local off = hw * 0.6 * k / REACHED_ACROSS
					here = math.max(here, water(px + nx * off, pz + nz * off))
				end
				if here > 0 then
					shallowest, deepest = math.min(shallowest, here), math.max(deepest, here)
				end
			end
		end
		local reached = if deepest > 0 then string.format("reached %.1f to %.1f", shallowest, deepest) else "reached none"
		table.insert(lines, string.format("%s: bed %.1f at %d %d, %.1f at %d %d, route %d studs, curve %s, meander %d, depth %s asked, %s, width %s%s", rv.id, ground(a[1], a[2]), a[1], a[2], ground(b[1], b[2]), b[1], b[2], poly.length, tostring(rv.curve or 0), rv.meander or 0, deepRange, reached, span, if rv.loops and #rv.loops > 0 then ", loops " .. #rv.loops else ""))
	end
	for _, lk in ipairs(plan.lakes or {}) do
		local deepest = 0
		local reach = lk.radius * (lk.elongate or 1)
		for i = -REACHED_GRID, REACHED_GRID do
			for j = -REACHED_GRID, REACHED_GRID do
				local h, _, _, level = Shape.height(plan, lk.center[1] + reach * i / REACHED_GRID, lk.center[2] + reach * j / REACHED_GRID)
				if level > 0 then
					deepest = math.max(deepest, level - h)
				end
			end
		end
		local asked, fromSize, capped = Shape.lakeDepth(lk)
		local depth = if not fromSize then string.format("depth %g asked", asked) elseif capped then string.format("depth %.1f from its size, cut to its cap", asked) else string.format("depth %.1f from its size", asked)
		table.insert(lines, string.format("%s: bed %.1f at %d %d, water level %d, %s, %.1f reached", lk.id, ground(lk.center[1], lk.center[2]), lk.center[1], lk.center[2], lk.waterLevel, depth, deepest))
	end
	for _, oc in ipairs(plan.oceans or {}) do
		local depth = Shape.oceanDepth(oc)
		table.insert(lines, string.format("%s: sea level %d, bed %.1f, depth %d, %d Chunks", oc.id, plan.seaLevel, plan.seaLevel - depth, depth, #touching(plan, oc.id)))
	end
	return table.concat(lines, "\n")
end

function Describe.format(report): string
	local lines = {}
	local e = report.extent
	table.insert(lines, string.format("extent: %d chunks, %d generated, %d locked, %d free", e.total, e.generated, e.locked, e.free))
	local ids = {}
	for id in pairs(report.regions) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local r = report.regions[id]
		table.insert(lines, string.format("%s (%s): chunks %s", id, r.kind, table.concat(r.chunks, " ")))
	end
	local keys = {}
	for k in pairs(report.chunks) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local c = report.chunks[k]
		table.insert(
			lines,
			string.format("chunk %s: %s%s [%s]", k, c.generated and "generated" or "not generated", c.locked and ", LOCKED" or "", table.concat(c.regions, ", "))
		)
	end
	table.insert(lines, "sites: " .. report.sites)
	return table.concat(lines, "\n")
end

return Describe
