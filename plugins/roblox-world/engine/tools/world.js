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
const layouts = require('./layout.js');
const plans = require('./plan-file.js');

const HELP = `Runs the Generator in Studio. Every command except help, status and scale takes --place <name>,
and all that touch a world take --project <dir>. Exits 1 when a check fails.

Where a world stands
  status [--project <dir>]        What the plan holds, which Chunks exist, the last change, and which
                                  places are open with how much terrain. Changes nothing, works with Studio closed

Create and write terrain
  new <dir> --place <name> [--seed <n>] [--landforms <list>] [--test-map]
                                  Start a world. With --landforms (range,mesa,river,fork) it composes and
                                  writes the whole World Plan. Without, it prints a template to fill in
  scale <factor> --project <dir> [--why <reason>]
                                  Rewrite the World Plan at a new size: extent, positions, lengths and heights,
                                  keeping its seeds. Writes no terrain, so run comes next
  run [--remove-baseplate]        Whole cycle: sync, test, describe, generate every Chunk, verify, heights
  generate [<i> <j> ...]          Write only the Chunks a change touched. With none listed, writes every Chunk
                                  run and generate stop when a world that has written nothing meets a place
                                  holding terrain. --over-terrain writes over it, on the developer's word
  remove <id> [--why <reason>]    Take a Landform, River or Lake out of the plan, a River with its valley, write only
                                  the generated Chunks it touched and record the exact block in the history
  verify <i> <j>                  Rewrite one Chunk and prove the result is identical

Inspect, writing no terrain
  check                           Debug start: sync, test, describe
  sync                            Paste into Studio only the modules that differ
  test                            Run the engine's tests
  describe                        What exists, which Chunks each thing touches, which are Locked
  borders [<i> <j> ...]           Compare the voxels on both sides of the borders of these Chunks, or of every Chunk. Slow, so only when the developer agrees
  height <x> <z>                  Surface height at one spot
  heights                         Surface height of each Landform and River, from the plan

Look, only on request or when the developer is away: these move their camera
  capture [<view> ...]            Save chosen views, or all of them, to docs/captures/run/
  shot <name> <x y z> <x y z>     Save one view from a camera position towards a target
  refresh                         Press Play then Stop, which rebuilds the render, and wait for it
                                  After a write, capture and shot do this first. Play runs the place's scripts,
                                  so add --no-refresh after the views for a place where that matters

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
// After a write, broken water stayed for 60 s until Play then Stop cleared it. A capture 0.4 s after Stop
// came out half blank and one at 5 s was right, so that is the wait. A capture's size cannot prove the
// render finished: it was the same with the water broken and whole.
const RENDER_WAIT_MS = Number(process.env.WORLD_RENDER_WAIT_MS || 5000);
// After a write, a view from about 1,860 studs left the water near the Lake broken for over 60 s, and
// one from about 965 studs did not, so a view farther than this asks the next look to rebuild the render.
const FAR_VIEW_STUDS = 1000;
// Studio sometimes lists no place for a few seconds while it is connected, which cost runs 20 to 40 s
// of retries by the model. An empty listing is waited out, and a listing of other places is an answer.
const LIST_TRIES = 20;
const LIST_WAIT_MS = Number(process.env.WORLD_LIST_WAIT_MS || 1000);
// status answers from the files whatever Studio does, so it waits little for it. A place comes back in
// the listing on the third or fourth try after any command, measured, so fewer tries report it closed.
const STATUS_LIST_TRIES = 6;
const STATUS_WAIT_MS = Number(process.env.WORLD_STATUS_WAIT_MS || 10000);

async function oneCapture(studio, id, camera, look) {
  const result = await studio.tool('screen_capture', { capture_id: id, camera_position: camera, look_at_position: look });
  const image = result.content.find((c) => c.type === 'image');
  if (!image) throw new Error(`No image for ${id}`);
  return image;
}

async function afterView(studio, camera, look) {
  const distance = Math.hypot(...camera.map((value, axis) => value - look[axis]));
  if (distance > FAR_VIEW_STUDS) await studio.luau(`return ${OPS}.markRenderStale()`);
}

async function rebuildRender(studio) {
  await studio.tool('start_stop_play', { is_start: true });
  await studio.tool('start_stop_play', { is_start: false });
  await new Promise((resolve) => { setTimeout(resolve, RENDER_WAIT_MS); });
}

// Before a look: a render that has not been rebuilt since a write can show what the voxels do not hold.
// Returns what to report. Play runs the place's scripts, so --no-refresh keeps a game's place out of it.
async function renderNote(studio, ctx) {
  const stale = (await studio.luau(`return tostring(${OPS}.takeRenderStale())`)).trim() === 'true';
  if (!stale) return '';
  if (ctx.flags['no-refresh'] !== undefined) return 'Render not rebuilt since a write, so glitches may show. ';
  await rebuildRender(studio);
  return 'Render rebuilt after a write. ';
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
    this.timers = new Set();
    this.nextId = 1;
    // WORLD_FAKE_STUDIO names a stand-in for Studio's server, for the tests.
    const fake = process.env.WORLD_FAKE_STUDIO;
    this.child = fake
      ? spawn(process.execPath, [fake], { stdio: ['pipe', 'pipe', 'inherit'] })
      : spawn('cmd.exe', ['/c', 'cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat'], { stdio: ['pipe', 'pipe', 'inherit'] });
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
      this.timers.add(timer);
      this.pending.set(id, (message) => {
        clearTimeout(timer);
        this.timers.delete(timer);
        if (message.error) reject(new Error(JSON.stringify(message.error)));
        else resolve(message.result);
      });
      this.child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
    });
  }

  // The places open in Studio, waiting out an empty listing up to `tries` times.
  async places(tries) {
    await this.request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'world', version: '1' } });
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`);
    let listed;
    for (let attempt = 1; attempt <= tries; attempt += 1) {
      listed = JSON.parse((await this.request('tools/call', { name: 'list_roblox_studios', arguments: {} })).content[0].text);
      if (listed.studios.length > 0) break;
      if (attempt < tries) await new Promise((resolve) => { setTimeout(resolve, LIST_WAIT_MS); });
    }
    return listed.studios;
  }

  async connect(place) {
    const studios = await this.places(LIST_TRIES);
    const match = studios.filter((studio) => studio.name === place);
    if (match.length !== 1) {
      throw new Error(`Place "${place}" must be open exactly once. Open: ${studios.map((s) => s.name).join(', ') || 'none'}`);
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
      if (!error.message.includes('Target is not reachable')) throw error;
      // The code keeps running after this error, so sending it again would run the work twice.
      throw new Error(`Studio did not answer and the code may still be running in it, so running the command now could do the work twice. Wait about 1 s for each Chunk it writes, then run it again. ${error.message.slice(0, 200)}`);
    }
    return (result.content || []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');
  }

  close() {
    for (const timer of this.timers) clearTimeout(timer);
    this.child.stdin.end();
    if (this.child.pid) spawn('taskkill', ['/PID', String(this.child.pid), '/T', '/F'], { stdio: 'ignore' });
  }
}

