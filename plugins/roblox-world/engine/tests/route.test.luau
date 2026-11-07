local plan = require("../src/world/plan")
local Route = require("../src/world/generator/Route")
local Geo = require("../src/world/generator/Geo")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")
local Chunk = require("../src/world/generator/Chunk")

local BEND = { { 0, 0 }, { 200, 0 }, { 200, 200 }, { 400, 200 } }

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

-- Distance from a point to a chain of straight legs, written apart from the engine's own.
local function distance(points, x, z)
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ex, ez = b[1] - a[1], b[2] - a[2]
		local u = math.clamp(((x - a[1]) * ex + (z - a[2]) * ez) / (ex * ex + ez * ez), 0, 1)
		best = math.min(best, math.sqrt((x - a[1] - u * ex) ^ 2 + (z - a[2] - u * ez) ^ 2))
	end
	return best
end

local function farthest(points, from)
	local worst = 0
	for _, p in ipairs(points) do
		worst = math.max(worst, distance(from, p[1], p[2]))
	end
	return worst
end

local function holdsNode(points, node)
	for _, p in ipairs(points) do
		if p[1] == node[1] and p[2] == node[2] then
			return true
		end
	end
	return false
end

-- A straight River through 0,0 500,0 1000,0 with its Valley alone, on the test map's hills.
local function straightPlan(fields)
	local p = clone(plan)
	p.regions = { { id = "v", kind = "valley", seed = 1, riverId = "r", halfWidth = 130, floorY = 24 } }
	p.lakes = {}
	local rv = { id = "r", points = { { 0, 0 }, { 500, 0 }, { 1000, 0 } }, bedY = if fields.depths then nil else 10, waterLevel = 20 }
	for k, v in pairs(fields) do
		rv[k] = v
	end
	p.rivers = { rv }
	return p
end

