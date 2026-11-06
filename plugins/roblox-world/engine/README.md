# Engine

The reusable world Generator. A world is a folder holding only its World Plan and generation state, and this engine does the rest.

```text
node tools/world.js help
```

`help` lists every command and needs no Studio. `src/world/plan.luau` is the test map, which the tests describe. `new --landforms` composes a whole plan with `tools/layout.js`, a pure function of the seed. Without it, `new` prints `templates/plan.luau` to fill in, and `new --test-map` copies the test map.

Tested only on Windows, where `tools/world.js` starts Studio's MCP server through `%LOCALAPPDATA%\\Roblox\\mcp.bat`.
