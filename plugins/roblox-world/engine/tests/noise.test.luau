local Noise = require("../src/world/generator/Noise")

return {
	["perlin is deterministic and bounded"] = function(t)
		for i = 1, 200 do
			local x, z = i * 0.37 - 30, i * 0.91 - 70
			local a = Noise.perlin(x, z, 12345)
			t.eq(a, Noise.perlin(x, z, 12345), "same input")
			t.ok(a >= -1 and a <= 1, "range")
		end
	end,

	["different seeds give different noise"] = function(t)
		local diff = 0
		for i = 1, 50 do
			if Noise.perlin(i * 0.53, i * 0.29, 1) ~= Noise.perlin(i * 0.53, i * 0.29, 2) then
				diff += 1
			end
		end
		t.ok(diff > 40, "seeds must change the field")
	end,

	["perlin is continuous across lattice lines"] = function(t)
		for _, x in ipairs({ -3, 0, 7 }) do
			t.near(Noise.perlin(x - 1e-6, 2.3, 9), Noise.perlin(x + 1e-6, 2.3, 9), 1e-4, "continuity")
		end
	end,

	["fbm and ridged stay in range"] = function(t)
		local lo, hi, rlo, rhi = 9, -9, 9, -9
		for i = 1, 400 do
			local f = Noise.fbm(i * 0.173, i * 0.311, 5, 5)
			local r = Noise.ridged(i * 0.173, i * 0.311, 5, 5)
			lo, hi, rlo, rhi = math.min(lo, f), math.max(hi, f), math.min(rlo, r), math.max(rhi, r)
		end
		t.ok(lo >= -1 and hi <= 1, "fbm range")
		t.ok(rlo >= 0 and rhi <= 1, "ridged range")
		t.ok(hi - lo > 0.3, "fbm actually varies")
	end,

	["hash is pinned so an engine change would show"] = function(t)
		-- Golden values, confirmed by an independent BigInt version (tools/hashcheck.js).
		t.eq(Noise.hash2(0, 0, 12345), 445614877, "hash2(0,0)")
		t.eq(Noise.hash2(-5, 17, 12345), 3033774020, "hash2(-5,17)")
	end,

	["rng repeats for one seed and differs between seeds"] = function(t)
		local a, b, c = Noise.newRng(7), Noise.newRng(7), Noise.newRng(8)
		local same, diff = true, false
		for _ = 1, 20 do
			local va, vb, vc = a:next(), b:next(), c:next()
			same = same and va == vb
			diff = diff or va ~= vc
			t.ok(va >= 0 and va < 1, "range")
		end
		t.ok(same, "same seed same sequence")
		t.ok(diff, "other seed other sequence")
	end,
}
