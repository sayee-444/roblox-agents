# Foundations

Research behind the plugin, read 2026-11-05 against primary sources where possible. Recheck anything that matters: these platforms change quickly.

How to read this file:

- A link supports the core fact of a row. Conclusions drawn from it are ours, and a "no X exists" claim is a negative search result.
- "Measured" means a read-only check in Studio 0.746.
- Terrain write measurements came later and live in the `roblox-terrain-facts` skill. Place file size is still unmeasured.

## Terrain

| Fact | Source |
|---|---|
| Voxels are 4 x 4 x 4 studs, and terrain has no finer resolution | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| One read or write handles at most 4,194,304 voxels. Measured on reads only | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| `Terrain` is not creatable, so a Chunk cannot be an instance | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| The roadmap calls 16K x 16K studs the earlier limit, and 64K is "still in the works". Our inference: about 16K is the only size with any stated history. No source says what enforces it | [Roadmap](https://devforum.roblox.com/t/creator-roadmap-2025-rdc-update/3961527), [staff post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620/145) |
| Roblox supports places up to 100 MB; beyond that, Save to Roblox and Publish to Roblox might fail. Standard terrain counts toward this. Expanded Terrain moves terrain to an asset with its own 200 MB limit (staff post, not documented) | [Place files](https://create.roblox.com/docs/projects/place-files.md), [staff post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620/145) |
| Expanded Terrain known issue: features under 16 voxels (64 studs) thick might disappear on clients when streaming is on with a small radius. Not established for standard terrain | [Release post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620) |
| Undo is not reliable for very large terrain writes | [Release post](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620) |
| Terrain writes are not allowed in Parallel Luau | [Multithreading](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/multithreading.md) |
| `SetMaterialColor` has no region argument, so it applies to the whole place | [Terrain](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Terrain.yaml) |
| Water colour is global | [Terrain guide](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/terrain.md) |
| No public water current simulation was found, and `WaterForce` is deprecated | [WaterForce](https://github.com/Roblox/creator-docs/blob/393d21c/content/en-us/reference/engine/enums/WaterForce.yaml) |
| Measured: no world-bounds member exists on the engine classes swept | Reflection sweep in Studio |
| A client that owns its character can bypass physical obstacles | [Network ownership](https://github.com/Roblox/creator-docs/blob/393d21c/content/en-us/scripting/security/network-ownership.md) |
| Server Authority (opt-in, `AuthorityMode` set to `Server`) rejects invalid client movement. This place measures `Automatic`, so it is off. Whether it enforces a game-defined limit is unknown, so the server check stays | [Release post](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993) |
| Parts "do not simulate or render properly at a great distance", so we keep the world near the origin | [Workspace](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) |
| `math.noise` has no seed parameter, and `Random` documents no algorithm | [math](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/libraries/math.yaml), [Random](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/datatypes/Random.yaml) |
| When configured, distant terrain stays visible while streaming, through simplified versions. No page says what that requires for terrain, and no official memory or distance figures exist. The default streaming target radius is 1,024 studs | [Streaming](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/workspace/streaming/index.md), [Workspace](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) |

### Expanded Terrain: not used yet

Expanded Terrain offers up to 62 editable materials and is the supported route to regional colour on one base material ([docs](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/parts/custom-terrain-materials.md)). It is on hold because painting a material depends on the undocumented `SolidMaterialIndex` channel ([staff post](https://devforum.roblox.com/t/early-access-program-unlocking-massive-terrain-with-up-to-64-custom-materials/4703282/288)), client optimizations were temporarily turned off in published games ([post 82](https://devforum.roblox.com/t/full-launch-publish-games-with-custom-terrain-materials-and-performance-improvements/4950620/82)), and Rojo and Lune lose its voxels ([PR 672](https://github.com/rojo-rbx/rbx-dom/pull/672)). Its own 200 MB limit is a point in its favour if standard terrain fails the size measurement. Reconsider it when Seasons are requested, since changing a material applies at once across the world.

## Generation techniques

| Topic | Source |
|---|---|
| The calculation at a position can be independent of every other position. Our inference: a generator built that way cannot disagree at Chunk borders, unless its output changes between generations | [Red Blob Games](https://www.redblobgames.com/maps/terrain-from-noise/) |
| Blending shapes with a bounded radius | [Inigo Quilez, smooth minimum](https://iquilezles.org/articles/smin/) |
| Domain warping | [Inigo Quilez, warp](https://iquilezles.org/articles/warp/) |
| Terrain from primitives with limited influence | [Genevaux et al. 2013](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf) |
| Automatic drainage, for when River routes stop being declared by hand | [Priority-Flood](https://ar5iv.labs.arxiv.org/html/1511.04463) |
| Hex grid reference, for why square Chunks were chosen | [Red Blob Games](https://www.redblobgames.com/grids/hexagons/) |

No Creator Store plugin reviewed offers scripted control, forced Landforms and per-Chunk writing that respects hand edits. The most complete one, [Atlas Studio](https://devforum.roblox.com/t/plugin-atlas-studio-%E2%80%94-node-based-procedural-terrain-for-roblox-studio/4802748) (community), replaces all terrain when it builds. Test third-party plugins only in a disposable place, since a [backdoored plugin](https://devforum.roblox.com/t/backdoor-found-in-a-circulating-roblox-studio-plugin/4486846) has been reported (community).

## External generation

- No official way to run native code on live servers was found: [the Luau sandbox removes `package`](https://luau.org/sandbox). A Studio plugin [can reach `127.0.0.1`](https://create.roblox.com/docs/cloud-services/http-service.md), which is the documented route if Rust is ever added.
- rbx-dom stores `SmoothGrid` as an opaque binary string ([database.json](https://raw.githubusercontent.com/rojo-rbx/rbx-dom/master/rbx_dom_lua/src/database.json)). [PR 444](https://github.com/rojo-rbx/rbx-dom/pull/444) would add an encoder for standard terrain, but it is unmerged and rests on a community-written format spec, so Rust has no supported way to write voxels into a place file.
- [Hunyuan 3D's licence](https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2.1/main/LICENSE) excludes the EU, the UK and South Korea, including displaying its output, so it is not used. It also produces objects, not terrain.
- Meshes are limited to [20,000 triangles](https://create.roblox.com/docs/art/modeling/specifications), and swimming requires terrain water, so the ground stays voxel terrain.

## Tooling

| Role | Tool | Version read |
|---|---|---|
| Pin tool versions | [Rokit](https://github.com/rojo-rbx/rokit) | 1.2.0 |
| Types, like basedpyright | [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp/releases) | 1.70.1 |
| Lint, like ruff | [Selene](https://github.com/Kampfkarren/selene/releases) | 0.32.0 |
| Format, like ruff format | [StyLua](https://github.com/JohnnyMorganz/StyLua/releases) | 2.6.0 |
| Tests outside Roblox | [Lute](https://raw.githubusercontent.com/luau-lang/lute/primary/docs/cli/test.md) | 1.0.0 |
| Sync code, when adopted | [Rojo](https://raw.githubusercontent.com/rojo-rbx/rojo/master/CHANGELOG.md) | 7.7.1 |

Gotchas, read in source code and not yet run:

- `luau-lsp analyze` with [`--formatter=plain` always exits 0](https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/src/AnalyzeCli.cpp), so use `default` or `gnu`.
- By default, lint warnings, including `DeprecatedApi`, do not change that exit code. Setting `lintErrors` in `.luaurc` makes every lint fatal.
- `analyze` [downloads no definitions](https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/src/AnalyzeCli.cpp), so pin the Roblox types by tag.
- Projects with strict scripts stay on the old solver unless they opt in ([announcement](https://devforum.roblox.com/t/general-release-luau%E2%80%99s-new-type-solver/4084991)). In Studio, [`Workspace.UseNewLuauTypeSolver`](https://create.roblox.com/docs/en-us/reference/engine/classes/Workspace.md) is set by hand because scripts cannot change it.
- [`@deprecated`](https://luau.org/attributes) is the form to use: the pinned StyLua and Selene use full_moon 3.0.0, whose parser rejects the bracket form.

## Environment

| Fact | Source |
|---|---|
| Clouds move with `Workspace.GlobalWind`, and have only Color, Cover, Density and Enabled | [Clouds](https://create.roblox.com/docs/environment/clouds) |
| No Roblox source states that clouds shadow the ground. A visual test is still needed | [Thread](https://devforum.roblox.com/t/869476/894.json) |
| Shadows turn off below quality level 4 | [Performance](https://create.roblox.com/docs/performance-optimization/improve) |
| `LightingStyle` cannot be changed by script, so a Graphics Profile cannot switch lighting technology | [Light sources](https://github.com/Roblox/creator-docs/blob/main/content/en-us/effects/light-sources.md) |
| No weather API was found. `weather-island` is the official MIT sample; its defaults reach about 50,000 particles by our count, unmeasured on phones | [weather-island](https://github.com/Roblox/resources/tree/main/experiences/weather-island) |
| Emitters are limited to 100 particles per second on mobile | [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) |
| `GetServerTimeNow` is "useful for creating synchronized experiences". Our inference: clients can derive the same time and weather from it without constant replication | [Workspace](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) |
| Most typical players use Android, many with 2 to 4 GB of RAM, so test on real phones | [Test on hardware](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/test-on-hardware.md) |

Not yet proven: that client writes to `Lighting` stay local to that client. Test it with two clients before relying on it.

## Agents and repository

| Fact | Source |
|---|---|
| Subagents inherit tools unless given a list, and can nest three layers by default | [Subagents](https://code.claude.com/docs/en/sub-agents.md) |
| `--agent` replaces the system prompt, while `CLAUDE.md` still loads | [Subagents](https://code.claude.com/docs/en/sub-agents.md) |
| Multi-agent systems use many more tokens, and most coding work is less parallel than research | [Anthropic](https://www.anthropic.com/engineering/multi-agent-research-system) |
| Play mode takes over the whole Studio instance. Staff say several agents are supported, but no document covers write conflicts | [Staff post](https://devforum.roblox.com/t/studio-mcp-multi-agent-improvements-and-connected-ai-clients/4820583) |
| `screen_capture` saves a JPEG and prints its path in the tool result. Measured once in this project | Studio MCP |
| Protected branches on private repositories need a paid plan | [GitHub](https://docs.github.com/en/rest/branches/branch-protection) |
| GitHub blocks files over 100 MiB | [GitHub](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github) |
