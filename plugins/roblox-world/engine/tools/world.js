#!/usr/bin/env node
// Runs the Generator in Studio from one command, talking to Studio's MCP server directly, so
// the model neither pastes modules nor writes Luau. A world is a project folder holding only
// its World Plan and generation state; the engine stays in this repository.
//
// Prints one line per fact. Exits 1 when a check fails, and writes nothing to a place whose
// name differs from --place.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const HELP = `Runs the Generator in Studio. Every command except help takes --place <name>, and all that
touch a world take --project <dir>. Exits 1 when a check fails.

Create and write terrain
  new <dir> [--seed <n>]          Start a world from the template
  run [--remove-baseplate]        Whole cycle: load, test, describe, generate every Chunk, borders, regenerate
  generate [<i> <j> ...]          Write only the Chunks a change touched. With none listed, writes every Chunk
  regenerate <i> <j>              Rewrite one Chunk and prove the result is identical

Inspect, writing no terrain
  check                           Debug start: load, test, describe, borders
  load                            Paste into Studio only the modules that differ
  test                            Run the engine's tests
  describe                        What exists, which Chunks each thing touches, which are Locked
  borders                         Compare the voxels on both sides of every Chunk border
  height <x> <z>                  Surface height at one spot

Look, only on request or when the developer is away: these move their camera
  capture [<view> ...]            Save chosen views, or all of them, to docs/captures/run/
  shot <name> <x y z> <x y z>     Save one view from a camera position towards a target
  refresh                         Press Play then Stop, which rebuilds the render

Delete
  wipe [--confirm <name>] [--include-locked]   Alone, only prints what would be lost. Confirmed, deletes ALL terrain

Help
  help                            This list
