local plan = require("../src/world/plan")
local Shape = require("../src/world/generator/Shape")
local Geo = require("../src/world/generator/Geo")

local function H(x, z)
	return (Shape.height(plan, x, z))
end

return {
	["height is deterministic"] = function(t)
		for i = 1, 100 do
			local x, z = i * 13.7 - 600, i * 9.1 - 400
			t.eq(H(x, z), H(x, z), "same position")
		end
	end,

	["hills are gentle away from every Landform Region"] = function(t)
		-- North-west corner, clear of the range (z < -380 - 170 is out of reach), mesa and valley.
		local maxSlope = 0
		for i = 0, 40 do
			local x, z = -700 + i * 4, 600 - i * 3
			local s = math.abs(H(x + 4, z) - H(x - 4, z)) / 8
			maxSlope = math.max(maxSlope, s)
			t.ok(H(x, z) > 10 and H(x, z) < 100, "hill height band")
		end
		t.ok(maxSlope < 0.5, "hill slope " .. maxSlope)
	end,

	["mountain range follows its polyline and towers over the hills"] = function(t)
		local range
		for _, r in ipairs(plan.regions) do
			if r.id == "range" then
				range = r
			end
		end
		local poly = Geo.polyline2(range.points)
		-- Sample the crest line: the best height within 25 studs of the polyline.
		local peak = 0
		for s = 0, poly.length, 15 do
			-- walk along segments
			local acc, seg = 0, nil
			for _, sg in ipairs(poly.segs) do
				if s <= sg[7] + sg[6] then
					seg = sg
					break
				end
			end
			seg = seg or poly.segs[#poly.segs]
			local tt = math.clamp((s - seg[7]) / seg[6], 0, 1)
			local px, pz = seg[1] + tt * seg[3], seg[2] + tt * seg[4]
			for dx = -25, 25, 25 do
				peak = math.max(peak, H(px + dx, pz))
			end
		end
		t.ok(peak > 220, "crest peak " .. peak)
		-- Beyond the blend margin the range has no influence at all.
		local x, z = -300, -300 + 171 -- just outside halfWidth, away from other regions
		t.ok(H(x, z) < 110, "outside margin " .. H(x, z))
	end,

	["mesa shows at least four distinct terraces on its richest side"] = function(t)
		local mesa
		for _, r in ipairs(plan.regions) do
			if r.id == "mesa" then
				mesa = r
			end
		end
		-- Along each radius, count flat runs at distinct heights, and keep the largest count.
		local cx, cz = mesa.center[1], mesa.center[2]
		local most = 0
		for a = 0, 345, 15 do
			local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
			local runs, last, flat = 0, nil, 0
			for d = mesa.radius + mesa.margin, 0, -2 do
				local h0 = H(cx + ca * d, cz + sa * d)
				local h1 = H(cx + ca * (d - 2), cz + sa * (d - 2))
				if math.abs(h1 - h0) < 1.2 then
					flat += 1
					if flat == 4 then -- 8 studs of tread
						local level = math.floor(h1 / 8)
						if last == nil or level > last + 1 then
							runs += 1
							last = level
						end
					end
				else
					flat = 0
				end
			end
			most = math.max(most, runs)
		end
		t.ok(most >= 4, "terraces found: " .. most)
	end,

	["mesa risers are cliffs, not needles: steep but under 3.6 rise over run"] = function(t)
		local mesa
		for _, r in ipairs(plan.regions) do
			if r.id == "mesa" then
				mesa = r
			end
		end
		local worst = 0
		for a = 0, 350, 25 do
			local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
			for d = 0, mesa.radius + mesa.margin, 1 do
				local h0 = H(mesa.center[1] + ca * d, mesa.center[2] + sa * d)
				local h1 = H(mesa.center[1] + ca * (d + 4), mesa.center[2] + sa * (d + 4))
				worst = math.max(worst, math.abs(h1 - h0) / 4)
			end
		end
		t.ok(worst < 3.6, "steepest riser " .. worst)
		t.ok(worst > 1.5, "still a cliff " .. worst)
	end,

	["mesa outline is irregular, not a circle"] = function(t)
		local mesa
		for _, r in ipairs(plan.regions) do
			if r.id == "mesa" then
				mesa = r
			end
		end
		local nearest, farthest = math.huge, 0
		for a = 0, 350, 10 do
			local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
			local foot = 0
			for d = 0, mesa.radius + mesa.margin + mesa.warp, 2 do
				local _, p = Shape.height(plan, mesa.center[1] + ca * d, mesa.center[2] + sa * d)
				if p > 0 then
					foot = d
				end
			end
			nearest = math.min(nearest, foot)
			farthest = math.max(farthest, foot)
		end
		t.ok(farthest / nearest >= 1.2, "widest over narrowest " .. farthest / nearest)
	end,

	["mesa ledges break and return instead of closing into rings"] = function(t)
		local mesa
		for _, r in ipairs(plan.regions) do
			if r.id == "mesa" then
				mesa = r
			end
		end
		local counts, distinct = {}, 0
		for a = 0, 345, 15 do
			local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
			local treads, flat = 0, 0
			for d = mesa.radius + mesa.margin, mesa.radius * 0.5, -2 do
				local h0 = H(mesa.center[1] + ca * d, mesa.center[2] + sa * d)
				local h1 = H(mesa.center[1] + ca * (d - 2), mesa.center[2] + sa * (d - 2))
				if math.abs(h1 - h0) < 0.8 then
					flat += 1
					if flat == 4 then
						treads += 1
					end
				else
					flat = 0
				end
			end
			if not counts[treads] then
				counts[treads] = true
				distinct += 1
			end
		end
		t.ok(distinct >= 3, "distinct ledge counts around the mesa " .. distinct)
	end,

	["a branching River keeps both beds under water where they meet"] = function(t)
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
		local forked = clone(plan)
		local main = forked.rivers[1]
		local junction = main.points[3]
		local branch = {
			id = "branch",
			points = { { junction[1], junction[2] }, { junction[1] + 80, junction[2] + 90 }, { junction[1] + 60, junction[2] + 220 } },
			halfWidth = 14,
			bedY = main.bedY,
			waterLevel = main.waterLevel,
		}
		table.insert(forked.rivers, branch)
		table.insert(forked.regions, { id = "branchValley", kind = "valley", seed = 7099, riverId = "branch", halfWidth = 90, floorY = 24 })
		for _, route in ipairs({ main.points, branch.points }) do
			-- Walk the whole channel, because a dam would sit between route points.
			for i = 1, #route - 1 do
				local p, q = route[i], route[i + 1]
				for s = 0, 1, 0.02 do
					local x, z = p[1] + (q[1] - p[1]) * s, p[2] + (q[2] - p[2]) * s
					local h, _, _, level = Shape.height(forked, x, z)
					t.ok(h < main.waterLevel, "bed at " .. x .. "," .. z .. " is at " .. h)
					t.ok(h > main.bedY - 4, "no pit where the beds meet: " .. x .. "," .. z .. " is at " .. h)
					t.eq(level, main.waterLevel, "water over the route")
				end
			end
		end
	end,

	["river bed lies below the water level along every route point"] = function(t)
		local river = plan.rivers[1]
		for _, p in ipairs(river.points) do
			local h, _, rd, wl = Shape.height(plan, p[1], p[2])
			t.ok(h < river.waterLevel - 3, "bed at route point " .. h)
			t.eq(wl, river.waterLevel, "water over route point")
			t.ok(rd < 1, "distance to route")
		end
	end,

	["river banks hold the water in"] = function(t)
		local river = plan.rivers[1]
		local poly = Geo.polyline2(river.points)
		-- Walk perpendicular to each segment: ground at 40 studs must be above the water.
		for _, sg in ipairs(poly.segs) do
			local mx, mz = sg[1] + sg[3] / 2, sg[2] + sg[4] / 2
			local nx, nz = -sg[4] / sg[6], sg[3] / sg[6]
			for _, side in ipairs({ -1, 1 }) do
				local h, _, _, wl = Shape.height(plan, mx + nx * 40 * side, mz + nz * 40 * side)
				t.ok(h > river.waterLevel + 1, "bank height " .. h)
				t.eq(wl, 0, "no water on the bank")
			end
		end
	end,

	["cave mouth is open ground and the tunnel gets covered by rock"] = function(t)
		local cave
		for _, r in ipairs(plan.regions) do
			if r.id == "cave" then
				cave = r
			end
		end
		t.ok(cave.radius >= 14, "tunnel at least 28 studs across, so voxels read as round")
		local p1, p4 = cave.points[1], cave.points[#cave.points]
		-- The axis is inside the tunnel along its whole length.
		for i = 1, #cave.points do
			local p = cave.points[i]
			t.ok(Shape.caveDistance(plan, p[1], p[2], p[3]) < -cave.radius * 0.6, "axis inside tunnel " .. i)
		end
		-- Mouth: outside the hill the ground is at or below the tunnel floor + 4.
		local floorY = p1[2] - cave.radius
		t.ok(H(p1[1] - 12, p1[3]) <= p1[2] - cave.radius + 14, "open ground in front of the mouth")
		-- Inside: at least 12 studs of rock over the roof from 60 studs in.
		local deep = cave.points[3]
		t.ok(H(deep[1], deep[3]) - (deep[2] + cave.radius) > 12, "rock above the deep tunnel")
		t.ok(p4[1] > p1[1] + 100, "tunnel runs at least 100 studs")
	end,
}