function readModule(file) {
  return fs.readFileSync(file, 'utf8').split('\r').join('');
}

const readIfThere = (file) => (fs.existsSync(file) ? readModule(file) : '');

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

// Chunks given as i j i j, as Luau: a list of { i, j }, or nil when none are given.
function chunkList(args) {
  const pairs = [];
  for (let n = 0; n + 1 < args.length; n += 2) pairs.push(`{ ${Number(args[n])}, ${Number(args[n + 1])} }`);
  return pairs.length ? `{ ${pairs.join(', ')} }` : 'nil';
}

const longString = (text) => `[=====[\n${text}]=====]`;

async function add(studio, mod, source) {
  const answer = await studio.luau(`return shared.World.add(${JSON.stringify(mod)}, ${longString(source)})`);
  const expected = `${mod} ${adler32(source)} ${Buffer.byteLength(source)}`;
  if (answer.trim() !== expected) throw new Error(`Checksum differs for ${mod}: Studio says "${answer.trim()}", expected "${expected}"`);
}

const steps = {
  async sync(studio, ctx) {
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
    const list = chunkList(args);
    const text = await studio.luau(`local O = ${OPS}; local g = O.generate(${list}); return g .. "\\n" .. O.placeSpawn(${remove})`);
    if (ctx.project !== ENGINE) {
      const source = await studio.luau(`return ${OPS}.stateSource()`);
      fs.writeFileSync(path.join(ctx.project, `${STATE}.luau`), `${source.trim()}\n`);
    }
    return text;
  },

  // Takes a Landform, River or Lake out of the plan, writes the Chunks it touched and records it, so that
  // no model copies its block twice. Until the new plan is known to be valid, any failure puts the old one
  // back. After that the history holds the block, so a failed write leaves only the write to repeat.
  async remove(studio, ctx, args) {
    const planFile = path.join(ctx.project, `${PLAN}.luau`);
    const before = readModule(planFile);
    const { text, taken } = plans.remove(before, args[0]);
    const ids = taken.map((block) => JSON.stringify(block.id)).join(', ');
    const { rewrite, lockedReached } = JSON.parse(await studio.luau(`return ${OPS}.impact({ removedIds = { ${ids} } })`));
    fs.writeFileSync(planFile, text);
    let described;
    try {
      await steps.sync(studio, ctx);
      described = await studio.luau(`return ${OPS}.describe()`);
    } catch (error) {
      fs.writeFileSync(planFile, before);
      throw new Error(`Nothing was removed, and the plan is as it was. ${error.message}`);
    }
    if (described.startsWith('INVALID PLAN')) {
      fs.writeFileSync(planFile, before);
      await steps.sync(studio, ctx);
      ctx.failed = true;
      return `Nothing was removed, since the plan would be invalid:\n${described}`;
    }
    const names = taken.map((block) => block.id).join(' and ');
    const lockedNote = lockedReached.length ? `\nLocked Chunks it reached, not written, so tell the developer: ${lockedReached.join(' ')}` : '';
    const record = (written, unwritten) => addHistory(ctx.project, plans.removalEntry({
      date: new Date().toISOString().slice(0, 10), why: whyOf(ctx.flags), taken, written, unwritten, locked: lockedReached,
    }));
    let result = 'No generated Chunk to write';
    if (rewrite.length) {
      const pairs = rewrite.flatMap((key) => key.split(','));
      try {
        result = await steps.generate(studio, ctx, pairs);
      } catch (error) {
        record([], rewrite);
        ctx.failed = true;
        return `Removed ${names} from the plan and recorded it, but its Chunks were not all written. ${error.message}\nTo finish, run: generate ${pairs.join(' ')} --place ${ctx.flags.place} --project ${ctx.project}${lockedNote}`;
      }
    }
    record(rewrite, []);
    return `Removed ${names}, recorded in docs/world/history.md. Chunks: ${rewrite.join(' ') || 'none'}\n${result}${lockedNote}`;
  },

  async borders(studio, ctx, args) {
    const text = await studio.luau(`return ${OPS}.borders(${chunkList(args)})`);
    if (!text.includes('disagreeing: none')) ctx.failed = true;
    return text;
  },

  async verify(studio, ctx, args) {
    const [i, j] = args.length === 2 ? args.map(Number) : [0, 0];
    const text = await studio.luau(`return ${OPS}.verify(${i}, ${j})`);
    if (!text.includes('identical=true') || !text.includes('checksum=true')) ctx.failed = true;
    return text;
  },

  async heights(studio) {
    return `\n${await studio.luau(`return ${OPS}.heights()`)}`;
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
    const note = await renderNote(studio, ctx);
    const camera = numbers.slice(0, 3).map(Number);
    const look = numbers.slice(3, 6).map(Number);
    const image = await oneCapture(studio, `world_${name}`, camera, look);
    await afterView(studio, camera, look);
    if (image.data.length < BLANK_CAPTURE_CHARS) { ctx.failed = true; return 'BLANK capture. The Studio window is probably minimized'; }
    const dir = path.join(ctx.project, 'docs/captures/run');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, `${name}.jpg`), Buffer.from(image.data, 'base64'));
    return `${note}${path.join(dir, `${name}.jpg`)}`;
  },

  // Rebuilds the render without changing the map, for a hole whose voxels are correct.
  async refresh(studio) {
    await studio.luau(`return tostring(${OPS}.takeRenderStale())`);
    await rebuildRender(studio);
    return 'Play then Stop done, and the render had time to rebuild';
  },

  // Views come from the World Plan, so a new map needs no camera positions. The overview goes last,
  // because a jump from its height left the next view broken for about 15 s.
  async capture(studio, ctx, args) {
    const all = JSON.parse(await studio.luau(`return ${OPS}.views()`));
    const views = args.length ? all.filter((view) => args.includes(view.name)) : all;
    if (args.length && views.length !== args.length) throw new Error(`Unknown view. Views: ${all.map((v) => v.name).join(' ')}`);
    const note = await renderNote(studio, ctx);
    const ordered = [...views.filter((view) => view.name !== 'overview'), ...views.filter((view) => view.name === 'overview')];
    const dir = path.join(ctx.project, 'docs/captures/run');
    fs.mkdirSync(dir, { recursive: true });
    const saved = [];
    for (const view of ordered) {
      const image = await oneCapture(studio, `world_${view.name}`, view.camera, view.look);
      await afterView(studio, view.camera, view.look);
      if (image.data.length < BLANK_CAPTURE_CHARS) {
        ctx.failed = true;
        return `BLANK capture at ${view.name}. The Studio window is probably minimized: ask the developer to restore it, then run the capture step`;
      }
      const name = `${String(all.indexOf(view) + 1).padStart(2, '0')}-${view.name}.jpg`;
      fs.writeFileSync(path.join(dir, name), Buffer.from(image.data, 'base64'));
      saved.push(name);
    }
    return `${note}${saved.length} views in ${dir}: ${saved.join(' ')}`;
  },
};

