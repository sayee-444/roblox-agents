// The expected numbers below were worked out by hand from tests/fixtures/run.jsonl.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const measure = (...args) => spawnSync(process.execPath, [path.join(root, 'tools/measure-run.js'), path.join(__dirname, 'fixtures/run.jsonl'), ...args], { encoding: 'utf8' });

test('reports the cost of a run as JSON, counting a repeated tool call once', () => {
  const run = JSON.parse(measure('--json').stdout);
  assert.strictEqual(run.durationMin, 2);
  assert.strictEqual(run.output, 600);
  assert.strictEqual(run.cacheRead, 9500);
  assert.strictEqual(run.contextStart, 1050);
  assert.strictEqual(run.contextEnd, 3500);
  assert.strictEqual(run.toolCalls, 6);
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
