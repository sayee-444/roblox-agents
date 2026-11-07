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
    'borders', 'capture', 'check', 'describe', 'generate', 'height', 'heights', 'help', 'new',
    'refresh', 'remove', 'run', 'scale', 'shot', 'status', 'sync', 'test', 'verify', 'wipe',
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

// A plan and the numbers a double of it must hold, taken from the double written by hand in commit 51602ae.
const SMALL_PLAN = `-- World Plan: declares what exists where. It wins over the seeds.
-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256),
-- so indices -5..6 give 12 x 12 Chunks (6,144 x 6,144 studs).

return {
	worldSeed = 12345,
	chunkSize = 512,
	voxel = 4,
	extent = { minX = -5, maxX = 6, minZ = -5, maxZ = 6 }, -- inclusive Chunk indices
	floorY = 0, -- ground stops here
	rockUnder = 8,
	base = { mean = 52, amp = 34, scale = 260, octaves = 5, warpScale = 300, warpAmp = 60 },
	regions = {
		{
			-- Range across the north, west to east.
			id = "range",
			kind = "mountain",
			seed = 7001,
			points = { { -2456, -1856 }, { -1456, -2056 } },
			halfWidth = 300,
			height = 250,
			ridgeScale = 150,
			crestScale = 220,
		},
		{
			id = "mesa",
			kind = "mesa",
			seed = 7002,
			center = { 2344, -456 },
			radius = 60,
			margin = 150,
			levels = 5,
			height = 100,
			warp = 40,
			elongate = 1.3,
			angle = 90,
			gully = 8,
		},
		{
			id = "valley",
			kind = "valley",
			seed = 7003,
			riverId = "river",
			halfWidth = 700,
			floorY = 28,
		},
		{
			id = "cave",
			kind = "cave",
			seed = 7004,
			points = { { 1928, 60, 2244 }, { 2004, 60, 2244 } },
			radius = 14,
		},
	},
	rivers = {
		{
			-- Leaves the mesa at (120, 40).
			id = "river",
			points = { { -2656, -556 }, { -1956, -356 } },
			loops = { { leg = 1, radius = 220, turn = 290, side = "right" } },
			curve = 1,
			meander = 80,
			widths = { 30, 36 }, -- grows towards the Lake
			bendWiden = 0.5,
			depths = { 12, 34 },
			depthVary = 0.5,
			banks = { shore = 50, shallows = 30, shallowDepth = 4, bedFlat = 0.2, steep = 1.6, rough = 3, vary = 0.6, smooth = 48 },
			bedRough = 6,
			waterLevel = 20,
		},
		{
			id = "fork",
			points = { { -1956, -356 }, { -1096, 644 } },
			halfWidth = 20,
			bedY = 10,
			waterLevel = 20,
		},
	},
	lakes = {
		{ id = "lake", seed = 7006, center = { 744, 1044 }, radius = 340, shore = 240, warp = 40, elongate = 1.2, angle = 30, bedY = -90, bedRough = 10, depthVary = 0.4, banks = { shallows = 50, shallowDepth = 6, bedFlat = 0.25, steep = 1.3, rough = 6, vary = 0.6 }, waterLevel = 20 },
	},
	sites = {},
	worldLimit = nil, -- not requested yet
	materials = {
		snowLine = 205,
		snowBlend = 30,
		snowMaxSlope = 1.4,
		steep = 0.85,
		rockLine = 140,
		bankDist = 26,
		bankHeight = 28,
		mesaRiser = 1.1,
	},
}
`;

