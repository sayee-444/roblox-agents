# Tooling and reasoning

Research behind two questions: how to call, observe and benchmark what this plugin does, and whether the reasoning behind the design holds up. Read and run 2026-11-06, on Claude Code 2.1.319 and plugin 0.11.0 at commit `b43ca35`. Recheck anything that matters: these platforms change quickly.

How to read this file:

- **Read** means the linked source says it. **Measured** means a local command or a past run's transcript shows it, and the row names which. **Ours** means our inference from the rows around it.
- No paid agent run, no Studio session and no `claude plugin eval` were started for this research. Measured transcripts are earlier runs on the developer's computer, named by the first 8 characters of their session, so they cannot be rechecked from this repository.
- Each item in parts A to D ends with a recommendation. Each item in part E ends with a verdict and what would change it, and looks for evidence against the idea.
- "Working tree" means the uncommitted changes on branch `docs/structure-and-benchmark` that appeared during this research. They are not part of `b43ca35`. The plan file cited here was `docs/next-steps.md` at that commit, and is `docs/archive/next-steps-2026-11-06.md` in the working tree.

## A. Making functions callable and observable

### 1. Skill frontmatter and its cost

| Fact | Source | How |
|---|---|---|
| All fields are optional and unknown fields are ignored. Fields: `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `background`, `hooks`, `paths`, `shell`, `metadata`, `license`, `compatibility` | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| `context: fork` runs the skill's body as the prompt of a new subagent of the type in `agent`. It does not see the conversation, runs in the background by default, and waits for the result under `-p` | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| An `allowed-tools` grant clears at the next message. `hooks` register when the skill is invoked and stay for the rest of the session. `paths` limits only automatic loading, and files outside the working directory never match | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| Always in context: name, description and `when_to_use`, capped at 1,536 characters per skill. The whole listing gets 1% of the context window, and overflow drops the descriptions of the least-used skills first. The body loads only on invoke | [Skills](https://code.claude.com/docs/en/skills.md), [Measure](https://code.claude.com/docs/en/plugins/measure.md) | Read |
| An invoked body stays in the conversation on later turns. After compaction each skill keeps its first 5,000 tokens, within 25,000 for all skills | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| Default: description in context, both you and Claude can invoke. `disable-model-invocation: true`: description not in context, "If Claude tries anyway, Claude Code blocks the call", and it cannot be preloaded in a subagent. `user-invocable: false`: description still in context, hidden from the menu | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| A skill whose `model` differs from the session's causes a full cache miss | [Prompt caching](https://code.claude.com/docs/en/prompt-caching.md) | Read |
| Plugin skills are named `/plugin-name:skill-name` | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| Commands merged into skills. `.claude/commands/` is "the older format and still works", and new plugins should "Prefer `skills/`" | [Skills](https://code.claude.com/docs/en/skills.md), [Manifest](https://code.claude.com/docs/en/plugins/manifest-reference.md) | Read |
| This plugin at 0.11.0 costs about 527 tokens always on. Always-on and on-invoke: `roblox-terrain-facts` 60 and 2.7k, `terrain-techniques` 90 and 2.1k, `world-generation` 80 and 2.2k, `world-history` 70 and 640, `world-project-setup` 50 and 570, `world-systems` 80 and 1.7k, agent `world` 100 and 1.8k. The hook costs the model nothing | `claude --plugin-dir plugins/roblox-world plugin details roblox-world` | Measured |

**Recommendation:** keep plain skills with short descriptions and no `commands/`. Use `disable-model-invocation: true` only for flows the developer types by hand.

### 2. Which substitutions expand where

| Place | What expands | Source | How |
|---|---|---|---|
| Hook commands | `${CLAUDE_PLUGIN_ROOT}` anywhere in `command` and `args`, and it is also exported to the hook | [Manifest](https://code.claude.com/docs/en/plugins/manifest-reference.md) | Read |
| Monitors, MCP stdio servers, LSP | Their `command`, plus `args` and `env` for MCP | [Manifest](https://code.claude.com/docs/en/plugins/manifest-reference.md) | Read |
| Skill, command and agent content | "Anywhere in the Markdown body" | [Manifest](https://code.claude.com/docs/en/plugins/manifest-reference.md) | Read |
| Bash tool | Nothing: "The variables aren't present in the environment of commands Claude runs through the Bash tool" | [Manifest](https://code.claude.com/docs/en/plugins/manifest-reference.md) | Read |
| Skill body and `allowed-tools` Bash rules | `${CLAUDE_SKILL_DIR}` exists and points at the skill's own folder. Also `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_DATA}`, `$ARGUMENTS` | [Skills](https://code.claude.com/docs/en/skills.md) | Read |
| Storage | `${CLAUDE_PLUGIN_ROOT}` changes on update, so store nothing there and keep no copy of the absolute path. `${CLAUDE_PLUGIN_DATA}` survives updates | [Manifest](https://code.claude.com/docs/en/plugins/manifest-reference.md) | Read |

**The suspected defect does not exist.** `prompt_snapshot` entries in six runs after 0.7.0 (`d1f16d01`, `21ca3273`, `76d899c1`, `a8d218a3`, `d8ea1c1a`, `0d37827f`) show `world.md`'s variable expanded to `<repo>/plugins/roblox-world/engine`, in forward slashes, under `--agent` with `--plugin-dir`. The literal variable never appears. Measured.

Runs found the engine "through memory" for a simpler reason. Run F (0.6.0, `cfb280db`) had a prompt that said "For a new world, look in your memory for an existing Generator", and the variable only entered with `ef051d4` (0.7.0), per `git log -S`. Measured. The agent's `MEMORY.md` holds no path to the checkout, and `new` writes a `<engine>` placeholder into `rules.md`, so no stale absolute path gets stored. Measured.

**Recommendation:** keep `${CLAUDE_PLUGIN_ROOT}` in the agent and skill bodies, and check it once from a marketplace install, which was not verified.

### 3. Proving that a skill, a tool or a hook ran

| Method | What it shows | Limit | Source | How |
|---|---|---|---|---|
| Transcript parsing | `tool_use` named `Skill` with `{"skill":"roblox-world:..."}`, every tool call, tokens, cost | "The entry format is internal to Claude Code and changes between versions, so scripts that parse these files directly can break on any release" | [Sessions](https://code.claude.com/docs/en/sessions.md) | Measured and read |
| `-p` with `json` or `stream-json` | `total_cost_usd`, duration, turns and per-model use. The `system/init` event lists `plugins`, `plugin_errors`, `mcp_servers`, `mcp_server_errors`, and `--include-hook-events` adds hooks | Cost is a "client-side estimate" and can drift from billing | [Headless](https://code.claude.com/docs/en/headless.md), [Cost tracking](https://code.claude.com/docs/en/agent-sdk/cost-tracking.md) | Read |
| Hook on `Skill` | Fires when Claude calls the tool | "typing `/skillname` directly bypasses `PreToolUse`", and `UserPromptExpansion` covers that path. A hook that exits 0 shows nothing in the transcript, so confirm it with `--debug-file` | [Hooks](https://code.claude.com/docs/en/hooks.md), [Components](https://code.claude.com/docs/en/plugins/components.md) | Read |
| OpenTelemetry | `claude_code.skill_activated` with its trigger (`user-slash`, `claude-proactive`, `nested-skill`), `tool_result`, `api_request`, `hook_execution_complete`, `plugin_loaded` | Needs an exporter and `CLAUDE_CODE_ENABLE_TELEMETRY=1`. Third-party skill names are redacted unless `OTEL_LOG_TOOL_DETAILS=1` | [Monitoring](https://code.claude.com/docs/en/monitoring-usage.md) | Read |
| `claude plugin eval` graders | `tool_used`, `tool_order`, and `regex` on the trace | See item 5 | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |

Ours: `world.js` talks to Studio's MCP server by itself, so every method above sees only a Bash command. Proof of a Studio step has to come from `world.js`'s output and exit code.

**Recommendation:** use `-p` result data for cost and time, `world.js` exit codes for Studio, and a hook only for rules that must always hold.

### 4. Plugin agent frontmatter

| Fact | Source | How |
|---|---|---|
| Plugin agents support `name`, `description`, `model`, `effort`, `maxTurns`, `autoCompactWindow`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation`, `color` and `experimental.cacheTtl` | [Components](https://code.claude.com/docs/en/plugins/components.md) | Read |
| `permissionMode`, `hooks`, `mcpServers` and `initialPrompt` are ignored "For security reasons". Put hooks in `hooks/hooks.json` and MCP in `.mcp.json`, which apply whenever the plugin is enabled | [Components](https://code.claude.com/docs/en/plugins/components.md), [Sub-agents](https://code.claude.com/docs/en/sub-agents.md) | Read |
| `memory: user` lives at `~/.claude/agent-memory/<name>/`. The first 200 lines or 25 KB of `MEMORY.md` go in the system prompt. It is off when auto memory is off | [Sub-agents](https://code.claude.com/docs/en/sub-agents.md) | Read |
| The folder is `roblox-world-world`, with the colon turned into a hyphen. Its 7,183 bytes cost about 1.8k tokens in every run up to 0.11.0. In the working tree it is 627 bytes | Local folder and transcripts | Measured |
| `world.md` uses only supported fields, so nothing in it is ignored | [Components](https://code.claude.com/docs/en/plugins/components.md) | Measured against read |
| A server shipped in a plugin gets tools named `mcp__plugin_<plugin>_<server>__<tool>`. Ours: shipping Studio's server would break the `tools:` list and the guard's matcher | [Hooks](https://code.claude.com/docs/en/hooks.md), [Permissions](https://code.claude.com/docs/en/permissions.md) | Read |

**Recommendation:** leave `world.md`'s fields as they are, and never rely on `hooks`, `mcpServers` or `permissionMode` in a plugin agent.

## B. A simple benchmark

### 5. `claude plugin eval`, `plugin details`, `/skill-doctor`

| Fact | Source | How |
|---|---|---|
| Layout: `evals/<case>/prompt.md` plus `graders/*.md`, with an optional `case.yaml`. `prompt.md` sets `runs` (default 3), `max_turns` (10), `timeout_seconds` (300), `allowed_tools`, `model`, `plugins` | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| Free graders: `regex`, `tool_used`, `tool_order`, `file_exists`. Paid: `llm` (best 2 of 3 votes), `baseline`. "There are no custom-code graders" | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| `--ablation with-without` is the default and doubles the runs, and `none` runs one arm. Cost is cases × runs × 2, plus 3 judge calls per `llm` grader per run. The docs' example: 1 case, 6 runs, $0.41, 74 s. It counts against the plan | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| Mocks live in `evals/mocks/<server>/<tool>.md`, only for servers the plugin declares. "Your personal MCP servers never load in a run". There is `--allow-real-servers` and `--mocks off` | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| Each run gets a temporary home, working directory and config, with no user settings, `CLAUDE.md` or memory | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| "Native Windows has no backend, so run shell-granting suites under WSL2". Granting Bash or PowerShell on a machine with no sandbox is refused | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| Reports: `aggregate-result.json` with `costUsd`, `durationSeconds`, `claudeVersion` and each run's grader results, and a `report.html`. Tokens per run are not listed | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| There is no `--agent` flag. An agent is reached only through the `Agent` tool | `claude plugin eval --help` | Measured |
| `claude plugin details plugins/roblox-world` fails with "not found". The working form is `claude --plugin-dir plugins/roblox-world plugin details roblox-world` | Local command | Measured |
| `plugin details` counts `disable-model-invocation: true` skills as always-on. A throwaway plugin showed the same ~70 tokens for a user-only skill and a plain one, while the real `skill_listing` of run `d8ea1c1a` omits user-only skills such as `mattpocock-skills:implement` | Local command and transcript | Measured |
| `/skill-doctor` (v2.1.252 or later) shows each skill's cost and how often it is used. It was not run here | [Commands](https://code.claude.com/docs/en/commands.md), [Skills](https://code.claude.com/docs/en/skills.md) | Read |

Ours: the live Studio path cannot be tested this way on this computer. `world.js` needs a shell, native Windows refuses shell-granting suites, and Studio's server is not declared by the plugin. Whether WSL2 can reach `%LOCALAPPDATA%\Roblox\mcp.bat` was not verified.

**Recommendation:** do not build the benchmark on `plugin eval`. Keep it in mind only for later checks on skill triggering and answers that need no Studio.

### 6. Headless runs and keeping them clean

| Fact | Source | How |
|---|---|---|
| Useful flags: `-p`, `--output-format json` or `stream-json` (which needs `--verbose`), `--max-budget-usd` (a client-side estimate that can overshoot), `--max-turns`, `--plugin-dir`, `--agent`, `--mcp-config`, `--strict-mcp-config`, `--setting-sources`, `--tools`, `--no-session-persistence` | [CLI reference](https://code.claude.com/docs/en/cli-reference.md), [Headless](https://code.claude.com/docs/en/headless.md) | Read |
| `--bare` "doesn't use your subscription login" and needs an API key. Plugin hooks do not run even with `--plugin-dir`, and there is no skill listing. It "will become the default for `-p` in a future release" | [Headless](https://code.claude.com/docs/en/headless.md) | Read |
| `--safe-mode` disables plugins too. `--restricted` is for "an evaluation harness" on a shared machine, and removes shell tools unless named in `--tools` | [CLI reference](https://code.claude.com/docs/en/cli-reference.md) | Read |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` also turns off agent memory. `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` drops `CLAUDE.md` files. A fresh `CLAUDE_CONFIG_DIR` is the official clean recipe, at the cost of first-run setup | [Env vars](https://code.claude.com/docs/en/env-vars.md), [Debug your config](https://code.claude.com/docs/en/debug-your-config.md) | Read |
| A `--setting-sources` list without `user` does not load synced plugins | [Plugin loading](https://code.claude.com/docs/en/plugins/loading.md) | Read |
| Transcripts sit at `~/.claude/projects/<project>/<session-id>.jsonl`, kept 30 days by default through `cleanupPeriodDays`. The format is internal, see item 3 | [Sessions](https://code.claude.com/docs/en/sessions.md), [Settings](https://code.claude.com/docs/en/settings-reference.md) | Read |
| The result message carries `duration_ms`, `duration_api_ms`, `num_turns`, `total_cost_usd` and `modelUsage` | [SDK reference](https://code.claude.com/docs/en/agent-sdk/typescript.md) | Read |

What a run's first request held, in two runs:

| Part | `d8ea1c1a`, 0.11.0, developer's settings | `c1bb9921`, working tree, `--setting-sources project` |
|---|---|---|
| Input tokens, first request | 27,397 (17,827 written, 9,568 read) | 19,497 (9,927 written, 9,568 read) |
| Skill listing | 21,662 characters in 47 entries, of which this plugin's 6 entries are 1,226 characters | 9,253 characters, no `anthropic-skills` or `mattpocock-skills` |
| Agent memory | 7,183 bytes | 627 bytes |
| Agent prompt | 6,156 characters | Not separated |
| Tools array | 24,925 characters: PowerShell 9,657, Bash 4,038, Grep 3,253, Read 1,948, Skill 1,832, others less | Not separated |

Both columns are Measured from transcripts, and `c1bb9921` was started by the working tree's benchmark, not by this research.

Ours, from that table:

- The plugin's own always-on 527 tokens are about 2% of the start. The largest cuts lay elsewhere: other plugins' skills (about 3k tokens by characters/4), the `PowerShell` tool (about 2.4k) and the memory file (about 1.6k, already gone). The rest of the 7,900-token drop between the two runs was not broken down.
- Removing `PowerShell` from `tools:` is the largest cut still inside the plugin's control. Its reason in `world.md` is a fallback for strict read settings. A Windows computer without Git Bash was not tested.
- `--setting-sources project` is enough to remove the developer's other plugins, and it keeps subscription login, unlike `--bare`.

The transcript also has `usage.output_tokens_details.thinking_tokens`, so the amount of reasoning can be counted, though its text is empty. Measured: 594 of 3,101 output tokens in `d8ea1c1a`. This corrects the plan file's "reasoning, which the transcript does not show" as far as the count goes.

**Recommendation:** a short script around `claude -p --output-format json --plugin-dir ... --agent roblox-world:world --setting-sources project --strict-mcp-config --max-budget-usd N`, not `--bare`. Record `claude --version` with each result, because the working tree's results lack it and a change of default for `-p` would change every number silently.

### 7. Anthropic's guidance on evals

| Fact | Source | How |
|---|---|---|
| "20-50 simple tasks drawn from real failures is a great start". "Evals get harder to build the longer you wait" | [Demystifying evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | Read |
| "it's often better to grade what the agent produced, not the path it took". Grader kinds: code, model, human | [Demystifying evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | Read |
| "we run multiple trials", with no fixed number. Its pass^k example uses 3. Regression suites should stay near 100%, and capability suites start low | [Demystifying evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | Read |
| "One run of a non-deterministic agent tells you little", and 3 runs is the eval tool's default | [Plugin evals](https://code.claude.com/docs/en/plugin-evals.md) | Read |
| A research team began with about 20 queries and still found manual testing essential | [Multi-agent research](https://www.anthropic.com/engineering/multi-agent-research-system) | Read |
| Collect runtime, tool calls, tokens and errors | [Writing tools](https://www.anthropic.com/engineering/writing-tools-for-agents) | Read |

Ours, as the minimum for one developer: 3 to 5 scenarios taken from real failures, code graders on output first, 3 runs whenever two versions are compared, and a read of the transcript of any surprising result. The repository's single-run comparisons so far are weak evidence, which the plan file admits.

**Recommendation:** start with the three jobs the agent exists for, grade outcomes and not paths, and keep the look as a human grade.

## C. Debug mode on request

### 8. Debug options and keeping debug text out of context

| Fact | Source | How |
|---|---|---|
| `--debug[=filter]` writes to `~/.claude/debug/<session-id>.txt`, not the terminal. `--debug-file <path>` picks the file. `CLAUDE_CODE_DEBUG_LOG_LEVEL=verbose` adds hook matching detail | [Hooks](https://code.claude.com/docs/en/hooks.md), [CLI reference](https://code.claude.com/docs/en/cli-reference.md) | Read |
| `/debug [description]` is a bundled skill that turns logging on mid-session, from that point forward | [Commands](https://code.claude.com/docs/en/commands.md) | Read |
| `/doctor`, `/context`, `/hooks`, `/mcp`, `/skills`, `/memory`, `/status` and `--safe-mode` inspect the setup. `/plugin` has an Errors tab. `claude plugin validate --strict` fails on warnings | [Debug your config](https://code.claude.com/docs/en/debug-your-config.md), [Troubleshooting](https://code.claude.com/docs/en/plugins/troubleshooting.md) | Read |
| The recommended pattern is to move instructions out of `CLAUDE.md` into skills, whose bodies load on demand | [Costs](https://code.claude.com/docs/en/costs.md) | Read |
| A `disable-model-invocation: true` skill costs zero listing tokens, per the docs and per the real listing of `d8ea1c1a`. `plugin details` wrongly shows about 70 | [Skills](https://code.claude.com/docs/en/skills.md), item 5 | Read and measured |
| That same setting means the agent cannot load the skill when a check fails, which conflicts with the plan "debugging lives in a skill loaded only when something fails" | [Skills](https://code.claude.com/docs/en/skills.md) | Read, conflict is ours |

Ours: the saving is about 70 tokens against a start of about 20k, so it buys nothing here. The working tree's `world-debug` is already a plain skill.

**Recommendation:** a plain skill with a short description for debugging by the agent, and `--debug-file` when the question is whether a hook ran.

## D. Docs structure

### 9. Layout and staleness

| Fact | Source | How |
|---|---|---|
| "Set `description`, `author`, `homepage`, and `repository` in `plugin.json`, and add a `README.md` at the plugin root". Also validate with `--strict` and install once from a local marketplace before release | [Publish](https://code.claude.com/docs/en/plugins/publish.md) | Read |
| With `version` set and not raised, `claude plugin update` says the plugin is already at the latest version. This confirms this repository's bump rule | [Publish](https://code.claude.com/docs/en/plugins/publish.md) | Read |
| `claude plugin validate plugins/roblox-world` and `--strict` both exit 0. The directory reports a missing icon and says the README came from the repository root, because the plugin folder has none | Local command | Measured |
| Diátaxis names four kinds: tutorials, how-to guides, reference, explanation | [Diátaxis](https://diataxis.fr/) | Read |
| It is "a guide, a map", "designed to guide small steps", and it "certainly does not mean that you should create empty structures... Don't do that. It's horrible" | [How to use Diátaxis](https://diataxis.fr/how-to-use-diataxis/) | Read |
| "A good README.md orients the new user to the directory and points to more detailed explanation". "Change your documentation in the same CL as the code change". "Default to delete". Docs do best "alive but frequently trimmed, like a bonsai tree" | [Google documentation best practices](https://google.github.io/styleguide/docguide/best_practices.html) | Read |
| The stale-docs problem cost real runs. At `b43ca35` the engine README listed three commands and `world.js` usage omitted `new` and `wipe`, so runs read the source (`a8d218a3`, `76d899c1`, `d8ea1c1a`, `d1f16d01`). The repository README's Skills table omitted `world-history` | Transcripts and grep | Measured |

Ours: Diátaxis fits as a check, one kind per page, and not as a folder layout. A project this small has few pages, and no source says it needs a tree. Generating tables adds a build step, so a test that compares docs with the source is simpler. The working tree already adds `node tools/world.js help` as the one source for commands and `tests/docs.test.js` as the comparison.

**Recommendation:** add `homepage` and a short plugin-root `README.md`, keep one kind per page, change docs in the same commit, and let a test fail when a skill or command is missing from them.

## E. The developer's reasoning

### 10. The agent writes and runs a Generator, and scripts do the work

**Verdict: supported.**

| Side | Evidence | Source |
|---|---|---|
| For | Code that filters data before the model sees it took its example "from 150,000 tokens to 2,000 tokens", because otherwise "Every intermediate result must pass through the model". This is the post's example, not a general rate | [Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) |
| For | Aim for the "smallest possible set of high-signal tokens", retrieved just in time | [Context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) |
| For | Find the "simplest solution possible", and "workflows offer predictability" | [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) |
| For | Measured here: 32.9 to 1.1 minutes and 192,619 to 3,101 output tokens. These were single runs and not like for like, and the engine's cost was paid once earlier | Plan file |
| Against | The same post names the costs: a sandbox and operating overhead | [Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) |
| Against | Procedural work still means trial-and-error tuning of parameters. A faster run says nothing about the look, and no measured run judged it | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |

**Would change it:** tasks where the agent spends more on understanding and extending the engine than a direct edit would cost, across several kinds of change.

### 11. Generate in Studio and save static terrain

**Verdict: supported, with place size still unknown.**

| Side | Evidence | Source |
|---|---|---|
| For | Online generation must be "very fast" and have "a predictable runtime". Offline results can be "edited and perfected by a human designer before the game is shipped" | [Togelius et al. 2011](http://julian.togelius.com/Togelius2011Searchbased.pdf) |
| For | `WriteVoxels()` "must be called in the serial phase", so run-time writes cannot be moved off the main thread | [Multithreading](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/multithreading.md) |
| Against | Roblox documents the opposite pattern: "To create a vast world for your game, you can populate the world dynamically", with chunks computed in Actors. Generating at run time is a supported choice, not a mistake | [Multithreading](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/scripting/multithreading.md) |
| Against | Saved terrain counts toward the place: "If you reach the 100 MB limit...", and "Reducing or simplifying terrain can significantly reduce place size". Messy holes and misplaced water under the surface "can increase compressed size" | [Place files](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/projects/place-files.md) |
| Against | The docs on streaming do not describe terrain specifically. Place size, streaming and phones are all unmeasured here. New terrain needs a publish and no server can vary it, by ADR 0001's own account | [Streaming](https://create.roblox.com/docs/workspace/streaming), plan file |

Ours: the test map's 1,536 studs is about 430 m at [1 stud = 28 cm](https://create.roblox.com/docs/physics/units). A map this small is unlikely to reach the limit, but that is untested.

**Would change it:** a measured place size near 100 MB at a target map, or a game that needs a different world per server.

### 12. The World Plan overrides seeds

**Verdict: supported for control, partly for the look.**

| Side | Evidence | Source |
|---|---|---|
| For | Noise and fractal methods "suffer from uncontrollability", and designers can only change "unintuitive parameters" | [PCG book, ch. 4](http://pcgbook.com/wp-content/uploads/chapter04.pdf) |
| For | "The lack of local control exhibited by these procedural techniques has driven researchers" to other methods. Manual editing remains needed in practice | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |
| For | Tanagra's generator guarantees playable levels while a human places and moves geometry. Abstract only | [Smith, Whitehead, Mateas 2011](https://doi.org/10.1109/TCIAIG.2011.2159716) |
| For | The human has the idea and the computer realizes it, one of the two mixed-initiative modes | [PCG book, ch. 11](http://pcgbook.com/wp-content/uploads/chapter11.pdf) |
| For | A user sketch can drive the whole result: rivers in Génevaux, a painted uplift map in Cordonnier. Cordonnier: abstract only | [Génevaux et al. 2013](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf), [Cordonnier et al. 2016](https://doi.org/10.1111/cgf.12820) |
| Against | Declaring shapes does not create what ties them together. Noise lacks global structure, and for erosion "The form of the initial input terrain thus plays a crucial role". A landform declared as a plain shape can read as artificial, as the developer said of the first map's mesa, recorded in the plan file | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |

**Would change it:** a Plan so detailed that writing it costs more than picking from generated options, or a look that only comes when landforms grow from a process and are not declared.

### 13. Seed hunting

**Verdict: partly. A cheap search is sound, but the best target is parameters and the score is the hard part.**

| Side | Evidence | Source |
|---|---|---|
| For | Generate-and-test is a named, simple approach, and offline generation has time for it | [Togelius et al. 2011](http://julian.togelius.com/Togelius2011Searchbased.pdf) |
| For | Ours, estimated and not measured: a Chunk takes 0.35 to 0.42 s to generate and write, most of it heights. At a quarter of the resolution on each axis, 9 Chunks take about 0.2 s, and 1,000 seeds about 4 minutes | Repo measure in `roblox-terrain-facts` |
| For | Humans can judge a short list when evaluation "is subjective, unknown in advance, or too daunting to formulate mathematically" | [PCG book, ch. 11](http://pcgbook.com/wp-content/uploads/chapter11.pdf) |
| Against | Seeds have "no locality": neighbouring seeds share nothing, so "All search performs as badly (or as well) as random search". A smarter search over seeds is pointless, and only parameters reward it | [Togelius et al. 2011](http://julian.togelius.com/Togelius2011Searchbased.pdf) |
| Against | "Designing the evaluation function is ill-posed": you first need to decide what to optimise | [Togelius et al. 2011](http://julian.togelius.com/Togelius2011Searchbased.pdf) |
| Against | Ours: the Plan fixes the layout and seeds supply only detail, and a coarse pass cannot see fine detail. The score may have little left to choose between | ADR 0002 |

**Would change it:** measure the score's spread over 1,000 seeds, then see whether it agrees with the developer's picks among about 20 finalists. Little spread or no agreement ends the idea.

### 14. A detail layer of noise and materials as the main path to a natural look

**Verdict: partly. It is necessary and cheap, and the literature says it is not enough alone.**

| Side | Evidence | Source |
|---|---|---|
| For | Noise is "widely used in industrial software", and is flexible with warping, clamping and blending | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |
| For | Domain warping and derivative-based fBm change the character of noise at little cost | [Quilez: warp](https://iquilezles.org/articles/warp/), [fBm](https://iquilezles.org/articles/fbm/), [more noise](https://iquilezles.org/articles/morenoise/) |
| For | Varying the fractal character "with altitude or other functions yields more realistic first approximations to eroded landscapes". Abstract only | [Musgrave, Kolb, Mace 1989](https://doi.org/10.1145/74333.74337) |
| For | Earth's topography "generally obeys fractal statistics". Arizona at 7 points per km. Abstract only | [Huang, Turcotte 1989](https://doi.org/10.1029/JB094iB06p07491) |
| For | 1/f noise "approximates real-world uneroded mountainous terrain well" | [Olsen 2004](http://web.mit.edu/cesium/Public/terrain.pdf) |
| Against | "The very nature of terrains is not strictly fractal", and these methods miss "material transport" and "the branching patterns evident in mountain ranges". "erosion- and example-based methods appear significantly more realistic than procedural approaches" | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |
| Against | Noise has "no global constraints" and "Different areas of the map don't relate to each other". You "still don't get flat valleys" | [Red Blob Games](https://www.redblobgames.com/maps/terrain-from-noise/) |
| Against | Real landscapes have "characteristic spatial scales". Spectral power "declines sharply above a frequency that corresponds roughly to hillslope length", so they are "relatively smooth at finer scales", and uniform valley spacing is unlikely in a random surface. Abstract only | [Perron, Kirchner, Dietrich 2008](https://doi.org/10.1029/2007JF000866) |
| Limit of erosion | It is "notoriously difficult to control", and scaling small-scale simulation up is "intrinsically flawed" | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |

Ours: more octaves everywhere can make it worse. The sources point to detail that varies by place, rough ridges and smooth valley floors, and not to detail added evenly.

Three ways to get erosion's look, by fit with this repository:

| Option | Fits "pure function of position"? | Cost at 4-stud voxels | Source |
|---|---|---|---|
| Local erosion-like filter: every point "evaluated in isolation", "trivial to generate in chunks", and needs height and gradient. Gullies sometimes "just stops halfway down a mountainside". MPL-2.0. The post gives no timings | Yes | Not measured in Luau. Ours: the gradient needs extra height samples unless it is analytic | [Johansen 2026](https://blog.runevision.com/2026/03/fast-and-gorgeous-erosion-filter.html), first 100k characters read |
| Whole-map bake: stream power over the domain, with uplift as a user map or analytic time as a slider. Abstracts only | Yes as a function of Plan and seeds, but no longer local. A Plan change can invalidate the whole bake, and one Chunk no longer regenerates cheaply | Ours: 384 × 384 = 147,456 cells. Node could compute it outside Studio and store a delta | [Cordonnier et al. 2016](https://doi.org/10.1111/cgf.12820), [Tzathas et al. 2024](https://doi.org/10.1111/cgf.15033) |
| Iterative simulation in Luau | As for the bake, and it needs neighbours and transport | Ours, estimated: a Chunk's 16,384 cells take about 0.4 s to generate and write, so about 40,000 cells/s. If one erosion pass costs the same, [Olsen's](http://web.mit.edu/cesium/Public/terrain.pdf) 50 to 500 iterations take 3 to 30 minutes. Real cost not measured | Repo measure in `roblox-terrain-facts` |

Ours: a cell is 1.12 m, so channels under about two cells wide cannot appear at all.

**Would change it:** the developer judging noise, warp and slope-driven materials as natural enough ends the need for more. Otherwise try in order: warp, ridges and materials, then the local filter, then a bake.

### 15. Fractal Rivers

**Verdict: partly. The method is sound, but rule-based forks on an existing map invert its logic.**

| Side | Evidence | Source |
|---|---|---|
| For | Rivers as modelling elements: the network is built first, with Horton-Strahler rules and Rosgen types, and terrain derives from it. This "guarantees that the construction satisfies hydrographic properties". Large terrains in "a few seconds", with no physics simulation, and an analytic form that suits a pure function | [Génevaux et al. 2013](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf) |
| For | River networks share "universal statistical features" regardless of "geology, exposed lithology, vegetation, or climate". Abstract only | [Rinaldo et al. 2014](https://doi.org/10.1073/pnas.1322700111) |
| Against | Génevaux derives terrain from rivers. This repository declares landforms and then places Rivers, and a fork rule on top inverts that. Its limits: "meandering crests and outcroppings of unnatural-looking hills", flat rivers can "cut through high mountains", and "a large amount of parameters" can create unnatural terrain | [Génevaux et al. 2013](https://www.cs.purdue.edu/homes/bbenes/papers/Genevaux13ToG.pdf) |
| Against | Nature rejects "strict self-similarity" in favour of statistical self-similarity, so a fixed fork rule is the wrong kind of fractal. Abstract only | [Rinaldo et al. 1992](https://doi.org/10.1029/92WR00801) |
| Against | Each River holds one water level and is placed by hand, water does not flow in Roblox, and the first fork already caused a dam and a pit. The map is 384 cells wide, which leaves few levels of branching | Plan file, `foundations.md` |

**Would change it:** a test of a three-order network that carves its valleys from the network, judged by the developer in Studio.

### 16. Many specialized agents in a circular sequence, exchanging files, with a stop condition

**Verdict: partly. Files and a stop condition are sound, and one evaluator may earn its place later. A circle of many agents is weak for now.**

| Side | Evidence | Source |
|---|---|---|
| For | "agents reliably skew positive when grading their own work", and separating doer from judge is "a strong lever", especially for subjective work. Agents there spoke through files. Asking "does this follow our principles" made taste gradable | [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps) |
| For | Subagents store work outside and return references, and "maximum number of iterations" is a named stopping condition | [Multi-agent research](https://www.anthropic.com/engineering/multi-agent-research-system), [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) |
| Against | The same post's numbers: 20 minutes and $9 solo, 6 hours and $200 with the harness, over 20 times the cost. The evaluator "is worth the cost when the task sits beyond what the current model does reliably solo". It later removed the sprints and kept one evaluator pass at the end. It also took several rounds to get the evaluator grading reasonably | [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps) |
| Against | Multi-agent systems use about 15 times the tokens of chat. They "excel at valuable tasks that involve heavy parallelization", and heavily dependent domains are "not a good fit" | [Multi-agent research](https://www.anthropic.com/engineering/multi-agent-research-system) |
| Against | Evaluator-optimizer works "when we have clear evaluation criteria, and when iterative refinement provides measurable value". Natural look has no clear criterion yet | [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) |
| Against | A subagent's first request "doesn't read the parent's cache", and it gets a five-minute cache by default. Measured: each agent start here is about 20k to 27k tokens. One agent writes to Studio at a time, so a circle runs in series | [Prompt caching](https://code.claude.com/docs/en/prompt-caching.md), transcripts, `CLAUDE.md` |

Ours: the goal today is less context and less time, and a circle moves against both. The evaluator's job is what the developer does now, and an evaluator needs captures, which move the developer's camera.

**Would change it:** a second domain with its own tools, work that truly runs in parallel, or written look principles that a separate agent grades in agreement with the developer. The last is the cheapest to test, with one evaluator and no circle.

### 17. Fresh sessions over long ones, and fewer captures

**Verdict: supported. The money case is smaller than raw cache counts suggest.**

| Side | Evidence | Source |
|---|---|---|
| For | "Token costs scale with context size". "Stale context wastes tokens on every subsequent message". "`/clear` costs nothing", while `/compact` is itself a large request | [Costs](https://code.claude.com/docs/en/costs.md) |
| For | Sessions should make incremental progress and leave structured updates, because an agent "tended to try to do too much at once" and ran out of context | [Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) |
| For | Image limits make Claude Code remove the oldest images in batches, and the next request reprocesses the conversation from there | [Prompt caching](https://code.claude.com/docs/en/prompt-caching.md) |
| For | Measured here: 350k context and 5.68M cache reads over 17 requests, against 47k in the leaner run | Plan file |
| Against | Cache reads are cheap. On Sonnet 5.5, $0.10 per million against $4 for a one-hour write and $2 for plain input. Raw cache counts overstate the money | [Pricing](https://platform.claude.com/docs/en/about-claude/pricing) |
| Against | Ours, at those prices: a request at 350k costs about $0.035 in cache reads, and a fresh start here about $0.04 to $0.07. So a fresh session pays back after a handful of requests at that size, and much later at smaller sizes | Pricing and transcripts |
| Against | Anthropic's newer harness dropped context resets: "Opus 4.5 largely removed that behavior on its own", and it ran "as one continuous session" with compaction. That was about wrapping up early and not about cost, but "always fresh" is not a law | [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps) |
| Against | A capture's tokens are small: 2,691 for 1920 × 1080 on recent models, capped at 4,784. Ten captures are about the size of one start. Capture size in Studio was not measured. The stronger reasons are that each moves the developer's camera and takes time, per `world.md` | [Vision](https://platform.claude.com/docs/en/build-with-claude/vision) |

**Would change it:** a measured task where re-orienting costs more than the long context it avoids.

### 18. Judging by eye and not by measures

**Verdict: supported as the final judge. Cheap measures should sit beside it as regression signals.**

| Side | Evidence | Source |
|---|---|---|
| For | Realism "can be surprisingly hard to answer", and perception and quantitative checks "do not always agree". Automated checks are usually limited to drainage | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |
| For | When evaluation is subjective, generators "can request human users to act as judges" | [PCG book, ch. 11](http://pcgbook.com/wp-content/uploads/chapter11.pdf) |
| For | This repository's own history: "passing measurements have not meant a natural result" | `CLAUDE.md` |
| Against | Human judgement is biased too. Static renderings are "influenced by the choice of viewpoint, rendering style, texturing", and viewers lean towards what they know, such as video games | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf) |
| Against | A person cannot judge a thousand candidates, so any search (item 13) needs some score | [Togelius et al. 2011](http://julian.togelius.com/Togelius2011Searchbased.pdf) |

Measures that could complement the eye. None has a known threshold for 1.12 m cells on a 430 m map:

| Measure | What it catches | Source |
|---|---|---|
| Erosion score: slope standard deviation over mean slope, about 0.3 to 0.7 across Olsen's maps | Slopes all alike, the mark of uneroded noise | [Olsen 2004](http://web.mit.edu/cesium/Public/terrain.pdf) |
| Slope histogram | The same, in more detail | Ours, from Olsen |
| Pits with no outflow, by Priority-Flood | Broken drainage, the one check Galin says is common | [Galin et al. 2019](https://www.cs.purdue.edu/homes/bbenes/papers/Galin19CGF.pdf), `foundations.md` |
| Height power spectrum: its slope, a sharp drop at hillslope scale, a peak at ridge-valley spacing | Too much fine detail, or no dominant valley spacing | [Huang, Turcotte 1989](https://doi.org/10.1029/JB094iB06p07491), [Perron et al. 2008](https://doi.org/10.1029/2007JF000866) |
| Geomorphon counts: ridges, valleys, hollows. Their histogram underlies a perceived-realism score, real Arizona 0.76 against thermal erosion 0.51. It calls itself "a first step" | Landforms missing from the mix | [PTRM](https://arxiv.org/abs/1909.04610) |

Ours: real-world numbers may not apply as they stand, since a map this small shows mountains and rivers far smaller than real ones. Use the measures to compare a map with its own earlier version, and never as a goal. Fixed cameras for before and after views reduce the viewpoint bias.

**Would change it:** a measure that repeatedly predicts the developer's own ranking of views.

## Defects found in this repository

Stated as of `b43ca35`. The last column is what the working tree showed at the time of writing.

| Finding | Evidence | Status in working tree |
|---|---|---|
| No defect: `${CLAUDE_PLUGIN_ROOT}` expands in `world.md` | Item 2, measured | Not applicable |
| Engine README and `world.js` usage were incomplete, so runs read the source | Item 9, measured | Addressed with `world.js help` |
| The repository README's Skills table omitted `world-history` | Item 9, measured | Addressed |
| The plugin folder has no README, and `plugin.json` has no `homepage` | Item 9, measured against [Publish](https://code.claude.com/docs/en/plugins/publish.md) | Addressed in 0.12.0 |
| The guard fails open where `powershell.exe` is missing or the script errors, since a hook that fails to start is a "Non-blocking error" unless `onFailure` is `"block"`. The README says Windows is needed, but nothing warns that the guard is off elsewhere | [Hooks](https://code.claude.com/docs/en/hooks.md), `hooks/hooks.json` | Open. Not tested on another system |
| `tools/measure-run.js` parses a format documented as internal, and can break on any release | [Sessions](https://code.claude.com/docs/en/sessions.md) | Open. Now has a fixture test, which catches a format change only if the fixture is refreshed |
| Merge checks run `claude plugin validate` without `--strict`, which the docs advise for CI. `--strict` passes today | [Publish](https://code.claude.com/docs/en/plugins/publish.md), measured | Addressed by `tools/check.js` |
| Benchmark results do not record the Claude Code version | `benchmarks/results.jsonl`, measured | Addressed |
| Baselines up to 0.11.0 included the developer's other plugins, about 3k tokens in the skill listing alone | Item 6, measured | Addressed by `--setting-sources project` |

Outside this repository: `claude plugin details` over-counts user-only skills (item 5), so a benchmark built on it would over-report if such a skill is added.

## Not verified

- Plugin behaviour from a real marketplace install. Everything measured used `--plugin-dir`.
- `claude plugin eval`, `/skill-doctor` and OpenTelemetry were read, not run. Tokens per run in eval reports could not be confirmed.
- Whether WSL2 can reach Studio's `mcp.bat`, and whether this plugin works on Windows without Git Bash or on any other system.
- Place size, streaming and phone behaviour at a target map. The cost of erosion in Luau or Node. Capture size in pixels. All are estimates or unknowns above.
- Abstract only: Musgrave 1989, Huang and Turcotte 1989, Perron 2008, Rinaldo 1992 and 2014, Cordonnier 2016, Tzathas 2024, Tanagra 2011. Full texts were blocked or paywalled.
- Not read: Rodriguez-Iturbe and Rinaldo's book, Musgrave's ridged multifractal chapter, and the last 40k characters of Johansen's post. The Quilez pages were retrieved with curl.
- The cited Anthropic posts report single cases, chosen by their authors. Their numbers are not rates that apply here.

## Ideas held for later

| Idea | Verdict | What would settle it |
|---|---|---|
| Seed hunting | Partly: seeds have no locality, so search is random, and the score is the hard part | Measure a score's spread over 1,000 seeds, and whether it agrees with the developer's picks among 20 finalists |
| Fractal Rivers | Partly: a fork rule on a declared map inverts the method, which derives terrain from the network | A three-order network that carves its own valleys, judged in Studio |
| Circular agents | Partly: files and a stop condition are sound, and a circle of many agents is weak today | Written look principles that one evaluator grades in agreement with the developer |
| Parameters for Biomes | Not researched | Build when the developer asks, from `docs/designs/world-systems.md` |

3D modeling costs money per use, so look for cheaper techniques first.
