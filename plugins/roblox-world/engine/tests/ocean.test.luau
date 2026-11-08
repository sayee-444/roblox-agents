-- Oceans, through what the pure Generator returns for a position and what it refuses or reports.
-- Until the coast exists (#70), every Ocean Chunk is the open Ocean: a flat bed at its depth cap.

local shipped = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Describe = require("../src/world/generator/Describe")
local Chunk = require("../src/world/generator/Chunk")

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

-- The engine's test map, 3 x 3 Chunks, with an Ocean over its eastern column.
local function oceanPlan(changes)
	local plan = clone(shipped)
	plan.floorY = 0
	plan.rockUnder = 8
	plan.seaLevel = 20
	plan.oceans = { { id = "ocean", seed = 8001, chunks = { { 1, -1, 1, 1 } }, depthCap = 100 } }
	if changes then
		changes(plan)
	end
	return plan
end

return {
	["an Ocean Chunk is a flat bed at its depth cap under the sea level"] = function(t)
		local plan = oceanPlan()
		-- Chunk 1 covers x from 256 to 768, so these reach both of its edges and its corners.
		for _, p in ipairs({ { 256, -768 }, { 300.5, 0 }, { 512, 440 }, { 767.9, 767.9 } }) do
			local h, _, _, level = Shape.height(plan, p[1], p[2])
			t.eq(h, -80, "bed at " .. p[1] .. " " .. p[2])
			t.eq(level, 20, "water at " .. p[1] .. " " .. p[2])
		end
	end,

	["a sound Ocean passes validation"] = function(t)
		local errors = Describe.validate(oceanPlan())
		t.eq(#errors, 0, table.concat(errors, "; "))
	end,

	["an Ocean's numbers out of range are refused"] = function(t)
		local cases = {
			{ "seaLevel must be a multiple of 4", function(p) p.seaLevel = 18 end },
			{ "seaLevel must be a multiple of 4", function(p) p.seaLevel = nil end },
			{ "needs a seed", function(p) p.oceans[1].seed = nil end },
			{ "depthCap must be a multiple of 4 above 0", function(p) p.oceans[1].depthCap = 0 end },
			{ "depthCap must be a multiple of 4 above 0", function(p) p.oceans[1].depthCap = 102 end },
			{ "chunks needs rectangles", function(p) p.oceans[1].chunks = {} end },
			{ "chunks needs rectangles", function(p) p.oceans[1].chunks = { { 1, -1, 1 } } end },
			{ "chunks needs rectangles", function(p) p.oceans[1].chunks = { { 1, 1, 1, -1 } } end },
			{ "chunks must lie inside the extent", function(p) p.oceans[1].chunks = { { 1, -1, 2, 1 } } end },
			{ "duplicate id ocean", function(p) p.oceans[2] = clone(p.oceans[1]) end },
		}
		for _, case in ipairs(cases) do
			local errors = table.concat(Describe.validate(oceanPlan(case[2])), "; ")
			t.ok(string.find(errors, case[1], 1, true) ~= nil, "expected '" .. case[1] .. "', got '" .. errors .. "'")
		end
	end,

	["an Ocean Chunk is written as plain blocks: ground under the bed, water up to the sea level"] = function(t)
		local plan = oceanPlan()
		t.eq(Chunk.columns(plan, 0, 0).flat, nil, "a Chunk of land is written column by column")
		local cols = Chunk.columns(plan, 1, 0)
		local flat = cols.flat
		t.ok(flat ~= nil, "an Ocean Chunk is a plain block")
		t.eq(flat.bed, -80, "bed")
		t.eq(flat.level, 20, "sea level")
		t.eq(flat.bottom, -88, "ground stops rockUnder below the bed")
		-- Its voxels, as a slab gives them, hold exactly that, so `borders` reads it like any Chunk.
		local slab = Chunk.slab(plan, cols, 0, 1, nil, 0, 1)
		for iy = 1, cols.ny do
			local yc = cols.ymin + (iy - 1) * 4 + 2
			for ix = 1, 2 do
				for iz = 1, 2 do
					local solid = slab.SolidOccupancy[ix][iy][iz]
					local water = slab.LiquidOccupancy[ix][iy][iz]
					if yc < -88 or yc > 20 then
						t.eq(solid + water, 0, "empty at y " .. yc)
					elseif yc < -80 then
						t.eq(solid, 1, "ground at y " .. yc)
						t.eq(water, 0, "no water in the ground at y " .. yc)
					else
						t.eq(solid, 0, "no ground over the bed at y " .. yc)
						t.eq(water, 1, "water at y " .. yc)
					end
				end
			end
		end
		t.ok(cols.ymin <= -88 and cols.ymax >= 20, "its box holds the bed and the water")
	end,

	["describe names exactly the Chunks an Ocean holds, in any shape they make"] = function(t)
		local plan = oceanPlan(function(p)
			p.oceans[1].chunks = { { 1, -1, 1, 1 }, { 0, 1, 0, 1 } }
		end)
		local report = Describe.report(plan, { chunks = {} })
		t.eq(report.regions.ocean.kind, "ocean", "kind")
		t.eq(table.concat(report.regions.ocean.chunks, " "), "1,-1 1,0 0,1 1,1", "chunks")
	end,

	["heights names each Ocean's sea level, bed and depth"] = function(t)
		local text = Describe.heights(oceanPlan())
		t.ok(string.find(text, "ocean: sea level 20, bed -80.0, depth 100, 3 Chunks", 1, true) ~= nil, text)
	end,

	["land outside the Ocean stays as it was"] = function(t)
		local plan = oceanPlan()
		local land = clone(shipped)
		land.floorY, land.rockUnder = 0, 8
		for _, p in ipairs({ { -700, -300 }, { 0, 0 }, { 255.9, 100 }, { -60, 740 } }) do
			local a, ma, ra, wa = Shape.height(plan, p[1], p[2])
			local b, mb, rb, wb = Shape.height(land, p[1], p[2])
			t.eq(a, b, "height at " .. p[1] .. " " .. p[2])
			t.eq(wa, wb, "water at " .. p[1] .. " " .. p[2])
			t.eq(ma, mb, "mesa at " .. p[1] .. " " .. p[2])
			t.eq(ra, rb, "river distance at " .. p[1] .. " " .. p[2])
		end
	end,
}