// A Region Seed for each Landform of a new world, following from its World Seed.
function regionSeeds(seed) {
  let n = 0;
  return () => { n += 1; return 10000 + ((seed * 31 + n * 7919) % 90000); };
}

function fillTemplate(seed) {
  return readModule(path.join(ENGINE, 'templates/plan.luau'))
    .split('{{worldSeed}}').join(String(seed))
    .replace(/\{\{regionSeed\}\}/g, regionSeeds(seed));
}

// A whole World Plan: the template's settings around a composed layout's regions and rivers.
function composedPlan(seed, layout) {
  const template = fillTemplate(seed);
  const start = template.indexOf('return {');
  const before = template.slice(start, template.indexOf('\t-- Landform Regions.'));
  const after = `\tlakes = {},\n${template.slice(template.indexOf('\tsites = {},'))}`;
  return `-- World Plan: declares what exists where. It wins over the seeds. Composed by new from the World Seed.\n-- Chunk (i, j) covers x in [i*512-256, i*512+256) and z in [j*512-256, j*512+256).\n\n${before}${layouts.renderLuau(layout, regionSeeds(seed))}\n${after}`;
}

const extentText = (e) => (e.minX === e.minZ && e.maxX === e.maxZ ? `${e.minX}..${e.maxX}` : `${e.minX}..${e.maxX} x ${e.minZ}..${e.maxZ}`);