`;

const ENGINE = path.resolve(__dirname, '..');
const PLAN = 'src/world/plan';
const STATE = 'src/world/state';
const OPS = 'shared.World.require("src/world/studio/Ops")';
const BLANK_CAPTURE_CHARS = 15000; // Blank captures measured about 7,400 base64 characters, real ones over 79,000.
// The render has settled when two captures in a row differ in size by this fraction or less. A
// settled view measured under 1% of variation, and a half-built one 18% to 70%. Some settled far
// views jump about 6% between two sizes, so tries are capped and an unsettled view is only reported.
const SETTLE_TOLERANCE = 0.02;
const SETTLE_PAUSE_MS = 2000;
const SETTLE_TRIES = 5;

async function oneCapture(studio, id, camera, look) {
  const result = await studio.tool('screen_capture', { capture_id: id, camera_position: camera, look_at_position: look });
  const image = result.content.find((c) => c.type === 'image');
  if (!image) throw new Error(`No image for ${id}`);
  return image;
}

// Repeats a capture until its size stops changing, and returns the last image with the tries used.
async function settledCapture(studio, id, camera, look) {
  let previous = null;
  for (let tries = 1; ; tries += 1) {
    const image = await oneCapture(studio, id, camera, look);
    const size = image.data.length;
    const settled = previous !== null && Math.abs(size - previous) <= SETTLE_TOLERANCE * Math.max(size, previous);
    if (settled || tries === SETTLE_TRIES) return { data: image.data, tries, settled };
    previous = size;
    await new Promise((resolve) => { setTimeout(resolve, SETTLE_PAUSE_MS); });
  }
}

function parseArgs(argv) {
  const flags = {};
  const positional = [];
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i].startsWith('--')) {
      const name = argv[i].slice(2);
      const next = argv[i + 1];
      if (next === undefined || (next.startsWith('--'))) flags[name] = true;
      else { flags[name] = next; i += 1; }
    } else positional.push(argv[i]);
  }
  return { flags, positional };
}

class Studio {
  constructor() {
    this.pending = new Map();
    this.nextId = 1;
    this.child = spawn('cmd.exe', ['/c', 'cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat'], { stdio: ['pipe', 'pipe', 'inherit'] });
    let buffer = '';
    this.child.stdout.on('data', (data) => {
      buffer += data;
      let end;
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end).trim();
        buffer = buffer.slice(end + 1);
        let message;
        try { message = JSON.parse(line); } catch { continue; }
        const waiter = this.pending.get(message.id);
        if (waiter) { this.pending.delete(message.id); waiter(message); }
      }
    });
  }

  request(method, params) {
    const id = this.nextId;
    this.nextId += 1;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Studio did not answer ${method} within 5 minutes`)), 300000);
      this.pending.set(id, (message) => {
        clearTimeout(timer);
        if (message.error) reject(new Error(JSON.stringify(message.error)));
        else resolve(message.result);
      });
      this.child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
    });
  }

  async connect(place) {
    await this.request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'world', version: '1' } });
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`);
    const listed = JSON.parse((await this.request('tools/call', { name: 'list_roblox_studios', arguments: {} })).content[0].text);
    const match = listed.studios.filter((studio) => studio.name === place);
    if (match.length !== 1) {
      throw new Error(`Place "${place}" must be open exactly once. Open: ${listed.studios.map((s) => s.name).join(', ') || 'none'}`);
    }
    this.id = match[0].id;
  }

  async tool(name, args) {
    const result = await this.request('tools/call', { name, arguments: { studio_id: this.id, ...args } });
    if (result.isError) throw new Error(`${name}: ${(result.content || []).map((c) => c.text).join(' ').slice(0, 600)}`);
    return result;
  }

  async luau(code) {
    let result;
    try {
      result = await this.tool('execute_luau', { datamodel_type: 'Edit', code });
    } catch (error) {
      // Studio sometimes reports this right after a call, before the code ever runs.
      if (!error.message.includes('Target is not reachable')) throw error;
      await new Promise((resolve) => { setTimeout(resolve, 1000); });
      result = await this.tool('execute_luau', { datamodel_type: 'Edit', code });
    }
    return (result.content || []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');
  }

  close() {
    this.child.stdin.end();
    if (this.child.pid) spawn('taskkill', ['/PID', String(this.child.pid), '/T', '/F'], { stdio: 'ignore' });
  }
}

function readModule(file) {
  return fs.readFileSync(file, 'utf8').split('\r').join('');
}

function adler32(text) {
  let a = 1;
  let b = 0;
  for (const byte of Buffer.from(text, 'utf8')) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return b * 65536 + a;
}

function walk(root, dir) {
  return fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap((entry) => {
    const rel = `${dir}/${entry.name}`;
    if (entry.isDirectory()) return walk(root, rel);
    return entry.name.endsWith('.luau') ? [rel] : [];
  });
}

// The engine and its tests, with the project's World Plan and state over the engine's own.
function modules(project) {
  const map = new Map();
  for (const rel of [...walk(ENGINE, 'src'), ...walk(ENGINE, 'tests')]) {
    map.set(rel.replace(/\.luau$/, ''), readModule(path.join(ENGINE, rel)));
  }
  for (const mod of [PLAN, STATE]) map.set(mod, readModule(path.join(project, `${mod}.luau`)));
  return map;
}

const longString = (text) => `[=====[\n${text}]=====]`;

async function add(studio, mod, source) {
  const answer = await studio.luau(`return shared.World.add(${JSON.stringify(mod)}, ${longString(source)})`);
  const expected = `${mod} ${adler32(source)} ${Buffer.byteLength(source)}`;
  if (answer.trim() !== expected) throw new Error(`Checksum differs for ${mod}: Studio says "${answer.trim()}", expected "${expected}"`);
}

const steps = {
  async load(studio, ctx) {
    const hasLoader = await studio.luau('return tostring(shared.World ~= nil and shared.World.differs ~= nil)');
    if (hasLoader.trim() !== 'true') await studio.luau(readModule(path.join(ENGINE, 'tools/studio_loader.luau')));
    const mods = modules(ctx.project);
    const manifest = [...mods].map(([mod, source]) => `${mod} ${adler32(source)} ${Buffer.byteLength(source)}`).join('\n');
    const ask = `return table.concat(shared.World.differs(${longString(manifest)}), "\\n")`;
    const differs = (await studio.luau(ask)).split('\n').map((s) => s.trim()).filter(Boolean);
    for (const mod of differs) await add(studio, mod, mods.get(mod));
    const left = (await studio.luau(ask)).trim();
    if (left) throw new Error(`Still different after pasting: ${left}`);
    return `${mods.size} modules match, pasted ${differs.length}`;
  },

  // The tests describe the engine's own test map, so they run against its plan and state.
  async test(studio, ctx) {
    const swap = ctx.project !== ENGINE;
    if (swap) for (const mod of [PLAN, STATE]) await add(studio, mod, readModule(path.join(ENGINE, `${mod}.luau`)));
    let report;
    try {
      report = await studio.luau('local r = shared.World.require("tests/run"); return (r.failed > 0 and "FAILED\\n" or "") .. r.report');
    } finally {
      if (swap) for (const mod of [PLAN, STATE]) await add(studio, mod, readModule(path.join(ctx.project, `${mod}.luau`)));
    }
    const lines = report.split('\n');
    if (lines[0] === 'FAILED') { ctx.failed = true; return lines.filter((l) => !l.startsWith('PASS')).join('\n'); }
    return lines[lines.length - 1];
  },

  async describe(studio, ctx) {
    const text = await studio.luau(`return ${OPS}.describe()`);
    if (text.startsWith('INVALID PLAN')) ctx.failed = true;
    return `\n${text}`;
  },

  async generate(studio, ctx, args) {
    const remove = ctx.flags['remove-baseplate'] === true;
    const pairs = [];
    for (let n = 0; n + 1 < args.length; n += 2) pairs.push(`{ ${Number(args[n])}, ${Number(args[n + 1])} }`);
    const list = pairs.length ? `{ ${pairs.join(', ')} }` : 'nil';
    const text = await studio.luau(`local O = ${OPS}; local g = O.generate(${list}); return g .. "\\n" .. O.placeSpawn(${remove})`);
    if (ctx.project !== ENGINE) {
      const source = await studio.luau(`return ${OPS}.stateSource()`);
      fs.writeFileSync(path.join(ctx.project, `${STATE}.luau`), `${source.trim()}\n`);
    }
    return text;
  },

  async borders(studio, ctx) {
    const text = await studio.luau(`return ${OPS}.borders()`);
    if (!text.includes('disagreeing: none')) ctx.failed = true;
    return text;
  },

  async regenerate(studio, ctx, args) {
    const [i, j] = args.length === 2 ? args.map(Number) : [0, 0];
    const text = await studio.luau(`return ${OPS}.regenerate(${i}, ${j})`);
    if (!text.includes('identical=true') || !text.includes('checksum=true')) ctx.failed = true;
    return text;
  },

  async height(studio, ctx, args) {
    const [x, z] = args.map(Number);
    return studio.luau(`return ${OPS}.height(${x}, ${z})`);
  },

  // Deletes all terrain in the place. Without --confirm it writes nothing and prints the warning
  // the agent must show the developer. It needs a project, because that holds the Locked Chunks.
  async wipe(studio, ctx) {
    const place = ctx.flags.place;
    if (typeof ctx.flags.project !== 'string') throw new Error('wipe needs --project, which says which Chunks are Locked');
    const facts = JSON.parse(await studio.luau(`return ${OPS}.wipeFacts()`));
    const locked = facts.locked.length ? facts.locked.join(' ') : 'none';
    const includeLocked = ctx.flags['include-locked'] === true;
    const lockedBlocks = facts.locked.length > 0 && !includeLocked;
    if (ctx.flags.confirm !== place) {
      return [
        '',
        '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
        `!!! WARNING: ABOUT TO DELETE ALL TERRAIN IN "${place}" !!!`,
        '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
        'NOTHING HAS BEEN DELETED YET.',
        `TERRAIN CELLS THAT WOULD BE LOST: ${facts.cells}`,
        `CHUNKS RECORDED AS GENERATED: ${facts.generated}`,
        `LOCKED (HAND-EDITED) CHUNKS: ${locked}`,
        'HAND EDITS ARE LOST FOR GOOD: THE GENERATOR CANNOT REBUILD THEM.',
        'GENERATED TERRAIN COMES BACK ONLY BY GENERATING IT AGAIN FROM THE WORLD PLAN.',
        lockedBlocks ? 'LOCKED CHUNKS BLOCK THIS WIPE UNLESS THE DEVELOPER ALSO ORDERS --include-locked.' : '',
        `THE DEVELOPER MUST CONFIRM. ONLY THEN RUN: wipe --place "${place}" --project <dir> --confirm "${place}"`,
      ].filter(Boolean).join('\n');
    }
    if (lockedBlocks) {
      ctx.failed = true;
      return `REFUSED: Locked Chunks would be lost: ${locked}. Nothing was deleted`;
    }
    const answer = JSON.parse(await studio.luau(`return ${OPS}.wipe()`));
    fs.writeFileSync(path.join(ctx.project, `${STATE}.luau`), `${(await studio.luau(`return ${OPS}.stateSource()`)).trim()}\n`);
    if (answer.cellsAfter !== 0) {
      ctx.failed = true;
      return `WIPE INCOMPLETE: ${answer.cellsAfter} cells remain`;
    }
    return `DELETED all terrain in "${place}": ${facts.cells} cells to 0, in ${answer.seconds.toFixed(2)} s. Generation state emptied. The saved file keeps its old terrain until the developer saves`;
  },

  // One view chosen by hand, for what the capture set does not cover.
  async shot(studio, ctx, args) {
    const [name, ...numbers] = args;
    const image = await settledCapture(studio, `world_${name}`, numbers.slice(0, 3).map(Number), numbers.slice(3, 6).map(Number));
    if (image.data.length < BLANK_CAPTURE_CHARS) { ctx.failed = true; return 'BLANK capture. The Studio window is probably minimized'; }
    const dir = path.join(ctx.project, 'docs/captures/run');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, `${name}.jpg`), Buffer.from(image.data, 'base64'));
    return `${path.join(dir, `${name}.jpg`)}${image.settled ? '' : ' (not settled)'}`;
  },

  // Rebuilds the render without changing the map, for a hole whose voxels are correct.
  async refresh(studio) {
    await studio.tool('start_stop_play', { is_start: true });
    await studio.tool('start_stop_play', { is_start: false });
    return 'Play then Stop done';
  },

  // Views come from the World Plan, so a new map needs no camera positions. Each capture moves the
  // developer's camera, so only the first repeats until the render settles, and the rest are taken once.
  async capture(studio, ctx, args) {
    const all = JSON.parse(await studio.luau(`return ${OPS}.views()`));
    const views = args.length ? all.filter((view) => args.includes(view.name)) : all;
    if (args.length && views.length !== args.length) throw new Error(`Unknown view. Views: ${all.map((v) => v.name).join(' ')}`);
    const dir = path.join(ctx.project, 'docs/captures/run');
    fs.mkdirSync(dir, { recursive: true });
    const saved = [];
    const unsettled = [];
    for (let n = 0; n < views.length; n += 1) {
      const view = views[n];
      const image = n === 0
        ? await settledCapture(studio, `world_${view.name}`, view.camera, view.look)
        : await oneCapture(studio, `world_${view.name}`, view.camera, view.look);
      if (n === 0 && !image.settled) unsettled.push(view.name);
      if (image.data.length < BLANK_CAPTURE_CHARS) {
        ctx.failed = true;
        return `BLANK capture at ${view.name}. The Studio window is probably minimized: ask the developer to restore it, then run the capture step`;
      }
      const name = `${String(all.indexOf(view) + 1).padStart(2, '0')}-${view.name}.jpg`;
      fs.writeFileSync(path.join(dir, name), Buffer.from(image.data, 'base64'));
      saved.push(name);
    }
    const note = unsettled.length ? `. Not settled, look at these first: ${unsettled.join(' ')}` : '';
    return `${saved.length} views in ${dir}: ${saved.join(' ')}${note}`;
  },
};

function newWorld(dir, flags) {
  if (!dir || typeof flags.place !== 'string') throw new Error('Usage: world.js new <dir> --place <name> [--seed <n>]');
  const project = path.resolve(dir);
  for (const rel of [`${PLAN}.luau`, 'docs/world/rules.md']) {
    if (fs.existsSync(path.join(project, rel))) throw new Error(`${rel} already exists in ${project}`);
  }
  const seed = flags.seed === undefined ? Math.floor(Math.random() * 1e9) : Number(flags.seed);
  const plan = readModule(path.join(ENGINE, `${PLAN}.luau`)).replace(/worldSeed = \d+/, `worldSeed = ${seed}`);
  fs.mkdirSync(path.join(project, 'src/world'), { recursive: true });
  fs.mkdirSync(path.join(project, 'docs/world'), { recursive: true });
  fs.writeFileSync(path.join(project, `${PLAN}.luau`), plan);
  fs.writeFileSync(path.join(project, `${STATE}.luau`), 'return {\n\tgeneratorVersion = 1,\n\tchunks = {},\n}\n');
    fs.writeFileSync(path.join(project, 'docs/world/rules.md'), `# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | ${flags.place} |
