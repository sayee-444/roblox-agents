--!nonstrict
-- Material choice from height, slope and noise. Slope comes from height differences at
-- neighbouring world positions (never from Chunk data), so it agrees across borders.
-- Materials are small integer ids; the Studio writer maps them to Enum.Material.

local Noise = require("./Noise")

local Materials = {}

Materials.names = { "Air", "Grass", "Ground", "Rock", "Slate", "Sand", "Sandstone", "Snow", "Mud" }
Materials.id = {}
for i, name in ipairs(Materials.names) do
	Materials.id[name] = i
end

local id = Materials.id

-- What lies a few studs under each surface material.
Materials.sub = {
	[id.Grass] = id.Ground,
	[id.Ground] = id.Ground,
	[id.Sand] = id.Sand,
	[id.Mud] = id.Mud,
	[id.Snow] = id.Rock,
	[id.Rock] = id.Rock,
	[id.Slate] = id.Rock,
	[id.Sandstone] = id.Sandstone,
}

-- Surface material of one column. `g` is the slope (rise over run), `mesaP` the mesa
-- parameter (0 outside, 1 on top) and `riverD` the distance to a River route, moved out where the River is wide, or to lake water.
function Materials.surface(plan, x: number, z: number, h: number, g: number, mesaP: number, riverD: number): number
	local M = plan.materials
	local n = Noise.perlin(x / 18, z / 18, plan.worldSeed + 77)

	if riverD < M.bankDist and h < M.bankHeight then
		return id.Sand
	end
	-- The foot of a mesa keeps the hills' ground, so that it grows out of them.
	local onMesa = mesaP > 0.12 + n * 0.08 or (mesaP > 0.02 and g > M.mesaRiser)
	if onMesa then
		if g > M.mesaRiser then
			local tilt = 14 * Noise.perlin(x / 120, z / 120, plan.worldSeed + 80)
			local bed = Noise.perlin(0.5 + x / 300, (h + tilt) / 13, plan.worldSeed + 78)
			return if bed > 0 then id.Rock else id.Sandstone
		end
		local patch = Noise.perlin(x / 70, z / 70, plan.worldSeed + 79) + n * 0.15
		if patch > 0.12 then -- no Sand here: it renders near-white
			return id.Ground
		end
		return if patch > -0.25 then id.Sandstone else id.Grass
	end
	if h > M.snowLine + n * M.snowBlend and g < M.snowMaxSlope then
		return id.Snow
	end
	if g > M.steep + n * 0.1 then
		return id.Rock
	end
	if h > M.rockLine + n * 20 then
		return if n > 0.35 then id.Slate else id.Rock
	end
	if g > M.steep * 0.6 then
		return if n > 0 then id.Rock else id.Ground
	end
	return if n > 0.55 then id.Ground else id.Grass
end

return Materials
