// A composed layout is a pure function of the seed, and its geometry can be checked without Studio.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { compose } = require('../plugins/roblox-world/engine/tools/layout.js');

const ALL = ['range', 'mesa', 'river', 'fork'];
const SEEDS = Array.from({ length: 300 }, (_, n) => 1000 + n * 7717);
const cli = path.resolve(__dirname, '../plugins/roblox-world/engine/tools/world.js');

const segment = (p, a, b) => {
  const [dx, dz] = [b[0] - a[0], b[1] - a[1]];
  const t = Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz)));
  return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz);
};
const toLine = (p, line) => Math.min(...line.slice(1).map((b, i) => segment(p, line[i], b)));
// Samples along the first line, because two lines can cross between their route points.
const sampled = (line) => line.slice(1).flatMap((b, i) => Array.from({ length: 20 }, (_, n) => [line[i][0] + ((b[0] - line[i][0]) * n) / 20, line[i][1] + ((b[1] - line[i][1]) * n) / 20]));
const between = (one, two) => Math.min(...sampled(one).map((p) => toLine(p, two)));
const footprint = (mesa) => (mesa.radius + mesa.margin) * mesa.elongate;

test('the same seed composes the same layout, and another seed a different one', () => {
  assert.deepStrictEqual(compose(555, ALL), compose(555, ALL));
  assert.notDeepStrictEqual(compose(555, ALL), compose(556, ALL));
});

test('every Landform stays on the map, and the World Plan rules hold, on 300 seeds', () => {
  for (const seed of SEEDS) {
    const { range, mesa, river, fork } = compose(seed, ALL);
    for (const p of [...range.points, ...river.points, ...fork.points, mesa.center]) {
      assert.ok(Math.abs(p[0]) <= 740 && Math.abs(p[1]) <= 740, `seed ${seed}: ${p}`);
    }
    assert.ok(range.points.length >= 4 && river.points.length >= 4 && fork.points.length >= 3, `seed ${seed}`);
    for (const line of [river, fork]) assert.strictEqual(line.waterLevel % 4, 0);
  }
});

test('a River begins and ends on the edge of the map', () => {
  for (const seed of SEEDS) {
    const { river, fork } = compose(seed, ALL);
    const onEdge = (p) => Math.abs(p[0]) === 740 || Math.abs(p[1]) === 740;
    assert.ok(onEdge(river.points[0]) && onEdge(river.points[river.points.length - 1]), `seed ${seed}`);
    assert.ok(onEdge(fork.points[fork.points.length - 1]), `seed ${seed}`);
  }
});

test('a River crosses the map, instead of cutting a corner or following an edge', () => {
  const span = (line) => Math.hypot(line[0][0] - line[line.length - 1][0], line[0][1] - line[line.length - 1][1]);
  const inland = (p) => 740 - Math.max(Math.abs(p[0]), Math.abs(p[1]));
  for (const seed of SEEDS) {
    const { river, fork } = compose(seed, ALL);
    assert.ok(span(river.points) >= 1000, `seed ${seed}: River spans ${span(river.points)}`);
    assert.ok(span(fork.points) >= 500, `seed ${seed}: fork spans ${span(fork.points)}`);
    for (const p of [...river.points.slice(1, -1), ...fork.points.slice(0, -1)]) assert.ok(inland(p) >= 120, `seed ${seed}: ${p} hugs the edge`);
  }
});

test('a fork leaves from a route point of the River, and then moves away from it', () => {
  for (const seed of SEEDS) {
    const { river, fork } = compose(seed, ALL);
    assert.ok(river.points.slice(1, -1).some((p) => p[0] === fork.points[0][0] && p[1] === fork.points[0][1]), `seed ${seed}`);
    assert.ok(between(fork.points.slice(2), river.points) >= 150, `seed ${seed}`);
  }
});

