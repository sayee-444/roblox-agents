-- The Depth Limit and the Destroy Height, through what the pure Generator refuses or reports.
-- The Depth Limit is the lowest height any bed or cave floor may take. The Destroy Height is where
-- Roblox removes what falls in the place, and the World Plan may declare it.

local shipped = require("../src/world/plan")
local Describe = require("../src/world/generator/Describe")

local function clone(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in pairs(v) do
		c[k] = clone(x)
	end
	return c
end

-- The engine's test map, with an Ocean over its eastern column at sea level 20.
local function deepPlan(changes)
	local plan = clone(shipped)
	plan.floorY = 0
	plan.rockUnder = 8
	plan.seaLevel = 20
	plan.oceans = { { id = "ocean", seed = 8001, chunks = { { 1, -1, 1, 1 } }, depthCap = 100 } }
	if changes then
		changes(plan)
	end
	return plan
end

local function refused(t, plan, expected)
	local errors = table.concat(Describe.validate(plan), "; ")
	t.ok(string.find(errors, expected, 1, true) ~= nil, "expected '" .. expected .. "', got '" .. errors .. "'")
end

return {
	["an Ocean whose bed lies below the Depth Limit is refused, naming it and by how much"] = function(t)
		refused(t, deepPlan(function(p)
			p.oceans[1].depthCap = 3600
		end), "ocean ocean: reaches -3580, 80 below the Depth Limit -3500")
	end,

	["a bed exactly at the Depth Limit passes, so the limit is the lowest height allowed"] = function(t)
		local errors = Describe.validate(deepPlan(function(p)
			p.oceans[1].depthCap = 3520
		end))
		t.eq(#errors, 0, table.concat(errors, "; "))
	end,

	["a Lake's asked depth and roughness count against the limit"] = function(t)
		refused(t, deepPlan(function(p)
			p.lakes = { { id = "lake", seed = 22, center = { -400, -700 }, radius = 60, shore = 30, warp = 10, bedY = -3496, bedRough = 8, waterLevel = 20 } }
		end), "lake lake: reaches -3504, 4 below the Depth Limit -3500")
	end,

	["a Lake's pools count against the limit"] = function(t)
		refused(t, deepPlan(function(p)
			p.lakes = { { id = "lake", seed = 22, center = { -400, -700 }, radius = 60, shore = 30, warp = 10, bedY = -3000, depthVary = 0.2, waterLevel = 20 } }
		end), "lake lake: reaches -3604, 104 below the Depth Limit -3500")
	end,

	["a Lake's depth from its size is its deepest, since its pools only make shallows there (ADR 0011)"] = function(t)
		-- Radius 425 gives a quarter of it, 106.25, under water at 20, with 2 of roughness.
		local text = Describe.heights(deepPlan(function(p)
			p.oceans = {}
			p.regions[4].points = { { 312, 69, 440 }, { 350, 69, 440 } }
			p.lakes = { { id = "lake", seed = 22, center = { -300, 300 }, radius = 425, shore = 60, warp = 10, bedRough = 2, banks = {}, waterLevel = 20 } }
		end))
		t.ok(string.find(text, "depth: deepest -88.25 in lake lake", 1, true) ~= nil, text)
	end,

	["a River's deepest asked depth counts against the limit"] = function(t)
		refused(t, deepPlan(function(p)
			p.rivers[1].bedY = nil
			p.rivers[1].depths = { 10, 10, 10, 10, 10, 3530 }
		end), "river river: reaches -3510, 10 below the Depth Limit -3500")
	end,

	["a Cave's floor, its lowest point less its widest radius, counts against the limit"] = function(t)
		refused(t, deepPlan(function(p)
			for _, point in ipairs(p.regions[4].points) do
				point[2] = -3490
			end
		end), "cave cave: reaches -3506.1, 6.1 below the Depth Limit -3500")
	end,

	["the World Plan may move the Depth Limit, deeper or shallower"] = function(t)
		local deeper = Describe.validate(deepPlan(function(p)
			p.depthLimit = -4800
			p.destroyHeight = -5000
			p.oceans[1].depthCap = 3600
		end))
		t.eq(#deeper, 0, table.concat(deeper, "; "))
		refused(t, deepPlan(function(p)
			p.depthLimit = -1000
			p.oceans[1].depthCap = 1100
		end), "ocean ocean: reaches -1080, 80 below the Depth Limit -1000")
	end,

	["a Depth Limit or Destroy Height out of range is refused"] = function(t)
		local cases = {
			{ "depthLimit must be a multiple of 4", function(p) p.depthLimit = -3502 end },
			{ "depthLimit must be a multiple of 4", function(p) p.depthLimit = "deep" end },
			{ "destroyHeight must be a whole number from -50000 to 50000", function(p) p.destroyHeight = -60000 end },
			{ "destroyHeight must be a whole number from -50000 to 50000", function(p) p.destroyHeight = "low" end },
			{ "destroyHeight must be a whole number from -50000 to 50000", function(p) p.destroyHeight = -4000.5 end },
			{ "depthLimit -3500 must lie above destroyHeight -3500", function(p) p.destroyHeight = -3500 end },
			{ "depthLimit -4000 must lie above destroyHeight -3600", function(p)
				p.depthLimit = -4000
				p.destroyHeight = -3600
			end },
		}
		for _, case in ipairs(cases) do
			refused(t, deepPlan(case[2]), case[1])
		end
	end,

	["heights names the deepest bed, what holds it, the Depth Limit and the Destroy Height"] = function(t)
		local text = Describe.heights(deepPlan())
		t.ok(string.find(text, "depth: deepest -80 in ocean ocean, 3420 above the Depth Limit -3500, Destroy Height not declared", 1, true) ~= nil, text)
		text = Describe.heights(deepPlan(function(p)
			p.destroyHeight = -4000
		end))
		t.ok(string.find(text, "depth: deepest -80 in ocean ocean, 3420 above the Depth Limit -3500, Destroy Height -4000", 1, true) ~= nil, text)
	end,
}
