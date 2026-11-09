--!nonstrict
-- Studio writer: the only code that touches Terrain. Takes the pure Generator (`Gen`, the
-- module returned by generator/Generator) as an argument, writes one Chunk in slabs with
-- task.wait() between them, and reads voxels back for verification. Runs in Edit mode only.

local Writer = {}

local V = 4
local CHANNELS = { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }
-- Seconds of work between yields. Blocks of 0.5 and 1 s pass, and repeated blocks of 2 to 3 s make
-- Studio stop answering with "Target is not reachable", measured in issue #53.
local BREATH = 0.25

-- A function for long work to call often. It yields once BREATH seconds have passed since it last did.
function Writer.breather()
	local last = os.clock()
	return function()
		if os.clock() - last >= BREATH then
			task.wait()
			last = os.clock()
		end
	end
end

function Writer.materialLookup(Materials)
	local lookup = {}
	for i, name in ipairs(Materials.names) do
		lookup[i] = Enum.Material[name]
	end
	return lookup
end

local function box(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number)
	return Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1))
end

-- Sets a Chunk's whole column of space to Air.
function Writer.clear(terrain: Terrain, plan, Gen, ci: number, cj: number, y0: number, y1: number)
	local x0, z0 = Gen.Chunk.origin(plan, ci, cj)
	local s = plan.chunkSize
	terrain:FillBlock(CFrame.new(x0 + s / 2, (y0 + y1) / 2, z0 + s / 2), Vector3.new(s, y1 - y0, s), Enum.Material.Air)
end

-- Generates and writes one Chunk. Returns measured seconds: columns (height pass), slab
-- (voxel arrays), write (WriteVoxelChannels), clear, total CPU-clock and wall time.
-- opts.cols takes columns the caller already has, so they are not worked out twice.
function Writer.writeChunk(terrain: Terrain, plan, Gen, ci: number, cj: number, opts)
	opts = opts or {}
	local slabWidth = opts.slabWidth or 16
	local stats = { columns = 0, slab = 0, write = 0, clear = 0, slabs = 0 }
	local wall0 = DateTime.now().UnixTimestampMillis
	local t0 = os.clock()

	local cols = opts.cols or Gen.Chunk.columns(plan, ci, cj, Writer.breather())
	stats.columns = os.clock() - t0
	stats.ymin, stats.ymax, stats.ny = cols.ymin, cols.ymax, cols.ny

	local lookup = Writer.materialLookup(Gen.Materials)
	if opts.clear ~= false then
		local c0 = os.clock()
		-- Down to the Depth Limit, the deepest an earlier plan may have taken this Chunk, so none of its old bed or
		-- water stays hidden under the new one. Clearing empty space costs nothing measurable, and 3,200 studs of
		-- rock under one Chunk took 0.14 s, measured on 2026-11-08.
		local bottom = math.min(cols.ymin, plan.clearBottom or Gen.Shape.depthLimit(plan))
		Writer.clear(terrain, plan, Gen, ci, cj, bottom, math.max(cols.ymax, plan.clearTop or 1024))
		stats.clear = os.clock() - c0
		task.wait()
	end

	local flat = cols.flat
	if flat then
		-- Three blocks, the same voxels Chunk.slab gives for this Chunk, with no voxel arrays built.
		local w0 = os.clock()
		local s = plan.chunkSize
		local function fill(y0, y1, material)
			if y1 > y0 then
				terrain:FillBlock(CFrame.new(cols.x0 + s / 2, (y0 + y1) / 2, cols.z0 + s / 2), Vector3.new(s, y1 - y0, s), material)
			end
		end
		local skinFrom = math.max(flat.bottom, flat.bed - flat.skin)
		fill(flat.bottom, skinFrom, lookup[flat.body])
		fill(skinFrom, flat.bed, lookup[flat.surface])
		fill(flat.bed, flat.level, Enum.Material.Water)
		stats.write = os.clock() - w0
		stats.slabs = 1
		task.wait()
		stats.cpuTotal = os.clock() - t0
		stats.wall = (DateTime.now().UnixTimestampMillis - wall0) / 1000
		stats.voxels = cols.n * cols.n * cols.ny
		return stats
	end

	for i0 = 0, cols.n - 1, slabWidth do
		local i1 = math.min(i0 + slabWidth - 1, cols.n - 1)
		local g0 = os.clock()
		local channels = Gen.Chunk.slab(plan, cols, i0, i1, lookup)
		stats.slab += os.clock() - g0
		local w0 = os.clock()
		local region = box(
			cols.x0 + V * i0, cols.ymin, cols.z0,
			cols.x0 + V * (i1 + 1), cols.ymax, cols.z0 + plan.chunkSize
		)
		terrain:WriteVoxelChannels(region, V, channels)
		stats.write += os.clock() - w0
		stats.slabs += 1
		task.wait()
	end

	stats.cpuTotal = os.clock() - t0
	stats.wall = (DateTime.now().UnixTimestampMillis - wall0) / 1000
	stats.voxels = cols.n * cols.n * cols.ny
	return stats
