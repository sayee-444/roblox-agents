--!nonstrict
-- The line a River follows and its width along that line. From the nodes the World Plan declares,
-- a chain of short straight steps that Geo measures like any other. Every node stays exactly on the
-- line, so a fork can leave one.

local Noise = require("./Noise")

local Route = {}

local STEP = 24 -- studs between points, which keeps a bend round next to a 4-stud voxel
local MEANDER_SCALE = 90 -- studs along the line for one swing of the meander
local BEND_STEP = 8 -- studs between the places where a bend's tightness is measured
local BEND_REACH = 60 -- studs looked at on each side of a place, to measure the turn there
local TIGHTEST = math.pi / 2 -- a turn this sharp within that reach gets all of bendWiden

local function mix(a, b, u)
	return { a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u }
end

local function knot(t, a, b)
	return t + math.sqrt(math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2))
end

-- Centripetal Catmull-Rom between p1 and p2, which keeps close to the nodes and forms no loops.
local function spline(p0, p1, p2, p3, u)
	local t1 = knot(0, p0, p1)
	local t2 = knot(t1, p1, p2)
	local t3 = knot(t2, p2, p3)
	local t = t1 + (t2 - t1) * u
	local a1 = mix(p0, p1, t / t1)
	local a2 = mix(p1, p2, (t - t1) / (t2 - t1))
	local a3 = mix(p2, p3, (t - t2) / (t3 - t2))
	local b1 = mix(a1, a2, t / t2)
	local b2 = mix(a2, a3, (t - t1) / (t3 - t1))
	return mix(b1, b2, (t - t1) / (t2 - t1))
end

-- Keeps each River's meander its own, and the same on every run.
local function seedOf(id)
	local seed = 0
	for i = 1, #id do
		seed = (seed * 31 + string.byte(id, i)) % 100000
	end
	return seed
end

-- The points of a River's line, and the index among them of each node.
local function trace(rv)
	local curve, meander = rv.curve or 0, rv.meander or 0
	local nodes = rv.points
	local nodeAt = {}
	if curve == 0 and meander == 0 then
		for i = 1, #nodes do
			nodeAt[i] = i
		end
		return nodes, nodeAt
	end
	local seed = seedOf(rv.id)
	local out = {}
	local along = 0
	for leg = 1, #nodes - 1 do
		local a, b = nodes[leg], nodes[leg + 1]
		local before = nodes[leg - 1] or { 2 * a[1] - b[1], 2 * a[2] - b[2] }
		local after = nodes[leg + 2] or { 2 * b[1] - a[1], 2 * b[2] - a[2] }
		local ex, ez = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(ex * ex + ez * ez)
		local steps = math.max(2, math.ceil(length / STEP))
		table.insert(out, { a[1], a[2] })
		nodeAt[leg] = #out
		for step = 1, steps - 1 do
			local u = step / steps
			local p = mix(mix(a, b, u), spline(before, a, b, after, u), curve)
			-- The swing fades to nothing at each node.
			local swing = meander * math.sin(math.pi * u) * math.clamp(Noise.perlin((along + u * length) / MEANDER_SCALE, 0.5, seed) * 2, -1, 1)
			table.insert(out, { p[1] - ez / length * swing, p[2] + ex / length * swing })
		end
		along += length
	end
	local last = nodes[#nodes]
	table.insert(out, { last[1], last[2] })
	nodeAt[#nodes] = #out
	return out, nodeAt
end

-- The points of a River's line. With neither a curve nor a meander, its nodes as they are.
function Route.points(rv)
	return (trace(rv))
end

-- Where on the chain a distance along it falls.
local function pointAt(points, arcs, s)
	local i = 1
	while i < #points - 1 and arcs[i + 1] < s do
		i += 1
	end
	return mix(points[i], points[i + 1], (s - arcs[i]) / (arcs[i + 1] - arcs[i]))
end

-- How much the line turns around each place, every BEND_STEP studs: 0 straight, 1 at TIGHTEST or more.
local function tightness(points, arcs)
	local length = arcs[#arcs]
	local out = {}
	for k = 0, math.ceil(length / BEND_STEP) do
		local s = math.min(k * BEND_STEP, length)
		local here = pointAt(points, arcs, s)
		local from = pointAt(points, arcs, math.max(s - BEND_REACH, 0))
		local to = pointAt(points, arcs, math.min(s + BEND_REACH, length))
		local ax, az = here[1] - from[1], here[2] - from[2]
		local bx, bz = to[1] - here[1], to[2] - here[2]
		local turn = math.abs(math.atan2(ax * bz - az * bx, ax * bx + az * bz))
		out[k + 1] = math.min(turn / TIGHTEST, 1)
	end
	return out
end

-- A River's half width along its line. `at(s)` takes the distance along the line that Geo.dist2
-- reports. `narrowest` and `widest` count the widening at bends and not the Shape's noise.
function Route.width(rv)
	local points, nodeAt = trace(rv)
	local arcs = { 0 }
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		arcs[i] = arcs[i - 1] + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end
	local length = arcs[#arcs]
	local widths = rv.widths
	local bendWiden = rv.bendWiden or 0
	local bends = if bendWiden > 0 then tightness(points, arcs) else nil

	local function declared(s)
		if not widths then
			return rv.halfWidth
		end
		local leg = 1
		while leg < #widths - 1 and arcs[nodeAt[leg + 1]] < s do
			leg += 1
		end
		local from, to = arcs[nodeAt[leg]], arcs[nodeAt[leg + 1]]
		local u = math.clamp((s - from) / (to - from), 0, 1)
		return widths[leg] + (widths[leg + 1] - widths[leg]) * u * u * (3 - 2 * u)
	end

	local function at(s)
		s = math.clamp(s, 0, length)
		if not bends then
			return declared(s)
		end
		local place = s / BEND_STEP
		local k = math.min(math.floor(place), #bends - 2)
		-- The last gap ends at the route's end, so it can be shorter than a step.
		local gap = math.min(k + 1, length / BEND_STEP) - k
		local tight = bends[k + 1] + (bends[k + 2] - bends[k + 1]) * (place - k) / gap
		return declared(s) * (1 + bendWiden * tight)
	end

	local narrowest, widest = math.huge, 0
	local function measure(s)
		local w = at(s)
		narrowest, widest = math.min(narrowest, w), math.max(widest, w)
	end
	for _, index in ipairs(nodeAt) do
		measure(arcs[index])
	end
	if bends then
		for s = 0, length, BEND_STEP do
			measure(s)
		end
	end
	return { at = at, narrowest = narrowest, widest = widest }
end

return Route