function withPlan({ plan = SMALL_PLAN, state, history, rules }, check) {
  const dir = tempDir();
  try {
    fs.mkdirSync(path.join(dir, 'src/world'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'docs/world'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'src/world/plan.luau'), plan);
    fs.writeFileSync(path.join(dir, 'src/world/state.luau'), state || 'return {\n\tgeneratorVersion = 1,\n\tchunks = {},\n}\n');
    if (history) fs.writeFileSync(path.join(dir, 'docs/world/history.md'), history);
    fs.writeFileSync(path.join(dir, 'docs/world/rules.md'), rules || '# World rules\n\n## Decisions\n\nNewest first.\n');
    check(dir, (file) => fs.readFileSync(path.join(dir, file), 'utf8'));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('scale 2 gives the plan that doubling by hand gave, with no Studio', () => {
  withPlan({}, (dir, read) => {
    const { status, stdout } = world('scale', '2', '--project', dir);
    assert.strictEqual(status, 0, stdout);
    const plan = read('src/world/plan.luau');
    for (const expected of [
      'extent = { minX = -11, maxX = 12, minZ = -11, maxZ = 12 }',
      'base = { mean = 104, amp = 68, scale = 520, octaves = 6, warpScale = 600, warpAmp = 120 }',
      'points = { { -5168, -3968 }, { -3168, -4368 } }',
      'halfWidth = 600',
      'height = 500',
      'ridgeScale = 300',
      'center = { 4432, -1168 }',
      'margin = 300',
      'gully = 16',
      'floorY = 56',
      'points = { { 3600, 120, 4232 }, { 3752, 120, 4232 } }',
      'radius = 28',
      'loops = { { leg = 1, radius = 440, turn = 290, side = "right" } }',
      'meander = 160',
      'widths = { 60, 72 }',
      'depths = { 24, 68 }',
      'banks = { shore = 100, shallows = 60, shallowDepth = 8, bedFlat = 0.2, steep = 1.6, rough = 6, vary = 0.6, smooth = 96 }',
      'bedRough = 12',
      'waterLevel = 40',
      'center = { 1232, 1832 }, radius = 680, shore = 480, warp = 80, elongate = 1.2, angle = 30, bedY = -180, bedRough = 20',
      'snowLine = 410',
      'bankHeight = 56',
    ]) assert.ok(plan.includes(expected), expected);
  });
});

test('scale keeps seeds, ratios and slopes, since those do not grow with the map', () => {
  withPlan({}, (dir, read) => {
    world('scale', '2', '--project', dir);
    const plan = read('src/world/plan.luau');
    for (const kept of ['worldSeed = 12345', 'chunkSize = 512', 'voxel = 4', 'seed = 7001', 'levels = 5', 'elongate = 1.3', 'angle = 90', 'curve = 1', 'bendWiden = 0.5', 'depthVary = 0.5', 'snowMaxSlope = 1.4', 'steep = 0.85', 'mesaRiser = 1.1', 'rockUnder = 8']) {
      assert.ok(plan.includes(kept), kept);
    }
  });
});

test('scale leaves a fork on the point of the River it leaves', () => {
  withPlan({}, (dir, read) => {
    world('scale', '1.5', '--project', dir);
    const [river, fork] = [...read('src/world/plan.luau').matchAll(/id = "(?:river|fork)"[^]*?points = \{ (\{[^}]*\}), (\{[^}]*\})/g)];
    assert.strictEqual(fork[1], river[2]);
  });
});

test('scale keeps water and the floor on the voxel grid, which validation requires', () => {
  withPlan({}, (dir, read) => {
    world('scale', '1.5', '--project', dir);
    const plan = read('src/world/plan.luau');
    assert.ok(plan.includes('waterLevel = 32'), 'a water level of 30 moves to 32');
    assert.ok(plan.includes('floorY = 44'), 'a valley floor of 42 moves to 44');
  });
});

test('scale stops smooth at the most validation accepts', () => {
  withPlan({}, (dir, read) => {
    world('scale', '4', '--project', dir);
    assert.ok(read('src/world/plan.luau').includes('smooth = 100'));
  });
});

test('scale removes comments holding a number, which would now be wrong, and keeps the others', () => {
  withPlan({}, (dir, read) => {
    const { stdout } = world('scale', '2', '--project', dir);
    const plan = read('src/world/plan.luau');
    assert.ok(!plan.includes('indices -5..6'), 'the header line of the old extent');
    assert.ok(!plan.includes('(120, 40)'), 'a position in a comment');
    assert.ok(plan.includes('-- Range across the north, west to east.'));
    assert.ok(plan.includes('-- grows towards the Lake'));
    assert.ok(plan.includes('-- Chunk (i, j) covers x in'), 'what a Chunk covers does not change');
    assert.match(stdout, /2 comments/);
  });
});

test('scale records itself in the history and the rules, and says what to run next', () => {
  withPlan({ history: '## 2026-01-01: An older change\n' }, (dir, read) => {
    const { stdout } = world('scale', '2', '--project', dir);
    const history = read('docs/world/history.md');
    assert.ok(history.startsWith('## '), history);
    assert.match(history.split('\n')[0], /Scaled the world by 2/);
    assert.ok(history.includes('## 2026-01-01: An older change'));
    assert.match(read('docs/world/rules.md'), /scaled by 2, extent -5\.\.6 to -11\.\.12/i);
    assert.match(stdout, /run --place/);
    assert.match(stdout, /24 x 24/);
  });
});

test('scale refuses a world with Locked Chunks and changes nothing, since their hand edits would no longer fit', () => {
  const state = 'return {\n\tgeneratorVersion = 1,\n\tchunks = {\n\t\t["1,1"] = { generated = true, locked = true },\n\t},\n}\n';
  withPlan({ state }, (dir, read) => {
    const { status, stderr } = world('scale', '2', '--project', dir);
    assert.strictEqual(status, 1);
    assert.match(stderr, /Locked/);
    assert.match(stderr, /1,1/);
    assert.strictEqual(read('src/world/plan.luau'), SMALL_PLAN);
  });
});

test('scale refuses a plan with Sites, which it would leave behind', () => {
  withPlan({ plan: SMALL_PLAN.replace('sites = {}', 'sites = { { id = "a", at = { 1, 2 } } }') }, (dir) => {
    const { status, stderr } = world('scale', '2', '--project', dir);
    assert.strictEqual(status, 1);
    assert.match(stderr, /sites/i);
  });
});

test('scale needs a number above 0 and a project', () => {
  withPlan({}, (dir) => {
    assert.strictEqual(world('scale', '--project', dir).status, 2);
    assert.strictEqual(world('scale', '0', '--project', dir).status, 2);
    assert.strictEqual(world('scale', 'big', '--project', dir).status, 2);
    assert.strictEqual(world('scale', '2').status, 2);
  });
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

test('the template opens the bends of a River and of a fork, each with its own value', () => {
  const template = fs.readFileSync(path.resolve(__dirname, '../plugins/roblox-world/engine/templates/plan.luau'), 'utf8');
  assert.match(template, /^\s*bendWiden = 0\.5,/m, 'the River sets it');
  assert.match(template, /id = "fork".*bendWiden = 0\.5/, 'the fork sets it');
});

test('the template starts a River curved', () => {
  const dir = tempDir();
  try {
    const { stdout } = world('new', dir, '--place', 'P');
    assert.match(stdout, /curve = 1/);
    assert.match(stdout, /meander = \d+/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

// A command in a real world folder, against the stand-in for Studio.
function inStudio(dir, env, ...args) {
  const log = path.join(os.tmpdir(), `fake-studio-${process.pid}-${Date.now()}.log`);
  try {
    const result = spawnSync(process.execPath, [cli, ...args], {
      encoding: 'utf8',
      timeout: 15000,
      env: { ...process.env, FAKE_STUDIO_LOG: log, WORLD_FAKE_STUDIO: path.resolve(__dirname, 'fixtures/fake-studio.js'), WORLD_LIST_WAIT_MS: '1', WORLD_STATUS_WAIT_MS: '500', ...env },
    });
    const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n') : [];
    return { ...result, calls };
  } finally {
    fs.rmSync(log, { force: true });
  }
}

const TWO_CHUNKS = 'return {\n\tgeneratorVersion = 1,\n\tchunks = {\n\t\t["0,0"] = { generated = true, locked = false },\n\t\t["1,1"] = { generated = true, locked = true },\n\t},\n}\n';

test('status says what a world holds, where it stands and what changed last', () => {
  const rules = '# World rules\n\n| Field | Value |\n|---|---|\n| PlaceId or window title | My Place |\n';
  withPlan({ state: TWO_CHUNKS, rules, history: '## 2026-11-06: Removed River `old`\n\ntext\n\n## 2026-01-01: Older\n' }, (dir) => {
    const { status, stdout } = inStudio(dir, { FAKE_STUDIO_CELLS: '1234567' }, 'status', '--project', dir);
    assert.strictEqual(status, 0, stdout);
    assert.match(stdout, /Seed 12345/);
    assert.match(stdout, /extent -5\.\.6, 12 x 12, 144 Chunks/);
    assert.match(stdout, /2 of 144 Chunks generated/);
    assert.match(stdout, /Locked: 1,1/);
    assert.match(stdout, /range \(mountain\), mesa \(mesa\), valley \(valley\), cave \(cave\)/);
    assert.match(stdout, /Rivers: river, fork/);
    assert.match(stdout, /Lakes: lake/);
    assert.match(stdout, /Last change: 2026-11-06: Removed River `old`/);
    assert.match(stdout, /Development Place: My Place/);
    assert.match(stdout, /P open, 1,234,567 terrain cells/);
  });
});

test('status writes nothing, in the world or in Studio', () => {
  withPlan({}, (dir, read) => {
    const { calls } = inStudio(dir, {}, 'status', '--project', dir);
    assert.ok(calls.includes('list_roblox_studios'));
    assert.ok(!calls.includes('paste'), calls.join(' | '));
    assert.strictEqual(read('src/world/plan.luau'), SMALL_PLAN);
  });
});

test('status names every place open, since several open means asking the developer', () => {
  withPlan({}, (dir) => {
    const { stdout } = inStudio(dir, { FAKE_STUDIO_PLACES: 'A,B', FAKE_STUDIO_CELLS: '5' }, 'status', '--project', dir);
    assert.match(stdout, /A open, 5 terrain cells; B open, 5 terrain cells/);
  });
});

test('status still answers from the files when no place is open', () => {
  withPlan({}, (dir) => {
    const { status, stdout } = inStudio(dir, { FAKE_STUDIO_MISSES: '9999' }, 'status', '--project', dir);
    assert.strictEqual(status, 0);
    assert.match(stdout, /Seed 12345/);
    assert.match(stdout, /Studio: no place open after [\d.]+ s/);
  });
});

test('status still answers from the files when Studio never answers, and ends', () => {
  withPlan({}, (dir) => {
    const { status, stdout } = inStudio(dir, { FAKE_STUDIO_SILENT: 'true' }, 'status', '--project', dir);
    assert.strictEqual(status, 0);
    assert.match(stdout, /Seed 12345/);
    assert.match(stdout, /Studio: did not answer/);
  });
});

test('status says when a folder has no world yet', () => {
  const dir = tempDir();
  try {
    const { status, stdout } = inStudio(dir, {}, 'status', '--project', dir);
    assert.strictEqual(status, 0);
    assert.match(stdout, /No World Plan/);
    assert.match(stdout, /No docs\/world\/rules\.md/);
    assert.match(stdout, /P open/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

const IMPACT = JSON.stringify({ rewrite: ['-1,0', '0,0'], lockedReached: ['1,1'] });

test('remove takes a River and its valley out of the plan, writes only their Chunks and records them exactly', () => {
  withPlan({ history: '## 2026-01-01: Older\n' }, (dir, read) => {
    const { status, stdout, calls } = inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT }, 'remove', 'river', '--place', 'P', '--project', dir, '--why', 'the developer wanted one River.');
    assert.strictEqual(status, 0, stdout);
    const plan = read('src/world/plan.luau');
    assert.ok(!plan.includes('id = "river"'));
    assert.ok(!plan.includes('id = "valley"'));
    for (const kept of ['id = "fork"', 'id = "range"', 'id = "lake"']) assert.ok(plan.includes(kept), kept);
    assert.ok(calls.includes('impact { removedIds = { "river", "valley" } }'), calls.join(' | '));
    assert.ok(calls.includes('generate { { -1, 0 }, { 0, 0 } }'), calls.join(' | '));
    assert.ok(calls.indexOf('describe') < calls.indexOf('generate { { -1, 0 }, { 0, 0 } }'), 'the new plan is validated before any write');
    const history = read('docs/world/history.md');
    assert.match(history.split('\n')[0], /^## \d{4}-\d{2}-\d{2}: Removed River `river` and valley `valley`$/);
    assert.match(history, /\*\*Why:\*\* the developer wanted one River\./);
    assert.match(history, /\*\*Chunks written:\*\* -1,0 0,0/);
    assert.ok(history.includes('\t\t\tpoints = { { -2656, -556 }, { -1956, -356 } },'), 'the block as it stood in the plan');
    assert.ok(history.includes('\t\t\triverId = "river",'));
    assert.ok(history.includes('## 2026-01-01: Older'), 'older entries stay');
    assert.match(stdout, /Locked.*1,1/);
  });
});

test('remove takes out a thing on one line and leaves its list empty and tidy', () => {
  withPlan({}, (dir, read) => {
    const { status } = inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT }, 'remove', 'lake', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 0);
    assert.ok(read('src/world/plan.luau').includes('lakes = {},'));
    assert.ok(read('docs/world/history.md').includes('id = "lake", seed = 7006'));
  });
});

test('remove of a valley takes its River too, since only a valley carves a River into the ground', () => {
  withPlan({}, (dir, read) => {
    inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT }, 'remove', 'valley', '--place', 'P', '--project', dir);
    const plan = read('src/world/plan.luau');
    assert.ok(!plan.includes('id = "valley"'));
    assert.ok(!plan.includes('id = "river"'));
    assert.ok(plan.includes('id = "fork"'), 'another River stays');
    assert.match(read('docs/world/history.md').split('\n')[0], /Removed valley `valley` and River `river`$/);
  });
});

test('remove writes no Chunk when none it touched was generated, since an empty list would write every Chunk', () => {
  withPlan({}, (dir, read) => {
    const { status, calls } = inStudio(dir, { FAKE_STUDIO_IMPACT: JSON.stringify({ rewrite: [], lockedReached: [] }) }, 'remove', 'cave', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 0);
    assert.ok(!calls.some((call) => call.startsWith('generate')), calls.join(' | '));
    assert.ok(!read('src/world/plan.luau').includes('id = "cave"'));
    assert.match(read('docs/world/history.md'), /\*\*Chunks written:\*\* none/);
  });
});

test('remove restores the plan and writes nothing when the plan would be invalid without it', () => {
  withPlan({}, (dir, read) => {
    const { status, stdout, calls } = inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT, FAKE_STUDIO_INVALID: 'true' }, 'remove', 'river', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.strictEqual(read('src/world/plan.luau'), SMALL_PLAN);
    assert.ok(!calls.some((call) => call.startsWith('generate')), calls.join(' | '));
    assert.ok(!fs.existsSync(path.join(dir, 'docs/world/history.md')));
    assert.match(stdout, /Nothing was removed/);
    assert.match(stdout, /unknown river/);
  });
});

test('remove of something the plan lacks names what it holds, before reaching Studio', () => {
  withPlan({}, (dir, read) => {
    const { status, stderr, calls } = inStudio(dir, {}, 'remove', 'volcano', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.match(stderr, /no "volcano"/);
    assert.match(stderr, /range mesa valley cave river fork lake/);
    assert.deepStrictEqual(calls, []);
    assert.strictEqual(read('src/world/plan.luau'), SMALL_PLAN);
  });
});

test('remove needs a project and a name, since it edits a plan', () => {
  withPlan({}, (dir) => {
    assert.strictEqual(inStudio(dir, {}, 'remove', 'river', '--place', 'P').status, 2);
    assert.strictEqual(inStudio(dir, {}, 'remove', '--place', 'P', '--project', dir).status, 2);
  });
});

test('scale below 1 shrinks the plan about its centre, and says the old terrain stays', () => {
  withPlan({}, (dir, read) => {
    const { status, stdout } = world('scale', '0.5', '--project', dir);
    assert.strictEqual(status, 0, stdout);
    const plan = read('src/world/plan.luau');
    // Worked out by hand: the centre of -5..6 is x 256, and a position p becomes (p - 256) / 2 + 256.
    for (const expected of [
      'extent = { minX = -2, maxX = 3, minZ = -2, maxZ = 3 }',
      'base = { mean = 26, amp = 17, scale = 130, octaves = 4, warpScale = 150, warpAmp = 30 }',
      'points = { { -1100, -800 }, { -600, -900 } }',
      'center = { 1300, -100 }',
      'halfWidth = 150',
      'height = 125',
      'floorY = 16',
    ]) assert.ok(plan.includes(expected), expected);
    assert.match(stdout, /6 x 6 Chunks/);
    assert.match(stdout, /outside the new extent keep their terrain/);
  });
});

test('scale puts its decision first in the rules, with its reason, since they run newest first', () => {
  const rules = '# World rules\n\n## Decisions\n\nNewest first: the date, the decision and why it was made.\n\n- 2026-01-01: an older decision.\n';
  withPlan({ rules }, (dir, read) => {
    world('scale', '2', '--project', dir, '--why', 'the map felt small.');
    const text = read('docs/world/rules.md');
    assert.match(text, /Newest first: the date, the decision and why it was made\.\n\n- \d{4}-\d{2}-\d{2}: scaled by 2, extent -5\.\.6 to -11\.\.12\. Why: the map felt small\.\n- 2026-01-01: an older decision\.\n$/);
  });
});

test('status counts only the Chunks inside the extent, and says how many lie outside it', () => {
  const state = 'return {\n\tgeneratorVersion = 1,\n\tchunks = {\n\t\t["0,0"] = { generated = true, locked = false },\n\t\t["9,9"] = { generated = true, locked = false },\n\t\t["-6,0"] = { generated = true, locked = false },\n\t},\n}\n';
  withPlan({ state }, (dir) => {
    const { stdout } = inStudio(dir, {}, 'status', '--project', dir);
    assert.match(stdout, /1 of 144 Chunks generated, and 2 outside the extent\. Locked: none/);
  });
});

test('remove records the Locked Chunks it reached, since they still hold what it took out', () => {
  withPlan({}, (dir, read) => {
    inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT }, 'remove', 'river', '--place', 'P', '--project', dir);
    assert.match(read('docs/world/history.md'), /\*\*Locked Chunks it reached, not written:\*\* 1,1/);
  });
});

test('remove puts the plan back and records nothing when Studio fails before any write', () => {
  withPlan({}, (dir, read) => {
    const { status, stderr, calls } = inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT, FAKE_STUDIO_UNREACHABLE: '.describe(' }, 'remove', 'river', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.strictEqual(read('src/world/plan.luau'), SMALL_PLAN);
    assert.ok(!fs.existsSync(path.join(dir, 'docs/world/history.md')));
    assert.ok(!calls.some((call) => call.startsWith('generate')), calls.join(' | '));
    assert.match(stderr, /Nothing was removed/);
  });
});

test('remove keeps the block in the history when the write fails, and names the command that finishes it', () => {
  withPlan({}, (dir, read) => {
    const { status, stdout } = inStudio(dir, { FAKE_STUDIO_IMPACT: IMPACT, FAKE_STUDIO_UNREACHABLE: '.generate(' }, 'remove', 'river', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.ok(!read('src/world/plan.luau').includes('id = "river"'));
    const history = read('docs/world/history.md');
    assert.ok(history.includes('\t\t\triverId = "river",'), 'the block is safe');
    assert.match(history, /\*\*Chunks written:\*\* none/);
    assert.match(history, /\*\*Chunks not written:\*\* -1,0 0,0/);
    assert.match(stdout, /generate -1 0 0 0 --place P --project/);
  });
});

test('a Luau call Studio does not answer is not sent again, since its code may still be running', () => {
  withPlan({}, (dir) => {
    const { status, stderr, calls } = inStudio(dir, { FAKE_STUDIO_UNREACHABLE: '.generate(' }, 'generate', '0', '0', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.strictEqual(calls.filter((call) => call.startsWith('generate')).length, 1, calls.join(' | '));
    assert.match(stderr, /may still be running/);
    assert.match(stderr, /Target is not reachable/);
  });
});

test('run of a world that has written nothing stops on a place holding terrain, before any step', () => {
  withPlan({}, (dir) => {
    const { status, stderr, stdout, calls } = inStudio(dir, { FAKE_STUDIO_CELLS: '1234567' }, 'run', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.match(stderr, /P already holds 1,234,567 terrain cells that this world did not write, so nothing was written/);
    assert.match(stderr, /--over-terrain/);
    assert.ok(!calls.some((call) => call.startsWith('generate')), calls.join(' | '));
    assert.ok(!stdout.includes('sync'), 'it stops before spending time on sync and test');
  });
});

test('generate stops in the same way, since it writes too', () => {
  withPlan({}, (dir) => {
    const { status, calls } = inStudio(dir, { FAKE_STUDIO_CELLS: '5' }, 'generate', '0', '0', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 1);
    assert.ok(!calls.some((call) => call.startsWith('generate')), calls.join(' | '));
  });
});

test('--over-terrain writes over it', () => {
  withPlan({}, (dir) => {
    const { status, calls } = inStudio(dir, { FAKE_STUDIO_CELLS: '5' }, 'generate', '0', '0', '--place', 'P', '--project', dir, '--over-terrain');
    assert.strictEqual(status, 0);
    assert.ok(calls.some((call) => call.startsWith('generate')), calls.join(' | '));
  });
});

test('a world that has written Chunks goes on, since the terrain may be its own', () => {
  const state = 'return {\n\tgeneratorVersion = 1,\n\tchunks = {\n\t\t["0,0"] = { generated = true, locked = false },\n\t},\n}\n';
  withPlan({ state }, (dir) => {
    const { status, calls } = inStudio(dir, { FAKE_STUDIO_CELLS: '5' }, 'generate', '0', '0', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 0);
    assert.ok(calls.some((call) => call.startsWith('generate')), calls.join(' | '));
  });
});

test('a new world writes at once on a place with no terrain', () => {
  withPlan({}, (dir) => {
    const { status, calls } = inStudio(dir, { FAKE_STUDIO_CELLS: '0' }, 'generate', '0', '0', '--place', 'P', '--project', dir);
    assert.strictEqual(status, 0);
    assert.ok(calls.some((call) => call.startsWith('generate')), calls.join(' | '));
  });
});
