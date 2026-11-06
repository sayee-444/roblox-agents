#!/usr/bin/env node
// Summarises a Claude Code transcript: time, tokens, context, tool calls and errors.
// A tool call can appear on several transcript lines, so calls are counted once by id.
// Usage: node tools/measure-run.js <transcript.jsonl>
const fs = require('fs');

const path = process.argv[2];
if (!path) {
  console.error('Usage: node tools/measure-run.js <transcript.jsonl>');
  process.exit(2);
}

const entries = fs.readFileSync(path, 'utf8').split('\n').filter(Boolean)
  .map((line) => { try { return JSON.parse(line); } catch { return null; } })
  .filter((entry) => entry && entry.timestamp);
const time = (entry) => Date.parse(entry.timestamp);
const start = time(entries[0]);
const end = time(entries[entries.length - 1]);
const short = (name) => name.replace('mcp__Roblox_Studio__', '');

const usage = { output: 0, cacheRead: 0, cacheWrite: 0 };
const messages = new Map();
const calls = new Map();
const tools = {};
const intervals = [];
const errors = [];

for (const entry of entries) {
  const message = entry.message;
  if (!message || !Array.isArray(message.content)) continue;
  if (entry.type === 'assistant') {
    if (message.id && message.usage) messages.set(message.id, message.usage);
    for (const block of message.content) {
      if (block.type === 'tool_use' && !calls.has(block.id)) {
        calls.set(block.id, { name: short(block.name), start: time(entry), chars: JSON.stringify(block.input || {}).length });
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

const context = [];
for (const value of messages.values()) {
  usage.output += value.output_tokens || 0;
  usage.cacheRead += value.cache_read_input_tokens || 0;
  usage.cacheWrite += value.cache_creation_input_tokens || 0;
  context.push(value.cache_read_input_tokens || 0);
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

const minutes = (ms) => (ms / 60000).toFixed(1);
console.log(`Duration ${minutes(end - start)} min | tool busy ${minutes(busy)} min | model and overhead ${minutes(end - start - busy)} min`);
console.log(`Requests ${messages.size} | output ${usage.output} | cache read ${usage.cacheRead} | cache write ${usage.cacheWrite}`);
if (context.length) console.log(`Context ${Math.round(context[0] / 1000)}k at the start, ${Math.round(context[context.length - 1] / 1000)}k at the end`);
const total = Object.values(tools).reduce((sum, tool) => sum + tool.calls, 0);
const failed = Object.values(tools).reduce((sum, tool) => sum + tool.errors, 0);
console.log(`Tool calls ${total}, with ${failed} errors\n`);
for (const [name, tool] of Object.entries(tools).sort((a, b) => b[1].calls - a[1].calls)) {
  console.log(`${name.padEnd(24)} calls ${String(tool.calls).padStart(4)}  errors ${String(tool.errors).padStart(3)}  sec ${(tool.ms / 1000).toFixed(0).padStart(5)}  input chars ${String(tool.chars).padStart(7)}`);
}
if (errors.length) console.log(`\nErrors:\n${errors.join('\n')}`);
