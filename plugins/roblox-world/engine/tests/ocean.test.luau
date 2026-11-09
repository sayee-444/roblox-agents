-- Oceans, through what the pure Generator returns for a position and what it refuses or reports.
-- The coast follows the Chunks' edges: an Ocean's depth grows with the distance to the nearest Chunk of land.

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

-- How deep the water over (x, z) is.
local function depthAt(plan, x, z)
	local h, _, _, level = Shape.height(plan, x, z)
	return level - h, level
end

return {
	["an Ocean deepens a quarter of a stud per stud from the coast, and stops at its cap"] = function(t)
		local plan = oceanPlan()
		-- Chunk column 1 covers x from 256 to 768, and the land of column 0 ends at 256.
		for _, p in ipairs({ { 256, 0, 0 }, { 296, -700, 10 }, { 456, 100, 50 }, { 652, 0, 99 }, { 656, 300, 100 }, { 767.9, 767.9, 100 } }) do
			local depth, level = depthAt(plan, p[1], p[2])
			t.near(depth, p[3], 1e-6, "depth at " .. p[1] .. " " .. p[2])
			t.eq(level, 20, "sea level at " .. p[1] .. " " .. p[2])
		end
	end,

	["a wide Ocean reaches about 400 at 3 Chunks from the coast, 512 at 4, and its default cap of 1200 by 13"] = function(t)
		-- Land in column -1 only, and Ocean from column 0 to 14, so the coast lies at x -256.
		local plan = oceanPlan(function(p)
			p.extent = { minX = -1, maxX = 14, minZ = -1, maxZ = 1 }
			p.oceans = { { id = "ocean", seed = 8001, chunks = { { 0, -1, 14, 1 } } } }
		end)
		-- Past 2,400 studs it grows as the natural log: 600 * (1 + ln(6000 / 2400)) = 1149.8.
		for _, p in ipairs({ { 1536, 384 }, { 2048, 512 }, { 2400, 600 }, { 6000, 1149.77 }, { 6656, 1200 }, { 7000, 1200 } }) do
			t.near((depthAt(plan, -256 + p[1], 0)), p[2], 0.01, "depth " .. p[1] .. " studs out")
		end
	end,

	["touching Ocean Chunks hold one sea level, with no wall between them"] = function(t)
		-- An L: down column 1, then west along row 1. Borders at z 256 and at x 256.
		local plan = oceanPlan(function(p)
			p.oceans[1].chunks = { { 1, -1, 1, 0 }, { 1, 1, 1, 1 }, { 0, 1, 0, 1 } }
		end)
		for _, pair in ipairs({ { { 500, 255.9 }, { 500, 256.1 } }, { { 255.9, 600 }, { 256.1, 600 } } }) do
			local a, la = depthAt(plan, pair[1][1], pair[1][2])
			local b, lb = depthAt(plan, pair[2][1], pair[2][2])
			t.eq(la, 20, "sea level")
			t.eq(lb, 20, "sea level")
			t.near(a, b, 0.1, "depth on both sides of the border at " .. pair[1][1] .. " " .. pair[1][2])
		end
	end,

	["a channel 20 studs wide stays wadeable, and one 5 Chunks wide reaches its cap"] = function(t)
		-- Chunks of 20 studs, so that the middle column is a channel 20 wide between two Landmasses.
		local narrow = oceanPlan(function(p)
			p.chunkSize = 20
			p.oceans = { { id = "channel", seed = 8001, chunks = { { 0, -1, 0, 1 } } } }
		end)
		-- A character's waist stands about 3 studs up, from its usual size and not measured.
		local deepest = 0
		for x = -9.5, 9.5, 0.5 do
			deepest = math.max(deepest, (depthAt(narrow, x, 3)))
		end
		t.ok(deepest <= 3, "the channel is " .. deepest .. " deep")
		t.ok(deepest > 0, "the channel holds water")
		local wide = oceanPlan(function(p)
			p.extent = { minX = -3, maxX = 3, minZ = -1, maxZ = 1 }
			p.oceans = { { id = "channel", seed = 8001, chunks = { { -2, -1, 2, 1 } }, depthCap = 300 } }
		end)
		t.near((depthAt(wide, 0, 0)), 300, 1e-6, "the middle of a channel 5 Chunks wide")
		t.near((depthAt(wide, -1100, 0)), 45, 1e-6, "180 studs from its coast")
	end,

	["a sound Ocean passes validation"] = function(t)
		local errors = Describe.validate(oceanPlan())
		t.eq(#errors, 0, table.concat(errors, "; "))
		local tuned = Describe.validate(oceanPlan(function(p)
			p.oceans[1].depthCap = false
			p.oceans[1].slope = 0.05
			p.oceans[1].bend = 1200
		end))
		t.eq(#tuned, 0, table.concat(tuned, "; "))
	end,

	["a gentler slope keeps the water shallow further out"] = function(t)
		local plan = oceanPlan(function(p)
			p.oceans[1].slope = 0.05
		end)
		t.near((depthAt(plan, 456, 0)), 10, 1e-6, "200 studs from the coast")
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
			{ "depthCap must be a multiple of 4 above 0, or false for no cap", function(p) p.oceans[1].depthCap = true end },
			{ "slope must be from 0.02 to 1.5", function(p) p.oceans[1].slope = 0 end },
			{ "slope must be from 0.02 to 1.5", function(p) p.oceans[1].slope = 2 end },
			{ "bend must be above 0", function(p) p.oceans[1].bend = -10 end },
			{ "has no field depth", function(p) p.oceans[1].depth = 100 end },
			-- Two Oceans that share a border would hold one body of water with two caps.
			{ "ocean west touches ocean ocean, so they form one body of water: declare them as one Ocean", function(p)
				p.oceans[2] = { id = "west", seed = 8002, chunks = { { 0, 1, 0, 1 } } }
			end },
			{ "ocean west shares Chunk 1,1 with ocean ocean", function(p)
				p.oceans[2] = { id = "west", seed = 8002, chunks = { { 1, 1, 1, 1 } } }
			end },
			{ "ocean ocean: with no cap and no land in the world, its depth has no bound", function(p)
				p.oceans[1].chunks = { { -1, -1, 1, 1 } }
				p.oceans[1].depthCap = false
			end },
		}
		for _, case in ipairs(cases) do
			local errors = table.concat(Describe.validate(oceanPlan(case[2])), "; ")
			t.ok(string.find(errors, case[1], 1, true) ~= nil, "expected '" .. case[1] .. "', got '" .. errors .. "'")
		end
	end,

	["an Ocean Chunk far from any coast is written as plain blocks: ground under the bed, water up to the sea level"] = function(t)
		local plan = oceanPlan(function(p)
			p.extent = { minX = -1, maxX = 14, minZ = -1, maxZ = 1 }
			p.oceans = { { id = "ocean", seed = 8001, chunks = { { 0, -1, 14, 1 } } } }
		end)
		t.eq(Chunk.columns(plan, -1, 0).flat, nil, "a Chunk of land is written column by column")
		-- Chunk 12 starts 6,144 studs from the coast, short of the 6,524 where the depth meets its cap.
		t.eq(Chunk.columns(plan, 12, 0).flat, nil, "an Ocean Chunk within reach of the coast is written column by column")
		-- Chunk 13 starts 6,656 out, past it.
		local cols = Chunk.columns(plan, 13, 0)
		local flat = cols.flat
		t.ok(flat ~= nil, "an Ocean Chunk past the reach of the coast is a plain block")
		t.eq(flat.bed, -1180, "bed")
		t.eq(flat.level, 20, "sea level")
		t.eq(flat.bottom, -1188, "ground stops rockUnder below the bed")
		-- Its voxels, as a slab gives them, hold exactly that, so `borders` reads it like any Chunk.
		local slab = Chunk.slab(plan, cols, 0, 1, nil, 0, 1)
		for iy = 1, cols.ny do
			local yc = cols.ymin + (iy - 1) * 4 + 2
			for ix = 1, 2 do
				for iz = 1, 2 do
					local solid = slab.SolidOccupancy[ix][iy][iz]
					local water = slab.LiquidOccupancy[ix][iy][iz]
					if yc < -1188 or yc > 20 then
						t.eq(solid + water, 0, "empty at y " .. yc)
					elseif yc < -1180 then
						t.eq(solid, 1, "ground at y " .. yc)
						t.eq(water, 0, "no water in the ground at y " .. yc)
					else
						t.eq(solid, 0, "no ground over the bed at y " .. yc)
						t.eq(water, 1, "water at y " .. yc)
					end
				end
			end
		end
		t.ok(cols.ymin <= -1188 and cols.ymax >= 20, "its box holds the bed and the water")
		-- Written column by column, the Chunk beside it meets it with no step.
		local h = Shape.height(plan, 6399.9, 0)
		t.near(h, -1180, 0.01, "bed at the border, on the side within reach")
	end,

	["describe names exactly the Chunks an Ocean holds, in any shape they make"] = function(t)
		local plan = oceanPlan(function(p)
			p.oceans[1].chunks = { { 1, -1, 1, 1 }, { 0, 1, 0, 1 } }
		end)
		local report = Describe.report(plan, { chunks = {} })
		t.eq(report.regions.ocean.kind, "ocean", "kind")
		t.eq(table.concat(report.regions.ocean.chunks, " "), "1,-1 1,0 0,1 1,1", "chunks")
	end,

	["heights names each Ocean's sea level, its deepest point and whether its cap cut it"] = function(t)
		local cut = Describe.heights(oceanPlan())
		t.ok(string.find(cut, "ocean: sea level 20, deepest %-80%.0 at %d+ %-?%d+, cut by its cap of 100, 3 Chunks") ~= nil, cut)
		-- Its far edge lies 511 studs from the coast: 127.75 deep.
		local short = Describe.heights(oceanPlan(function(p)
			p.oceans[1].depthCap = 200
		end))
		t.ok(string.find(short, "ocean: sea level 20, deepest %-107%.8 at 767 %-?%d+, its cap of 200 not reached, 3 Chunks") ~= nil, short)
		local none = Describe.heights(oceanPlan(function(p)
			p.oceans[1].depthCap = false
		end))
		t.ok(string.find(none, "ocean: sea level 20, deepest %-107%.8 at 767 %-?%d+, no cap, 3 Chunks") ~= nil, none)
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
