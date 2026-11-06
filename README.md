# roblox-agents

Specialized [Claude Code](https://code.claude.com/docs) agents and skills for Roblox development, distributed as a plugin marketplace.

| Plugin | Agent | What it does |
|---|---|---|
| `roblox-world` | `world` | Builds and runs a deterministic world Generator in Roblox Studio |

## Requirements

- Claude Code.
- [Roblox Studio MCP](https://create.roblox.com/docs/studio/mcp), with the server registered under the name `Roblox_Studio`, because the agent's tool list and the guard depend on that name. A server added with local scope exists only in its own project, so add it at user scope to reach every project. On Windows:

  ```text
  claude mcp add --scope user Roblox_Studio -- cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
  ```

- Windows, for the guard hook. It runs through `powershell.exe`, and it has not been tested on macOS.

## Install

```text
claude plugin marketplace add sayee-444/roblox-agents
claude plugin install roblox-world@roblox-agents
```

Then start it from your project folder:

```text
claude --agent roblox-world:world
```

On its first task in a project, the agent asks about your map and writes `docs/world/rules.md`.

## Where the agent keeps its context

| Place | Holds | Travels with |
|---|---|---|
| This plugin | The method and verified engine facts | Every installation |
| `~/.claude/agent-memory/roblox-world-world/` | Lessons learned in any Roblox project | This computer. Copy the folder to move it |
| The project's Git repository | The map plan, its rules and decisions | The project |

## Guard

While the plugin is enabled, a hook applies to the whole Claude Code session, including sessions outside this agent. It blocks agent attempts to publish a place and to run `rojo build`, `rojo upload` or `rojo syncback`. It catches mistakes, and it is not a security boundary. Run `tests/guard-tests.ps1` to check it.

## License

[MIT](LICENSE).