test('Landforms keep apart: the River clear of the range, the mesa clear of both', () => {
  for (const seed of SEEDS) {
    const { range, mesa, river, fork } = compose(seed, ALL);
    assert.ok(between(river.points, range.points) >= range.halfWidth, `seed ${seed}: River and range`);
    assert.ok(between(fork.points, range.points) >= range.halfWidth, `seed ${seed}: fork and range`);
    assert.ok(toLine(mesa.center, river.points) >= footprint(mesa), `seed ${seed}: mesa and River`);
    assert.ok(toLine(mesa.center, fork.points) >= footprint(mesa), `seed ${seed}: mesa and fork`);
    assert.ok(toLine(mesa.center, range.points) >= footprint(mesa), `seed ${seed}: mesa and range`);
  }
});

// The curve the engine's Route draws through a River's points: centripetal Catmull-Rom.
const mix = (a, b, u) => [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u];
const knot = (t, a, b) => t + Math.sqrt(Math.hypot(b[0] - a[0], b[1] - a[1]));
const spline = (p0, p1, p2, p3, u) => {
  const t1 = knot(0, p0, p1);
  const t2 = knot(t1, p1, p2);
  const t3 = knot(t2, p2, p3);
  const t = t1 + (t2 - t1) * u;
  const b1 = mix(mix(p0, p1, t / t1), mix(p1, p2, (t - t1) / (t2 - t1)), t / t2);
  const b2 = mix(mix(p1, p2, (t - t1) / (t2 - t1)), mix(p2, p3, (t - t2) / (t3 - t2)), (t - t1) / (t3 - t1));
  return mix(b1, b2, (t - t1) / (t2 - t1));
};
const curved = (nodes) => nodes.slice(1).flatMap((b, leg) => {
  const a = nodes[leg];
  const before = nodes[leg - 1] || [2 * a[0] - b[0], 2 * a[1] - b[1]];
  const after = nodes[leg + 2] || [2 * b[0] - a[0], 2 * b[1] - a[1]];
  return Array.from({ length: 16 }, (_, n) => spline(before, a, b, after, n / 16));
});

test('Landforms keep apart measured on the curved route, at its largest meander', () => {
  for (const seed of SEEDS) {
    const { range, mesa, river, fork } = compose(seed, ALL);
    for (const [name, line, meander] of [['River', river, 40], ['fork', fork, 30]]) {
      const route = curved(line.points);
      const toRange = Math.min(...route.map((p) => toLine(p, range.points)));
      assert.ok(toRange - meander >= range.halfWidth, `seed ${seed}: ${name} reaches the range, ${toRange}`);
      const toMesa = Math.min(...route.map((p) => Math.hypot(p[0] - mesa.center[0], p[1] - mesa.center[1])));
      assert.ok(toMesa - meander >= (mesa.radius + mesa.margin + mesa.warp) * mesa.elongate, `seed ${seed}: ${name} reaches the mesa, ${toMesa}`);
    }
  }
});

test('compositions vary: no map side or quarter takes most of the seeds', () => {
  const count = (keyOf) => {
    const tally = {};
    for (const seed of SEEDS) { const key = keyOf(compose(seed, ALL)); tally[key] = (tally[key] || 0) + 1; }
    return tally;
  };
  const middle = (points) => points[Math.floor(points.length / 2)];
  const side = (p) => (Math.abs(p[0]) > Math.abs(p[1]) ? (p[0] > 0 ? 'east' : 'west') : (p[1] > 0 ? 'south' : 'north'));
  const quarter = (p) => `${p[0] > 0 ? 'east' : 'west'}-${p[1] > 0 ? 'south' : 'north'}`;
  const spread = (tally, kinds, label) => {
    assert.strictEqual(Object.keys(tally).length, kinds, `${label}: ${JSON.stringify(tally)}`);
    for (const value of Object.values(tally)) assert.ok(value >= 300 * 0.1, `${label}: ${JSON.stringify(tally)}`);
  };
  spread(count((layout) => side(middle(layout.range.points))), 4, 'range');
  spread(count((layout) => quarter(layout.mesa.center)), 4, 'mesa');
  spread(count((layout) => side(layout.river.points[0])), 4, 'River entry');
});

