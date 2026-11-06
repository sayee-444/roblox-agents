#!/usr/bin/env node
// Summarises a Claude Code transcript: time, tokens and tool calls, what filled the context, and the
// proof of what ran, meaning which skills loaded and which engine commands were called.
// A tool call can appear on several transcript lines, so calls are counted once by id.
// Token counts for the whole run are exact. Its parts are estimates, at 4 characters per token.
// Usage: node tools/measure-run.js <transcript.jsonl> [--json]
const fs = require('fs');

// A real run of the engine's command line, so reading the file with `head` does not count.
const ENGINE_COMMAND = /\bnode\s+(?:"[^"]*world\.js"|\S*world\.js)(?:\s+([a-z]+))?/g;
const estimate = (chars) => Math.round(chars / 4);
const textLength = (content) => {
  if (typeof content === 'string') return content.length;
  if (!Array.isArray(content)) return 0;
  return content.reduce((sum, block) => sum + (block.type === 'text' ? block.text.length : 0), 0);
};

// What the first request carried, split into the parts this project can act on.
function startContext({ shape, snapshot, listing, renderedChars }, firstRequest) {
  if (!shape || !snapshot) return { context: null, startTools: null };
  const system = (snapshot.systemPrompt || []).join('');
  const rulesAt = system.indexOf('# Persistent Agent Memory');
  const fileAt = system.lastIndexOf('## MEMORY.md');
  const agentEnd = rulesAt >= 0 ? rulesAt : system.length;
  const rulesEnd = fileAt >= 0 ? fileAt : system.length;
  const startTools = {};
  for (const tool of [...(shape.tools || [])].sort((a, b) => JSON.stringify(b).length - JSON.stringify(a).length)) {
    startTools[tool.name] = estimate(JSON.stringify(tool).length);
  }
  const listingLines = String(listing ? listing.content : '').split('\n').filter(Boolean);
  const ownListing = listingLines.filter((line) => line.startsWith('- roblox-world:'));
  const lengthOf = (lines) => lines.reduce((sum, line) => sum + line.length + 1, 0);
  const context = {
    agent: estimate(agentEnd),
    memoryRules: estimate(rulesAt >= 0 ? rulesEnd - rulesAt : 0),
    memoryFile: estimate(fileAt >= 0 ? system.length - fileAt : 0),
    tools: Object.values(startTools).reduce((sum, tokens) => sum + tokens, 0),
    pluginSkills: estimate(lengthOf(ownListing)),
    otherSkills: estimate(lengthOf(listingLines) - lengthOf(ownListing)),
    attachments: estimate(renderedChars),
  };
  context.unattributed = firstRequest - Object.values(context).reduce((sum, tokens) => sum + tokens, 0);
  return { context, startTools };
}