return {
	["a River with no curve and no meander follows its points exactly"] = function(t)
		local points = Route.points({ id = "r", points = BEND })
		t.eq(#points, #BEND)
		t.eq(farthest(points, BEND), 0)
	end,

	["a curved route leaves the straight legs"] = function(t)
		t.ok(farthest(Route.points({ id = "r", points = BEND, curve = 1 }), BEND) > 10, "the bend is rounded")
	end,

	["half a curve lies between the straight legs and the full curve"] = function(t)
		local half = farthest(Route.points({ id = "r", points = BEND, curve = 0.5 }), BEND)
		local full = farthest(Route.points({ id = "r", points = BEND, curve = 1 }), BEND)
		t.ok(half > 0 and half < full, string.format("half %.1f, full %.1f", half, full))
	end,

	["a curved and meandering route still passes through every node, so a fork can leave one"] = function(t)
		local points = Route.points({ id = "r", points = BEND, curve = 1, meander = 12 })
		for _, node in ipairs(BEND) do
			t.ok(holdsNode(points, node), "node " .. node[1] .. "," .. node[2])
		end
		t.eq(points[1][1], 0)
		t.eq(points[#points][1], 400)
	end,

	["a curved route has no jump between one step and the next"] = function(t)
		local points = Route.points({ id = "r", points = BEND, curve = 1, meander = 12 })
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			t.ok(math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2) < 80, "step " .. i)
		end
	end,

	["meander moves the route, within its size"] = function(t)
		local curved = Route.points({ id = "r", points = BEND, curve = 1 })
		local moved = farthest(Route.points({ id = "r", points = BEND, curve = 1, meander = 12 }), curved)
		t.ok(moved > 1 and moved <= 12, string.format("moved %.1f", moved))
	end,

	["two Rivers with the same nodes meander differently, and each always the same"] = function(t)
		local a = Route.points({ id = "a", points = BEND, meander = 12 })
		local again = Route.points({ id = "a", points = BEND, meander = 12 })
		local b = Route.points({ id = "b", points = BEND, meander = 12 })
		t.eq(farthest(a, again), 0)
		t.ok(farthest(a, b) > 0.5, "another id gives another meander")
	end,

	["the distance to a long route is the true nearest distance"] = function(t)
		local points = Route.points({ id = "r", points = BEND, curve = 1, meander = 12 })
		local poly = Geo.polyline2(points)
		for i = 1, 300 do
			local x, z = (i * 37.3) % 700 - 150, (i * 53.9) % 600 - 150
			t.near((Geo.dist2(poly, x, z)), distance(points, x, z), 0.0001, "at " .. x .. "," .. z)
		end
	end,

	["every point of a curved River holds water, and lies inside its bounds"] = function(t)
		local curved = clone(plan)
		curved.rivers[1].curve = 1
		curved.rivers[1].meander = 12
		local bounds = Shape.bounds(curved, curved.rivers[1].id)
		for _, p in ipairs(Route.points(curved.rivers[1])) do
			local _, _, _, water = Shape.height(curved, p[1], p[2])
			t.ok(water > 0, "water at " .. p[1] .. "," .. p[2])
			t.ok(p[1] >= bounds[1] and p[2] >= bounds[2] and p[1] <= bounds[3] and p[2] <= bounds[4], "inside the bounds")
		end
	end,

	["a plan is refused for a curve outside 0 to 1, a negative meander or a repeated node"] = function(t)
		for _, change in ipairs({
			function(rv) rv.curve = 2 end,
			function(rv) rv.meander = -1 end,
			function(rv) rv.points[2] = { rv.points[1][1], rv.points[1][2] } end,
		}) do
			local bad = clone(plan)
			change(bad.rivers[1])
			t.ok(#Describe.validate(bad) > 0, "refused")
		end
	end,

	["declared widths hold at their points, and change gradually between them"] = function(t)
		local width = Route.width({ id = "r", points = { { 0, 0 }, { 100, 0 }, { 300, 0 } }, widths = { 10, 20, 30 } })
		t.near(width.at(0), 10, 0.001, "first point")
		t.near(width.at(100), 20, 0.001, "second point")
		t.near(width.at(300), 30, 0.001, "last point")
		t.near(width.at(50), 15, 0.001, "halfway along the first leg")
		t.near(width.at(25), 11.5625, 0.001, "a quarter along, eased")
		t.eq(width.narrowest, 10)
		t.eq(width.widest, 30)
		for s = 0, 296, 4 do
			t.ok(math.abs(width.at(s + 4) - width.at(s)) < 1, "a step at " .. s)
		end
	end,

	["a route that curves still reaches each declared width at its point"] = function(t)
		local rv = { id = "r", points = BEND, curve = 1, meander = 12, widths = { 14, 20, 32, 14 } }
		local width = Route.width(rv)
		local points = Route.points(rv)
		local s = 0
		local nextNode = 1
		for i, p in ipairs(points) do
			if i > 1 then
				s += math.sqrt((p[1] - points[i - 1][1]) ^ 2 + (p[2] - points[i - 1][2]) ^ 2)
			end
			local node = BEND[nextNode]
			if node and p[1] == node[1] and p[2] == node[2] then
				t.near(width.at(s), rv.widths[nextNode], 0.001, "node " .. nextNode)
				nextNode += 1
			end
		end
		t.eq(nextNode, #BEND + 1)
	end,

	["a River with no widths keeps its halfWidth everywhere"] = function(t)
		local width = Route.width({ id = "r", points = BEND, curve = 1, meander = 12, halfWidth = 20 })
		for s = 0, 600, 37 do
			t.eq(width.at(s), 20)
		end
		t.eq(width.narrowest, 20)
		t.eq(width.widest, 20)
	end,

	["a fork can start thin at the point it leaves"] = function(t)
		local width = Route.width({ id = "fork", points = { { 0, 0 }, { 300, 0 }, { 600, 100 } }, curve = 1, meander = 8, widths = { 5, 12, 14 } })
		t.near(width.at(0), 5, 0.001, "where it leaves")
		t.ok(width.at(300) > 2 * width.at(0), "it grows")
	end,

	["every point of a River that starts thin holds water"] = function(t)
		local thin = straightPlan({ widths = { 6, 12, 20 }, curve = 1, meander = 30, bendWiden = 0.5 })
		for _, p in ipairs(Route.points(thin.rivers[1])) do
			local _, _, _, water = Shape.height(thin, p[1], p[2])
			t.ok(water > 0, "water at " .. p[1] .. "," .. p[2])
		end
	end,

	["no spot of a River passes the ceiling of its width, worked out by hand"] = function(t)
		local rv = { id = "r", points = { { 0, 0 }, { 200, 0 }, { 200, 200 }, { 400, 200 } }, widths = { 10, 30, 20, 15 }, bendWiden = 0.5 }
		local width = Route.width(rv)
		t.eq(width.ceiling, 45, "the widest declared, with all of bendWiden")
		for s = 0, 600, 2 do
			t.ok(width.at(s) <= width.ceiling, "at " .. s .. ": " .. width.at(s))
		end
		t.eq(Route.width({ id = "r", points = { { 0, 0 }, { 200, 0 } }, halfWidth = 20 }).ceiling, 20, "one width, no bends")
	end,

	["bendWiden widens by how tight the bend is, worked out by hand"] = function(t)
		-- A square corner: 90 degrees within the distance judged, so the whole of bendWiden.
		local square = Route.width({ id = "r", points = { { 0, 0 }, { 200, 0 }, { 200, 200 } }, halfWidth = 20, bendWiden = 0.5 })
		t.near(square.at(200), 30, 0.001, "square corner: 20 * 1.5")
		t.near(square.at(50), 20, 0.001, "far from the corner")
		t.near(square.widest, 30, 0.001, "the widest counts the widening")
		t.eq(square.narrowest, 20)
		-- 45 degrees is half of that: 20 * (1 + 0.5 * 0.5).
		local half = Route.width({ id = "r", points = { { 0, 0 }, { 200, 0 }, { 400, 200 } }, halfWidth = 20, bendWiden = 0.5 })
		t.near(half.at(200), 25, 0.001, "45 degree corner")
		for s = 0, 396, 4 do
			t.ok(math.abs(square.at(s + 4) - square.at(s)) < 2, "a step at " .. s)
		end
	end,

	["bendWiden is measured right up to the end of a route that is no multiple of the step"] = function(t)
		-- 300 studs long, with the corner 10 studs from the end. Nothing turns at the very end.
		local width = Route.width({ id = "r", points = { { 0, 0 }, { 290, 0 }, { 290, 10 } }, halfWidth = 20, bendWiden = 0.5 })
		t.near(width.at(300), 20, 0.001, "the last point")
	end,

	["bendWiden 0, or none, leaves a bend even"] = function(t)
		local corner = { { 0, 0 }, { 200, 0 }, { 200, 200 } }
		t.eq(Route.width({ id = "r", points = corner, halfWidth = 20, bendWiden = 0 }).at(200), 20)
		t.eq(Route.width({ id = "r", points = corner, halfWidth = 20 }).at(200), 20)
	end,

	["a wider point digs a wider bed"] = function(t)
		local _, _, _, waterWide = Shape.height(straightPlan({ widths = { 20, 45, 20 } }), 500, 30)
		local _, _, _, waterEven = Shape.height(straightPlan({ widths = { 20, 20, 20 } }), 500, 30)
		t.ok(waterWide > 0, "water 30 studs from the route where the half width is 45")
		t.eq(waterEven, 0, "no water there on an even River")
	end,

	["the width noise is soft: the bank wanders, within 15 percent of the width"] = function(t)
		local even = straightPlan({ widths = { 30, 30, 30 } })
		local low, high = math.huge, -math.huge
		for x = 0, 1000, 20 do
			-- The bank is where the ground rises back to the valley floor, walking away from the route.
			local bank = 60
			for d = 10, 60, 0.5 do
				if (Shape.height(even, x, d)) > 24 - 3 then
					bank = d
					break
				end
			end
			low, high = math.min(low, bank), math.max(high, bank)
		end
		t.ok(high - low > 1, string.format("the bank wanders, from %.1f to %.1f", low, high))
		t.ok(high <= 30 * 1.15, string.format("the bank stays within the noise, at most %.1f", high))
	end,

	["the sand band follows the bank where a River widens"] = function(t)
		local wide = straightPlan({ widths = { 20, 60, 20 } })
		local _, _, near = Shape.height(wide, 500, 50)
		t.near(near, 10, 0.001, "50 from the route, with the bank moved out by 60 - 20")
		local _, _, plain = Shape.height(straightPlan({ widths = { 20, 20, 20 } }), 500, 10)
		t.near(plain, 10, 0.001, "an even River measures from its route")
	end,

	["a wider River reaches further in its bounds"] = function(t)
		local function spread(p)
			local b = Shape.bounds(p, "r")
			return b[4] - b[2]
		end
		t.ok(spread(straightPlan({ widths = { 20, 60, 20 } })) >= 2 * 60 * 1.15, "bounds hold the widest bank")
		t.ok(spread(straightPlan({ widths = { 20, 60, 20 } })) > spread(straightPlan({ widths = { 20, 20, 20 } })), "and grow with it")
	end,

	["a plan is refused for a bad width, a wrong count, a bad bendWiden or a Valley too narrow"] = function(t)
		for label, change in pairs({
			["a width that is zero"] = function(rv) rv.widths = { 20, 0, 20 } end,
			["a negative width"] = function(rv) rv.widths = { 20, -4, 20 } end,
			["a width that is no number"] = function(rv) rv.widths = { 20, "wide", 20 } end,
			["too few widths"] = function(rv) rv.widths = { 20, 20 } end,
			["too many widths"] = function(rv) rv.widths = { 20, 20, 20, 20 } end,
			["no width at all"] = function(rv) rv.widths = nil end,
			["a negative bendWiden"] = function(rv) rv.bendWiden = -1 end,
			["a Valley too narrow for the widest width"] = function(rv) rv.widths = { 20, 100, 20 } end,
			["a Valley too narrow once a bend widens"] = function(rv)
				rv.points = { { 0, 0 }, { 500, 0 }, { 500, 500 } }
				rv.widths = { 60, 60, 60 }
				rv.bendWiden = 2
			end,
		}) do
			local bad = straightPlan({ widths = { 20, 20, 20 } })
			t.eq(#Describe.validate(bad), 0, "the plan starts valid")
			change(bad.rivers[1])
			t.ok(#Describe.validate(bad) > 0, "refused: " .. label)
		end
	end,

	["a Valley is accepted up to the widest width it holds"] = function(t)
		-- A Valley of 130 needs 1.3 * width + 20 <= 130, so 84 fits and 85 does not.
		t.eq(#Describe.validate(straightPlan({ widths = { 20, 84, 20 } })), 0)
		t.ok(#Describe.validate(straightPlan({ widths = { 20, 85, 20 } })) > 0, "85 needs more than 130")
	end,

	["a half loop is a semicircle to the side chosen, worked out by hand"] = function(t)
		local leg = { { 0, 0 }, { 400, 0 } }
		local right = Route.points({ id = "r", points = leg, curve = 1, loops = { { leg = 1, radius = 100, turn = 180, side = "right" } } })
		t.near(distance(right, 100, 0), 0, 0.001, "it leaves the leg 100 before the middle")
		t.near(distance(right, 200, 100), 0, 0.001, "the far side, to the right of the flow, which is south here")
		t.near(distance(right, 300, 0), 0, 0.001, "it comes back 100 after the middle")
		local left = Route.points({ id = "r", points = leg, curve = 1, loops = { { leg = 1, radius = 100, turn = 180, side = "left" } } })
		t.near(distance(left, 200, -100), 0, 0.001, "the far side to the left")
	end,

	["a near-closed loop leaves a neck, worked out by hand"] = function(t)
		-- 290 degrees leave 70 open, so the neck is 2 * 110 * sin 35 = 126.2 wide, around the middle at 200.
		local points = Route.points({ id = "r", points = { { 0, 0 }, { 400, 0 } }, curve = 1, loops = { { leg = 1, radius = 110, turn = 290, side = "right" } } })
		t.near(distance(points, 136.9, 0), 0, 0.1, "the upstream side of the neck")
		t.near(distance(points, 263.1, 0), 0, 0.1, "the downstream side of the neck")
		t.near(distance(points, 200, 200.1), 0, 0.1, "the far side: 110 * cos 35 + 110")
	end,

	["a whole loop closes on itself and leaves a dry island"] = function(t)
		local ring = straightPlan({ widths = { 20, 20, 20 }, curve = 1, loops = { { leg = 1, radius = 100, turn = 360, side = "right" } } })
		t.eq(#Describe.validate(ring), 0, "the plan is valid")
		local points = Route.points(ring.rivers[1])
		t.near(distance(points, 250, 200), 0, 0.001, "the far side")
		local visits = 0
		for _, p in ipairs(points) do
			if p[1] == 250 and p[2] == 0 then
				visits += 1
			end
		end
		t.eq(visits, 2, "it passes the middle of the leg twice")
		local _, _, _, waterFar = Shape.height(ring, 250, 200)
		local _, _, _, waterIsland = Shape.height(ring, 250, 100)
		t.ok(waterFar > 0, "water around the ring")
		t.eq(waterIsland, 0, "a dry island in the middle")
	end,

	["a loop keeps the declared points and their widths"] = function(t)
		local rv = { id = "r", points = { { 0, 0 }, { 500, 0 }, { 1000, 0 } }, curve = 1, meander = 30, widths = { 10, 20, 30 }, loops = { { leg = 1, radius = 100, turn = 290, side = "left" } } }
		local points = Route.points(rv)
		local width = Route.width(rv)
		local s = 0
		local held = false
		for i = 2, #points do
			s += math.sqrt((points[i][1] - points[i - 1][1]) ^ 2 + (points[i][2] - points[i - 1][2]) ^ 2)
			if points[i][1] == 500 and points[i][2] == 0 then
				t.near(width.at(s), 20, 0.001, "the second declared point")
				held = true
			end
		end
		t.ok(held, "the route holds the second declared point")
		t.near(width.at(0), 10, 0.001, "the first")
		t.near(width.at(s), 30, 0.001, "the last")
	end,

	["points stay free: a route with no loops is what it was, and a leg can hold a loop beside hand-placed points"] = function(t)
		t.eq(farthest(Route.points({ id = "r", points = BEND, curve = 1 }), Route.points({ id = "r", points = BEND, curve = 1, loops = {} })), 0)
		local mixed = Route.points({ id = "r", points = BEND, curve = 1, loops = { { leg = 3, radius = 60, turn = 180, side = "left" } } })
		for _, node in ipairs(BEND) do
			t.ok(holdsNode(mixed, node), "node " .. node[1] .. "," .. node[2])
		end
	end,

	["a plan is refused for a loop it cannot draw"] = function(t)
		local good = { leg = 1, radius = 100, turn = 290, side = "right" }
		local function with(field, value)
			local loop = clone(good)
			loop[field] = value
			return loop
		end
		for label, loops in pairs({
			["loops that are no list"] = 5,
			["a loop that is no table"] = { 5 },
			["a leg before the first"] = { with("leg", 0) },
			["a leg past the last"] = { with("leg", 3) },
			["a leg that is no whole number"] = { with("leg", 1.5) },
			["a radius of zero"] = { with("radius", 0) },
			["a turn of zero"] = { with("turn", 0) },
			["a turn over a full circle"] = { with("turn", 400) },
			["a side that is neither"] = { with("side", "up") },
			["two loops on one leg"] = { good, good },
			["a neck wider than its leg"] = { { leg = 1, radius = 300, turn = 180, side = "right" } },
		}) do
			local bad = straightPlan({ widths = { 20, 20, 20 }, curve = 1 })
			t.eq(#Describe.validate(bad), 0, "the plan starts valid")
			bad.rivers[1].loops = loops
			t.ok(#Describe.validate(bad) > 0, "refused: " .. label)
		end
		local straight = straightPlan({ widths = { 20, 20, 20 } })
		straight.rivers[1].loops = { good }
		t.ok(#Describe.validate(straight) > 0, "refused: a loop on a River with no curve")
	end,

	["heights report a River's loops"] = function(t)
		local looped = straightPlan({ widths = { 20, 20, 20 }, curve = 1, loops = { { leg = 1, radius = 100, turn = 290, side = "right" } } })
		t.ok(Describe.heights(looped):find("loops 1", 1, true) ~= nil, "counted")
		t.ok(Describe.heights(straightPlan({ widths = { 20, 20, 20 } })):find("loops", 1, true) == nil, "left out when there are none")
	end,

	["declared depths hold at their points, and change gradually between them"] = function(t)
		local depth = Route.depth({ id = "r", points = { { 0, 0 }, { 100, 0 }, { 300, 0 } }, depths = { 10, 20, 40 }, waterLevel = 20 })
		t.near(depth.at(0), 10, 0.001, "first point")
		t.near(depth.at(100), 20, 0.001, "second point")
		t.near(depth.at(300), 40, 0.001, "last point")
		t.near(depth.at(50), 15, 0.001, "halfway along the first leg")
		t.eq(depth.shallowest, 10)
		t.eq(depth.deepest, 40)
	end,

	["a River with no depths keeps the depth of its bedY"] = function(t)
		local depth = Route.depth({ id = "r", points = BEND, curve = 1, meander = 12, bedY = 10, waterLevel = 20 })
		t.eq(depth.at(100), 10)
		t.eq(depth.deepest, 10)
	end,

	["a declared depth digs the bed that far below the water, even below the plan's floor"] = function(t)
		local deep = straightPlan({ widths = { 30, 30, 30 }, depths = { 8, 60, 8 } })
		deep.rivers[1].bedY = nil
		deep.floorY = 0
		t.eq(#Describe.validate(deep), 0, table.concat(Describe.validate(deep), "; "))
		t.near((Shape.height(deep, 500, 0)), 20 - 60, 3, "60 below the water at the middle")
		t.near((Shape.height(deep, 0, 0)), 20 - 8, 3, "8 below the water at the start")
	end,

	["bedRough varies the bed by up to its size, and only inside the water"] = function(t)
		local even = straightPlan({ widths = { 30, 30, 30 }, depths = { 20, 20, 20 } })
		local rough = straightPlan({ widths = { 30, 30, 30 }, depths = { 20, 20, 20 }, bedRough = 6 })
		local biggest, unchanged = 0, 0
		for x = 0, 1000, 10 do
			biggest = math.max(biggest, math.abs(Shape.height(rough, x, 0) - Shape.height(even, x, 0)))
			unchanged = math.max(unchanged, math.abs(Shape.height(rough, x, 100) - Shape.height(even, x, 100)))
		end
		t.ok(biggest > 2 and biggest <= 6, string.format("the bed moved by up to %.1f", biggest))
		t.eq(unchanged, 0, "the dry valley does not move")
	end,

	["a plan is refused for a bad depth, or a bedRough that could reach the surface"] = function(t)
		for label, change in pairs({
			["a depth of zero"] = function(rv) rv.depths = { 10, 0, 10 } end,
			["a negative depth"] = function(rv) rv.depths = { 10, -4, 10 } end,
			["too few depths"] = function(rv) rv.depths = { 10, 10 } end,
			["no depth and no bedY"] = function(rv) rv.bedY = nil end,
			["a negative bedRough"] = function(rv) rv.bedRough = -1 end,
			["a bedRough as large as the shallowest depth"] = function(rv)
				rv.depths = { 10, 30, 10 }
				rv.bedRough = 10
			end,
		}) do
			local bad = straightPlan({ widths = { 20, 20, 20 } })
			t.eq(#Describe.validate(bad), 0, "the plan starts valid")
			change(bad.rivers[1])
			t.ok(#Describe.validate(bad) > 0, "refused: " .. label)
		end
	end,

	["a lake's bedRough varies its bed"] = function(t)
		local function lake(rough)
			local p = straightPlan({ widths = { 20, 20, 20 } })
			p.lakes = { { id = "l", seed = 3, center = { 500, 600 }, radius = 170, shore = 60, warp = 0, bedY = 6, waterLevel = 20, bedRough = rough } }
			return p
		end
		local biggest = 0
		for x = 450, 550, 5 do
			biggest = math.max(biggest, math.abs(Shape.height(lake(4), x, 600) - Shape.height(lake(nil), x, 600)))
		end
		t.ok(biggest > 1 and biggest <= 4, string.format("the bed moved by up to %.1f", biggest))
		local bad = lake(14)
		t.ok(#Describe.validate(bad) > 0, "refused: as large as the lake's depth")
	end,

	["ground goes below the plan's floor only under deep water, by rockUnder studs"] = function(t)
		local deep = straightPlan({ widths = { 30, 30, 30 }, depths = { 8, 60, 8 } })
		deep.rivers[1].bedY = nil
		deep.floorY = 0
		local cols = Chunk.columns(deep, 1, 0) -- holds the deepest point, at 500,0
		t.ok(cols.ymin <= -56, "the Chunk reaches under the deep bed, ymin " .. cols.ymin)
		local slab = Chunk.slab(deep, cols, 0, cols.n - 1)
		local function lowest(x, z)
			local i, j = (x - cols.x0) // 4, (z - cols.z0) // 4
			for iy = 1, cols.ny do
				if slab.SolidOccupancy[i + 1][iy][j + 1] > 0 then
					return cols.ymin + (iy - 1) * 4
				end
			end
		end
		local bed = Shape.height(deep, 502, 2)
		t.ok(lowest(502, 2) <= bed - 16 + 4 and lowest(502, 2) >= bed - 16 - 4, string.format("16 under the bed at %.1f, lowest %d", bed, lowest(502, 2)))
		t.eq(lowest(502, 202), 0, "dry ground stops at the plan's floor")
	end,

	["ground also reaches under a cave that goes below the plan's floor"] = function(t)
		local p = straightPlan({ widths = { 20, 20, 20 } })
		p.floorY = 0
		table.insert(p.regions, { id = "c", kind = "cave", seed = 2, radius = 10, points = { { 500, -10, 300 }, { 540, -10, 300 } } })
		t.ok(Shape.bottom(p, 520, 300, 50) <= -10 - 10 * 1.4 - 10 - 16, "under the cave")
		t.eq(Shape.bottom(p, 520, 700, 50), 0, "away from the cave")
	end,

	["rockUnder sets how much rock lies under deep water, on the voxel grid"] = function(t)
		local p = straightPlan({ widths = { 20, 20, 20 } })
		p.floorY = 0
		t.eq(Shape.bottom(p, 0, 0, -30), -48, "16 by default: -46 down to a multiple of 4")
		p.rockUnder = 32
		t.eq(Shape.bottom(p, 0, 0, -30), -64, "-62 down to a multiple of 4")
	end,

	["heights report the range of a River's depth"] = function(t)
		local p = straightPlan({ widths = { 20, 20, 20 }, depths = { 8, 30, 12 } })
		t.ok(Describe.heights(p):find("depth 8 to 30", 1, true) ~= nil, Describe.heights(p))
		t.ok(Describe.heights(straightPlan({ widths = { 20, 20, 20 }, bedY = 10 })):find("depth 10,", 1, true) ~= nil, "one depth")
	end,

	["heights report the range of a River's width"] = function(t)
		t.ok(Describe.heights(straightPlan({ widths = { 14, 20, 32 } })):find("width 14 to 32", 1, true) ~= nil, "a range")
		t.ok(Describe.heights(straightPlan({ widths = { 20, 20, 20 } })):find("width 20$") ~= nil, "one width")
		t.ok(Describe.heights(straightPlan({ widths = { 20, 20, 29.6 } })):find("width 20 to 30$") ~= nil, "rounded, not cut")
		t.ok(Describe.heights(straightPlan({ widths = { 20, 20, 20.3 } })):find("width 20$") ~= nil, "one width once rounded")
	end,

	["heights say how a River is shaped, so a run knows without reading the plan"] = function(t)
		local curved = clone(plan)
		curved.rivers[1].curve = 1
		curved.rivers[1].meander = 12
		local text = Describe.heights(curved)
		t.ok(text:find(curved.rivers[1].id .. ": bed", 1, true) ~= nil, "the River is reported")
		t.ok(text:find("curve 1, meander 12", 1, true) ~= nil, text)
		t.ok(text:match("route %d+ studs") ~= nil, text)
	end,
}