end

-- Reads a grid-aligned box back from Terrain.
function Writer.read(terrain: Terrain, x0, y0, z0, x1, y1, z1)
	return terrain:ReadVoxelChannels(box(x0, y0, z0, x1, y1, z1), V, CHANNELS)
end

-- Order-sensitive checksum of the voxel data of one Chunk's box (8-bit quantised, since
-- the engine stores occupancy in 8 bits), plus counts, read back from Terrain.
function Writer.checksum(terrain: Terrain, plan, Gen, ci: number, cj: number, y0: number, y1: number)
	local x0, z0 = Gen.Chunk.origin(plan, ci, cj)
	local s = plan.chunkSize
	local data = Writer.read(terrain, x0, y0, z0, x0 + s, y1, z0 + s)
	local M = 4294967296
	local s1, s2, solid, liquid = 1, 0, 0, 0
	local mat, occ, liq = data.SolidMaterial, data.SolidOccupancy, data.LiquidOccupancy
	local breathe = Writer.breather()
	for ix = 1, #mat do
		breathe()
		local mx, ox, lx = mat[ix], occ[ix], liq[ix]
		for iy = 1, #mx do
			local my, oy, ly = mx[iy], ox[iy], lx[iy]
			for iz = 1, #my do
				local oq = math.floor(oy[iz] * 255 + 0.5)
				local lq = math.floor(ly[iz] * 255 + 0.5)
				if oq > 0 then
					solid += 1
				end
				if lq > 0 then
					liquid += 1
				end
				s1 = (s1 + my[iz].Value * 65536 + oq * 256 + lq) % M
				s2 = (s2 + s1) % M
			end
		end
	end
	return { s1 = s1, s2 = s2, solid = solid, liquid = liquid, size = data.Size }
end

local function surfaceOf(occ, ix, iz, ny, ymin)
	-- Height of the highest solid voxel's filled top, in studs.
	for iy = ny, 1, -1 do
		local o = occ[ix][iy][iz]
		if o > 0.01 then
			return ymin + (iy - 1) * V + o * V
		end
	end
	return ymin
end

