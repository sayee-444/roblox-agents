// The expected numbers below were worked out by hand from tests/fixtures/run.jsonl.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const measure = (...args) => spawnSync(process.execPath, [path.join(root, 'tools/measure-run.js'), path.join(__dirname, 'fixtures/run.jsonl'), ...args], { encoding: 'utf8' });

test('counts an engine command called through a shell variable', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'measure-'));
  try {
    const file = path.join(dir, 'run.jsonl');
    const command = 'W=/x/world.js; node $W new . --place P && node "$W" run --place P --project .';
    fs.writeFileSync(file, `${JSON.stringify({ type: 'assistant', timestamp: '2026-11-06T10:00:00.000Z', message: { content: [{ type: 'tool_use', id: 'a', name: 'Bash', input: { command } }] } })}\n`);
    const run = JSON.parse(spawnSync(process.execPath, [path.join(root, 'tools/measure-run.js'), file, '--json'], { encoding: 'utf8' }).stdout);
    assert.deepStrictEqual(run.commands, { new: 1, run: 1 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('reports the cost of a run as JSON, counting a repeated tool call once', () => {
  const run = JSON.parse(measure('--json').stdout);
  assert.strictEqual(run.durationMin, 2);
  assert.strictEqual(run.durationSec, 120);
  assert.strictEqual(run.output, 600);
  assert.strictEqual(run.cacheRead, 9500);
  assert.strictEqual(run.contextStart, 1050);
  assert.strictEqual(run.contextEnd, 3500);
  assert.strictEqual(run.toolCalls, 7);
  assert.strictEqual(run.errors, 1);
});

test('proves which skills and engine commands ran, and ignores a file merely being read', () => {
  const run = JSON.parse(measure('--json').stdout);
  assert.deepStrictEqual(run.skills, { 'world-history': 1 });
  assert.deepStrictEqual(run.commands, { new: 1, help: 1, capture: 1 });
  assert.strictEqual(run.captures, 2);
});

test('prints the same proof for a person to read', () => {
  const { stdout } = measure();
  assert.match(stdout, /Skills loaded: world-history 1/);
  assert.match(stdout, /Engine commands: new 1, help 1, capture 1/);
  assert.match(stdout, /Capture calls 2/);
});

test('reports every token the run sent, which does not depend on what happened to be cached', () => {
  const run = JSON.parse(measure('--json').stdout);
  assert.strictEqual(run.tokensSent, 9550);
  assert.strictEqual(run.thinking, 120);
});

test('breaks the starting context into parts, and says how much it could not attribute', () => {
  const { context } = JSON.parse(measure('--json').stdout);
  assert.deepStrictEqual(context, {
    agent: 100,
    memoryRules: 200,
    memoryFile: 50,
    tools: 300,
    pluginSkills: 30,
    otherSkills: 70,
    attachments: 10,
    unattributed: 290,
  });
});

test('names each tool the context carries from the start', () => {
  const run = JSON.parse(measure('--json').stdout);
  assert.deepStrictEqual(run.startTools, { Bash: 200, Read: 100 });
});

test('shows what grew the context during the run', () => {
  const { growth } = JSON.parse(measure('--json').stdout);
  assert.deepStrictEqual(growth.skills, { 'world-history': 100 });
  assert.strictEqual(growth.toolResults.Read, 200);
  assert.deepStrictEqual(growth.reads, { 'plan.luau': 200 });
});

test('prints the context parts for a person to read', () => {
  const { stdout } = measure();
  assert.match(stdout, /Tokens sent 9550 \| output 600, thinking 120/);
  assert.match(stdout, /Start, estimated: agent 100, memoryRules 200, memoryFile 50, tools 300, pluginSkills 30, otherSkills 70, attachments 10, unattributed 290/);
  assert.match(stdout, /Tools at the start: Bash 200, Read 100/);
  assert.match(stdout, /Added, estimated: skill world-history 100/);
});

test('reports the effort the requests of a run really used', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'measure-'));
  try {
    const file = path.join(dir, 'run.jsonl');
    const lines = [
      { type: 'user', timestamp: '2026-11-06T10:00:00.000Z', message: { content: 'hello' } },
      { type: 'api-request-blob', message: { output_config: { effort: 'low' } } },
    ];
    fs.writeFileSync(file, lines.map((line) => `${JSON.stringify(line)}\n`).join(''));
    const run = JSON.parse(spawnSync(process.execPath, [path.join(root, 'tools/measure-run.js'), file, '--json'], { encoding: 'utf8' }).stdout);
    assert.strictEqual(run.effort, 'low');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
