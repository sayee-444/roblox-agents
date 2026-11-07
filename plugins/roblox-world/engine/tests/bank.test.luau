local shipped = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")
local Materials = require("../src/world/generator/Materials")

local WATER = 20
local WIDTH = 40 -- the bank wanders within about 6 studs of this

local function riverPlan(fields, seed, valleyFields)
	local rv = { id = "r", points = { { 0, 0 }, { 500, 0 }, { 1000, 0 } }, halfWidth = WIDTH, depths = { 40, 40, 40 }, waterLevel = WATER }
	for k, v in pairs(fields or {}) do
		rv[k] = v
	end
	local valley = { id = "v", kind = "valley", seed = seed or 1, riverId = "r", halfWidth = 300, floorY = 24 }
	for k, v in pairs(valleyFields or {}) do
		valley[k] = v
	end
	return {
		worldSeed = 4242,
		chunkSize = 512,
		voxel = 4,
		extent = { minX = 0, maxX = 1, minZ = -1, maxZ = 0 },
		floorY = 0,
		base = shipped.base,
		materials = shipped.materials,
		regions = { valley },
		rivers = { rv },
		lakes = {},
		sites = {},
	}
end

local function lakePlan(fields, seed)
	local lake = { id = "l", seed = seed or 22, center = { 450, 0 }, radius = 120, shore = 60, warp = 0, bedY = -60, waterLevel = WATER }
	for k, v in pairs(fields or {}) do
		lake[k] = v
	end
	return {
		worldSeed = 4242,
		chunkSize = 512,
		voxel = 4,
		extent = { minX = 0, maxX = 1, minZ = -1, maxZ = 0 },
		floorY = 0,
		base = shipped.base,
		materials = shipped.materials,
		regions = {},
		rivers = {},
		lakes = { lake },
		sites = {},
	}
end

local function ground(plan, x, z)
	return (Shape.height(plan, x, z))
end

local function errorsOf(plan)
	return table.concat(Describe.validate(plan), "\n")
end

-- Where the ground crosses the water's level, walking from (x, z) along (dx, dz), which starts under the water.
local function waterline(plan, x, z, dx, dz)
	local wet, dry = 0, 0
	for step = 1, 400 do
		if ground(plan, x + dx * step, z + dz * step) >= WATER then
			dry = step
			break
		end
		wet = step
	end
	for _ = 1, 40 do
		local mid = (wet + dry) / 2
		if ground(plan, x + dx * mid, z + dz * mid) >= WATER then
			dry = mid
		else
			wet = mid
		end
	end
	return (wet + dry) / 2
end

-- The slope just under the water and just above it, measured over `run` studs on each side of the waterline.
local function slopesAtWaterline(plan, x, z, dx, dz, run)
	local at = waterline(plan, x, z, dx, dz)
	local under = (WATER - ground(plan, x + dx * (at - run), z + dz * (at - run))) / run
	local above = (ground(plan, x + dx * (at + run), z + dz * (at + run)) - WATER) / run
	return under, above, at
end

-- The surface material at a spot, with the slope taken from its neighbours as a Chunk takes it.
local function surfaceAt(plan, x, z)
	local h, mesaP, riverD, water = Shape.height(plan, x, z)
	local gx = (ground(plan, x + 4, z) - ground(plan, x - 4, z)) / 8
	local gz = (ground(plan, x, z + 4) - ground(plan, x, z - 4)) / 8
	return Materials.surface(plan, x, z, h, math.sqrt(gx * gx + gz * gz), mesaP, riverD, water)
end

-- The steepest fall between two spots `run` studs apart, walking from the deepest line out to the waterline.
local function steepestUnder(plan, x, z, dx, dz, run)
	local at = waterline(plan, x, z, dx, dz)
	local steepest = 0
	for d = 0, at - run, 1 do
		local a = ground(plan, x + dx * d, z + dz * d)
		local b = ground(plan, x + dx * (d + run), z + dz * (d + run))
		steepest = math.max(steepest, math.abs(b - a) / run)
	end
	return steepest
