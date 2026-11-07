---
name: world-history
description: The log of past map changes, kept apart from the current state. Use after a change to what exists on the map, when asked what changed or why, and when restoring something removed.
---

The current state is the World Plan, the generation state and `describe`. Orient from those. `docs/world/history.md` is the past, so open it only to add an entry or to answer a question about the past.

## Removing something

`world.js remove <id> --place <name> --project <dir> --why "<reason>"` takes it out of the World Plan with a River's Valley, writes the generated unlocked Chunks it touched and adds its entry, with the exact block. The history becomes the only place it remains, so the World Plan keeps no commented code, disabled flag or leftover reference. Done when it exits 0.

## Adding an entry

Record each change to what exists on the map: a Landform, River, cave or Chunk added, changed or removed, a Chunk Locked, or all terrain deleted. Tuning that the developer rejected in the same task and test runs stay out. Done when the task's change has its entry.

Add the entry at the top of `docs/world/history.md`, creating the file if it is missing. Read only its first lines to do so:

````markdown
## 2026-11-06: Removed River `fork`

- **Why:** the developer wanted one River in the valley.
- **Chunks written:** 1,1 1,2
- **Restore:** paste the block below into `rivers` in the World Plan, and generate those Chunks again.

```luau
{ id = "fork", ... the exact block taken out of the World Plan ... },
```
````

Include the block only for a removal or a change, holding the previous version exactly, so restoring it needs no Git. Deleting all terrain changes the World Plan not at all, so that entry says how to generate it again and lists any Locked Chunks lost, whose hand edits cannot be restored.

## Reading it

Search by name or date, and read only the matching entries. To restore, paste the block back, run `describe` to confirm it still fits the current World Plan, generate, and add a new entry. Entries stay as written, and a correction is a new entry.