// Puts an entry at the top of a world's history, creating the file when it is missing.
const whyOf = (flags) => (typeof flags.why === 'string' ? flags.why : 'the developer asked for it.');

// Decisions run newest first, under the line that says so.
function addDecision(project, decision) {
  const file = path.join(project, 'docs/world/rules.md');
  if (!fs.existsSync(file)) return;
  const text = readModule(file);
  const first = /^(Newest first:.*)\n*/m;
  fs.writeFileSync(file, first.test(text) ? text.replace(first, (_, line) => `${line}\n\n${decision}\n`) : `${text.trimEnd()}\n\n${decision}\n`);
}

function addHistory(project, entry) {
  const file = path.join(project, 'docs/world/history.md');
  const before = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${entry}${before ? `\n${before}` : ''}`);
}

// One line on the places open in Studio, read without writing anything.
async function studioLine() {
  const studio = new Studio();
  const read = async () => {
    const studios = await studio.places(STATUS_LIST_TRIES);
    if (!studios.length) return `Studio: no place open after ${(STATUS_LIST_TRIES * LIST_WAIT_MS) / 1000} s`;
    const open = [];
    for (const { id, name } of studios) {
      studio.id = id;
      const cells = Number(await studio.luau('return workspace.Terrain:CountCells()'));
      const destroy = Number(await studio.luau('return workspace.FallenPartsDestroyHeight'));
      open.push(`${name} open, ${cells.toLocaleString('en-US')} terrain cells, Destroy Height ${destroy.toLocaleString('en-US')}`);
    }
    return `Studio: ${open.join('; ')}`;
  };
  let timer;
  const late = new Promise((resolve) => { timer = setTimeout(() => resolve(`Studio: did not answer within ${STATUS_WAIT_MS / 1000} s`), STATUS_WAIT_MS); });
  try {
    return await Promise.race([read(), late]);
  } catch (error) {
    return `Studio: could not be read: ${error.message.slice(0, 200)}`;
  } finally {
    clearTimeout(timer);
    studio.close();
  }
}

// What a world holds and where it stands, from its files, so that no model reads and adds them up.
function worldLines(project) {
  const lines = [];
  const plan = readIfThere(path.join(project, `${PLAN}.luau`));
  if (plan) {
    const held = plans.facts(plan);
    const { generated, locked } = plans.stateFacts(readIfThere(path.join(project, `${STATE}.luau`)));
    const e = held.extent;
    const inExtent = generated.filter((key) => {
      const [i, j] = key.split(',').map(Number);
      return i >= e.minX && i <= e.maxX && j >= e.minZ && j <= e.maxZ;
    }).length;
    const outside = generated.length - inExtent;
    const names = (things) => things.map((thing) => thing.id).join(', ') || 'none';
    lines.push(
      `Seed ${held.seed}, extent ${extentText(e)}, ${e.maxX - e.minX + 1} x ${e.maxZ - e.minZ + 1}, ${held.chunks} Chunks`,
      `${inExtent} of ${held.chunks} Chunks generated${outside ? `, and ${outside} outside the extent` : ''}. Locked: ${locked.join(' ') || 'none'}`,
      `Regions: ${held.regions.map((region) => `${region.id} (${region.kind})`).join(', ') || 'none'}`,
      `Rivers: ${names(held.rivers)}`,
      `Lakes: ${names(held.lakes)}`,
      `Last change: ${plans.lastChange(readIfThere(path.join(project, 'docs/world/history.md'))) || 'none recorded'}`,
    );
  } else {
    lines.push(`No World Plan in ${project}`);
  }
  const rules = readIfThere(path.join(project, 'docs/world/rules.md'));
  const place = /PlaceId or window title \| *([^|\n]*?) *\|/.exec(rules);
  if (!rules) lines.push('No docs/world/rules.md');
  else if (place && place[1]) lines.push(`Development Place: ${place[1]}`);
  return lines;
}

async function status(flags) {
  const project = path.resolve(typeof flags.project === 'string' ? flags.project : '.');
  console.log([...worldLines(project), await studioLine()].join('\n'));
  return 0;
}

// Rewrites a World Plan at a new size, so that no model writes it. Writes no terrain and needs no Studio.
function scaleWorld(args, flags) {
  const factor = Number(args[0]);
  if (!(factor > 0) || typeof flags.project !== 'string') {
    console.error('Usage: world.js scale <factor above 0> --project <dir> [--why <reason>]. Run: node world.js help');
    return 2;
  }
  const project = path.resolve(flags.project);
  const planFile = path.join(project, `${PLAN}.luau`);
  if (!fs.existsSync(planFile)) {
    console.error(`No World Plan at ${planFile}`);
    return 2;
  }
  const { locked } = plans.stateFacts(readIfThere(path.join(project, `${STATE}.luau`)));
  if (locked.length) throw new Error(`Locked Chunks would no longer fit the map: ${locked.join(' ')}. Nothing was changed`);
  const scaled = plans.scale(readModule(planFile), factor);
  fs.writeFileSync(planFile, scaled.text);
  const date = new Date().toISOString().slice(0, 10);
  const change = `extent ${extentText(scaled.before)} to ${extentText(scaled.extent)}`;
  addDecision(project, `- ${date}: scaled by ${factor}, ${change}. Why: ${whyOf(flags)}`);
  addHistory(project, `## ${date}: Scaled the world by ${factor}\n\n- **Why:** ${whyOf(flags)}\n- **Chunks written:** none yet, until \`run\` writes every Chunk.\n- **Restore:** the World Plan before this entry, in Git, and generate every Chunk again.\n`);
  const side = (min, max) => max - min + 1;
  const e = scaled.extent;
  const notes = [`Scaled by ${factor}: ${change}, ${side(e.minX, e.maxX)} x ${side(e.minZ, e.maxZ)} Chunks.`];
  if (scaled.droppedComments) notes.push(`${scaled.droppedComments} comments holding a number were removed, since they described the old size.`);
  if (factor < 1) notes.push('Chunks outside the new extent keep their terrain until the developer orders a wipe.');
  notes.push('No terrain changed. To write it: run --place <name> --project <dir>');
  console.log(notes.join('\n'));
  return 0;
}

