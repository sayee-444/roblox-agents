local plan = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Chunk = require("../src/world/generator/Chunk")
local Materials = require("../src/world/generator/Materials")

local N = 128

-- Padded index of interior column (i, j), both 0-based.
local function pidx(i, j)
	return (j + 1) * (N + 2) + (i + 1) + 1
end

local function slabSum(cols, i0, i1)
	local slab = Chunk.slab(plan, cols, i0, i1)
	local sum, occ = 0, 0
	for ix = 1, i1 - i0 + 1 do
		for iy = 1, cols.ny do
			for iz = 1, N do
				sum += slab.SolidMaterial[ix][iy][iz] * 7 + slab.SolidOccupancy[ix][iy][iz] * 3 + slab.LiquidOccupancy[ix][iy][iz]
				occ += slab.SolidOccupancy[ix][iy][iz]
			end
		end
	end
	return sum, occ
end

return {
	["chunk origin and size follow the plan"] = function(t)
		local x0, z0 = Chunk.origin(plan, -1, 1)
		t.eq(x0, -768)
		t.eq(z0, 256)
		t.eq(Chunk.columns(plan, 0, 0).n, 128)
	end,

	["seam: neighbouring chunks hold the same function values on both sides of the border"] = function(t)
		local left, right = Chunk.columns(plan, 0, 0), Chunk.columns(plan, 1, 0)
		for j = 0, N - 1, 7 do
			-- Left chunk's padding column IS the right chunk's first column, and the reverse.
			t.eq(left.H[(j + 1) * (N + 2) + (N + 1) + 1], right.H[pidx(0, j)], "left pad = right first, j=" .. j)
			t.eq(right.H[(j + 1) * (N + 2) + 0 + 1], left.H[pidx(N - 1, j)], "right pad = left last, j=" .. j)
			-- And both equal the pure function at the world position.
			local zc = left.z0 + j * 4 + 2
			t.eq(left.H[pidx(N - 1, j)], (Shape.height(plan, left.x0 + (N - 1) * 4 + 2, zc)), "left last = function")
			t.eq(right.H[pidx(0, j)], (Shape.height(plan, right.x0 + 2, zc)), "right first = function")
		end
	end,

	["seam: no jump across a border beyond the local slope"] = function(t)
		-- Border between chunks (0,-1) and (1,-1) runs through the mountains: the hardest case.
		local a, b = Chunk.columns(plan, 0, -1), Chunk.columns(plan, 1, -1)
		local worst, worstInside = 0, 0
		for j = 0, N - 1 do
			worst = math.max(worst, math.abs(b.H[pidx(0, j)] - a.H[pidx(N - 1, j)]))
			worstInside = math.max(worstInside, math.abs(a.H[pidx(N - 1, j)] - a.H[pidx(N - 2, j)]))
		end
		t.ok(worst <= worstInside * 1.5 + 4, string.format("border jump %.2f vs inside %.2f", worst, worstInside))
	end,

	["regenerating a chunk slab gives identical data"] = function(t)
		local cols1, cols2 = Chunk.columns(plan, 1, 1), Chunk.columns(plan, 1, 1)
		local s1, o1 = slabSum(cols1, 20, 27)
		local s2, o2 = slabSum(cols2, 20, 27)
		t.eq(s1, s2, "checksum")
		t.eq(o1, o2, "occupancy")
	end,

	["occupancy stays in 0..1, ground is solid and the sky is empty"] = function(t)
		local cols = Chunk.columns(plan, 0, 0)
		local slab = Chunk.slab(plan, cols, 40, 41)
		for ix = 1, 2 do
			for iy = 1, cols.ny do
				for iz = 1, N, 9 do
					local o = slab.SolidOccupancy[ix][iy][iz]
					t.ok(o >= 0 and o <= 1, "range")
				end
			end
			t.eq(slab.SolidOccupancy[ix][1][1], 1, "bottom voxel solid")
			t.eq(slab.SolidOccupancy[ix][cols.ny][1], 0, "top voxel empty")
			t.eq(slab.SolidMaterial[ix][cols.ny][1], Materials.id.Air, "top material Air")
		end
	end,

	["the river column holds water up to the water level"] = function(t)
		local river = plan.rivers[1]
		local p = river.points[3] -- (-340, 200) in chunk (-1, 0)
		local cols = Chunk.columns(plan, -1, 0)
		local i = math.floor((p[1] - cols.x0) / 4)
		local j = math.floor((p[2] - cols.z0) / 4)
		local slab = Chunk.slab(plan, cols, i, i)
		local topWater, solidTop = nil, nil
		for iy = 1, cols.ny do
			local yb = cols.ymin + (iy - 1) * 4
			if slab.LiquidOccupancy[1][iy][j + 1] > 0 then
				topWater = yb + slab.LiquidOccupancy[1][iy][j + 1] * 4
			end
			if slab.SolidOccupancy[1][iy][j + 1] > 0.5 then
				solidTop = yb
			end
		end
		t.ok(topWater ~= nil, "water exists")
		t.near(topWater, river.waterLevel, 0.01, "water surface")
		t.ok(solidTop < river.waterLevel, "bed below surface")
	end,

	["the cave is air along its axis and has solid floor under the mouth"] = function(t)
		local cave
		for _, r in ipairs(plan.regions) do
			if r.id == "cave" then
				cave = r
			end
		end
		local cols = Chunk.columns(plan, 1, 1)
		local p = cave.points[1]
		local i = math.floor((p[1] + 20 - cols.x0) / 4)
		local j = math.floor((p[3] - cols.z0) / 4)
		local slab = Chunk.slab(plan, cols, i, i)
		local function occAt(y)
			return slab.SolidOccupancy[1][math.floor((y - cols.ymin) / 4) + 1][j + 1]
		end
		t.ok(occAt(p[2]) < 0.2, "axis voxel is air")
		t.ok(occAt(p[2] + 6) < 0.2, "head room")
		t.ok(occAt(p[2] - cave.radius - 6) > 0.9, "solid below the floor")
	end,
}
