## 2026-11-07: Valley sides now decide how deep the water gets

- **Why:** the engine changed so a valley's `sides` set the depth of its water, and the River's `depths` and the Lake's `bedY` are only the deepest it may reach. `banks` no longer accepts `shallows`, `shallowDepth`, `bedFlat` or `steep`, so those were removed, and each valley got `sides`: `river` steep (0.7, then 1.2) in its last stretch before the Lake, and `fork`, `branch`, `oxbowA`, `oxbowB` gentle (0.1 to 0.12).
- **Chunks written:** all 144 (extent -5..6)
- **Result (asked / reached):** river depth 12 to 90 / 1.1 to 77.5; fork 8 to 70 / 1.0 to 4.9; branch 8 to 40 / 1.0 to 4.9; oxbowA 6 to 40 / 1.0 to 2.5; oxbowB 6 to 30 / 1.0 to 1.8; lake 110 / 63.6.
- **Restore:** replace these lines in the World Plan with the old ones below, then generate every Chunk again. Delete the `sides` lines of the five valleys.

```luau
-- river banks
banks = { shore = 50, shallows = 30, shallowDepth = 4, bedFlat = 0.2, steep = 1.6, rough = 3, vary = 0.6, smooth = 48 },
-- fork banks
banks = { shore = 36, shallows = 20, shallowDepth = 3, bedFlat = 0.2, steep = 1.4, rough = 2.5, vary = 0.6, smooth = 40 },
-- branch banks
banks = { shore = 30, shallows = 12, shallowDepth = 2, bedFlat = 0.3, steep = 2, rough = 3, vary = 0.5, smooth = 40 },
-- oxbowA banks
banks = { shore = 30, shallows = 16, shallowDepth = 3, bedFlat = 0.4, steep = 1.3, rough = 2, vary = 0.5 },
-- oxbowB banks
banks = { shore = 30, shallows = 16, shallowDepth = 3, bedFlat = 0.3, steep = 1.3, rough = 2, vary = 0.5 },
-- lake banks
banks = { shallows = 50, shallowDepth = 6, bedFlat = 0.25, steep = 1.3, rough = 6, vary = 0.6 }
```

## 2026-11-07: Kept this map as the result of #43

- **Why:** the developer wants the next Implementations compared against this state. PR #46, for issue #43, is the last Implementation that changed this World Plan, and doubling the map in #49 was undone in #50.
- **Implementation:** #43
- **Chunks written:** none for this entry. All 144 were last written on plugin 0.32.0, and Chunks 0,0 and -3,-5 rewrote identical on 0.33.0.
- **Snapshot:** `lab-issue-43.rbxl`

## 2026-11-07: Made the world and its water larger, with parametrized banks

- **Why:** the River read as a deep stream, its depth barely changed, the water fell straight from the shore, and hills stood around it.
- **Chunks written:** all 144.
- **Restore:** set `extent` to -2..3. Take each `points`, `center` and cave position back with (value + 256) / 2. Remove every `depthVary` and `banks`. Range `halfWidth` 170. Valleys' `floorY` 24 and `halfWidth`: valley 130, forkValley 90, oxbowValleyA 60, oxbowValleyB 60, branchValley 90. Loops' `radius`: river 110, fork 120. `meander`: river 40, fork 30, branch 30. `widths`: river 14 16 18 20 26 34, fork 6 10 12 14 20, branch 6 10 12 14 14, oxbowA 6 14 18 14 6, oxbowB 6 10 14 10 6. `depths`: river 10 14 24 36 44 50, fork 6 10 18 28 44, branch 4 6 8 10 10, oxbowA 4 10 16 10 4, oxbowB 4 8 12 8 4. River `bedRough` 3. Lake `radius` 170, `shore` 60, `warp` 20, `bedY` -50, `bedRough` 6. Then regenerate all Chunks. Chunks outside -2..3 stay until the developer orders a wipe.

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

