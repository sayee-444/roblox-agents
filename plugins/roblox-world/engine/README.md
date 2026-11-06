# Engine

The reusable world Generator. A world is a folder holding only its World Plan and generation state, and this engine does the rest.

```text
node tools/world.js new <dir> --place <name> [--seed <n>]
node tools/world.js run --place <name> --project <dir>
node tools/world.js wipe --place <name> --project <dir>
```

`wipe` alone only prints a warning. With `--confirm <name>` it deletes all terrain in the place and empties the generation state, and Locked Chunks stop it unless `--include-locked` is added. It leaves the World Plan alone.

`src/world/plan.luau` is the test map. The tests describe it, and `new` copies it as a commented template.

Tested only on Windows, where `tools/world.js` starts Studio's MCP server through `%LOCALAPPDATA%\\Roblox\\mcp.bat`.
