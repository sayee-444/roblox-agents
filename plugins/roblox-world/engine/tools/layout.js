// Composes a new world's layout from its seed: where each Landform goes and how large it is, so a
// world needs no model to place it. Pure, so one seed always gives one layout. World Plan coordinates
// stay within EDGE of the centre, and z grows towards the south.
const EDGE = 740;
const LANDFORMS = ['range', 'mesa', 'river', 'fork'];
const MAX_ATTEMPTS = 2000;

// A small seeded random number generator (mulberry32), since Math.random takes no seed.
function randomFrom(seed) {
  let state = seed >>> 0;
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    between: (low, high) => Math.round(low + next() * (high - low)),
    pick: (list) => list[Math.floor(next() * list.length)],
  };
}

const clamp = (value) => Math.max(-EDGE, Math.min(EDGE, value));
const distanceToSegment = (p, a, b) => {
  const dx = b[0] - a[0];
  const dz = b[1] - a[1];
  const t = Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz || 1)));
  return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz);
};
const distanceToLine = (p, line) => Math.min(...line.slice(1).map((b, i) => distanceToSegment(p, line[i], b)));
// Samples along a line, because two lines can cross between their route points.
const along = (line) => line.slice(1).flatMap((b, i) => {
  const a = line[i];
  return Array.from({ length: 12 }, (_, n) => [a[0] + ((b[0] - a[0]) * n) / 12, a[1] + ((b[1] - a[1]) * n) / 12]);
}).concat([line[line.length - 1]]);
const distanceBetween = (one, two) => Math.min(...along(one).map((p) => distanceToLine(p, two)));

// A line between two points, with its middle route points pushed sideways.
function wander(rng, from, to, count, sway) {
  const dx = to[0] - from[0];
  const dz = to[1] - from[1];
  const length = Math.hypot(dx, dz) || 1;
  const bend = rng.between(-sway, sway);
  return Array.from({ length: count }, (_, n) => {
    if (n === 0) return from;
    if (n === count - 1) return to;
    const t = n / (count - 1);
    const push = bend * Math.sin(t * Math.PI) + rng.between(-sway / 3, sway / 3);
    return [clamp(Math.round(from[0] + dx * t - (dz / length) * push)), clamp(Math.round(from[1] + dz * t + (dx / length) * push))];
  });
}

// A point on the map's edge: side 0 is north, then east, south and west.
function onEdge(side, offset) {
  return [[offset, -EDGE], [EDGE, offset], [offset, EDGE], [-EDGE, offset]][side];
}

// The range lies along one side of the map, or cuts across one of its corners.
function composeRange(rng) {
  const side = rng.between(0, 3);
  const depth = rng.between(380, 620);
  const length = rng.between(450, EDGE);
  const start = rng.between(-(EDGE - length), EDGE - length);
  const rotate = ([u, v]) => [[u, v], [-v, u], [-u, -v], [v, -u]][side];
  const corner = rng.pick([false, false, true]);
  const from = corner ? rotate([rng.between(-150, 250), -EDGE]) : rotate([start - length, -depth]);
  const to = corner ? rotate([EDGE, rng.between(-250, 150)]) : rotate([start + length, -depth]);
  return {
    points: wander(rng, from.map(clamp), to.map(clamp), rng.between(4, 6), 90),
    halfWidth: rng.between(140, 180),
    height: rng.between(190, 290),
    ridgeScale: rng.between(120, 180),
    crestScale: rng.between(180, 260),
    describe: `a range about ${['north', 'east', 'south', 'west'][side]}`,
  };
}

function composeRiver(rng) {
  const entry = rng.between(0, 3);
  const exit = rng.pick([0, 1, 2, 3].filter((side) => side !== entry));
  return {
    entry,
    exit,
    points: wander(rng, onEdge(entry, rng.between(-600, 600)), onEdge(exit, rng.between(-600, 600)), rng.between(5, 6), 170),
    meander: 40, // the size the developer approved
    halfWidth: rng.between(18, 24),
    bendWiden: 0.5,
    bedY: 10,
    bedRough: 3,
    waterLevel: 20,
  };
}

function composeFork(rng, river) {
  const start = rng.pick(river.points.slice(1, -1));
  const side = rng.pick([0, 1, 2, 3].filter((candidate) => candidate !== river.entry));
  return {
    points: wander(rng, start, onEdge(side, rng.between(-650, 650)), rng.between(3, 5), 110),
    meander: 30, // the size the developer approved
    halfWidth: rng.between(12, 16),
    bendWiden: 0.5,
    bedY: 10,
    bedRough: 3,
    waterLevel: 20,
  };
}

function composeMesa(rng) {
  return {
    center: [rng.between(-560, 560), rng.between(-560, 560)],
    radius: rng.between(45, 85),
    margin: rng.between(120, 170),
    levels: rng.between(4, 6),
    height: rng.between(80, 125),
    warp: rng.between(30, 45),
    elongate: rng.between(110, 145) / 100,
    angle: rng.between(0, 179),
    gully: rng.between(6, 10),
  };
}

