// The engine's command line must explain itself without Studio, since an agent's first move is to ask it.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const cli = path.resolve(__dirname, '../plugins/roblox-world/engine/tools/world.js');
const world = (...args) => spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', timeout: 10000 });

test('help lists every command, without Studio', () => {
  const { status, stdout } = world('help');
  assert.strictEqual(status, 0);
  const listed = stdout.split('\n').map((line) => line.match(/^ {2}([a-z]+)/)).filter(Boolean).map((match) => match[1]);
  assert.deepStrictEqual(listed.sort(), [
    'borders', 'capture', 'check', 'describe', 'generate', 'height', 'heights', 'help', 'load', 'new',
    'refresh', 'regenerate', 'run', 'shot', 'test', 'wipe',
  ]);
});

const tempDir = () => fs.mkdtempSync(path.join(os.tmpdir(), 'world-cli-'));

test('help shows that new needs a place', () => {
  assert.match(world('help').stdout, /new <dir> --place <name>/);
});

test('new prints a World Plan template that holds no position of the test map', () => {
  const dir = tempDir();
  try {
    const { status, stdout } = world('new', dir, '--place', 'P', '--seed', '555');
    assert.strictEqual(status, 0);
    assert.match(stdout, /worldSeed = 555/);
    assert.match(stdout, /points = <[^>]+>/);
    assert.match(stdout, /center = <[^>]+>/);
    for (const testMap of ['-720, -380', '520, 440', '-740, 40', 'seed = 7001']) assert.ok(!stdout.includes(testMap), testMap);
    assert.ok(!fs.existsSync(path.join(dir, 'src/world/plan.luau')), 'the agent writes the plan in one go');
    assert.match(fs.readFileSync(path.join(dir, 'docs/world/rules.md'), 'utf8'), /\| 555 \|/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('the template shows how to fork a River', () => {
  const dir = tempDir();
  try {
    assert.match(world('new', dir, '--place', 'P').stdout, /fork/i);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('new gives every Landform a Region Seed of its own, which follows from the World Seed', () => {
  const seedsOf = (seed) => {
    const dir = tempDir();
    try {
      return [...world('new', dir, '--place', 'P', '--seed', seed).stdout.matchAll(/\bseed = (\d+)/g)].map((match) => match[1]);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  };
  const seeds = seedsOf('555');
  assert.ok(seeds.length >= 3, `found ${seeds.length}`);
  assert.strictEqual(new Set(seeds).size, seeds.length);
  assert.deepStrictEqual(seedsOf('555'), seeds);
  assert.notDeepStrictEqual(seedsOf('556'), seeds);
});

test('the template names every field of the test map', () => {
  const dir = tempDir();
  try {
    const { stdout } = world('new', dir, '--place', 'P');
    const testMap = fs.readFileSync(path.resolve(__dirname, '../plugins/roblox-world/engine/src/world/plan.luau'), 'utf8');
    const fields = [...new Set([...testMap.replace(/--.*$/gm, '').matchAll(/\b([a-zA-Z]+) =/g)].map((match) => match[1]))];
    assert.deepStrictEqual(fields.filter((field) => !new RegExp(`\\b${field} =`).test(stdout)), []);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('new --test-map copies the runnable test map, for the benchmark', () => {
  const dir = tempDir();
  try {
    assert.strictEqual(world('new', dir, '--place', 'P', '--seed', '555', '--test-map').status, 0);
    const plan = fs.readFileSync(path.join(dir, 'src/world/plan.luau'), 'utf8');
    assert.match(plan, /worldSeed = 555/);
    assert.match(plan, /id = "river"/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a project with no World Plan is refused before reaching Studio', () => {
  const dir = tempDir();
  try {
    world('new', dir, '--place', 'P');
    const { status, stderr } = world('run', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 2);
    assert.match(stderr, /No World Plan/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
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
