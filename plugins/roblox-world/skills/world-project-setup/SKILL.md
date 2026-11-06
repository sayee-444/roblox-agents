---
name: world-project-setup
description: Creates the world context of a Roblox project. Use when a project has no docs/world/rules.md.
---

1. **Ask** the developer, one question at a time, for what the code cannot tell you:
   - The Development Place: the only place the Generator may write to. Its `PlaceId` is 0 until the developer saves it to Roblox; record the Studio window title until then.
   - The target map: its overall size and shape, the Landforms it needs, and where the player may walk.
   - Rules for the repository, if there is no `CLAUDE.md`.
2. **Write** `docs/world/rules.md` using the template below. Mark every value you chose yourself as a default the developer can change.
3. **Add** the terms of the systems this project uses, from the `world-generation` and `world-systems` skills, to `GLOSSARY.md`, creating it if needed.

Done when the developer has confirmed the target map and every row in the template holds a value.

## Template

```markdown
# World rules

Terms are defined in `GLOSSARY.md`.

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | |
| World Seed | |

## Target map

| Element | Target |
|---|---|
| Maximum extent | |
| Chunk | 512 x 512 studs |
| Playable area | |
| Landform Regions | |
| Rivers and Lakes | |
| Sites | |
| World Limit | |
| Ground | |

## Decisions

Newest first: the date, the decision and why it was made.
```
