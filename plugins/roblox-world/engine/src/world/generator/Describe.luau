--!nonstrict
-- The `describe` report: validates the World Plan and answers, from facts, which Chunks
-- exist, what each Landform touches, and what a change would rewrite.

local Shape = require("./Shape")
local Chunk = require("./Chunk")

local Describe = {}

local KINDS = { mountain = true, mesa = true, valley = true, cave = true }

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
	for _, rv in ipairs(plan.rivers or {}) do
		if ids[rv.id] then
			table.insert(e, "duplicate id " .. tostring(rv.id))
		end
		ids[rv.id] = true
		rivers[rv.id] = rv
		checkPoints(e, "river " .. tostring(rv.id), rv.points, 2)
		if not isNum(rv.waterLevel) or rv.waterLevel % 4 ~= 0 then
			table.insert(e, "river " .. tostring(rv.id) .. ": waterLevel must be a multiple of 4")
		elseif isNum(rv.bedY) and rv.bedY >= rv.waterLevel then
			table.insert(e, "river " .. tostring(rv.id) .. ": bedY must be below waterLevel")
		end
		if isNum(rv.bedY) and isNum(plan.floorY) and rv.bedY - plan.floorY < 64 then
			table.insert(e, "river " .. tostring(rv.id) .. ": less than 64 studs of ground under the bed")
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
			elseif isNum(r.halfWidth) and r.halfWidth < rv.halfWidth * 1.3 + 20 then
				table.insert(e, label .. ": halfWidth too small for its river")
			elseif isNum(r.floorY) and r.floorY <= rv.waterLevel + 1 then
				table.insert(e, label .. ": floorY must be above the water level")
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

local function touching(plan, id)
	local b = Shape.bounds(plan, id)
	local out = {}
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

-- Chunks a change would rewrite. change = { regionId = "mesa" } or { all = true } (a seed or
-- Generator change). Locked Chunks are never rewritten but are reported.
function Describe.impact(plan, state, change)
	local touched = {}
	if change.all then
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
