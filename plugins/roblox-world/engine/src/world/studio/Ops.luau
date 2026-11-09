--!nonstrict
-- Named operations on the map, so a run calls them instead of writing Luau. Runs in Studio
-- Edit mode only. Each operation skips or refuses Locked Chunks and returns exact facts.

local plan = require("../plan")
local state = require("../state")
local Gen = require("../generator/Generator")
local Writer = require("./Writer")

local Ops = {}

local function isLocked(ci, cj)
	local entry = state.chunks[Gen.Chunk.key(ci, cj)]
	return entry ~= nil and entry.locked == true
end

local function eachChunk(fn)
	local e = plan.extent
	for cj = e.minZ, e.maxZ do
		for ci = e.minX, e.maxX do
			fn(ci, cj)
		end
	end
end

local function isGenerated(ci, cj)
	local entry = state.chunks[Gen.Chunk.key(ci, cj)]
	return entry ~= nil and entry.generated == true
end

local function eachGenerated(fn)
	eachChunk(function(ci, cj)
		if isGenerated(ci, cj) then
			fn(ci, cj)
		end
	end)
end

-- Says whether terrain was written since the last call, and clears it. It lives in `shared`, which
-- stays between commands and goes away with the Studio session, as a stale render does.
function Ops.takeRenderStale()
	local stale = shared.World.renderStale == true
	shared.World.renderStale = false
	return stale
end

function Ops.markRenderStale()
	shared.World.renderStale = true
	return "stale"
end

local function sameData(a, b)
	return a.s1 == b.s1 and a.s2 == b.s2 and a.solid == b.solid and a.liquid == b.liquid
end

-- Validation errors and the describe report.
function Ops.describe()
	local errors = Gen.Describe.validate(plan)
	if #errors > 0 then
		return "INVALID PLAN\n" .. table.concat(errors, "\n")
	end
	return Gen.Describe.format(Gen.Describe.report(plan, state))
end

-- What a write must know about falling, as JSON: the place's Destroy Height, the plan's Depth Limit and
-- Destroy Height, and its deepest bed or cave floor, or the plan's errors when it is invalid. Writes nothing.
function Ops.depthFacts()
	local facts = {
		placeHeight = workspace.FallenPartsDestroyHeight,
		depthLimit = Gen.Shape.depthLimit(plan),
		destroyHeight = plan.destroyHeight,
	}
	local errors = Gen.Describe.validate(plan)
	if #errors > 0 then
		facts.invalid = errors
	else
		local _, deepest = Gen.Describe.depthLine(plan)
		facts.deepest = deepest
	end
	return game:GetService("HttpService"):JSONEncode(facts)
end

-- Sets the place's Destroy Height and returns it as read back. Roblox lets plugins and the command bar set
-- it, which is how code from Studio's MCP server runs, measured on 2026-11-08, and no running game can.
function Ops.setDestroyHeight(height)
	workspace.FallenPartsDestroyHeight = height
	return workspace.FallenPartsDestroyHeight
end

-- What a change would rewrite and which Locked Chunks it reaches, as JSON. Writes nothing.
function Ops.impact(change)
	local impact = Gen.Describe.impact(plan, state, change)
	return game:GetService("HttpService"):JSONEncode(impact)
end

-- Writes the given Chunks, as a list of { i, j }, or every Chunk of the extent when none is
-- given. Skips Locked Chunks, records the rest as generated and reports seconds per Chunk.
function Ops.generate(list)
	local t = workspace.Terrain
	local seconds, skipped = {}, {}
	local total = 0
	local function write(ci, cj)
		local key = Gen.Chunk.key(ci, cj)
		if isLocked(ci, cj) then
			table.insert(skipped, key)
			return
		end
		local stats = Writer.writeChunk(t, plan, Gen, ci, cj)
		shared.World.renderStale = true
		table.insert(seconds, stats.wall)
		total += stats.wall
		state.chunks[key] = { generated = true, locked = false }
		task.wait()
	end
	if list then
		for _, c in ipairs(list) do
			write(c[1], c[2])
		end
	else
		eachChunk(write)
	end
	if #seconds == 0 then
		return "generated 0 Chunks, skipped Locked: " .. table.concat(skipped, " ")
	end
	return string.format(
		"generated %d Chunks in %.2f s, per Chunk min %.2f mean %.2f max %.2f, skipped Locked: %s",
		#seconds, total, math.min(table.unpack(seconds)), total / #seconds, math.max(table.unpack(seconds)),
		if #skipped > 0 then table.concat(skipped, " ") else "none"
	)
end

