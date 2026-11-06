#!/usr/bin/env node
// Summarises a Claude Code transcript: time, tokens, context and tool calls, plus the proof of what
// ran, meaning which skills loaded and which engine commands were called.
// A tool call can appear on several transcript lines, so calls are counted once by id.
// Usage: node tools/measure-run.js <transcript.jsonl> [--json]
const fs = require('fs');

// A real run of the engine's command line, so reading the file with `head` does not count.
const ENGINE_COMMAND = /\bnode\s+(?:"[^"]*world\.js"|\S*world\.js)(?:\s+([a-z]+))?/g;

function measure(file) {
  const entries = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean)
    .map((line) => { try { return JSON.parse(line); } catch { return null; } })
    .filter((entry) => entry && entry.timestamp);
  const time = (entry) => Date.parse(entry.timestamp);
  const start = time(entries[0]);
  const end = time(entries[entries.length - 1]);
  const short = (name) => name.replace('mcp__Roblox_Studio__', '');
  const count = (table, key) => { table[key] = (table[key] || 0) + 1; };

  const messages = new Map();
  const calls = new Map();
  const tools = {};
  const skills = {};
  const commands = {};
  const intervals = [];
  const errors = [];

  for (const entry of entries) {
    const message = entry.message;
    if (!message || !Array.isArray(message.content)) continue;
    if (entry.type === 'assistant') {
      if (message.id && message.usage) messages.set(message.id, message.usage);
      for (const block of message.content) {
        if (block.type === 'tool_use' && !calls.has(block.id)) {
          const input = block.input || {};
          calls.set(block.id, { name: short(block.name), start: time(entry), chars: JSON.stringify(input).length });
          if (block.name === 'Skill' && input.skill) count(skills, input.skill.split(':').pop());
          for (const match of String(input.command || '').matchAll(ENGINE_COMMAND)) count(commands, match[1] || 'help');
        }
      }
    } else if (entry.type === 'user') {
      for (const block of message.content) {
        const call = block.type === 'tool_result' && calls.get(block.tool_use_id);
        if (!call || call.done) continue;
        call.done = true;
        const tool = tools[call.name] = tools[call.name] || { calls: 0, errors: 0, ms: 0, chars: 0 };
        tool.calls += 1;
        tool.ms += time(entry) - call.start;
        tool.chars += call.chars;
        intervals.push([call.start, time(entry)]);
        if (block.is_error) {
          tool.errors += 1;
          const text = typeof block.content === 'string' ? block.content : JSON.stringify(block.content);
          errors.push(`${((call.start - start) / 60000).toFixed(1)}m ${call.name}: ${text.slice(0, 160).replace(/\s+/g, ' ')}`);
        }
      }
    }
  }

  const usage = { output: 0, cacheRead: 0, cacheWrite: 0 };
  const context = [];
  for (const value of messages.values()) {
    usage.output += value.output_tokens || 0;
    usage.cacheRead += value.cache_read_input_tokens || 0;
    usage.cacheWrite += value.cache_creation_input_tokens || 0;
    // Everything the request sent: new input, what it wrote to the cache and what it read from it.
    context.push((value.input_tokens || 0) + (value.cache_creation_input_tokens || 0) + (value.cache_read_input_tokens || 0));
  }

  // Parallel calls overlap, so merge intervals before adding them up.
  let busy = 0;
  let open = null;
  let close = null;
  for (const [from, to] of intervals.sort((a, b) => a[0] - b[0])) {
    if (close === null || from > close) {
      if (close !== null) busy += close - open;
      open = from;
      close = to;
    } else {
      close = Math.max(close, to);
    }
  }
  if (close !== null) busy += close - open;

  const minutes = (ms) => Number((ms / 60000).toFixed(1));
  const all = Object.values(tools);
  return {
    durationMin: minutes(end - start),
    busyMin: minutes(busy),
    modelMin: minutes(end - start - busy),
    requests: messages.size,
    ...usage,
    contextStart: context[0] || 0,
    contextEnd: context[context.length - 1] || 0,
    toolCalls: all.reduce((sum, tool) => sum + tool.calls, 0),
    errors: all.reduce((sum, tool) => sum + tool.errors, 0),
    captures: (tools.screen_capture ? tools.screen_capture.calls : 0) + (commands.capture || 0) + (commands.shot || 0),
    skills,
    commands,
    tools,
    errorLines: errors,
  };
}

function report(run) {
  const list = (table) => Object.entries(table).map(([name, n]) => `${name} ${n}`).join(', ') || 'none';
  const lines = [
    `Duration ${run.durationMin} min | tool busy ${run.busyMin} min | model and overhead ${run.modelMin} min`,
    `Requests ${run.requests} | output ${run.output} | cache read ${run.cacheRead} | cache write ${run.cacheWrite}`,
    `Context ${Math.round(run.contextStart / 1000)}k at the start, ${Math.round(run.contextEnd / 1000)}k at the end`,
    `Tool calls ${run.toolCalls}, with ${run.errors} errors | Capture calls ${run.captures}`,
    `Skills loaded: ${list(run.skills)}`,
    `Engine commands: ${list(run.commands)}`,
    '',
  ];
  for (const [name, tool] of Object.entries(run.tools).sort((a, b) => b[1].calls - a[1].calls)) {
    lines.push(`${name.padEnd(24)} calls ${String(tool.calls).padStart(4)}  errors ${String(tool.errors).padStart(3)}  sec ${(tool.ms / 1000).toFixed(0).padStart(5)}  input chars ${String(tool.chars).padStart(7)}`);
  }
  if (run.errorLines.length) lines.push('', 'Errors:', ...run.errorLines);
  return lines.join('\n');
}

if (require.main === module) {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node tools/measure-run.js <transcript.jsonl> [--json]');
    process.exit(2);
  }
  const run = measure(file);
  console.log(process.argv.includes('--json') ? JSON.stringify(run, null, 2) : report(run));
}

module.exports = { measure };
