--!strict
-- Distance to polylines (route points) in 2D and 3D, with arc length of the nearest point.

local Geo = {}

local BLOCK = 8
local cache2 = setmetatable({}, { __mode = "k" })
local cache3 = setmetatable({}, { __mode = "k" })

function Geo.polyline2(points: { { number } })
	local c = cache2[points]
	if c then
		return c
	end
	local segs, total = {}, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ex, ez = b[1] - a[1], b[2] - a[2]
		local len2 = ex * ex + ez * ez
		local len = math.sqrt(len2)
		segs[i] = { a[1], a[2], ex, ez, len2, len, total }
		total += len
	end
	-- Runs of segments with their bounds, so that a long route costs little more than a short one.
	local blocks = {}
	for first = 1, #segs, BLOCK do
		local last = math.min(first + BLOCK - 1, #segs)
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for i = first, last do
			local a, b = points[i], points[i + 1]
			x0, x1 = math.min(x0, a[1], b[1]), math.max(x1, a[1], b[1])
			z0, z1 = math.min(z0, a[2], b[2]), math.max(z1, a[2], b[2])
		end
		table.insert(blocks, { x0, x1, z0, z1, first, last })
	end
	c = { segs = segs, blocks = blocks, length = total }
	cache2[points] = c
	return c
end

-- Returns distance and arc length of the nearest point on the polyline.
function Geo.dist2(poly: any, px: number, pz: number): (number, number)
	local best, bestS = math.huge, 0
	local segs = poly.segs
	for _, block in ipairs(poly.blocks) do
		local gapX = math.max(block[1] - px, 0, px - block[2])
		local gapZ = math.max(block[3] - pz, 0, pz - block[4])
		if gapX * gapX + gapZ * gapZ < best then
			for i = block[5], block[6] do
				local s = segs[i]
				local wx, wz = px - s[1], pz - s[2]
				local t = (wx * s[3] + wz * s[4]) / s[5]
				if t < 0 then
					t = 0
				elseif t > 1 then
					t = 1
				end
				local qx, qz = wx - t * s[3], wz - t * s[4]
				local d2 = qx * qx + qz * qz
				if d2 < best then
					best = d2
					bestS = s[7] + t * s[6]
				end
			end
		end
	end
	return math.sqrt(best), bestS
end

function Geo.polyline3(points: { { number } })
	local c = cache3[points]
	if c then
		return c
	end
	local segs, total = {}, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ex, ey, ez = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local len2 = ex * ex + ey * ey + ez * ez
		local len = math.sqrt(len2)
		segs[i] = { a[1], a[2], a[3], ex, ey, ez, len2, len, total }
		total += len
	end
	c = { segs = segs, length = total }
	cache3[points] = c
	return c
end

function Geo.dist3(poly: any, px: number, py: number, pz: number): (number, number)
	local best, bestS = math.huge, 0
	for _, s in ipairs(poly.segs) do
		local wx, wy, wz = px - s[1], py - s[2], pz - s[3]
		local t = (wx * s[4] + wy * s[5] + wz * s[6]) / s[7]
		if t < 0 then
			t = 0
		elseif t > 1 then
			t = 1
		end
		local qx, qy, qz = wx - t * s[4], wy - t * s[5], wz - t * s[6]
		local d2 = qx * qx + qy * qy + qz * qz
		if d2 < best then
			best = d2
			bestS = s[9] + t * s[8]
		end
	end
	return math.sqrt(best), bestS
end

function Geo.smoothstep(a: number, b: number, x: number): number
	local t = (x - a) / (b - a)
	if t < 0 then
		t = 0
	elseif t > 1 then
		t = 1
	end
	return t * t * (3 - 2 * t)
end

return Geo