-- Reads voxels on both sides of each border between two generated Chunks and compares them with
-- the Generator. With a list of { i, j }, only the borders touching those Chunks. Lists only the
-- borders that disagree.
function Ops.borders(list)
	local t = workspace.Terrain
	local count, voxels, mat, occ, liq, worstErr, worstCross, worstInside = 0, 0, 0, 0, 0, 0, 0, 0
	local bad = {}
	for _, border in ipairs(Gen.Describe.bordersOf(plan, state, list)) do
		local r = Writer.borderReport(t, plan, Gen, border.axis, border.ci, border.cj)
		count += 1
		voxels += r.voxelsCompared
		mat += r.matMismatch
		occ += r.occMismatch
		liq += r.liqMismatch
		worstErr = math.max(worstErr, r.maxOccErr)
		worstCross = math.max(worstCross, r.maxCross)
		worstInside = math.max(worstInside, r.maxInside)
		if r.matMismatch + r.occMismatch + r.liqMismatch > 0 then
			table.insert(bad, r.axis .. " " .. r.between)
		end
		task.wait()
	end
	return string.format(
		"%d borders, %d voxels: material %d, occupancy %d, water %d mismatches; worst occupancy error %.4f; surface step max %.2f across, %.2f inside; disagreeing: %s",
		count, voxels, mat, occ, liq, worstErr, worstCross, worstInside,
		if #bad > 0 then table.concat(bad, "; ") else "none"
	)
end

-- Wipes one Chunk, writes it again and compares checksums. The wipe is the control: it must
-- change the checksum, or the comparison proves nothing. Refuses a Locked Chunk.
function Ops.verify(ci, cj)
	if isLocked(ci, cj) then
		return "refused: Chunk " .. Gen.Chunk.key(ci, cj) .. " is Locked"
	end
	local t = workspace.Terrain
	local cols = Gen.Chunk.columns(plan, ci, cj, Writer.breather())
	local before = Writer.checksum(t, plan, Gen, ci, cj, cols.ymin, cols.ymax)
	task.wait()
	Writer.clear(t, plan, Gen, ci, cj, cols.ymin, cols.ymax)
	task.wait()
	local wiped = Writer.checksum(t, plan, Gen, ci, cj, cols.ymin, cols.ymax)
	local stats = Writer.writeChunk(t, plan, Gen, ci, cj, { cols = cols })
	shared.World.renderStale = true
	task.wait()
	local after = Writer.checksum(t, plan, Gen, ci, cj, cols.ymin, cols.ymax)
	return string.format(
		"Chunk %s: identical=%s, wipe changed checksum=%s, solid %d, water %d, rewrite %.2f s",
		Gen.Chunk.key(ci, cj), tostring(sameData(before, after)), tostring(not sameData(before, wiped)),
		after.solid, after.liquid, stats.wall
	)
end

-- Surface height at a world position, from the pure function. Use it to place a cave.
function Ops.height(x, z)
	return string.format("%.1f", (Gen.Shape.height(plan, x, z)))
end

-- What a run needs to know about each Landform and River, from the pure function.
function Ops.heights()
	return Gen.Describe.heights(plan)
end

-- Puts the SpawnLocation on the ground, and removes the template Baseplate only when asked.
function Ops.placeSpawn(removeBaseplate)
	local notes = {}
	local spawnPoint = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnPoint then
		local p = spawnPoint.Position
		local y = (Gen.Shape.height(plan, p.X, p.Z)) + spawnPoint.Size.Y / 2
		spawnPoint.Position = Vector3.new(p.X, y, p.Z)
		table.insert(notes, string.format("spawn on the ground at y %.1f", y))
	end
	local base = workspace:FindFirstChild("Baseplate")
	if base and removeBaseplate then
		base:Destroy()
		table.insert(notes, "Baseplate removed")
	elseif base then
		table.insert(notes, "Baseplate kept")
	end
	return table.concat(notes, ", ")
end

-- What wiping would lose, as JSON. Writes nothing.
function Ops.wipeFacts()
	local generated, locked = 0, {}
	for key, entry in pairs(state.chunks) do
		if entry.generated == true then
			generated += 1
		end
		if entry.locked == true then
			table.insert(locked, key)
		end
	end
	table.sort(locked)
	return game:GetService("HttpService"):JSONEncode({
		cells = workspace.Terrain:CountCells(),
		generated = generated,
		locked = locked,
	})
end

-- Deletes all terrain and forgets every Chunk, Locked ones included. Only tools/world.js calls
-- this, after the developer has confirmed. Returns the cells left, as JSON.
function Ops.wipe()
	local t = workspace.Terrain
	local started = os.clock()
	t:Clear()
	state.chunks = {}
	task.wait()
	return game:GetService("HttpService"):JSONEncode({
		cellsAfter = t:CountCells(),
		seconds = os.clock() - started,
	})
end

