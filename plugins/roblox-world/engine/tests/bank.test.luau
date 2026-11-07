local shipped = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")

local WATER = 20
local WIDTH = 40 -- the bank wanders within about 6 studs of this

local function riverPlan(fields, seed)
	local rv = { id = "r", points = { { 0, 0 }, { 500, 0 }, { 1000, 0 } }, halfWidth = WIDTH, depths = { 40, 40, 40 }, waterLevel = WATER }
	for k, v in pairs(fields or {}) do
		rv[k] = v
	end
	return {
		worldSeed = 4242,
		chunkSize = 512,
		voxel = 4,
		extent = { minX = 0, maxX = 1, minZ = -1, maxZ = 0 },
		floorY = 0,
		base = shipped.base,
		materials = shipped.materials,
		regions = { { id = "v", kind = "valley", seed = seed or 1, riverId = "r", halfWidth = 300, floorY = 24 } },
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

return {
	["a shore brings the ground down gently to the water"] = function(t)
		local without, with = riverPlan({ banks = { shore = 1 } }), riverPlan({ banks = { shore = 60 } })
		-- Averaged along the River, since a bump in the valley floor fades differently on each.
		local fall, count = 0, 0
		for x = 100, 900, 20 do
			fall += ground(without, x, 75) - ground(with, x, 75)
			count += 1
		end
		t.ok(fall / count > 1, "the ground has started to fall 30 studs from the water, by " .. fall / count)
		local _, _, _, water = Shape.height(with, 500, 30)
		t.eq(water, WATER, "water still reaches its width")
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

	["shallows keep the water shallow on the way in"] = function(t)
		local plan = riverPlan({ banks = { shore = 30, shallows = 24, shallowDepth = 3 } })
		t.ok(ground(plan, 500, 28) >= WATER - 3 - 2, "about 12 studs in, the bed is at most 3 under the water")
		t.ok(ground(plan, 500, 0) < WATER - 30, "the middle is still deep")
		local sudden = riverPlan({ banks = { shore = 30 } })
		t.ok(ground(sudden, 500, 28) < ground(plan, 500, 28) - 3, "without shallows it falls sooner")
	end,

	["bedFlat sets how much of the bottom is flat, so a low value narrows it"] = function(t)
		local wide, narrow = riverPlan({ banks = { shore = 30, bedFlat = 0.6 } }), riverPlan({ banks = { shore = 30, bedFlat = 0 } })
		t.ok(ground(wide, 500, 12) < ground(narrow, 500, 12) - 2, "a wide bottom is already deepest 12 studs from the line")
	end,

	["steep makes the wall fall sooner after the edge"] = function(t)
		local even, steep = riverPlan({ banks = { shore = 30, bedFlat = 0 } }), riverPlan({ banks = { shore = 30, bedFlat = 0, steep = 3 } })
		t.ok(ground(steep, 500, 30) < ground(even, 500, 30) - 3, "10 studs in, the steep wall is well below the even one")
	end,

	["rough breaks the wall into small slopes and leaves the bottom alone"] = function(t)
		local smooth, rough = riverPlan({ banks = { shore = 30, bedFlat = 0.3 } }), riverPlan({ banks = { shore = 30, bedFlat = 0.3, rough = 4 } })
		local most = 0
		for x = 100, 900, 10 do
			most = math.max(most, math.abs(ground(smooth, x, 25) - ground(rough, x, 25)))
			t.near(ground(smooth, x, 0), ground(rough, x, 0), 0.001, "the middle of the bottom")
		end
		t.ok(most > 1, "the wall moves by " .. most)
	end,

	["vary changes the banks along the River, by its seed"] = function(t)
		local fixed = riverPlan({ banks = { shore = 40, shallows = 20 } })
		local varied = riverPlan({ banks = { shore = 40, shallows = 20, vary = 0.8 } })
		local other = riverPlan({ banks = { shore = 40, shallows = 20, vary = 0.8 } }, 2)
		local most, apart = 0, 0
		for x = 100, 900, 10 do
			local a = ground(varied, x, 70)
			most = math.max(most, math.abs(a - ground(fixed, x, 70)))
			t.eq(a, ground(riverPlan({ banks = { shore = 40, shallows = 20, vary = 0.8 } }), x, 70), "the same seed gives the same bank")
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

	["a Lake uses the same banks and depthVary"] = function(t)
		t.ok(ground(lakePlan(), 550, 0) < 0, "with no banks it is deep 20 studs in")
		t.ok(ground(lakePlan({ banks = { shallows = 40, shallowDepth = 3 } }), 550, 0) >= WATER - 3, "with shallows it is not")
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

	["the plan refuses banks it cannot use"] = function(t)
		t.eq(errorsOf(riverPlan({ banks = { shore = 40, shallows = 20, shallowDepth = 3, bedFlat = 0.3, steep = 1.5, rough = 3, vary = 0.5 }, depthVary = 0.5 })), "", "a sound River")
		t.ok(errorsOf(riverPlan({ banks = { bedFlat = 2 } })):find("bedFlat"), "bedFlat above 0.9")
		t.ok(errorsOf(riverPlan({ banks = { shores = 40 } })):find("shores"), "a field that does not exist")
		t.ok(errorsOf(riverPlan({ depthVary = 1 })):find("depthVary"), "a depth that could reach the water")
		t.ok(errorsOf(riverPlan({ banks = { shore = 400 } })):find("halfWidth"), "a shore wider than the valley")
		t.ok(errorsOf(lakePlan({ banks = { shore = 40 } })):find("shore"), "a Lake keeps its shore in its own field")
	end,
}
