local plan = require("../src/world/plan")
local state = require("../src/world/state")
local Describe = require("../src/world/generator/Describe")

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

local function has(list, v)
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

return {
	["the shipped plan validates"] = function(t)
		local errors = Describe.validate(plan)
		t.eq(#errors, 0, table.concat(errors, "; "))
	end,

	["validation catches a bad plan"] = function(t)
		local bad = clone(plan)
		bad.regions[1].points = { { 0, 0 } }
		bad.rivers[1].waterLevel = 21
		bad.worldSeed = "x"
		local errors = Describe.validate(bad)
		t.ok(#errors >= 3, "errors found: " .. #errors)
	end,

	["the mountain range touches at least three chunks"] = function(t)
		local r = Describe.report(plan, state)
		t.ok(#r.regions.range.chunks >= 3, "range chunks: " .. #r.regions.range.chunks)
		t.ok(has(r.regions.range.chunks, "-1,-1") and has(r.regions.range.chunks, "0,-1") and has(r.regions.range.chunks, "1,-1"))
	end,

	["every declared landform is listed with its chunks"] = function(t)
		local r = Describe.report(plan, state)
		for _, id in ipairs({ "range", "mesa", "valley", "cave", "river" }) do
			t.ok(r.regions[id] and #r.regions[id].chunks >= 1, id .. " listed")
		end
		t.ok(has(r.regions.cave.chunks, "1,1"), "cave in chunk 1,1")
	end,

	["impact of one region lists only the chunks it touches and flags locked ones"] = function(t)
		local s = clone(state)
		s.chunks["1,1"] = { generated = true, locked = true }
		local impact = Describe.impact(plan, s, { regionId = "mesa" })
		t.ok(has(impact.rewrite, "1,1") == false, "locked chunk is not rewritten")
		t.ok(has(impact.lockedReached, "1,1"), "locked chunk reported")
		t.ok(#impact.rewrite < 9, "not everything")
		local all = Describe.impact(plan, s, { all = true })
		t.eq(#all.rewrite, 8, "all unlocked chunks")
	end,

	["free extent is counted"] = function(t)
		local r = Describe.report(plan, { generatorVersion = 1, chunks = {} })
		t.eq(r.extent.total, 9)
		t.eq(r.extent.free, 9)
	end,
}
