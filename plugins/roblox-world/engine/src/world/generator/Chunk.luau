--!nonstrict
-- Turns the pure terrain function into the data of one Chunk: per-column facts first
-- (Chunk.columns), then voxel arrays for any slab of columns (Chunk.slab), so the writer
-- can work in small batches. Pure Luau: no Terrain, no Enum.

local Shape = require("./Shape")
local Materials = require("./Materials")

local Chunk = {}

local id = Materials.id
local V = 4 -- voxel size in studs; the plan's `voxel` must equal this

function Chunk.key(i: number, j: number): string
	return i .. "," .. j
end

-- World position of a Chunk's minimum corner.
function Chunk.origin(plan, ci: number, cj: number): (number, number)
	local s = plan.chunkSize
	return ci * s - s / 2, cj * s - s / 2
end

-- Column facts for Chunk (ci, cj). Heights are kept on a grid padded by one voxel on
-- every side, so slopes at the border use the neighbour's true values.
-- Padded index of interior column (i, j), both 0-based: (j + 1) * (n + 2) + (i + 1) + 1.
function Chunk.columns(plan, ci: number, cj: number)
	assert(plan.voxel == V, "plan.voxel must be 4")
	local n = math.floor(plan.chunkSize / V)
	local x0, z0 = Chunk.origin(plan, ci, cj)
	local w = n + 2
	local H = table.create(w * w, 0)
	local MP, RD, WL = table.create(n * n, 0), table.create(n * n, 0), table.create(n * n, 0)
	local hmax, wmax = -math.huge, 0

	for jj = 0, w - 1 do
		local zc = z0 + (jj - 1) * V + V / 2
		local interiorRow = jj >= 1 and jj <= n
		for ii = 0, w - 1 do
			local xc = x0 + (ii - 1) * V + V / 2
			local h, mp, rd, wl = Shape.height(plan, xc, zc)
			H[jj * w + ii + 1] = h
			if interiorRow and ii >= 1 and ii <= n then
				local k = (jj - 1) * n + ii
				MP[k], RD[k], WL[k] = mp, rd, wl
				if h > hmax then
					hmax = h
				end
				if wl > wmax then
					wmax = wl
				end
			end
		end
	end

	local G = table.create(n * n, 0)
	local S, B = table.create(n * n, 0), table.create(n * n, 0)
	local BOTTOM = table.create(n * n, 0)
	local ymin = plan.floorY
	for j = 0, n - 1 do
		local zc = z0 + j * V + V / 2
		for i = 0, n - 1 do
			local k = j * n + i + 1
			local p = (j + 1) * w + (i + 1) + 1
			local gx = (H[p + 1] - H[p - 1]) / (2 * V)
			local gz = (H[p + w] - H[p - w]) / (2 * V)
			local g = math.sqrt(gx * gx + gz * gz)
			G[k] = g
			local xc = x0 + i * V + V / 2
			S[k] = Materials.surface(plan, xc, zc, H[p], g, MP[k], RD[k], WL[k])
			B[k] = if MP[k] > 0.02 then id.Sandstone else id.Rock
			BOTTOM[k] = Shape.bottom(plan, xc, zc, math.min(H[p], H[p - 1], H[p + 1], H[p - w], H[p + w]))
			ymin = math.min(ymin, BOTTOM[k])
		end
	end

	-- Cave rectangle (all caves together), so columns far from any cave skip the 3D test.
	local caveRect
	for _, r in ipairs(plan.regions) do
		if r.kind == "cave" then
			local b = Shape.bounds(plan, r.id)
			if caveRect then
				caveRect = {
					math.min(caveRect[1], b[1]),
					math.min(caveRect[2], b[2]),
					math.max(caveRect[3], b[3]),
					math.max(caveRect[4], b[4]),
				}
			else
				caveRect = b
			end
		end
	end

	local ny = math.ceil((math.max(hmax, wmax) + 8 - ymin) / V)
	return {
		ci = ci,
		cj = cj,
		n = n,
		x0 = x0,
		z0 = z0,
		ymin = ymin,
		ny = ny,
		ymax = ymin + ny * V,
		H = H, -- padded heights
		G = G, -- slope
		S = S, -- surface material id
		B = B, -- body material id
		BOTTOM = BOTTOM, -- lowest height of ground in the column
		WL = WL, -- water level over the column (0 = dry)
		caveRect = caveRect, -- {x0, z0, x1, z1} or nil
	}
end

-- Voxel arrays for columns i0..i1 (x) and j0..j1 (z), all 0-based and inclusive, in the
-- layout Terrain:WriteVoxelChannels wants: array[x][y][z]. `lookup` maps material ids to
-- the writer's own values (Enum.Material); without it the ids stay integers.
function Chunk.slab(plan, cols, i0: number, i1: number, lookup, j0: number?, j1: number?)
	local n, ny, ymin = cols.n, cols.ny, cols.ymin
	j0, j1 = j0 or 0, j1 or n - 1
	local nz = j1 - j0 + 1
	local w = n + 2
	local air = if lookup then lookup[id.Air] else id.Air
	local mats, occs, liqs = {}, {}, {}
	local rect = cols.caveRect
	local slate = id.Slate

	for ii = i0, i1 do
		local mx, ox, lx = {}, {}, {}
		for iy = 1, ny do
			mx[iy] = table.create(nz, air)
			ox[iy] = table.create(nz, 0)
			lx[iy] = table.create(nz, 0)
		end
		mats[ii - i0 + 1], occs[ii - i0 + 1], liqs[ii - i0 + 1] = mx, ox, lx
		local xc = cols.x0 + ii * V + V / 2

		for jj = j0, j1 do
			local k = jj * n + ii + 1
			local h = cols.H[(jj + 1) * w + (ii + 1) + 1]
			local norm = 1 / math.sqrt(1 + cols.G[k] ^ 2)
			local wl = cols.WL[k]
			local surf, body = cols.S[k], cols.B[k]
			local sub = Materials.sub[surf]
			local zc = cols.z0 + jj * V + V / 2
			local caveOn = rect ~= nil and xc > rect[1] and xc < rect[3] and zc > rect[2] and zc < rect[4]
			local top = if wl > h then wl else h
			local iyEnd = math.min(ny, math.floor((top - ymin) / V) + 2)
			local zi = jj - j0 + 1

			for iy = (cols.BOTTOM[k] - ymin) // V + 1, iyEnd do
				local yb = ymin + (iy - 1) * V
				local yc = yb + V / 2
				-- Signed distance in studs, positive in rock: first-order estimate for the
				-- ground (vertical gap over the gradient length), exact for the cave tunnel.
				local s = (h - yc) * norm
				local nearCave = false
				if caveOn and s > -8 then
					local cs = Shape.caveDistance(plan, xc, yc, zc)
					if cs < s then
						s = cs
					end
					nearCave = cs < 6
				end
				local occ = s / V + 0.5
				if occ > 1 then
					occ = 1
				elseif occ < 0 then
					occ = 0
				end
				if occ > 0 then
					local depth = h - yc
					local m
					if nearCave then
						m = slate
					elseif depth < 5 then
						m = surf
					elseif depth < 14 then
						m = sub
					else
						m = body
					end
					mx[iy][zi] = if lookup then lookup[m] else m
					ox[iy][zi] = occ
				end
				if wl > 0 and occ < 1 and yb < wl then
					local f = (wl - yb) / V
					lx[iy][zi] = if f > 1 then 1 else f
				end
			end
		end
	end

	return { SolidMaterial = mats, SolidOccupancy = occs, LiquidOccupancy = liqs }
end

return Chunk