// A River crosses the map rather than cutting a corner or following an edge. Landforms keep apart,
// so each one reads as itself and no River runs through a mountain.
function isClear({ range, mesa, river, fork }) {
  const span = (line) => Math.hypot(line[0][0] - line[line.length - 1][0], line[0][1] - line[line.length - 1][1]);
  const inland = (p) => EDGE - Math.max(Math.abs(p[0]), Math.abs(p[1]));
  if (river && (span(river.points) < 1000 || river.points.slice(1, -1).some((p) => inland(p) < 120))) return false;
  if (fork && (span(fork.points) < 500 || fork.points.slice(0, -1).some((p) => inland(p) < 120))) return false;
  const reach = mesa ? (mesa.radius + mesa.margin + mesa.warp) * mesa.elongate : 0;
  const rivers = [river, fork].filter(Boolean);
  // Distances are measured on straight legs. A curve strayed up to 21 studs from them on 500 seeds,
  // so 30 covers it, and each River's meander comes on top.
  if (range && rivers.some((line) => distanceBetween(line.points, range.points) < range.halfWidth + 30 + line.meander)) return false;
  if (mesa && rivers.some((line) => distanceToLine(mesa.center, line.points) < reach + 30 + line.meander)) return false;
  if (mesa && range && distanceToLine(mesa.center, range.points) < reach + range.halfWidth * 0.6) return false;
  if (fork && distanceBetween(fork.points.slice(2), river.points) < 150) return false;
  return true;
}

function compose(seed, landforms) {
  const unknown = landforms.filter((name) => !LANDFORMS.includes(name));
  if (unknown.length) throw new Error(`Cannot compose ${unknown.join(', ')}. new composes: ${LANDFORMS.join(', ')}. Use the template for anything else`);
  const wanted = new Set(landforms);
  const rng = randomFrom(seed);
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt += 1) {
    const layout = {};
    if (wanted.has('range')) layout.range = composeRange(rng);
    if (wanted.has('river') || wanted.has('fork')) layout.river = composeRiver(rng);
    if (wanted.has('fork')) layout.fork = composeFork(rng, layout.river);
    if (wanted.has('mesa')) layout.mesa = composeMesa(rng);
    if (isClear(layout)) return layout;
  }
  throw new Error(`Seed ${seed} found no clear layout in ${MAX_ATTEMPTS} attempts. Try another seed`);
}

const points = (line) => `{ ${line.map((p) => `{ ${p[0]}, ${p[1]} }`).join(', ')} }`;

// The regions and rivers of a World Plan, as Luau. Each Landform gets a Region Seed from regionSeed.
function renderLuau(layout, regionSeed) {
  const regions = [];
  const rivers = [];
  const { range, mesa, river, fork } = layout;
  if (range) regions.push(`{ id = "range", kind = "mountain", seed = ${regionSeed()}, points = ${points(range.points)}, halfWidth = ${range.halfWidth}, height = ${range.height}, ridgeScale = ${range.ridgeScale}, crestScale = ${range.crestScale} }`);
  if (mesa) regions.push(`{ id = "mesa", kind = "mesa", seed = ${regionSeed()}, center = { ${mesa.center[0]}, ${mesa.center[1]} }, radius = ${mesa.radius}, margin = ${mesa.margin}, levels = ${mesa.levels}, height = ${mesa.height}, warp = ${mesa.warp}, elongate = ${mesa.elongate}, angle = ${mesa.angle}, gully = ${mesa.gully} }`);
  if (river) {
    regions.push(`{ id = "valley", kind = "valley", seed = ${regionSeed()}, riverId = "river", halfWidth = 260, floorY = 24, sides = 0.3 }`);
    rivers.push(`{ id = "river", points = ${points(river.points)}, curve = 1, meander = ${river.meander}, bendWiden = ${river.bendWiden}, halfWidth = ${river.halfWidth}, bedY = ${river.bedY}, bedRough = ${river.bedRough}, depthVary = 0.5, banks = { shore = 24, rough = 2.5, vary = 0.5 }, waterLevel = ${river.waterLevel} }`);
  }
  if (fork) {
    regions.push(`{ id = "forkValley", kind = "valley", seed = ${regionSeed()}, riverId = "fork", halfWidth = 180, floorY = 24, sides = 0.3 }`);
    rivers.push(`{ id = "fork", points = ${points(fork.points)}, curve = 1, meander = ${fork.meander}, bendWiden = ${fork.bendWiden}, halfWidth = ${fork.halfWidth}, bedY = ${fork.bedY}, bedRough = ${fork.bedRough}, depthVary = 0.5, banks = { shore = 24, rough = 2.5, vary = 0.5 }, waterLevel = ${fork.waterLevel} }`);
  }
  const block = (name, items) => `\t${name} = {\n${items.map((item) => `\t\t${item},`).join('\n')}\n\t},`;
  return `${block('regions', regions)}\n\n${block('rivers', rivers)}`;
}

// One plain sentence for the project's Decisions, and for the agent's report.
function summary(layout) {
  const parts = [];
  if (layout.range) parts.push(`${layout.range.describe}, height ${layout.range.height}`);
  if (layout.mesa) parts.push(`a mesa at ${layout.mesa.center.join(', ')}, height ${layout.mesa.height}`);
  if (layout.river) parts.push(`a River from ${layout.river.points[0].join(', ')} to ${layout.river.points[layout.river.points.length - 1].join(', ')}`);
  if (layout.fork) parts.push(`a fork from ${layout.fork.points[0].join(', ')} to ${layout.fork.points[layout.fork.points.length - 1].join(', ')}`);
  return parts.join('; ');
}

module.exports = { compose, renderLuau, summary, LANDFORMS };
