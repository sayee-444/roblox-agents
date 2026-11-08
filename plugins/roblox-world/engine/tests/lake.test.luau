local shipped = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")
local Chunk = require("../src/world/generator/Chunk")

local function lakePlan(changes)
	local plan = {
		worldSeed = 4242,
		chunkSize = 512,
		voxel = 4,
		extent = { minX = 0, maxX = 1, minZ = -1, maxZ = 0 },
		floorY = -64,
		base = shipped.base,
		materials = shipped.materials,
		regions = { { id = "valley", kind = "valley", seed = 11, riverId = "river", halfWidth = 130, floorY = 24 } },
		rivers = { { id = "river", points = { { 0, 0 }, { 200, 0 }, { 450, 0 } }, halfWidth = 20, bedY = 10, waterLevel = 20 } },
		lakes = { { id = "lake", seed = 22, center = { 450, 0 }, radius = 120, shore = 60, warp = 20, elongate = 1.2, angle = 30, bedY = 6, waterLevel = 20 } },
		sites = {},
	}
	if changes then
		changes(plan)
	end
	return plan
end

local function deepRiver(p)
	p.floorY = 0
	p.rockUnder = 8
	p.lakes = {}
	p.rivers[1].bedY = -60
end

return {
	["a deep River's bed is a bowl, deepest in its middle"] = function(t)
		local plan = lakePlan(deepRiver)
		local middle = Shape.height(plan, 200.5, 1)
		local between = Shape.height(plan, 200.5, 7)
		local side = Shape.height(plan, 200.5, 13)
		t.ok(middle < between - 1, "middle " .. middle .. " below " .. between)
		t.ok(between < side - 1, between .. " below the side " .. side)
	end,

	["a shallow River keeps its flat bed"] = function(t)
		local plan = lakePlan()
		t.near(Shape.height(plan, 200.5, 1), Shape.height(plan, 200.5, 6), 0.5, "flat in its middle")
	end,

	["the wall of a deep Lake has no gap either"] = function(t)
		local plan = lakePlan(function(p)
			p.floorY = 0
			p.rockUnder = 8
			p.lakes[1].bedY = -60
		end)
		local cols = Chunk.columns(plan, 1, 0)
		local n, w = cols.n, cols.n + 2
		local checked = 0
		for j = 0, n - 1 do
			for i = 0, n - 1 do
				local bottom = cols.BOTTOM[j * n + i + 1]
				local p = (j + 1) * w + (i + 1) + 1
				for _, q in ipairs({ p - 1, p + 1, p - w, p + w }) do
					if cols.H[q] < 0 then
						checked += 1
						t.ok(bottom <= cols.H[q] - 8, "column " .. i .. "," .. j .. " stops at " .. bottom .. " beside a bed at " .. cols.H[q])
					end
				end
			end
		end
		t.ok(checked > 0, "the Lake goes below the floor here")
	end,

	["the wall of a deep bed has no gap: a column's ground reaches below the beds beside it"] = function(t)
		local plan = lakePlan(deepRiver)
		local cols = Chunk.columns(plan, 0, 0)
		local n, w = cols.n, cols.n + 2
		local checked = 0
		for j = 0, n - 1 do
			for i = 0, n - 1 do
				local bottom = cols.BOTTOM[j * n + i + 1]
				local p = (j + 1) * w + (i + 1) + 1
				for _, q in ipairs({ p - 1, p + 1, p - w, p + w }) do
					if cols.H[q] < 0 then
						checked += 1
						t.ok(bottom <= cols.H[q] - 8, "column " .. i .. "," .. j .. " stops at " .. bottom .. " beside a bed at " .. cols.H[q])
					end
				end
			end
		end
		t.ok(checked > 0, "the River goes below the floor here")
	end,

	["a lake holds water over a bed below its level"] = function(t)
		local plan = lakePlan()
		local h, _, _, water = Shape.height(plan, 450, 0)
		t.eq(water, 20, "water level at the centre")
		t.ok(h < 12, "deep at the centre: " .. h)
		local beside, _, _, beyond = Shape.height(plan, 450, 60)
		t.eq(beyond, 20, "water away from the River's route")
		t.ok(beside < 20, "the bed lies under it: " .. beside)
	end,

	["a River reaches the lake's water with no dam across it"] = function(t)
		local plan = lakePlan()
		for x = 100, 450, 4 do
			local h, _, _, water = Shape.height(plan, x, 0)
			t.eq(water, 20, "water at x " .. x)
			t.ok(h < 20, "bed under the water at x " .. x .. ": " .. h)
		end
	end,

	["the ground around a lake stays dry and rises away from it"] = function(t)
		local plan = lakePlan()
		for _, angle in ipairs({ 90, 135, 225, 270 }) do
			local a = math.rad(angle)
			local inner = Shape.height(plan, 450 + math.cos(a) * 190, math.sin(a) * 190)
			local _, _, _, water = Shape.height(plan, 450 + math.cos(a) * 250, math.sin(a) * 250)
			t.eq(water, 0, "dry past the shore at angle " .. angle)
			t.ok(inner >= 20 - 1, "the shore holds the water at angle " .. angle .. ": " .. inner)
		end
	end,

	["the shore is sand"] = function(t)
		local plan = lakePlan()
		local _, _, waterDistance = Shape.height(plan, 450, 130)
		t.ok(waterDistance < plan.materials.bankDist + 30, "distance to the water near the shore: " .. waterDistance)
		local _, _, centre = Shape.height(plan, 450, 0)
		t.eq(centre, 0, "the centre is in the water")
	end,

	["nothing changes beyond a lake's bounds"] = function(t)
		local plan = lakePlan()
		local dry = lakePlan(function(p)
			p.lakes = {}
		end)
		local b = Shape.bounds(plan, "lake")
		t.ok(b[1] < 450 and b[3] > 450 and b[2] < 0 and b[4] > 0, "the bounds hold the lake")
		for z = -700, 700, 40 do
			local x = b[3] + 8
			t.eq((Shape.height(plan, x, z)), (Shape.height(dry, x, z)), "east of the bounds at z " .. z)
		end
		local h = Shape.height(plan, 450, b[2] - 8)
		t.eq(h, (Shape.height(dry, 450, b[2] - 8)), "north of the bounds")
	end,

	["a lake is deterministic"] = function(t)
		local plan = lakePlan()
		for i = 1, 40 do
			local x, z = 300 + i * 7, -150 + i * 8
			t.eq((Shape.height(plan, x, z)), (Shape.height(plan, x, z)), "same position")
		end
	end,

	["describe lists a lake with the Chunks it touches"] = function(t)
		local plan = lakePlan()
		t.eq(#Describe.validate(plan), 0, table.concat(Describe.validate(plan), "; "))
		local report = Describe.report(plan, { chunks = {} })
		t.eq(report.regions.lake.kind, "lake", "kind")
		t.ok(#report.regions.lake.chunks >= 1, "it touches a Chunk")
	end,

	["heights report a lake's bed and level"] = function(t)
		t.ok(Describe.heights(lakePlan()):find("lake: bed", 1, true) ~= nil, "lake line")
	end,

	["validation catches a bad lake"] = function(t)
		local errors = Describe.validate(lakePlan(function(p)
			p.lakes[1].waterLevel = 21
			p.lakes[1].radius = 0
		end))
		t.ok(#errors >= 2, "errors found: " .. #errors)
	end,

	["a lake without banks needs bedY, since its depth cannot follow the ground"] = function(t)
		local errors = table.concat(Describe.validate(lakePlan(function(p)
			p.lakes[1].bedY = nil
		end)), "; ")
		t.ok(errors:find("bedY", 1, true) ~= nil, errors)
	end,

	["a River ending in a lake must share its water level"] = function(t)
		local errors = Describe.validate(lakePlan(function(p)
			p.lakes[1].waterLevel = 24
		end))
		t.eq(#errors, 1, table.concat(errors, "; "))
		t.ok(errors[1]:find("river", 1, true) ~= nil, errors[1])
	end,
}