| World Seed | ${seed} |

## Generator

The engine ships with the \`roblox-world\` plugin. This project holds only \`src/world/plan.luau\` and \`src/world/state.luau\`.

\`node <engine>/tools/world.js run --place ${flags.place} --project .\` loads the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run \`generate <i> <j> ...\` for the Chunks it touched instead. \`node <engine>/tools/world.js help\` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.
`);
  return `World started in ${project}, seed ${seed}. Edit src/world/plan.luau, which is the engine's test map with comments as a template`;
}

async function main() {
  const { flags, positional } = parseArgs(process.argv.slice(2));
  const [command, ...args] = positional;
  if (!command || command === 'help') { console.log(HELP); return 0; }
  if (command === 'new') { console.log(newWorld(args[0], flags)); return 0; }
  const cycles = {
    run: ['load', 'test', 'describe', 'generate', 'borders', 'regenerate'],
    check: ['load', 'test', 'describe', 'borders'],
  };
  if (!cycles[command] && !steps[command]) {
    console.error(`Unknown command "${command}". Run: node world.js help`);
    return 2;
  }
  if (typeof flags.place !== 'string') {
    console.error(`${command} needs --place <name>. Run: node world.js help`);
    return 2;
  }
  const order = cycles[command] || ['load', command];
  const ctx = { flags, project: path.resolve(typeof flags.project === 'string' ? flags.project : ENGINE), failed: false };
  const studio = new Studio();
  try {
    await studio.connect(flags.place);
    const started = Date.now();
    for (const name of [...new Set(order)]) {
      if (ctx.failed && ['generate', 'borders', 'regenerate', 'capture'].includes(name)) {
        console.log(`${name}: skipped after a failure`);
      } else {
        const t0 = Date.now();
        const text = await steps[name](studio, ctx, name === command ? args : []);
        console.log(`${name} (${((Date.now() - t0) / 1000).toFixed(1)} s): ${text}`);
      }
    }
    console.log(`Total ${((Date.now() - started) / 1000).toFixed(1)} s`);
  } finally {
    studio.close();
  }
  return ctx.failed ? 1 : 0;
}

main().then((code) => { process.exitCode = code; }, (error) => { console.error(error.message); process.exitCode = 1; });
