--!nonstrict
-- The `describe` report: validates the World Plan and answers, from facts, which Chunks
-- exist, what each Landform touches, and what a change would rewrite.

local Shape = require("./Shape")
local Geo = require("./Geo")
local Route = require("./Route")
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
		elseif isNum(rv.bedY) and rv.bedY >= rv.waterLevel then
			table.insert(e, "river " .. tostring(rv.id) .. ": bedY must be below waterLevel")
		end
		if isNum(rv.bedY) and isNum(plan.floorY) and rv.bedY - plan.floorY < 64 then
			table.insert(e, "river " .. tostring(rv.id) .. ": less than 64 studs of ground under the bed")
		end
		-- Any error here already refuses the plan, so only a sound River is measured.
		if #e == before then
			widest[rv.id] = Route.width(rv).widest
		end
	end
	for _, lk in ipairs(plan.lakes or {}) do
		local label = "lake " .. tostring(lk.id)
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
		elseif isNum(lk.bedY) and lk.bedY >= lk.waterLevel then
			table.insert(e, label .. ": bedY must be below waterLevel")
		end
		if isNum(lk.bedY) and isNum(plan.floorY) and lk.bedY - plan.floorY < 64 then
			table.insert(e, label .. ": less than 64 studs of ground under the bed")
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
			elseif isNum(r.halfWidth) and widest[r.riverId] and r.halfWidth < widest[r.riverId] * 1.3 + 20 then
				table.insert(e, label .. string.format(": halfWidth too small for its river, whose widest half width is %.1f", widest[r.riverId]))
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
	for _, rv in ipairs(plan.rivers) do
		local a, b = rv.points[1], rv.points[#rv.points]
		local route = Geo.polyline2(Route.points(rv)).length
		local width = Route.width(rv)
		local narrowest, widest = math.round(width.narrowest), math.round(width.widest)
		local span = if narrowest == widest then tostring(widest) else narrowest .. " to " .. widest
		table.insert(lines, string.format("%s: bed %.1f at %d %d, %.1f at %d %d, route %d studs, curve %s, meander %d, width %s%s", rv.id, ground(a[1], a[2]), a[1], a[2], ground(b[1], b[2]), b[1], b[2], route, tostring(rv.curve or 0), rv.meander or 0, span, if rv.loops and #rv.loops > 0 then ", loops " .. #rv.loops else ""))
	end
	for _, lk in ipairs(plan.lakes or {}) do
		table.insert(lines, string.format("%s: bed %.1f at %d %d, water level %d", lk.id, ground(lk.center[1], lk.center[2]), lk.center[1], lk.center[2], lk.waterLevel))
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