end

return {
	["the ground keeps its slope across the waterline, with no break"] = function(t)
		local plan = riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.3 })
		for x = 100, 900, 80 do
			for _, dz in ipairs({ 1, -1 }) do
				local under, above = slopesAtWaterline(plan, x, 0, 0, dz, 1)
				t.ok(under > 0.15, "the ground falls into the water at " .. x .. ": " .. under)
				t.near(under, above, 0.05, "slope under and above the water at " .. x .. ", side " .. dz)
			end
		end
	end,

	["a bend is a Cut Bank on its outside, steeper and deeper, and a sandy Point Bar on its inside"] = function(t)
		-- Half a circle of radius 300 around (500, 0), whose top at (500, 300) has its inside towards the centre.
		local arc = { { 200, 0 }, { 288, 212 }, { 500, 300 }, { 712, 212 }, { 800, 0 } }
		local plan = riverPlan({ points = arc, curve = 1, depths = { 40, 40, 40, 40, 40 }, banks = { shore = 30, smooth = 0 } }, nil, { sides = 0.4 })
		t.eq(errorsOf(plan), "", "a sound plan")
		for _, x in ipairs({ 480, 500, 520 }) do
			local z = 300
			local outEdge = waterline(plan, x, z, 0, 1)
			local inEdge = waterline(plan, x, z, 0, -1)
			for _, inside in ipairs({ 4, 8, 12 }) do
				local outer = WATER - ground(plan, x, z + outEdge - inside)
				local inner = WATER - ground(plan, x, z - inEdge + inside)
				t.ok(outer > inner * 1.2, inside .. " studs in at " .. x .. ", the outside is " .. outer .. " deep and the inside " .. inner)
			end
			local outUnder = slopesAtWaterline(plan, x, z, 0, 1, 0.25)
			local inUnder = slopesAtWaterline(plan, x, z, 0, -1, 0.25)
			t.ok(outUnder > inUnder * 1.3, "at " .. x .. " the outside falls into the water at " .. outUnder .. " and the inside at " .. inUnder)
			local sandIn = surfaceAt(plan, x, z - inEdge - 25)
			local sandOut = surfaceAt(plan, x, z + outEdge + 25)
			t.eq(sandIn, Materials.id.Sand, "25 studs from the water on the inside at " .. x)
			t.ok(sandOut ~= Materials.id.Sand, "25 studs from the water on the outside at " .. x .. " there is no sand")
		end
	end,

	["a valley's ground keeps rising from its River towards its edge, with no flat plain beside the water"] = function(t)
		local plan = riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.15 })
		-- Averaged along the River, since a bump in the valley floor moves each spot a little.
		local last
		for _, out in ipairs({ 50, 80, 110, 140, 170 }) do
			local total, count = 0, 0
			for x = 100, 900, 20 do
				total += ground(plan, x, out) + ground(plan, x, -out)
				count += 2
			end
			local mean = total / count
			if last then
				t.ok(mean > last + 1, out .. " studs from the line, the ground stands at " .. mean .. ", against " .. last .. " 30 studs nearer")
			end
			last = mean
		end
	end,

	["a shore leaves no puddles: walking out from the water, it is dry once and stays dry"] = function(t)
		local plan = riverPlan({ banks = { shore = 60 } })
		for x = 100, 900, 20 do
			local dry = false
			for d = 20, 130, 2 do
				local _, _, _, water = Shape.height(plan, x, d)
				if water == 0 then
					dry = true
				else
					t.ok(not dry, "a puddle at " .. x .. ", " .. d)
				end
			end
		end
	end,

	["sand covers about half of a shore, so grass comes down towards the water"] = function(t)
		local plan = riverPlan({ banks = { shore = 60 } })
		local _, _, nearSand = Shape.height(plan, 500, 60)
		local _, _, farSand = Shape.height(plan, 500, 104)
		t.ok(nearSand < plan.materials.bankDist, "sand 20 studs from the water")
		t.ok(farSand >= plan.materials.bankDist, "grass 64 studs from the water")
	end,

	["a gentle valley keeps its water shallow and its bed gentle, so the Shallows come by themselves"] = function(t)
		local plan = riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.1 })
		for x = 100, 900, 100 do
			for _, dz in ipairs({ 1, -1 }) do
				local steepest = steepestUnder(plan, x, 0, 0, dz, 2)
				t.ok(steepest < 0.13, "the steepest slope under the water at " .. x .. " is " .. steepest)
			end
			t.ok(ground(plan, x, 0) > WATER - 4, "the middle is shallow at " .. x .. ": " .. ground(plan, x, 0))
		end
	end,

	["the bed curves into its deepest line, with no flat bottom"] = function(t)
		local plan = riverPlan({ banks = { shore = 30, smooth = 0 } }, nil, { sides = 0.6 })
		for x = 100, 900, 100 do
			local last = ground(plan, x, 32)
			for _, d in ipairs({ 24, 16, 8, 0 }) do
				local h = ground(plan, x, d)
				t.ok(h < last - 0.3, "the bed still falls " .. d .. " studs from the line at " .. x .. ": " .. h .. " after " .. last)
				last = h
			end
		end
	end,

	["a steeper valley gives deeper water than a gentle one"] = function(t)
		local gentle = riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.15 })
		local steep = riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.6 })
		for x = 100, 900, 100 do
			local shallow, deep = WATER - ground(gentle, x, 0), WATER - ground(steep, x, 0)
			t.ok(deep > shallow * 2.5, "at " .. x .. " the steep valley's water is " .. deep .. " deep, the gentle one's " .. shallow)
		end
	end,

	["the water never reaches deeper than the World Plan asks, whatever rough, depthVary and bedRough add"] = function(t)
		local plain = riverPlan({ banks = { shore = 30 }, depths = { 10, 10, 10 } }, nil, { sides = 1.2 })
		local varied = riverPlan({ banks = { shore = 30, rough = 4 }, depths = { 10, 10, 10 }, depthVary = 0.5, bedRough = 3 }, nil, { sides = 1.2 })
		for _, plan in ipairs({ plain, varied }) do
			local deepest = 0
			for x = 100, 900, 25 do
				for d = -48, 48, 2 do
					deepest = math.max(deepest, WATER - ground(plan, x, d))
				end
			end
			t.ok(deepest <= 10, "the deepest water is " .. deepest)
			t.ok(deepest > 9, "and steep sides reach the depth asked: " .. deepest)
		end
		local lake = lakePlan({ banks = { rough = 6 }, depthVary = 0.4, bedRough = 10 })
		lake.base = table.clone(shipped.base)
		lake.base.mean = 110
		local deepest = 0
		for x = 330, 570, 8 do
			for z = -120, 120, 8 do
				deepest = math.max(deepest, WATER - ground(lake, x, z))
			end
		end
		t.ok(deepest <= WATER - -60, "the Lake's deepest water is " .. deepest .. " of " .. WATER - -60)
	end,

	["depthVary still makes pools and shallows along a River in a gentle valley"] = function(t)
		local plan = riverPlan({ banks = { shore = 30 }, depthVary = 0.6 }, nil, { sides = 0.2 })
		local low, high = math.huge, -math.huge
		for x = 50, 950, 10 do
			local h = ground(plan, x, 0)
			low, high = math.min(low, h), math.max(high, h)
		end
		t.ok(high - low > 3, "the bed spans " .. (high - low) .. " studs")
		t.ok(high < WATER, "and stays under the water: " .. high)
	end,

	["the ground has no step halfway between two passes of a River whose sides differ, away from the water"] = function(t)
		-- Two legs 400 studs apart, gentle along the first and steep along the last, so the nearest pass
		-- changes along z = 200, 200 studs from either.
		local plan = riverPlan({ points = { { 0, 0 }, { 1000, 0 }, { 1000, 400 }, { 0, 400 } }, depths = { 20, 20, 20, 20 }, banks = { shore = 30, smooth = 0 } }, nil, { sides = { 0.1, 0.1, 0.9, 0.9 } })
		t.eq(errorsOf(plan), "", "a sound plan")
		for _, x in ipairs({ 300, 500, 700 }) do
			local worst, at = 0, 0
			for z = 120, 280, 2 do
				local step = math.abs(ground(plan, x, z + 2) - ground(plan, x, z))
				if step > worst then
					worst, at = step, z
				end
			end
			t.ok(worst < 1.5, "at " .. x .. " the ground moves " .. worst .. " in 2 studs at z " .. at)
		end
	end,

	["sides can change along a River, deep where they are steep and shallow where they are gentle"] = function(t)
		local plan = riverPlan({ banks = { shore = 30 } }, nil, { sides = { 0.1, 0.3, 0.9 } })
		local upstream, middle, downstream = WATER - ground(plan, 60, 0), WATER - ground(plan, 500, 0), WATER - ground(plan, 940, 0)
		t.ok(upstream < middle and middle < downstream, "the depth goes " .. upstream .. ", " .. middle .. ", " .. downstream)
		local step = 0
		for x = 100, 900, 4 do
			step = math.max(step, math.abs(ground(plan, x + 4, 0) - ground(plan, x, 0)))
		end
		t.ok(step < 1, "and changes gradually, at most " .. step .. " in 4 studs")
	end,

	["rough breaks the slope under the water into small slopes, and leaves the waterline and the deepest line alone"] = function(t)
		local smooth = riverPlan({ banks = { shore = 30, smooth = 0 } }, nil, { sides = 0.6 })
		local rough = riverPlan({ banks = { shore = 30, smooth = 0, rough = 4 } }, nil, { sides = 0.6 })
		local most = 0
		for x = 100, 900, 10 do
			most = math.max(most, math.abs(ground(smooth, x, 20) - ground(rough, x, 20)))
			t.near(ground(smooth, x, 0), ground(rough, x, 0), 0.001, "the deepest line at " .. x)
		end
		t.ok(most > 1, "the slope moves by " .. most)
		for x = 100, 900, 200 do
			local under, above = slopesAtWaterline(rough, x, 0, 0, 1, 1)
			t.near(under, above, 0.05, "the waterline at " .. x)
		end
	end,

	["vary changes the banks along the River, by its seed"] = function(t)
		local fixed = riverPlan({ banks = { shore = 40 } })
		local varied = riverPlan({ banks = { shore = 40, vary = 0.8 } })
		local other = riverPlan({ banks = { shore = 40, vary = 0.8 } }, 2)
		local most, apart = 0, 0
		for x = 100, 900, 10 do
			local a = ground(varied, x, 70)
			most = math.max(most, math.abs(a - ground(fixed, x, 70)))
			t.eq(a, ground(riverPlan({ banks = { shore = 40, vary = 0.8 } }), x, 70), "the same seed gives the same bank")
			apart = math.max(apart, math.abs(a - ground(other, x, 70)))
		end
		t.ok(most > 0.3, "the banks moved by " .. most)
		t.ok(apart > 0.3, "another seed gives other banks: " .. apart)
	end,

	["depthVary makes pools and shallows along a River, by its seed"] = function(t)
		local plan = riverPlan({ depthVary = 0.6 })
		local other = riverPlan({ depthVary = 0.6 }, 2)
		local low, high, apart = math.huge, -math.huge, 0
		for x = 0, 1000, 10 do
			local h = ground(plan, x, 0)
			low, high = math.min(low, h), math.max(high, h)
			apart = math.max(apart, math.abs(h - ground(other, x, 0)))
		end
		t.ok(high - low > 20, "the bed spans " .. (high - low) .. " studs")
		t.ok(high < WATER, "the bed stays under the water: " .. high)
		t.ok(apart > 5, "another seed puts the pools elsewhere: " .. apart)
	end,

	["a Lake's bed follows the slope of the ground around it, so steeper ground gives a deeper Lake"] = function(t)
		t.ok(ground(lakePlan(), 550, 0) < 0, "with no banks it is deep 20 studs in")
		local plain = lakePlan({ banks = {} })
		local hills = lakePlan({ banks = {} })
		hills.base = table.clone(shipped.base)
		hills.base.mean = 110
		local flat, steep = WATER - ground(plain, 450, 0), WATER - ground(hills, 450, 0)
		t.ok(steep > flat * 1.5, "among higher ground the Lake is " .. steep .. " deep, and in a plain " .. flat)
		t.ok(steep <= WATER - -60, "and never deeper than its bedY: " .. steep)
		-- Measured close to the waterline, since ground this steep curves within a stud.
		local under, above = slopesAtWaterline(hills, 450, 0, 1, 0, 0.25)
		t.near(under, above, 0.05, "the ground keeps its slope across the Lake's waterline")
		local plan = lakePlan({ depthVary = 0.6 })
		local low, high = math.huge, -math.huge
		for x = 400, 500, 5 do
			for z = -50, 50, 5 do
				local h = ground(plan, x, z)
				low, high = math.min(low, h), math.max(high, h)
			end
		end
		t.ok(high - low > 10, "the Lake's bed spans " .. (high - low) .. " studs")
	end,

	["a River passing close to itself leaves no crest between its two stretches"] = function(t)
		local plan = riverPlan({ points = { { 0, 0 }, { 400, 0 }, { 400, 60 }, { 0, 60 } }, depths = { 40, 40, 40, 40 }, banks = { shore = 30 } })
		local crest, _, _, water = Shape.height(plan, 200, 30)
		t.ok(crest < ground(plan, 200, 0) + 8, "between the stretches the bed is at " .. crest .. ", and under a stretch at " .. ground(plan, 200, 0))
		t.eq(water, WATER, "water covers it")
	end,

	["the bed has no step halfway between two stretches of different widths"] = function(t)
		local plan = riverPlan({
			points = { { 0, 0 }, { 400, 0 }, { 400, 120 }, { 0, 120 } },
			widths = { 30, 30, 70, 70 },
			depths = { 40, 40, 40, 40 },
			banks = { shore = 30, smooth = 0 },
		})
		for x = 120, 280, 40 do
			local step = math.abs(ground(plan, x, 59) - ground(plan, x, 61))
			t.ok(step < 3, "the ground steps " .. step .. " studs in 2 at x " .. x)
		end
	end,

	["a wide island between two stretches stays dry"] = function(t)
		local plan = riverPlan({ points = { { 0, 0 }, { 400, 0 }, { 400, 300 }, { 0, 300 } }, depths = { 40, 40, 40, 40 }, banks = { shore = 30 } })
		local island, _, _, water = Shape.height(plan, 200, 150)
		t.ok(island > WATER, "the island stands at " .. island)
		t.eq(water, 0, "and has no water")
	end,

	["smooth leaves a plain wall and the water's edge where they were"] = function(t)
		local filled = riverPlan({ banks = { shore = 30, smooth = 24 } })
		local plain = riverPlan({ banks = { shore = 30, smooth = 0 } })
		for x = 100, 900, 25 do
			for _, d in ipairs({ 10, 25, 34, 40, 46, 55 }) do
				t.near(ground(filled, x, d), ground(plain, x, d), 1, "at " .. x .. ", " .. d)
			end
		end
	end,

	["heights report the depth each River and Lake reached next to the depth asked"] = function(t)
		local function reached(text, id)
			local asked, low, high = text:match(id .. ": .-depth ([%d%.]+) asked, reached ([%d%.]+) to ([%d%.]+)")
			return tonumber(asked), tonumber(low), tonumber(high)
		end
		local gentle = Describe.heights(riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.15 }))
		local asked, low, high = reached(gentle, "r")
		t.eq(asked, 40, gentle)
		t.ok(low and low > 1 and high < 5, "a gentle valley's River reached " .. tostring(low) .. " to " .. tostring(high))
		local steep = Describe.heights(riverPlan({ banks = { shore = 30 }, depths = { 10, 10, 10 } }, nil, { sides = 1.2 }))
		local _, _, deep = reached(steep, "r")
		t.ok(deep and deep > 9 and deep <= 10, "a steep valley's River reached " .. tostring(deep) .. " of 10")
		local lakes = Describe.heights(lakePlan({ banks = {} }))
		local lakeAsked, lakeReached = lakes:match("l: .-depth ([%d%.]+) asked, ([%d%.]+) reached")
		t.eq(tonumber(lakeAsked), 80, lakes)
		local deepest = WATER - ground(lakePlan({ banks = {} }), 450, 0)
		t.ok(tonumber(lakeReached) and math.abs(tonumber(lakeReached) - deepest) < 2, "the Lake reached " .. tostring(lakeReached) .. ", and its middle is " .. deepest .. " deep")
	end,

	["the plan refuses the banks fields that Valley Sides replaced, naming what replaces them"] = function(t)
		for _, field in ipairs({ "shallows", "shallowDepth", "bedFlat", "steep" }) do
			local river = errorsOf(riverPlan({ banks = { shore = 30, [field] = 1 } }))
			t.ok(river:find("banks." .. field, 1, true) and river:find("sides", 1, true), field .. " on a River: " .. river)
			local lake = errorsOf(lakePlan({ banks = { [field] = 1 } }))
			t.ok(lake:find("banks." .. field, 1, true) and lake:find("ground around", 1, true), field .. " on a Lake: " .. lake)
		end
	end,

	["a valley's sides are one steepness, or one per point of its River"] = function(t)
		t.eq(errorsOf(riverPlan({ banks = { shore = 30 } }, nil, { sides = 0.3 })), "", "one steepness")
		t.eq(errorsOf(riverPlan({ banks = { shore = 30 } }, nil, { sides = { 0.1, 0.3, 0.8 } })), "", "one per point")
		t.ok(errorsOf(riverPlan({ banks = { shore = 30 } }, nil, { sides = { 0.1, 0.3 } })):find("one per point", 1, true), "a point without one")
		t.ok(errorsOf(riverPlan({ banks = { shore = 30 } }, nil, { sides = 0 })):find("sides", 1, true), "flat sides")
		t.ok(errorsOf(riverPlan({ banks = { shore = 30 } }, nil, { sides = { 0.3, 5, 0.3 } })):find("sides", 1, true), "a wall")
		t.ok(errorsOf(riverPlan(nil, nil, { sides = 0.3 })):find("banks", 1, true), "sides on a River without banks")
	end,

	["the plan refuses banks it cannot use"] = function(t)
		t.eq(errorsOf(riverPlan({ banks = { shore = 40, rough = 3, vary = 0.5, smooth = 30 }, depthVary = 0.5 })), "", "a sound River")
		t.ok(errorsOf(riverPlan({ banks = { vary = 2 } })):find("vary"), "vary above 0.9")
		t.ok(errorsOf(riverPlan({ banks = { shores = 40 } })):find("shores"), "a field that does not exist")
		t.ok(errorsOf(riverPlan({ depthVary = 1 })):find("depthVary"), "a depth that could reach the water")
		t.ok(errorsOf(riverPlan({ banks = { shore = 400 } })):find("halfWidth"), "a shore wider than the valley")
		t.ok(errorsOf(lakePlan({ banks = { shore = 40 } })):find("shore"), "a Lake keeps its shore in its own field")
	end,
}