-- Reads a 4-voxel-wide strip across the border between Chunk (ci, cj) and its +x ("x") or
-- +z ("z") neighbour, compares it with what the Generator says it must hold, and measures
-- the surface jump across the border against the jumps just inside each Chunk.
function Writer.borderReport(terrain: Terrain, plan, Gen, axis: string, ci: number, cj: number)
	local lookup = Writer.materialLookup(Gen.Materials)
	local nci, ncj = if axis == "x" then ci + 1 else ci, if axis == "z" then cj + 1 else cj
	local a, b = Gen.Chunk.columns(plan, ci, cj), Gen.Chunk.columns(plan, nci, ncj)
	local n = a.n
	-- Two Chunks can start at different heights, when one holds deep water and the other does not.
	local ymin = math.min(a.ymin, b.ymin)
	local ymax = math.max(a.ymax, b.ymax)
	local ny = (ymax - ymin) // V
	local S = plan.chunkSize

	local data, expA, expB
	if axis == "x" then
		local border = b.x0
		data = Writer.read(terrain, border - 2 * V, ymin, a.z0, border + 2 * V, ymax, a.z0 + S)
		expA = Gen.Chunk.slab(plan, a, n - 2, n - 1, lookup)
		expB = Gen.Chunk.slab(plan, b, 0, 1, lookup)
	else
		local border = b.z0
		data = Writer.read(terrain, a.x0, ymin, border - 2 * V, a.x0 + S, ymax, border + 2 * V)
		expA = Gen.Chunk.slab(plan, a, 0, n - 1, lookup, n - 2, n - 1)
		expB = Gen.Chunk.slab(plan, b, 0, n - 1, lookup, 0, 1)
	end

	local air = Enum.Material.Air
	local function expected(channel, ix, iy, iz, aIndex)
		-- ix, iz are read-array indices; pick the Chunk that owns this voxel.
		local src, jx, jz, own
		if axis == "x" then
			if ix <= 2 then src, jx, own = expA, ix, a else src, jx, own = expB, ix - 2, b end
			jz = iz
		else
			if iz <= 2 then src, jz, own = expA, iz, a else src, jz, own = expB, iz - 2, b end
			jx = ix
		end
		-- Each Chunk's arrays start at its own lowest height.
		local row = src[channel][jx][iy - (own.ymin - ymin) // V]
		if row == nil then
			return if channel == "SolidMaterial" then air else 0
		end
		return row[jz]
	end

	local matMismatch, occMismatch, liqMismatch, maxOccErr, checked = 0, 0, 0, 0, 0
	local nx, nz = #data.SolidMaterial, #data.SolidMaterial[1][1]
	for ix = 1, nx do
		for iy = 1, ny do
			for iz = 1, nz do
				local eo = expected("SolidOccupancy", ix, iy, iz)
				local ro = data.SolidOccupancy[ix][iy][iz]
				local err = math.abs(eo - ro)
				if err > maxOccErr then
					maxOccErr = err
				end
				if err > 0.02 then
					occMismatch += 1
				end
				if eo > 0.05 and ro > 0.05 then
					checked += 1
					if expected("SolidMaterial", ix, iy, iz) ~= data.SolidMaterial[ix][iy][iz] then
						matMismatch += 1
					end
				end
				if math.abs(expected("LiquidOccupancy", ix, iy, iz) - data.LiquidOccupancy[ix][iy][iz]) > 0.02 then
					liqMismatch += 1
				end
			end
		end
	end

	-- Surface profile along the border, in the read data itself.
	local along = if axis == "x" then nz else nx
	local maxCross, maxInside, sumCross = 0, 0, 0
	for k = 1, along do
		local s = table.create(4, 0)
		for c = 1, 4 do
			if axis == "x" then
				s[c] = surfaceOf(data.SolidOccupancy, c, k, ny, ymin)
			else
				-- along x, strip index c is the z layer
				local top = ymin
				for iy = ny, 1, -1 do
					local o = data.SolidOccupancy[k][iy][c]
					if o > 0.01 then
						top = ymin + (iy - 1) * V + o * V
						break
					end
				end
				s[c] = top
			end
		end
		local cross = math.abs(s[3] - s[2])
		maxCross = math.max(maxCross, cross)
		sumCross += cross
		maxInside = math.max(maxInside, math.abs(s[2] - s[1]), math.abs(s[4] - s[3]))
	end

	return {
		axis = axis,
		between = ci .. "," .. cj .. " | " .. nci .. "," .. ncj,
		voxelsCompared = nx * ny * nz,
		matMismatch = matMismatch,
		occMismatch = occMismatch,
		liqMismatch = liqMismatch,
		maxOccErr = maxOccErr,
		materialChecked = checked,
		maxCross = maxCross,
		meanCross = sumCross / along,
		maxInside = maxInside,
	}
end

return Writer
