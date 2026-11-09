-- Test runner. Works under Lute (`lute tests/run.luau`) and inside Studio through the
-- loader in tools/studio_loader.luau, which supplies `require` for these relative paths.
-- Each suite returns { [testName] = function(t) ... end }.

local suites = {
	{ "noise", require("./noise.test") },
	{ "shape", require("./shape.test") },
	{ "materials", require("./materials.test") },
	{ "chunk", require("./chunk.test") },
	{ "describe", require("./describe.test") },
	{ "lake", require("./lake.test") },
	{ "route", require("./route.test") },
	{ "bank", require("./bank.test") },
	{ "ocean", require("./ocean.test") },
	{ "depth", require("./depth.test") },
}

local T = {}
function T.ok(cond, msg)
	if not cond then
		error(msg or "expected truthy", 2)
	end
end
function T.eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
	end
end
function T.near(a, b, tol, msg)
	if math.abs(a - b) > tol then
		error(string.format("%s: expected %s +- %s, got %s", msg or "near", tostring(b), tostring(tol), tostring(a)), 2)
	end
end

local lines, passed, failed = {}, 0, 0
local lastYield = os.clock()
for _, entry in ipairs(suites) do
	local names = {}
	for name in pairs(entry[2]) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local ok, err = pcall(entry[2][name], T)
		if ok then
			passed += 1
			table.insert(lines, "PASS " .. entry[1] .. " / " .. name)
		else
			failed += 1
			table.insert(lines, "FAIL " .. entry[1] .. " / " .. name .. " -> " .. tostring(err))
		end
		-- Under Lute there is no `task`. In Studio a long block keeps it from answering any call.
		if task and os.clock() - lastYield >= 0.25 then
			task.wait()
			lastYield = os.clock()
		end
	end
end
table.insert(lines, string.format("%d passed, %d failed", passed, failed))
return { passed = passed, failed = failed, report = table.concat(lines, "\n") }
