local plan = require("../src/world/plan")
local Route = require("../src/world/generator/Route")
local Geo = require("../src/world/generator/Geo")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")

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
