# World history

## 2026-11-08: Ocean `ocean` depthCap 40 to 220

- **Why:** the developer asked to see an Ocean 220 studs deep and decide.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Result:** bed at -200, depth 220, `generate` 50.4 s.
- **Restore:** set `depthCap = 40` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 40 },
```

## 2026-11-08: Ocean `ocean` depthCap 100 to 40

- **Why:** the third depth measured for issue #69, at which the developer wanted the cost of a pure Ocean known.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Result:** bed at -20, `generate` 50.4 s over the Ocean at 100.
- **Snapshot:** `lab-ocean-depth-40.rbxl`, 87,395 bytes, saved by the developer.
- **Restore:** set `depthCap = 100` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 100 },
```

## 2026-11-08: Ocean `ocean` depthCap 220 to 100

- **Why:** the second depth measured for issue #69.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Result:** bed at -80, `generate` 49.1 s over the Ocean at 220.
- **Snapshot:** `lab-ocean-depth-100.rbxl`, 87,770 bytes, saved by the developer.
- **Restore:** set `depthCap = 220` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 220 },
```

## 2026-11-08: Created as a pure Ocean at depth 220

- **Why:** issue #69 measures what a pure Ocean costs to generate and save before Oceans get a coast, on a Test World of its own, apart from `lab`.
- **Implementation:** #69
- **Chunks written:** all 576 (-11,-11 to 12,12), in an empty place where 4 of them had been written first to time them.
- **Result:** bed at -200, `generate` 29.2 s, `verify 0 0` identical.
- **Snapshot:** `lab-ocean-depth-220.rbxl`, 86,553 bytes, saved by the developer.
- **Restore:** none before it. This entry starts the world.
