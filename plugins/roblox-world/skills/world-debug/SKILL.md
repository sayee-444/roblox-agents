---
name: world-debug
description: Debug mode for a world, as the last step of a task. Use when a check fails, a view looks wrong, or the developer asks for debug.
---

Debugging is bounded: find which kind of problem this is, then fix it or report it. Build first, and debug last.

1. **Run the facts.** `world.js check --place <name> --project <dir>` tests the engine, validates the plan and compares every border, and writes no terrain. A failing test, an invalid plan or a border mismatch is a real defect, so reproduce it with a failing test and fix it through the World Plan or the Generator.
2. **Read the one spot.** For a place the developer points at, use `height <x> <z>`, a raycast or a voxel read. Confirm an empty test on a known-good spot, because a wrong index once reported 2,806 false holes.
3. **Refresh once.** When voxels are correct, the problem is only rendering. Run `refresh` once, then ask the developer what they see, or run `capture <view>` if they are away.
4. **Stop and report.** If it stays after one refresh, report it as rendering. Chasing one such rectangle once cost 5.5 minutes and proved nothing.

Done when each symptom has one verdict: defect fixed, defect reported, rendering, or unknown.

## False alarms

| Seen | What it is | Do this |
|---|---|---|
| Flat dark capture with only the view cube | The Studio window is minimized. Covered by another window, it still renders | Ask the developer to restore it |
| Dark rectangle, missing patch or sky through a wall after a write | The render mesh is still building | Refresh once |
| Coarse or missing Chunk far from the camera | Studio builds the mesh near its real camera, and a capture moves it only for an instant | Move the camera near it, or look from there |
| Thin straight dark crack at ground level, with no holes in the voxels | Probably a meshing artifact. The cause is not proven, and waiting does not clear it | Report it |
| Seam in a far view | A level-of-detail boundary | Confirm with a voxel read |
| Capture times out | Happens when sent beside a long `task.wait`. The cause is not proven | Send captures one at a time |

## Report

Give the symptom, the facts you read, the verdict and what you did not verify. Record a lesson only if it holds in any project.
