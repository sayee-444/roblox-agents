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
    assert.match(stdout, /points = \{ \{ <x>, <z> \}, \{ <x>, <z> \}/, 'a point is written as an array, as the engine reads it');
    assert.match(stdout, /center = \{ <x>, <z> \}/);
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

// The steps of a command that reaches Studio, against a stand-in for Studio's MCP server.
function withStudio(env, args, check) {
  const dir = tempDir();
  try {
    const log = path.join(dir, 'calls.log');
    fs.mkdirSync(path.join(dir, 'src/world'), { recursive: true });
    for (const name of ['plan', 'state']) fs.writeFileSync(path.join(dir, `src/world/${name}.luau`), 'return {}\n');
    const fake = path.resolve(__dirname, 'fixtures/fake-studio.js');
    const result = spawnSync(process.execPath, [cli, ...args, '--place', 'P', '--project', dir], {
      encoding: 'utf8',
      timeout: 15000,
      env: { ...process.env, ...env, FAKE_STUDIO_LOG: log, WORLD_FAKE_STUDIO: fake, WORLD_RENDER_WAIT_MS: '1', WORLD_LIST_WAIT_MS: '1' },
    });
    const calls = fs.readFileSync(log, 'utf8').trim().split('\n').filter((line) => line !== 'execute_luau');
    check(result, calls);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('a capture after a write rebuilds the render first, and only once', () => {
  withStudio({ FAKE_STUDIO_STALE: 'true' }, ['capture'], ({ status, stdout }, calls) => {
    assert.strictEqual(status, 0, stdout);
    assert.deepStrictEqual(calls.slice(0, 3), ['list_roblox_studios', 'start_stop_play', 'start_stop_play']);
    assert.strictEqual(calls.filter((call) => call === 'start_stop_play').length, 2);
    assert.strictEqual(calls.filter((call) => call.startsWith('capture')).length, 3);
    assert.match(stdout, /rebuilt/);
  });
});

test('a capture with no write since the last rebuild leaves Play alone', () => {
  withStudio({}, ['capture'], (_, calls) => {
    assert.ok(!calls.includes('start_stop_play'));
  });
});

test('a shot after a write rebuilds the render first', () => {
  withStudio({ FAKE_STUDIO_STALE: 'true' }, ['shot', 'one', '1', '2', '3', '4', '5', '6'], (_, calls) => {
    assert.deepStrictEqual(calls, ['list_roblox_studios', 'start_stop_play', 'start_stop_play', 'capture world_one']);
  });
});

test('--no-refresh keeps a place from entering Play, and warns that glitches may show', () => {
  withStudio({ FAKE_STUDIO_STALE: 'true' }, ['capture', '--no-refresh'], ({ stdout }, calls) => {
    assert.ok(!calls.includes('start_stop_play'));
    assert.match(stdout, /glitch/i);
  });
});

test('capture takes the overview last, since a jump from its height leaves the next view broken', () => {
  withStudio({}, ['capture'], (_, calls) => {
    assert.deepStrictEqual(calls.filter((call) => call.startsWith('capture')), [
      'capture world_hills-above', 'capture world_river-above', 'capture world_overview',
    ]);
  });
});

test('capture takes each view once, since its file size cannot prove the render finished', () => {
  withStudio({}, ['capture', 'overview'], (_, calls) => {
    assert.strictEqual(calls.filter((call) => call.startsWith('capture')).length, 1);
  });
});

test('a view from far away leaves the next look to rebuild the render, since the near terrain stays broken', () => {
  withStudio({}, ['capture', 'overview'], (_, calls) => {
    assert.deepStrictEqual(calls.slice(-2), ['capture world_overview', 'mark render stale']);
  });
  withStudio({}, ['shot', 'far', '0', '1500', '1500', '0', '0', '0'], (_, calls) => {
    assert.strictEqual(calls[calls.length - 1], 'mark render stale');
  });
});

test('a view from nearby leaves the render as it is', () => {
  withStudio({}, ['capture', 'river-above'], (_, calls) => {
    assert.ok(!calls.includes('mark render stale'));
  });
  withStudio({}, ['shot', 'near', '760', '250', '500', '1250', '110', '-320'], (_, calls) => {
    assert.ok(!calls.includes('mark render stale'));
  });
});

test('a command waits out an empty listing of places, which Studio sometimes gives while connected', () => {
  withStudio({ FAKE_STUDIO_MISSES: '3' }, ['describe'], ({ status, stdout }, calls) => {
    assert.strictEqual(status, 0, stdout);
    assert.strictEqual(calls.filter((call) => call === 'list_roblox_studios').length, 4);
  });
});

test('a command stops waiting when no place ever appears, and says so', () => {
  withStudio({ FAKE_STUDIO_MISSES: '9999' }, ['describe'], ({ status, stderr }) => {
    assert.strictEqual(status, 1);
    assert.match(stderr, /Open: none/);
  });
});

test('another place being open is an answer, so a command stops at once and writes nothing', () => {
  const dir = tempDir();
  try {
    fs.mkdirSync(path.join(dir, 'src/world'), { recursive: true });
    for (const name of ['plan', 'state']) fs.writeFileSync(path.join(dir, `src/world/${name}.luau`), 'return {}\n');
    const log = path.join(dir, 'calls.log');
    const fake = path.resolve(__dirname, 'fixtures/fake-studio.js');
    const { status, stderr } = spawnSync(process.execPath, [cli, 'describe', '--place', 'Other', '--project', dir], {
      encoding: 'utf8',
      timeout: 15000,
      env: { ...process.env, FAKE_STUDIO_LOG: log, WORLD_FAKE_STUDIO: fake, WORLD_LIST_WAIT_MS: '1' },
    });
    assert.strictEqual(status, 1);
    assert.match(stderr, /Open: P/);
    assert.deepStrictEqual(fs.readFileSync(log, 'utf8').trim().split('\n'), ['list_roblox_studios']);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('borders passes on the Chunks it is given, and with none it checks them all', () => {
  withStudio({}, ['borders', '1', '2', '3', '-4'], ({ status, stdout }, calls) => {
    assert.strictEqual(status, 0, stdout);
    assert.ok(calls.includes('borders { { 1, 2 }, { 3, -4 } }'), calls.join(' | '));
  });
  withStudio({}, ['borders'], (_, calls) => {
    assert.ok(calls.includes('borders nil'), calls.join(' | '));
  });
});
