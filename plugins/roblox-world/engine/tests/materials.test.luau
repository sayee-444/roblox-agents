local plan = require("../src/world/plan")
local Materials = require("../src/world/generator/Materials")

local function surface(h, g, mesaP, riverD)
	return Materials.names[Materials.surface(plan, 100.5, -40.5, h, g, mesaP or 0, riverD or 999)]
end

return {
	["gentle low ground is grass or ground"] = function(t)
		local ok = true
		for i = 0, 50 do
			local m = Materials.names[Materials.surface(plan, i * 7.3, i * 3.1, 50, 0.1, 0, 999)]
			ok = ok and (m == "Grass" or m == "Ground")
		end
		t.ok(ok, "low gentle ground must be Grass or Ground")
	end,

	["steep ground is rock"] = function(t)
		t.eq(surface(80, 2.0), "Rock")
		t.eq(surface(160, 2.0), "Rock")
	end,

	["high gentle ground is snow, high steep ground is not"] = function(t)
		t.eq(surface(280, 0.3), "Snow")
		t.ok(surface(280, 2.5) ~= "Snow", "steep stays bare")
	end,

	["river banks are sand, but only a narrow band"] = function(t)
		t.eq(surface(24, 0.1, 0, 20), "Sand")
		t.ok(surface(24, 0.1, 0, 40) ~= "Sand", "40 studs from the route is grass, not a sand road")
		t.ok(surface(24, 0.1, 0, 200) ~= "Sand", "far from the river is not sand")
	end,

	["a bed changes with the depth of its water: sand, then earth, then earth with rock"] = function(t)
		local function seenAt(depth)
			local seen = {}
			for i = 0, 400 do
				local m = Materials.surface(plan, i * 7.3, i * 3.1 - 200, 20 - depth, 0.1, 0, 0, 20)
				seen[Materials.names[m]] = true
			end
			return seen
		end
		local shallow, middle, deep = seenAt(2), seenAt(10.5), seenAt(24)
		t.ok(shallow.Sand and not shallow.Ground and not shallow.Rock, "shallow water lies on sand only")
		t.ok(middle.Sand and middle.Ground and not middle.Rock, "further down, earth comes through the sand")
		t.ok(deep.Ground and deep.Rock and deep.Sand, "at the bottom: earth, rock and a little sand")
	end,

	["a deep Ocean bed is earth with wide patches of rock, and no white spots of sand"] = function(t)
		local seen, changes, last = {}, 0, nil
		for i = 0, 800 do
			local m = Materials.names[Materials.surface(plan, i * 4, 300, -400, 0.1, 0, 0, 20, "ocean")]
			seen[m] = true
			if last and m ~= last then
				changes += 1
			end
			last = m
		end
		t.ok(seen.Ground and seen.Rock and not seen.Sand, "earth and rock only")
		t.ok(changes <= 24, "along 3,200 studs the material changes " .. changes .. " times")
	end,

	["an Ocean's shallows are still sand, as any beach"] = function(t)
		t.eq(Materials.names[Materials.surface(plan, 100.5, -40.5, 18, 0.1, 0, 0, 20, "ocean")], "Sand")
	end,

	["ground below height 0 with no water over it is not a bed"] = function(t)
		for i = 0, 200 do
			local m = Materials.names[Materials.surface(plan, i * 7.3, i * 3.1 - 200, -30, 0.1, 0, 999, 0)]
			t.ok(m == "Grass" or m == "Ground", "dry ground material " .. m)
		end
	end,

	["mesa risers are bare rock in bands, treads carry no white sand"] = function(t)
		local seen = {}
		for y = 40, 160, 2 do
			local m = surface(y, 1.5, 0.5)
			t.ok(m == "Sandstone" or m == "Rock", "riser material " .. m)
			seen[m] = true
		end
		t.ok(seen.Sandstone and seen.Rock, "risers show both bands")
		for i = 0, 200 do
			local m = Materials.names[Materials.surface(plan, i * 5.7, i * 2.3 - 90, 100, 0.05, 0.5, 999)]
			t.ok(m == "Ground" or m == "Sandstone" or m == "Grass", "tread material " .. m)
		end
	end,

	["the gentle foot of a mesa keeps the ground of the hills around it"] = function(t)
		for i = 0, 100 do
			local m = Materials.names[Materials.surface(plan, i * 7.3, i * 3.1 - 50, 55, 0.1, 0.03, 999)]
			t.ok(m == "Grass" or m == "Ground", "foot material " .. m)
		end
	end,

	["every id has a name and a distinct entry"] = function(t)
		local seen = {}
		for id, name in ipairs(Materials.names) do
			t.eq(Materials.id[name], id, name)
			t.ok(not seen[name], "duplicate")
			seen[name] = true
		end
		t.eq(Materials.id.Air, 1, "Air is id 1")
	end,
}