-- Source of the current generation state. Locked Chunks stay as they were.
function Ops.stateSource()
	local lines = { "return {", "\tgeneratorVersion = " .. tostring(state.generatorVersion or 1) .. ",", "\tchunks = {" }
	eachChunk(function(ci, cj)
		local entry = state.chunks[Gen.Chunk.key(ci, cj)]
		if entry then
			table.insert(lines, string.format('\t\t["%s"] = { generated = %s, locked = %s },', Gen.Chunk.key(ci, cj), tostring(entry.generated == true), tostring(entry.locked == true)))
		end
	end)
	table.insert(lines, "\t},")
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

-- The capture set, derived from the plan: an overview, then one view from above and one from
-- the ground per Landform, with the ground camera on the lowest side that stays on the map.
function Ops.views()
	local e, S = plan.extent, plan.chunkSize
	local minX, maxX = e.minX * S - S / 2, (e.maxX + 1) * S - S / 2
	local minZ, maxZ = e.minZ * S - S / 2, (e.maxZ + 1) * S - S / 2
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local span = math.max(maxX - minX, maxZ - minZ)
	local function h(x, z)
		return (Gen.Shape.height(plan, x, z))
	end
	local views = {}
	local function add(name, camera, look)
		table.insert(views, { name = name, camera = camera, look = look })
	end
	local function around(x, z, distance)
		local best
		for _, d in ipairs({ { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }) do
			local px, pz = x + d[1] * distance, z + d[2] * distance
			if px > minX and px < maxX and pz > minZ and pz < maxZ then
				local ground = h(px, pz)
				if not best or ground < best.ground then
					best = { x = px, z = pz, ground = ground }
				end
			end
		end
		return best or { x = x, z = z, ground = h(x, z) }
	end
	local function landform(name, x, z, distance, eye)
		local top = h(x, z)
		local above = around(x, z, distance * 0.8)
		add(name .. "-above", { above.x, top + distance, above.z }, { x, top, z })
		local ground = around(x, z, distance)
		add(name .. "-ground", { ground.x, ground.ground + eye, ground.z }, { x, top, z })
	end
	local function middle(points)
		local p = points[math.ceil(#points / 2)]
		return p[1], p[2]
	end

	add("overview", { cx, span * 0.52, cz + span * 0.455 }, { cx, 40, cz })

	-- Hills: the Chunk centre farthest from every declared Landform.
	local marks = {}
	for _, r in ipairs(plan.regions) do
		if r.kind == "mountain" then
			for _, p in ipairs(r.points) do
				table.insert(marks, p)
			end
		elseif r.kind == "mesa" then
			table.insert(marks, r.center)
		elseif r.kind == "cave" then
			table.insert(marks, { r.points[1][1], r.points[1][3] })
		end
	end
	for _, rv in ipairs(plan.rivers) do
		for _, p in ipairs(rv.points) do
			table.insert(marks, p)
		end
	end
	for _, lk in ipairs(plan.lakes or {}) do
		table.insert(marks, lk.center)
	end
	local hillX, hillZ, farthest = cx, cz, -1
	eachGenerated(function(ci, cj)
		local x, z = ci * S, cj * S
		local near = math.huge
		for _, m in ipairs(marks) do
			near = math.min(near, math.sqrt((x - m[1]) ^ 2 + (z - m[2]) ^ 2))
		end
		if near > farthest then
			hillX, hillZ, farthest = x, z, near
		end
	end)
	landform("hills", hillX, hillZ, 180, 25)

	for _, r in ipairs(plan.regions) do
		if r.kind == "mountain" then
			local x, z = middle(r.points)
			landform(r.id, x, z, 300, 40)
		elseif r.kind == "mesa" then
			landform(r.id, r.center[1], r.center[2], 320, 30)
		end
	end
	for _, rv in ipairs(plan.rivers) do
		local x, z = middle(rv.points)
		landform(rv.id, x, z, 140, 16)
	end
	for _, lk in ipairs(plan.lakes or {}) do
		landform(lk.id, lk.center[1], lk.center[2], 300, 16)
	end
	for _, r in ipairs(plan.regions) do
		if r.kind == "cave" then
			local a, b = r.points[1], r.points[2]
			local dx, dz = b[1] - a[1], b[3] - a[3]
			local length = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / length, dz / length
			local mx, mz = a[1] - dx * 70, a[3] - dz * 70
			add(r.id .. "-mouth", { mx, math.max(a[2], h(mx, mz) + 4), mz }, { a[1], a[2], a[3] })
			local inner = r.points[math.min(3, #r.points)]
			add(r.id .. "-inside", { a[1] + dx * 24, a[2], a[3] + dz * 24 }, { inner[1], inner[2], inner[3] })
		end
	end
	return game:GetService("HttpService"):JSONEncode(views)
end

return Ops
