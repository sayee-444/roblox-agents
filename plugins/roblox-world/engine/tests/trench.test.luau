-- Trenches, through what the pure Generator returns for a position and what it refuses or reports.
-- A Trench lowers an Ocean's bed within its half width, down to a floor given as a height at each route point.

local shipped = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")
local Chunk = require("../src/world/generator/Chunk")
local Materials = require("../src/world/generator/Materials")

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

-- Land in Chunk column -1, so the coast lies at x -256, and an Ocean from column 0 to 14 capped at 100: past 400 studs
-- from the coast its bed lies flat at -80. A Trench runs north to south at x 3000, 300 studs to each side, falling
-- 1 stud per stud from that bed to a floor at -300, with no roughness, so every height below is worked out by hand.
local function trenchPlan(changes)
	local plan = clone(shipped)
	plan.floorY = 0
	plan.rockUnder = 8
	plan.seaLevel = 20
	plan.extent = { minX = -1, maxX = 14, minZ = -1, maxZ = 1 }
	plan.oceans = { { id = "ocean", seed = 8001, chunks = { { 0, -1, 14, 1 } }, depthCap = 100 } }
	plan.rivers, plan.lakes = {}, {}
	plan.regions = {
		{ id = "trench", kind = "trench", seed = 9001, points = { { 3000, -400 }, { 3000, 400 } }, floors = { -300, -300 }, halfWidth = 300, walls = 1, rough = 0 },
	}
	if changes then
		changes(plan, plan.regions[1])
	end
	return plan
end

local function ground(plan, x, z)
	return (Shape.height(plan, x, z))
end