test('sizes vary too', () => {
  const values = (pick) => new Set(SEEDS.map((seed) => pick(compose(seed, ALL)))).size;
  assert.ok(values((layout) => layout.range.height) > 10);
  assert.ok(values((layout) => layout.mesa.radius) > 10);
  assert.ok(values((layout) => layout.mesa.angle) > 10);
});

test('a layout holds only what was asked for, and a fork brings its River', () => {
  assert.deepStrictEqual(Object.keys(compose(1, ['mesa'])).filter((key) => ALL.includes(key)), ['mesa']);
  assert.deepStrictEqual(Object.keys(compose(1, ['fork'])).filter((key) => ALL.includes(key)).sort(), ['fork', 'river']);
});

const inTemp = (fn) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'layout-'));
  try { return fn(dir); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
};
const world = (...args) => spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', timeout: 10000 });

test('new --landforms writes a whole World Plan and records its layout', () => {
  inTemp((dir) => {
    const { status, stdout } = world('new', dir, '--place', 'P', '--seed', '555', '--landforms', 'range,mesa,fork');
    assert.strictEqual(status, 0);
    assert.ok(stdout.split('\n').length < 12, 'the output stays short');
    const plan = fs.readFileSync(path.join(dir, 'src/world/plan.luau'), 'utf8');
    assert.match(plan, /worldSeed = 555/);
    for (const id of ['range', 'mesa', 'valley', 'river', 'fork', 'forkValley']) assert.match(plan, new RegExp(`id = "${id}"`));
    assert.ok(!plan.includes('<'), 'no placeholder remains');
    assert.ok(!plan.includes('{{'), 'no placeholder remains');
    for (const field of ['materials', 'snowLine', 'base', 'floorY', 'lakes']) assert.match(plan, new RegExp(`\\b${field} =`));
    assert.match(fs.readFileSync(path.join(dir, 'docs/world/rules.md'), 'utf8'), /## Decisions[\s\S]*seed 555/);
  });
});

test('new --landforms gives each valley medium sides and banks without the fields Valley Sides replaced', () => {
  inTemp((dir) => {
    assert.strictEqual(world('new', dir, '--place', 'P', '--seed', '555', '--landforms', 'fork').status, 0);
    const plan = fs.readFileSync(path.join(dir, 'src/world/plan.luau'), 'utf8');
    assert.strictEqual(plan.match(/kind = "valley"[^\n]*sides = 0\.3 \}/g).length, 2, 'both valleys');
    for (const removed of ['shallows', 'shallowDepth', 'bedFlat', 'steep =']) assert.ok(!plan.slice(0, plan.indexOf('materials =')).includes(removed), removed);
  });
});

test('new --landforms leaves out what was not asked for', () => {
  inTemp((dir) => {
    assert.strictEqual(world('new', dir, '--place', 'P', '--landforms', 'mesa').status, 0);
    const plan = fs.readFileSync(path.join(dir, 'src/world/plan.luau'), 'utf8');
    assert.match(plan, /id = "mesa"/);
    assert.ok(!plan.includes('id = "range"') && !plan.includes('id = "river"'));
  });
});

test('new refuses a Landform it cannot compose, and names those it can', () => {
  inTemp((dir) => {
    const { status, stderr } = world('new', dir, '--place', 'P', '--landforms', 'range,volcano');
    assert.notStrictEqual(status, 0);
    assert.match(stderr, /volcano/);
    assert.match(stderr, /range, mesa, river, fork/);
    assert.ok(!fs.existsSync(path.join(dir, 'docs/world/rules.md')), 'nothing was started');
  });
});

test('a composed world has Rivers that curve', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'layout-curve-'));
  try {
    spawnSync(process.execPath, [cli, 'new', dir, '--place', 'P', '--seed', '42', '--landforms', 'river,fork'], { encoding: 'utf8' });
    const plan = fs.readFileSync(path.join(dir, 'src/world/plan.luau'), 'utf8');
    assert.deepStrictEqual(plan.match(/curve = 1, meander = \d+/g), ['curve = 1, meander = 40', 'curve = 1, meander = 30']);
    assert.strictEqual((plan.match(/bendWiden = 0\.5/g) || []).length, 2, 'both Rivers open their bends');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
