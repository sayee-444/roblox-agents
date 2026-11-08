# World history

## 2026-11-08: Changed Landform `ocean` depthCap 100 to 40

- **Why:** the developer asked for a shallower ocean (depthCap 40).
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Restore:** set `depthCap = 100` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 100 },
```

## 2026-11-08: Changed Landform `ocean` depthCap 220 to 100

- **Why:** the developer asked for a shallower ocean (bed at y -80).
- **Chunks written:** all 576 (-11,-11 to 12,12)
- **Restore:** set `depthCap = 220` in the `ocean` block of the World Plan, and generate all Chunks again.

```luau
{ id = "ocean", seed = 8001, chunks = { { -11, -11, 12, 12 } }, depthCap = 220 },
```