return {
	["the ground reaches the floor on the route and climbs its walls to the Ocean's bed at the half width"] = function(t)
		local plan = trenchPlan()
		for _, p in ipairs({
			{ 3000, 0, -300 },
			{ 3000, 400, -300 },
			{ 3050, -200, -300 }, -- 50 out, the walls would still lie below the floor
			{ 3100, 0, -280 },
			{ 2750, 0, -130 },
			{ 3000, 600, -180 }, -- 200 past the end of the route
			{ 3300, 0, -80 },
			{ 3400, 0, -80 },
			{ 3000, 750, -80 },
		}) do
			t.near(ground(plan, p[1], p[2]), p[3], 1e-6, "ground at " .. p[1] .. " " .. p[2])
		end
		local _, _, _, level, body, trench = Shape.height(plan, 3000, 0)
		t.eq(level, 20, "the sea level stands over it")
		t.eq(body, "ocean", "the Ocean's water covers it")
		t.eq(trench, "trench", "the Trench lowers it")
		local _, _, _, _, _, none = Shape.height(plan, 3400, 0)
		t.eq(none, nil, "beyond its half width no Trench lowers the bed")
	end,

	["a floor given per point deepens the Trench towards one end"] = function(t)
		local plan = trenchPlan(function(_, tr)
			tr.points = { { 3000, -300 }, { 3000, 300 } }
			tr.floors = { -300, -500 }
			tr.halfWidth = 450
		end)
		t.near(ground(plan, 3000, -300), -300, 1e-6, "at the first point")
		t.near(ground(plan, 3000, 0), -400, 1e-6, "halfway")
		t.near(ground(plan, 3000, 300), -500, 1e-6, "at the last point")
		t.near(ground(plan, 3400, 0), -130, 1e-6, "400 out, on the wall")
	end,

	["a route bends at its points"] = function(t)
		local plan = trenchPlan(function(_, tr)
			tr.points = { { 2600, -400 }, { 3000, 0 }, { 2600, 400 } }
			tr.floors = { -300, -300, -300 }
		end)
		t.near(ground(plan, 2800, -200), -300, 1e-6, "on the first leg")
		t.near(ground(plan, 2800, 200), -300, 1e-6, "on the second leg")
		t.near(ground(plan, 3200, 0), -180, 1e-6, "200 beyond the bend")
	end,

	["a short route gives a round pit"] = function(t)
		local plan = trenchPlan(function(_, tr)
			tr.points = { { 3000, 0 }, { 3000, 4 } }
		end)
		t.near(ground(plan, 3000, 2), -300, 1e-6, "its middle")
		for k = 0, 7 do
			local a = k * math.pi / 4
			t.near(ground(plan, 3000 + 150 * math.cos(a), 2 + 150 * math.sin(a)), -230, 2.01, "150 out, direction " .. k)
		end
	end,

	["its floors are heights, which a change to the Ocean's cap or coast never moves"] = function(t)
		local capped = trenchPlan(function(p)
			p.oceans[1].depthCap = 60
		end)
		t.near(ground(capped, 3000, 0), -300, 1e-6, "the floor under a shallower Ocean")
		t.near(ground(capped, 3400, 0), -40, 1e-6, "the Ocean's bed beyond it follows the cap")
		local landed = trenchPlan(function(p)
			p.oceans[1].chunks = { { 1, -1, 14, 1 } }
		end)
		t.near(ground(landed, 3000, 0), -300, 1e-6, "the floor once land is added elsewhere")
	end,

	["its Region Seed roughens the walls and floor, and another seed changes only the Trench"] = function(t)
		local a = trenchPlan(function(_, tr)
			tr.rough = 40
		end)
		local again = trenchPlan(function(_, tr)
			tr.rough = 40
		end)
		local b = trenchPlan(function(_, tr)
			tr.rough = 40
			tr.seed = 9002
		end)
		local differs = false
		for x = 2700, 3300, 20 do
			for z = -600, 600, 100 do
				local h = ground(a, x, z)
				t.eq(ground(again, x, z), h, "the same seed gives the same ground at " .. x .. " " .. z)
				differs = differs or math.abs(ground(b, x, z) - h) > 1
				t.ok(h >= -300, "no ground below its floor at " .. x .. " " .. z)
			end
		end
		t.ok(differs, "another seed moves its walls or floor")
		for _, p in ipairs({ { 3300, 0 }, { 2690, 100 }, { 3000, 710 }, { 3600, -500 } }) do
			t.eq(ground(b, p[1], p[2]), -80, "the Ocean beyond the half width at " .. p[1] .. " " .. p[2])
		end
		local smooth = trenchPlan()
		local rough = 0
		for z = -400, 400, 8 do
			local h = ground(a, 3000, z)
			t.ok(h <= -260, "the floor rises at most its rough, at z " .. z)
			rough = math.max(rough, math.abs(h - ground(smooth, 3000, z)))
		end
		t.ok(rough > 1, "the floor is uneven")
	end,

	["two Trenches that meet take the deeper of them"] = function(t)
		local plan = trenchPlan(function(p)
			table.insert(p.regions, { id = "cross", kind = "trench", seed = 9003, points = { { 2600, 0 }, { 3400, 0 } }, floors = { -500, -500 }, halfWidth = 450, walls = 1, rough = 0 })
		end)
		t.near(ground(plan, 3000, 0), -500, 1e-6, "where they cross")
		t.near(ground(plan, 3000, 300), -300, 1e-6, "on the shallower one's route, above the deeper one's wall")
		t.eq(#Describe.validate(plan), 0, table.concat(Describe.validate(plan), "; "))
	end,

	["a sound Trench passes validation, with its defaults for what it leaves out"] = function(t)
		local errors = Describe.validate(trenchPlan())
		t.eq(#errors, 0, table.concat(errors, "; "))
		local defaults = trenchPlan(function(p, tr)
			p.extent = { minX = -1, maxX = 14, minZ = -3, maxZ = 3 }
			p.oceans[1].chunks = { { 0, -3, 14, 3 } }
			tr.points = { { 4000, -300 }, { 4000, 300 } }
			tr.floors = { -900, -900 }
			tr.halfWidth, tr.walls, tr.rough = nil, nil, nil
		end)
		local found = Describe.validate(defaults)
		t.eq(#found, 0, table.concat(found, "; "))
		t.ok(ground(defaults, 4000, 0) < -800, "the defaults reach near its floor")
		local atLimit = Describe.validate(trenchPlan(function(p)
			p.depthLimit = -300
		end))
		t.eq(#atLimit, 0, "a floor on the Depth Limit: " .. table.concat(atLimit, "; "))
	end,

	["a Trench outside an Ocean, or with numbers out of range, is refused and named"] = function(t)
		local cases = {
			{ "region trench: its half width reaches Chunk -1,-1, which no Ocean holds", function(_, tr)
				tr.points = { { 0, -400 }, { 0, 400 } }
			end },
			{ "region trench: its half width reaches Chunk -1,0, which no Ocean holds", function(p, tr)
				p.lakes = { { id = "lake", seed = 7006, center = { -500, 0 }, radius = 100, shore = 60, warp = 10, bedY = 0, waterLevel = 20 } }
				tr.points = { { 0, -50 }, { 0, 50 } }
			end },
			{ "region trench: its half width reaches Chunk 5,2, outside the extent", function(_, tr)
				tr.points = { { 3000, -400 }, { 3000, 600 } }
			end },
			-- Land added under a Trench is refused until the Trench moves.
			{ "region trench: its half width reaches Chunk 6,-1, which no Ocean holds", function(p)
				p.oceans[1].chunks = { { 0, -1, 5, 1 }, { 7, -1, 14, 1 } }
			end },
			{ "region trench: its half width reaches Chunk 5,-1, which no Ocean holds", function(p)
				p.oceans = {}
			end },
			{ "trench trench: reaches -300, 20 below the Depth Limit -280", function(p)
				p.depthLimit = -280
			end },
			{ "region trench: its floor -50 at point 1 is not below the Ocean's bed -80.0 there", function(_, tr)
				tr.floors = { -50, -300 }
			end },
			{ "region trench: its walls reach only 150 below the Ocean's bed at 3000 -400, short of its floor -300 by 70", function(_, tr)
				tr.walls = 0.5
			end },
			{ "region trench: needs at least 2 route points", function(_, tr)
				tr.points = { { 3000, 0 } }
				tr.floors = { -300 }
			end },
			{ "region trench: points 1 and 2 are the same", function(_, tr)
				tr.points = { { 3000, 0 }, { 3000, 0 } }
			end },
			{ "region trench: floors needs one height per point", function(_, tr)
				tr.floors = { -300 }
			end },
			{ "region trench: floors needs one height per point", function(_, tr)
				tr.floors = nil
			end },
			{ "region trench: floor 2 must be a number", function(_, tr)
				tr.floors = { -300, "deep" }
			end },
			{ "region trench: halfWidth must be above its rough", function(_, tr)
				tr.halfWidth = 0
			end },
			{ "region trench: halfWidth must be above its rough", function(_, tr)
				tr.rough = 300
			end },
			{ "region trench: rough must be 0 or more", function(_, tr)
				tr.rough = -1
			end },
			{ "region trench: walls must be from 0.1 to 5, as rise over run", function(_, tr)
				tr.walls = 0
			end },
			{ "region trench: walls must be from 0.1 to 5, as rise over run", function(_, tr)
				tr.walls = 6
			end },
			{ "region trench: has no field floor", function(_, tr)
				tr.floor = -300
			end },
		}
		for _, case in ipairs(cases) do
			local errors = table.concat(Describe.validate(trenchPlan(case[2])), "; ")
			t.ok(string.find(errors, case[1], 1, true) ~= nil, "expected '" .. case[1] .. "', got '" .. errors .. "'")
		end
	end,

	["only the Chunks a Trench reaches are written column by column, and the open Ocean stays plain blocks"] = function(t)
		local plan = trenchPlan()
		-- Chunk 6 covers x 2816 to 3328 and Chunk 5 x 2304 to 2816, both within the half width of x 2700 to 3300.
		t.eq(Chunk.columns(plan, 6, 0).flat, nil, "the Chunk holding its route")
		t.eq(Chunk.columns(plan, 5, 0).flat, nil, "the Chunk its wall reaches")
		for _, i in ipairs({ 4, 7, 10 }) do
			t.ok(Chunk.columns(plan, i, 0).flat ~= nil, "open Ocean Chunk " .. i .. ",0")
		end
	end,

	["a Trench's walls and floor are deep rock, not a beach"] = function(t)
		local cols = Chunk.columns(trenchPlan(), 6, 0)
		local rocky = { [Materials.id.Rock] = true, [Materials.id.Slate] = true }
		-- Chunk 6,0 starts at x 2816 and z -256, so column (i, j) is centred at x 2818 + 4i and z -254 + 4j.
		for _, i in ipairs({ 42, 46, 50, 70, 83, 100, 115 }) do
			for _, j in ipairs({ 10, 64, 120 }) do
				local s = cols.S[j * cols.n + i + 1]
				t.ok(rocky[s], "column at x " .. (2818 + 4 * i) .. " z " .. (-254 + 4 * j) .. " is " .. Materials.names[s])
			end
		end
	end,

	["describe names exactly the Chunks a Trench reaches"] = function(t)
		local report = Describe.report(trenchPlan(), { chunks = {} })
		t.eq(report.regions.trench.kind, "trench", "kind")
		t.eq(table.concat(report.regions.trench.chunks, " "), "5,-1 6,-1 5,0 6,0 5,1 6,1", "chunks")
		-- A diagonal from 2400 -600 to 3600 600, 40 studs to each side: its box would hold 9 Chunks, and it reaches 5.
		local diagonal = trenchPlan(function(_, tr)
			tr.points = { { 2400, -600 }, { 3600, 600 } }
			tr.floors = { -200, -200 }
			tr.halfWidth, tr.walls = 40, 5
		end)
		t.eq(#Describe.validate(diagonal), 0, table.concat(Describe.validate(diagonal), "; "))
		t.eq(table.concat(Describe.report(diagonal, { chunks = {} }).regions.trench.chunks, " "), "5,-1 5,0 6,0 6,1 7,1", "a diagonal")
		t.eq(Chunk.columns(diagonal, 7, -1).flat ~= nil, true, "a Chunk its box holds and it does not reach stays plain blocks")
	end,

	["heights names each Trench's deepest point, its floor and the Ocean's bed beside it"] = function(t)
		local flat = Describe.heights(trenchPlan())
		t.ok(string.find(flat, "trench: deepest %-300%.0 at 3000 %-?%d+, floor %-300%.0 there, the Ocean's bed %-80%.0 beside it, 6 Chunks") ~= nil, flat)
		local sloped = Describe.heights(trenchPlan(function(_, tr)
			tr.points = { { 3000, -300 }, { 3000, 300 } }
			tr.floors = { -300, -500 }
			tr.halfWidth = 450
		end))
		t.ok(string.find(sloped, "trench: deepest %-500%.0 at 3000 300, floor %-500%.0 there, the Ocean's bed %-80%.0 beside it") ~= nil, sloped)
		t.ok(string.find(sloped, "depth: deepest %-500 in trench trench") ~= nil, sloped)
	end,
}
