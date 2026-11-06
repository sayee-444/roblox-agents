#!/usr/bin/env node
// Runs the Generator in Studio from one command, talking to Studio's MCP server directly, so
// the model neither pastes modules nor writes Luau. A world is a project folder holding only
// its World Plan and generation state; the engine stays in this repository.
//
//   node tools/world.js new <dir> --place <name> [--seed <n>]    Start a world from the template
//   node tools/world.js run --place <name> [--project <dir>]     load, test, describe, generate,
//        [--remove-baseplate] [--wait <s>]                       borders, regenerate, capture
//   node tools/world.js <step> --place <name> [--project <dir>]  One step of the above: load,
//        test, describe, generate, borders, capture, regenerate <i> <j>, height <x> <z>
//
// Prints one line per fact. Exits 1 when a check fails, and writes nothing to a place whose
// name differs from --place.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const ENGINE = path.resolve(__dirname, '..');
const PLAN = 'src/world/plan';
const STATE = 'src/world/state';
const OPS = 'shared.World.require("src/world/studio/Ops")';
const BLANK_CAPTURE_CHARS = 15000; // Blank captures measured about 7,400 base64 characters, real ones over 79,000.

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

  async generate(studio, ctx) {
    const remove = ctx.flags['remove-baseplate'] === true;
    const text = await studio.luau(`local O = ${OPS}; local g = O.generate(); return g .. "\\n" .. O.placeSpawn(${remove})`);
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

  // Views come from the World Plan, so a new map needs no camera positions.
  async capture(studio, ctx) {
    const wait = ctx.flags.wait === undefined ? 45 : Number(ctx.flags.wait);
    if (ctx.wrote && wait > 0) await new Promise((resolve) => { setTimeout(resolve, wait * 1000); });
    const views = JSON.parse(await studio.luau(`return ${OPS}.views()`));
    const dir = path.join(ctx.project, 'docs/captures/run');
    fs.mkdirSync(dir, { recursive: true });
    const saved = [];
    for (let n = 0; n < views.length; n += 1) {
      const view = views[n];
      const result = await studio.tool('screen_capture', { capture_id: `world_${view.name}`, camera_position: view.camera, look_at_position: view.look });
      const image = result.content.find((c) => c.type === 'image');
      if (!image) throw new Error(`No image for ${view.name}`);
      if (image.data.length < BLANK_CAPTURE_CHARS) {
        ctx.failed = true;
        return `BLANK capture at ${view.name}. The Studio window is probably minimized: ask the developer to restore it, then run the capture step`;
      }
      const name = `${String(n + 1).padStart(2, '0')}-${view.name}.jpg`;
      fs.writeFileSync(path.join(dir, name), Buffer.from(image.data, 'base64'));
      saved.push(name);
    }
    return `${saved.length} views in ${dir}: ${saved.join(' ')}`;
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

\`node <engine>/tools/world.js run --place ${flags.place} --project .\` loads the engine, tests it, describes the plan, generates, verifies and writes captures to \`docs/captures/run/\`. Run it with a Bash timeout of 600000 ms. Its header lists the single steps.

## Decisions

Newest first: the date, the decision and why it was made.
`);
  return `World started in ${project}, seed ${seed}. Edit src/world/plan.luau, which is the engine's test map with comments as a template`;
}

async function main() {
  const { flags, positional } = parseArgs(process.argv.slice(2));
  const [command, ...args] = positional;
  if (command === 'new') { console.log(newWorld(args[0], flags)); return 0; }
  const order = command === 'run'
    ? ['load', 'test', 'describe', 'generate', 'borders', 'regenerate', 'capture']
    : ['load', command];
  if (!command || (command !== 'run' && !steps[command]) || typeof flags.place !== 'string') {
    console.error('Usage: world.js <run|load|test|describe|generate|borders|capture|regenerate i j|height x z> --place <name> [--project <dir>]');
    return 2;
  }
  const ctx = { flags, project: path.resolve(typeof flags.project === 'string' ? flags.project : ENGINE), failed: false, wrote: false };
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
        if (name === 'generate' || name === 'regenerate') ctx.wrote = true;
      }
    }
    console.log(`Total ${((Date.now() - started) / 1000).toFixed(1)} s`);
  } finally {
    studio.close();
  }
  return ctx.failed ? 1 : 0;
}

main().then((code) => { process.exitCode = code; }, (error) => { console.error(error.message); process.exitCode = 1; });