function measure(file) {
  const entries = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean)
    .map((line) => { try { return JSON.parse(line); } catch { return null; } })
    .filter((entry) => entry && entry.timestamp);
  const time = (entry) => Date.parse(entry.timestamp);
  const start = time(entries[0]);
  const end = time(entries[entries.length - 1]);
  const short = (name) => name.replace('mcp__Roblox_Studio__', '');
  const count = (table, key) => { table[key] = (table[key] || 0) + 1; };
  const add = (table, key, amount) => { table[key] = (table[key] || 0) + amount; };

  const messages = new Map();
  const calls = new Map();
  const tools = {};
  const skills = {};
  const commands = {};
  const intervals = [];
  const errors = [];
  const firstRequest = { shape: null, snapshot: null, listing: null, renderedChars: 0 };
  const skillChars = {};
  const readChars = {};

  for (const entry of entries) {
    if (entry.type === 'api-request-shape' && !firstRequest.shape) firstRequest.shape = entry.shape;
    if (entry.type === 'attachment' && entry.attachment) {
      const kind = entry.attachment.type;
      if (kind === 'prompt_snapshot') firstRequest.snapshot = firstRequest.snapshot || entry.attachment;
      else if (kind === 'skill_listing') firstRequest.listing = firstRequest.listing || entry.attachment;
      else if (messages.size === 0 && Array.isArray(entry.rendered)) {
        firstRequest.renderedChars += entry.rendered.reduce((sum, part) => sum + String(part.content || '').length, 0);
      }
    }
    const message = entry.message;
    if (!message) continue;
    if (entry.type === 'user') {
      const blocks = typeof message.content === 'string' ? [{ type: 'text', text: message.content }] : message.content;
      for (const block of Array.isArray(blocks) ? blocks : []) {
        const body = block.type === 'text' && block.text.match(/^Base directory for this skill: .*skills\W+([\w-]+)/);
        if (body) add(skillChars, body[1], block.text.length);
      }
    }
    if (!Array.isArray(message.content)) continue;
    if (entry.type === 'assistant') {
      if (message.id && message.usage) messages.set(message.id, message.usage);
      for (const block of message.content) {
        if (block.type === 'tool_use' && !calls.has(block.id)) {
          const input = block.input || {};
          calls.set(block.id, { name: short(block.name), start: time(entry), chars: JSON.stringify(input).length, file: input.file_path });
          if (block.name === 'Skill' && input.skill) count(skills, input.skill.split(':').pop());
          for (const match of String(input.command || '').matchAll(ENGINE_COMMAND)) count(commands, match[1] || 'help');
        }
      }
    } else if (entry.type === 'user') {
      for (const block of message.content) {
        const call = block.type === 'tool_result' && calls.get(block.tool_use_id);
        if (!call || call.done) continue;
        call.done = true;
        const tool = tools[call.name] = tools[call.name] || { calls: 0, errors: 0, ms: 0, chars: 0, resultChars: 0 };
        const returned = textLength(block.content);
        tool.calls += 1;
        tool.ms += time(entry) - call.start;
        tool.chars += call.chars;
        tool.resultChars += returned;
        if (call.name === 'Read' && call.file) add(readChars, call.file.split(/\/|\x5c/).pop(), returned);
        intervals.push([call.start, time(entry)]);
        if (block.is_error) {
          tool.errors += 1;
          const text = typeof block.content === 'string' ? block.content : JSON.stringify(block.content);
          errors.push(`${((call.start - start) / 60000).toFixed(1)}m ${call.name}: ${text.slice(0, 160).replace(/\s+/g, ' ')}`);
        }
      }
    }
  }

  const usage = { output: 0, thinking: 0, cacheRead: 0, cacheWrite: 0, tokensSent: 0 };
  const context = [];
  for (const value of messages.values()) {
    // Everything the request sent: new input, what it wrote to the cache and what it read from it.
    // The split between them depends on what happened to be cached, and their sum does not.
    const sent = (value.input_tokens || 0) + (value.cache_creation_input_tokens || 0) + (value.cache_read_input_tokens || 0);
    usage.output += value.output_tokens || 0;
    usage.thinking += (value.output_tokens_details && value.output_tokens_details.thinking_tokens) || 0;
    usage.cacheRead += value.cache_read_input_tokens || 0;
    usage.cacheWrite += value.cache_creation_input_tokens || 0;
    usage.tokensSent += sent;
    context.push(sent);
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
  const estimated = (table) => Object.fromEntries(Object.entries(table).map(([key, chars]) => [key, estimate(chars)]));
  const all = Object.values(tools);
  return {
    durationMin: minutes(end - start),
    busyMin: minutes(busy),
    modelMin: minutes(end - start - busy),
    requests: messages.size,
    ...usage,
    contextStart: context[0] || 0,
    contextEnd: context[context.length - 1] || 0,
    ...startContext(firstRequest, context[0] || 0),
    growth: {
      skills: estimated(skillChars),
      toolResults: estimated(Object.fromEntries(Object.entries(tools).map(([name, tool]) => [name, tool.resultChars]))),
      reads: estimated(readChars),
    },
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
  const list = (table) => Object.entries(table || {}).map(([name, n]) => `${name} ${n}`).join(', ') || 'none';
  const prefixed = (prefix, table) => Object.entries(table).map(([name, n]) => `${prefix} ${name} ${n}`);
  const added = [...prefixed('skill', run.growth.skills), ...prefixed('read', run.growth.reads), ...prefixed('result', run.growth.toolResults)];
  const lines = [
    `Duration ${run.durationMin} min | tool busy ${run.busyMin} min | model and overhead ${run.modelMin} min`,
    `Tokens sent ${run.tokensSent} | output ${run.output}, thinking ${run.thinking} | requests ${run.requests} | cache read ${run.cacheRead}, write ${run.cacheWrite}`,
    `Context ${Math.round(run.contextStart / 1000)}k at the start, ${Math.round(run.contextEnd / 1000)}k at the end`,
    `Start, estimated: ${run.context ? list(run.context) : 'not recorded in this transcript'}`,
    `Tools at the start: ${list(run.startTools)}`,
    `Added, estimated: ${added.join(', ') || 'none'}`,
    `Tool calls ${run.toolCalls}, with ${run.errors} errors | Capture calls ${run.captures}`,
    `Skills loaded: ${list(run.skills)}`,
    `Engine commands: ${list(run.commands)}`,
    '',
  ];
  for (const [name, tool] of Object.entries(run.tools).sort((a, b) => b[1].calls - a[1].calls)) {
    lines.push(`${name.padEnd(24)} calls ${String(tool.calls).padStart(4)}  errors ${String(tool.errors).padStart(3)}  sec ${(tool.ms / 1000).toFixed(0).padStart(5)}  input chars ${String(tool.chars).padStart(7)}  result chars ${String(tool.resultChars).padStart(7)}`);
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
