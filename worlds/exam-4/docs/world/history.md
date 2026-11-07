# World history

Newest first.

## 2026-11-06: Extended the map west, with the Rivers ending in a lake

- **Why:** the developer asked for a full rectangle, with the same Rivers flowing into a lake.
- **Chunks written:** -2,-1 -2,0 -2,1 -1,-1 -1,0
- **Restore:** in the World Plan set `extent` back to `minX = -1`, set `lakes = {}`, and end the Rivers at the points below. The terrain of column -2 stays until the developer deletes it, since no command removes one Chunk.

```luau
{ id = "river", points = { { 740, 102 }, { 369, 59 }, { 7, -49 }, { -365, -84 }, { -740, -96 } }, halfWidth = 24, bedY = 10, waterLevel = 20 },
{ id = "fork", points = { { 7, -49 }, { -241, -135 }, { -474, -266 }, { -740, -301 } }, halfWidth = 14, bedY = 10, waterLevel = 20 },
```
