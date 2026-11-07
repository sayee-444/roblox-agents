## 2026-11-06: Restored River `river` and Landform Region `valley`

- **Why:** the developer asked to bring back the River removed earlier today.
- **Chunks written:** all 9 (-1,-1 to 1,1); none were Locked. The River and valley touch -1,0 0,0 -1,1 0,1.
- **Restore:** the blocks from the entry below went back into `regions` and `rivers` unchanged. To remove them again, delete those two blocks and regenerate.

## 2026-11-06: Removed River `river` and Landform Region `valley`

- **Why:** the developer asked to remove the river. The `valley` Region only carved along that River (`riverId = "river"`), so it went with it.
- **Chunks written:** all 9 (-1,-1 to 1,1); the River crossed -1,0 -1,1 0,1 and the valley margin reached the neighbours.
- **Restore:** paste the first block into `regions` and the second into `rivers` in the World Plan, and regenerate.

```luau
{
	id = "valley",
	kind = "valley",
	seed = 7003,
	riverId = "river",
	halfWidth = 130,
	floorY = 24,
},
```

```luau
{
	id = "river",
	points = { { -740, 40 }, { -540, 140 }, { -340, 200 }, { -160, 330 }, { -40, 520 }, { -60, 740 } },
	halfWidth = 20,
	bedY = 10,
	waterLevel = 20, -- multiple of the voxel size, so the surface meets a voxel boundary
},
```
