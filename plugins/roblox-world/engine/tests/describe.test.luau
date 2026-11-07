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

-- The test map's 3 by 3 Chunks, all generated.
local function allGenerated()
	local chunks = {}
	for i = -1, 1 do
		for j = -1, 1 do
			chunks[i .. "," .. j] = { generated = true, locked = false }
		end
	end
	return { generatorVersion = 1, chunks = chunks }
end

return {
	["the shipped plan validates"] = function(t)
		local errors = Describe.validate(plan)
		t.eq(#errors, 0, table.concat(errors, "; "))
	end,

	["heights report each Landform and River of the shipped plan"] = function(t)
		local text = Describe.heights(plan)
		local crest = tonumber(text:match("range: crest ([%d%.]+)"))
		local top = tonumber(text:match("mesa: top ([%d%.]+)"))
		local bed = tonumber(text:match("river: bed ([%d%.]+)"))
		t.ok(crest ~= nil and crest > 150, "the range rises above the hills: " .. tostring(crest))
		t.ok(top ~= nil and top > 100, "the mesa rises above the hills: " .. tostring(top))
		t.ok(bed ~= nil and bed < plan.rivers[1].waterLevel, "the River's bed lies under its water: " .. tostring(bed))
		t.ok(text:find("cave: ground", 1, true) ~= nil, "the cave is reported")
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

	["impact of several regions lists each generated chunk once, and skips those never generated"] = function(t)
		local s = allGenerated()
		s.chunks["1,1"] = { generated = true, locked = true }
		s.chunks["0,0"] = nil
		local impact = Describe.impact(plan, s, { regionIds = { "mesa", "cave" } })
		t.ok(has(impact.lockedReached, "1,1"), "locked chunk reported")
		t.eq(#impact.lockedReached, 1, "reported once, though both touch it")
		t.ok(not has(impact.rewrite, "1,1"), "locked chunk is not rewritten")
		t.ok(not has(impact.rewrite, "0,0"), "a chunk never generated stays that way")
		t.ok(has(impact.rewrite, "1,0"), "a chunk the mesa touches")
	end,

	["with no list, the borders are every pair of generated neighbours"] = function(t)
		t.eq(#Describe.bordersOf(plan, allGenerated(), nil), 12)
	end,

	["a Chunk in the middle has four borders, and one in a corner two"] = function(t)
		t.eq(#Describe.bordersOf(plan, allGenerated(), { { 0, 0 } }), 4)
		t.eq(#Describe.bordersOf(plan, allGenerated(), { { -1, -1 } }), 2)
	end,

	["two neighbouring Chunks count their shared border once"] = function(t)
		t.eq(#Describe.bordersOf(plan, allGenerated(), { { 0, 0 }, { 1, 0 } }), 6)
	end,

	["a border with a Chunk not yet generated is left out"] = function(t)
		local s = allGenerated()
		s.chunks["1,0"] = nil
		t.eq(#Describe.bordersOf(plan, s, { { 0, 0 } }), 3)
	end,

	["free extent is counted"] = function(t)
		local r = Describe.report(plan, { generatorVersion = 1, chunks = {} })
		t.eq(r.extent.total, 9)
		t.eq(r.extent.free, 9)
	end,
}