function newWorld(dir, flags) {
  if (!dir || typeof flags.place !== 'string') throw new Error('Usage: world.js new <dir> --place <name> [--seed <n>] [--test-map]');
  const project = path.resolve(dir);
  for (const rel of [`${PLAN}.luau`, 'docs/world/rules.md']) {
    if (fs.existsSync(path.join(project, rel))) throw new Error(`${rel} already exists in ${project}`);
  }
  const seed = flags.seed === undefined ? Math.floor(Math.random() * 1e9) : Number(flags.seed);
  // Composed before anything is written, so a refused Landform leaves nothing behind.
  const layout = typeof flags.landforms === 'string' ? layouts.compose(seed, flags.landforms.split(',').map((name) => name.trim())) : null;
  fs.mkdirSync(path.join(project, 'src/world'), { recursive: true });
  fs.mkdirSync(path.join(project, 'docs/world'), { recursive: true });
  if (flags['test-map'] === true) {
    fs.writeFileSync(path.join(project, `${PLAN}.luau`), readModule(path.join(ENGINE, `${PLAN}.luau`)).replace(/worldSeed = \d+/, `worldSeed = ${seed}`));
  }
  fs.writeFileSync(path.join(project, `${STATE}.luau`), 'return {\n\tgeneratorVersion = 1,\n\tchunks = {},\n}\n');
    fs.writeFileSync(path.join(project, 'docs/world/rules.md'), `# World rules

## Development Place

| Field | Value |
|---|---|
| PlaceId or window title | ${flags.place} |
| World Seed | ${seed} |

## Generator

The engine ships with the \`roblox-world\` plugin. This project holds only \`src/world/plan.luau\` and \`src/world/state.luau\`.

\`node <engine>/tools/world.js run --place ${flags.place} --project .\` syncs the engine, tests it, describes the plan, generates and verifies. Run it with a Bash timeout of 600000 ms. After a local change, run \`generate <i> <j> ...\` for the Chunks it touched instead. \`node <engine>/tools/world.js help\` lists every command.

## Decisions

Newest first: the date, the decision and why it was made.
`);
  if (flags['test-map'] === true) return `World started in ${project}, seed ${seed}, on the engine's test map`;
  if (layout) {
    fs.writeFileSync(path.join(project, `${PLAN}.luau`), composedPlan(seed, layout));
    const line = `${new Date().toISOString().slice(0, 10)}: composed by new from seed ${seed}: ${layouts.summary(layout)}.`;
    fs.appendFileSync(path.join(project, 'docs/world/rules.md'), `\n- ${line}\n`);
    return `World started in ${project}. Its plan is written. ${line}`;
  }
  return `World started in ${project}, seed ${seed}. Write src/world/plan.luau from this template, in one go:\n\n${fillTemplate(seed)}`;
}

