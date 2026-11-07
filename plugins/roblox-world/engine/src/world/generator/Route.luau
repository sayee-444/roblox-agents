--!nonstrict
-- The line a River follows: from the nodes the World Plan declares, a chain of short straight steps
-- that Geo measures like any other. Every node stays exactly on the line, so a fork can leave one.

local Noise = require("./Noise")

local Route = {}

local STEP = 24 -- studs between points, which keeps a bend round next to a 4-stud voxel
local MEANDER_SCALE = 90 -- studs along the line for one swing of the meander

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

-- The points of a River's line. With neither a curve nor a meander, its nodes as they are.
function Route.points(rv)
	local curve, meander = rv.curve or 0, rv.meander or 0
	local nodes = rv.points
	if curve == 0 and meander == 0 then
		return nodes
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
	return out
end

return Route
