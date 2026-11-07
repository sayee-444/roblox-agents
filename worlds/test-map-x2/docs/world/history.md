## 2026-11-07: Made the deep water a bowl, with a thin wall under it

- **Why:** the developer could see the bulge under the map and could not get into it, because the bed stopped at about -8 on 20 studs of ground. They also wanted sand near the surface and a real bed further down.
- **Chunks written:** -2,0 -1,0 0,0 1,0 -2,1 -1,1 0,1 1,1 2,1 -2,2 -1,2 0,2 1,2 2,2
- **Restore:** remove `rockUnder`, set `river` to `depths = { 8, 10, 14, 18, 26, 30 }`, `fork` to `depths = { 4, 6, 8, 10, 16 }` and the Lake to `bedY = -20`, and regenerate those Chunks. The materials and the bowl come from plugin 0.27.0.

## 2026-11-07: Gave the water varied depth, and removed the slab under the map

- **Why:** the developer wanted water of varied, editable depth, with no large slab of ground under the map. `floorY` went from -64 to 0, so every Chunk was rewritten, and solid cells in Chunk 0,1 fell from 449,281 to 189,365.
- **Chunks written:** all 36.
- **Restore:** set `floorY` back to -64, each River to `bedY = 10`, `oxbowA` and `oxbowB` to `bedY = 12` and the Lake to `bedY = 6`, remove `depths` and `bedRough`, and regenerate all Chunks.

## 2026-11-07: Moved the loop and the ring to `loops`

- **Why:** plugin 0.25.0 draws them from a radius and a turn, so the plan no longer lists each point. The shapes stay close to the ones the developer liked, and the ring is rounder, with 8 legs instead of 6.
- **Chunks written:** all that the Valleys of `river` and `fork` touch.
- **Restore:** in Git, the plan before this entry, and regenerate those Chunks.

## 2026-11-07: Tried two oxbow lakes

- **Why:** the developer asked to see oxbow lakes as a quick test. Each is a short crescent River connected to nothing, with no engine change. The developer approved how they look.
- **Chunks written:** -1,0 -2,0 0,2
- **Restore:** remove the Rivers `oxbowA` and `oxbowB` and the Valleys `oxbowValleyA` and `oxbowValleyB`, and regenerate those Chunks.

## 2026-11-07: Tried a near-closed loop, a closed ring and a third branch

- **Why:** the developer asked for rivers with far more pronounced curves and more branches. This test uses declared points only, with no engine change. The developer likes how it looks.
- **Chunks written:** -1,-1 -1,0 -1,1 -1,2 -2,-1 -2,0 -2,1 -2,2 0,-1 0,0 0,1 0,2 1,-1 1,0 1,1 1,2
- **Restore:** remove the River `branch` and the Valley `branchValley`, take the added points and their widths out of `river` and `fork`, and regenerate those Chunks.

## 2026-11-07: Gave the Rivers widths and wider bends

- **Why:** issue #31 of the engine, plugin 0.23.0: the River grows towards the Lake, the fork starts thin, and bends open up. The developer approved how the curves look.
- **Chunks written:** -1,-1 -1,0 -1,1 -1,2 -2,-1 -2,0 -2,1 0,-1 0,0 0,1 0,2 1,-1 1,0 1,1 1,2
- **Restore:** remove `widths` and `bendWiden`, set `halfWidth` back to 20 on `river` and 14 on `fork`, and regenerate those Chunks. The softer width noise comes with the plugin and stays.

## 2026-11-06: Raised the Rivers' meander

- **Why:** the developer tried a stronger bend and approved how it looks.
- **Chunks written:** -1,-1 -1,0 -1,1 -1,2 -2,-1 -2,0 -2,1 0,-1 0,0 0,1 0,2 1,-1 1,0 1,1 1,2
- **Restore:** set `meander` back to 12 on `river` and 8 on `fork`, and regenerate those Chunks.

## 2026-11-06: Curved the Rivers

- **Why:** the developer wanted Rivers that curve instead of straight legs.
- **Chunks written:** -1,-1 -1,0 -1,1 -1,2 -2,-1 -2,0 -2,1 0,-1 0,0 0,1 0,2 1,-1 1,0 1,1 1,2 
- **Restore:** remove `curve` and `meander` from each River in the World Plan, and regenerate those Chunks.

## 2026-11-06: Moved mesa `mesa` closer to the range

- **Why:** the developer wanted the mesa closer to the range.
- **Chunks written:** 2,2 3,2 2,3 3,3 (where it was) and 2,-1 3,-1 2,0 3,0 (where it is now).
- **Restore:** in the `mesa` block, set `center` back to the previous value and regenerate those Chunks.
- **Cave:** left unchanged at the old foot. Without the mesa, ground there is 46.9 at the mouth, 60.4 at (1180,1262) and 56.5 at the end (1240,1250), so the east part of the cave (axis y 60, radius 14) is now an open trench instead of a tunnel.

```luau
center = { 1300, 1250 },
```

