// The engine's command line must explain itself without Studio, since an agent's first move is to ask it.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const cli = path.resolve(__dirname, '../plugins/roblox-world/engine/tools/world.js');
const world = (...args) => spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', timeout: 10000 });

test('help lists every command, without Studio', () => {
  const { status, stdout } = world('help');
  assert.strictEqual(status, 0);
  const listed = stdout.split('\n').map((line) => line.match(/^ {2}([a-z]+)/)).filter(Boolean).map((match) => match[1]);
  assert.deepStrictEqual(listed.sort(), [
    'borders', 'capture', 'check', 'describe', 'generate', 'height', 'help', 'load', 'new',
    'refresh', 'regenerate', 'run', 'shot', 'test', 'wipe',
  ]);
});

test('help steers a local change towards generating only its Chunks', () => {
  assert.match(world('help').stdout, /generate.*only the Chunks a change touched/i);
});

test('no command prints the same help as asking for it', () => {
  const bare = world();
  assert.strictEqual(bare.status, 0);
  assert.strictEqual(bare.stdout, world('help').stdout);
});

test('an unknown command fails and points at help, without Studio', () => {
  const { status, stderr } = world('fly', '--place', 'P');
  assert.strictEqual(status, 2);
  assert.match(stderr, /world\.js help/);
});

test('check needs a place, like every command that reaches Studio', () => {
  const { status, stderr } = world('check');
  assert.strictEqual(status, 2);
  assert.match(stderr, /--place/);
});