// A world that has written nothing cannot have written what the place holds, which may be another world or a
// game's map. Checked before any step, so a refusal costs no sync and no test.
async function refuseOtherTerrain(studio, ctx) {
  if (ctx.project === ENGINE || ctx.flags['over-terrain'] !== undefined) return;
  const { generated } = plans.stateFacts(readIfThere(path.join(ctx.project, `${STATE}.luau`)));
  if (generated.length) return;
  const cells = Number(await studio.luau('return workspace.Terrain:CountCells()'));
  if (cells > 0) throw new Error(`${ctx.flags.place} already holds ${cells.toLocaleString('en-US')} terrain cells that this world did not write, so nothing was written. It may be another world or a game's map. Tell the developer, and only on their word run this again with --over-terrain, which replaces the terrain in this world's Chunks and leaves the rest.`);
}

// Roblox removes what falls below a place's Destroy Height, so a write first makes sure a character on the deepest
// bed survives. The plan's value is set in the place. With none declared, the place's own value stays, and a world
// that goes deeper writes nothing. Runs after sync, which writes no terrain, since the depths come from the plan.
async function guardDestroyHeight(studio, ctx) {
  const facts = JSON.parse(await studio.luau(`return ${OPS}.depthFacts()`));
  const place = ctx.flags.place;
  const n = (value) => Number(value).toLocaleString('en-US');
  if (facts.invalid) {
    ctx.failed = true;
    return `the World Plan is invalid, so nothing was written and the Destroy Height of ${place} stays ${n(facts.place)}:\n${facts.invalid.join('\n')}`;
  }
  if (typeof facts.destroyHeight === 'number') {
    if (facts.destroyHeight === facts.place) return `Destroy Height of ${place} is ${n(facts.place)}, as the World Plan declares`;
    const now = Number(await studio.luau(`return ${OPS}.setDestroyHeight(${facts.destroyHeight})`));
    if (now !== facts.destroyHeight) throw new Error(`Nothing was written: Studio did not take the Destroy Height ${n(facts.destroyHeight)} for ${place} and holds ${n(now)}. Ask the developer to set Workspace.FallenPartsDestroyHeight in Studio's Properties window.`);
    return `Destroy Height of ${place} set from ${n(facts.place)} to ${n(now)}, as the World Plan declares. It lasts once the developer saves the place`;
  }
  const deep = facts.deepest;
  if (!deep) return `Destroy Height of ${place} left at ${n(facts.place)}, since the World Plan declares none and nothing in it goes below the ground`;
  const where = `${n(deep.y)} in ${deep.kind} ${deep.id}`;
  if (deep.y > facts.place) return `Destroy Height of ${place} left at ${n(facts.place)}, since the World Plan declares none, and the deepest bed, ${where}, lies above it`;
  throw new Error(`Nothing was written: the deepest bed of this world, ${where}, is not above ${place}'s Destroy Height ${n(facts.place)}, below which Roblox removes what falls, so a character there would be removed. Either declare destroyHeight in the World Plan, below its Depth Limit ${n(facts.depthLimit)}, and run this again so the engine sets it in the place, or set Workspace.FallenPartsDestroyHeight in Studio's Properties window.`);
}

