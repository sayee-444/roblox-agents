--!strict
-- Our own seeded noise and random number generator. Pure integer hashing plus
-- arithmetic, so no engine update can change the output (math.noise and Random
-- document no algorithm and math.noise takes no seed).

local Noise = {}

local M32 = 4294967296

-- 32-bit multiply that stays exact in doubles: split `a` into 16-bit halves.
local function mul32(a: number, b: number): number
	local lo = a % 65536
	local hi = (a - lo) / 65536
	return (lo * b + ((hi * b) % 65536) * 65536) % M32
end

-- Hash of an integer lattice point and a seed, as an integer in [0, 2^32).
function Noise.hash2(ix: number, iz: number, seed: number): number
	local h = seed % M32
	h = bit32.bxor(h, mul32(ix % M32, 0x27D4EB2D))
	h = mul32(h, 0x165667B1)
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = bit32.bxor(h, mul32(iz % M32, 0x85EBCA6B))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0x27D4EB2D)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

-- Eight unit-ish gradient directions.
local GX = { 1, -1, 0, 0, 0.70710678, -0.70710678, 0.70710678, -0.70710678 }
local GZ = { 0, 0, 1, -1, 0.70710678, 0.70710678, -0.70710678, -0.70710678 }

-- Gradient noise, range about [-1, 1], zero at lattice points.
function Noise.perlin(x: number, z: number, seed: number): number
	local xi = math.floor(x)
	local zi = math.floor(z)
	local xf = x - xi
	local zf = z - zi
	local u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
	local v = zf * zf * zf * (zf * (zf * 6 - 15) + 10)

	local g00 = bit32.band(bit32.rshift(Noise.hash2(xi, zi, seed), 8), 7) + 1
	local g10 = bit32.band(bit32.rshift(Noise.hash2(xi + 1, zi, seed), 8), 7) + 1
	local g01 = bit32.band(bit32.rshift(Noise.hash2(xi, zi + 1, seed), 8), 7) + 1
	local g11 = bit32.band(bit32.rshift(Noise.hash2(xi + 1, zi + 1, seed), 8), 7) + 1

	local n00 = GX[g00] * xf + GZ[g00] * zf
	local n10 = GX[g10] * (xf - 1) + GZ[g10] * zf
	local n01 = GX[g01] * xf + GZ[g01] * (zf - 1)
	local n11 = GX[g11] * (xf - 1) + GZ[g11] * (zf - 1)

	local nx0 = n00 + (n10 - n00) * u
	local nx1 = n01 + (n11 - n01) * u
	local r = (nx0 + (nx1 - nx0) * v) * 1.4142136
	if r > 1 then
		return 1
	elseif r < -1 then
		return -1
	end
	return r
end

-- Octave sum that doubles frequency and halves amplitude, normalised to about [-1, 1].
function Noise.fbm(x: number, z: number, seed: number, octaves: number): number
	local sum, amp, norm, freq = 0, 1, 0, 1
	for o = 1, octaves do
		sum += amp * Noise.perlin(x * freq + o * 31.7, z * freq - o * 17.3, seed + o * 101)
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end

-- Ridged noise in [0, 1]: sharp crests; each octave is weighted by the one below,
-- so fine detail gathers on the crests.
function Noise.ridged(x: number, z: number, seed: number, octaves: number): number
	local sum, amp, norm, freq, weight = 0, 1, 0, 1, 1
	for o = 1, octaves do
		local n = 1 - math.abs(Noise.perlin(x * freq + o * 13.1, z * freq - o * 7.9, seed + o * 211))
		n = n * n * weight
		weight = math.clamp(n * 2, 0, 1)
		sum += n * amp
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end

-- Small seeded generator (xorshift32). Same seed, same sequence, on any engine.
export type Rng = { state: number, next: (Rng) -> number }

local RngMethods = {}
RngMethods.__index = RngMethods

function RngMethods.next(self: Rng): number
	local s = self.state
	s = bit32.bxor(s, bit32.lshift(s, 13))
	s = bit32.bxor(s, bit32.rshift(s, 17))
	s = bit32.bxor(s, bit32.lshift(s, 5))
	self.state = s
	return s / M32
end

function Noise.newRng(seed: number): Rng
	local s = Noise.hash2(seed, 0x9E37, 0x1234)
	if s == 0 then
		s = 0x6D2B79F5
	end
	return setmetatable({ state = s }, RngMethods) :: any
end

return Noise
