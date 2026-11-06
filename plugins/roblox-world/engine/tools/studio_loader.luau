-- Bootstrap pasted into Studio through execute_luau (Edit datamodel). Studio's MCP thread
-- cannot fetch over HTTP or parent scripts, but loadstring works and `shared` persists
-- between calls. So source text is pushed with shared.World.add(path, source) and run
-- with shared.World.require(path); relative requires such as "../plan" resolve here.
-- tools/world.js sends this file and checks the adler32 + length that shared.World.add returns.

local W = shared.World or {}
shared.World = W
W.src = W.src or {}
W.cache = {}

local function adler32(s)
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + string.byte(s, i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

local function normalise(dir, rel)
	local parts = {}
	for seg in string.gmatch(dir, "[^/]+") do
		table.insert(parts, seg)
	end
	for seg in string.gmatch(rel, "[^/]+") do
		if seg == ".." then
			table.remove(parts)
		elseif seg ~= "." then
			table.insert(parts, seg)
		end
	end
	return table.concat(parts, "/")
end

local function load(path)
	local hit = W.cache[path]
	if hit ~= nil then
		return hit
	end
	local src = W.src[path]
	assert(src, "missing module " .. path)
	local dir = string.match(path, "^(.*)/[^/]*$") or ""
	local fn, err = loadstring("local require = ...; " .. src, "=" .. path)
	assert(fn, err)
	local value = fn(function(rel)
		return load(normalise(dir, rel))
	end)
	W.cache[path] = value
	return value
end

W.add = function(path, source)
	W.src[path] = source
	W.cache = {}
	return string.format("%s %d %d", path, adler32(source), #source)
end
W.require = load
-- Takes lines of "<path> <adler32> <length>" and returns the paths whose source in
-- Studio is missing or different, so only those are pasted.
W.differs = function(manifest)
	local out = {}
	for path, sum, len in string.gmatch(manifest, "(%S+) (%d+) (%d+)") do
		local src = W.src[path]
		if not src or #src ~= tonumber(len) or adler32(src) ~= tonumber(sum) then
			table.insert(out, path)
		end
	end
	return out
end
return "loader ready"