async function main() {
  const { flags, positional } = parseArgs(process.argv.slice(2));
  const [command, ...args] = positional;
  if (!command || command === 'help') { console.log(HELP); return 0; }
  if (command === 'new') { console.log(newWorld(args[0], flags)); return 0; }
  if (command === 'scale') return scaleWorld(args, flags);
  if (command === 'status') return status(flags);
  const cycles = {
    run: ['sync', 'test', 'describe', 'generate', 'verify', 'heights'],
    check: ['sync', 'test', 'describe'],
  };
  if (!cycles[command] && !steps[command]) {
    console.error(`Unknown command "${command}". Run: node world.js help`);
    return 2;
  }
  if (typeof flags.place !== 'string') {
    console.error(`${command} needs --place <name>. Run: node world.js help`);
    return 2;
  }
  const order = cycles[command] || ['sync', command];
  const ctx = { flags, project: path.resolve(typeof flags.project === 'string' ? flags.project : ENGINE), failed: false };
  if (!fs.existsSync(path.join(ctx.project, `${PLAN}.luau`))) {
    console.error(`No World Plan at ${path.join(ctx.project, `${PLAN}.luau`)}. Write it from the template that new printed`);
    return 2;
  }
  if (command === 'remove') {
    if (!args[0] || typeof flags.project !== 'string') {
      console.error('Usage: world.js remove <id> --place <name> --project <dir> [--why <reason>]. Run: node world.js help');
      return 2;
    }
    plans.remove(readModule(path.join(ctx.project, `${PLAN}.luau`)), args[0]); // Fails here, before reaching Studio, on a name the plan lacks.
  }
  const studio = new Studio();
  try {
    await studio.connect(flags.place);
    if (['run', 'generate'].includes(command)) await refuseOtherTerrain(studio, ctx);
    const started = Date.now();
    const guards = { 'destroy height': guardDestroyHeight };
    if (['run', 'generate'].includes(command)) order.splice(order.indexOf('sync') + 1, 0, 'destroy height');
    for (const name of [...new Set(order)]) {
      if (ctx.failed && ['generate', 'borders', 'verify', 'heights', 'capture'].includes(name)) {
        console.log(`${name}: skipped after a failure`);
      } else {
        const t0 = Date.now();
        const text = await (steps[name] || guards[name])(studio, ctx, name === command ? args : []);
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
