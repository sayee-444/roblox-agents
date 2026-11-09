// A stand-in for Studio's MCP server, so the engine's command line can be tested without Studio.
// It appends each tool call to FAKE_STUDIO_LOG, one name per line.
//   FAKE_STUDIO_STALE=true       terrain was written since the last rebuild of the render
//   FAKE_STUDIO_MISSES=<n>       the first n listings report no open place
//   FAKE_STUDIO_PLACES=<a,b>     the places open, P when not set
//   FAKE_STUDIO_SILENT=true      nothing is ever answered
//   FAKE_STUDIO_CELLS=<n>        the terrain cells a place holds
//   FAKE_STUDIO_IMPACT=<json>    what a change to a Landform would rewrite
//   FAKE_STUDIO_INVALID=true     the plan fails validation
//   FAKE_STUDIO_UNREACHABLE=<s>  Luau holding this text fails as Studio fails when it is too busy to answer
//   FAKE_STUDIO_DESTROY=<n>      the place's Destroy Height, -500 when not set, as in a new place
//   FAKE_STUDIO_DEPTH=<json>     what depthFacts answers: the place's Destroy Height, the plan's limits and its deepest bed
//   FAKE_STUDIO_WATER=<json>     what waterFacts answers: written Chunks whose land turns into water, and which change
const fs = require('fs');
const readline = require('readline');

const log = (line) => fs.appendFileSync(process.env.FAKE_STUDIO_LOG, `${line}\n`);
const text = (value) => ({ content: [{ type: 'text', text: value }] });
const VIEWS = [
  { name: 'overview', camera: [0, 1500, 1500], look: [0, 0, 0] },
  { name: 'hills-above', camera: [0, 100, 0], look: [1, 0, 0] },
  { name: 'river-above', camera: [0, 90, 0], look: [1, 0, 0] },
];
let misses = Number(process.env.FAKE_STUDIO_MISSES || 0);

function luau(code) {
  const borders = code.match(/\.borders\((.*)\)/);
  if (borders) { log(`borders ${borders[1]}`); return 'disagreeing: none'; }
  if (code.includes('.markRenderStale()')) log('mark render stale');
  if (code.includes('shared.World.add(')) log('paste');
  const impact = code.match(/\.impact\((.*)\)/);
  if (impact) { log(`impact ${impact[1]}`); return process.env.FAKE_STUDIO_IMPACT; }
  const setHeight = code.match(/\.setDestroyHeight\((.*?)\)/);
  if (setHeight) { log(`set destroy height ${setHeight[1]}`); return setHeight[1]; }
  if (code.includes('.waterFacts()')) { log('water facts'); return process.env.FAKE_STUDIO_WATER || JSON.stringify({ flooded: [], lockedFlooded: [], changed: [], unrecorded: 0 }); }
  if (code.includes('.depthFacts()')) return process.env.FAKE_STUDIO_DEPTH || JSON.stringify({ placeHeight: -500, depthLimit: -3500, deepest: { id: 'ocean', kind: 'ocean', y: -80 } });
  if (code.includes('FallenPartsDestroyHeight')) return process.env.FAKE_STUDIO_DESTROY || '-500';
  const generate = code.match(/\.generate\((.*?)\);/);
  if (generate) {
    log(`generate ${generate[1]}`);
    const count = (generate[1].match(/\{ -?\d+, -?\d+ \}/g) || []).length;
    return JSON.stringify({ seconds: Array(count).fill(0.5), skipped: [] });
  }
  if (code.includes('.stateSource()')) return 'return {\n\tchunks = {},\n}';
  if (code.includes('.describe()')) { log('describe'); return process.env.FAKE_STUDIO_INVALID === 'true' ? 'INVALID PLAN\nregion x: unknown river' : 'extent: 9 chunks'; }
  if (code.includes('CountCells')) return process.env.FAKE_STUDIO_CELLS || '0';
  if (code.includes('shared.World ~= nil')) return 'true';
  if (code.includes('.differs(')) return '';
  if (code.includes('.views()')) return JSON.stringify(VIEWS);
  if (code.includes('.takeRenderStale()')) return process.env.FAKE_STUDIO_STALE === 'true' ? 'true' : 'false';
  return '';
}

function call(name, args) {
  log(name === 'screen_capture' ? `capture ${args.capture_id}` : name);
  if (name === 'list_roblox_studios') {
    if (misses > 0) { misses -= 1; return text(JSON.stringify({ studios: [] })); }
    return text(JSON.stringify({ studios: (process.env.FAKE_STUDIO_PLACES || 'P').split(',').map((name) => ({ id: name, name })) }));
  }
  if (name === 'execute_luau' && process.env.FAKE_STUDIO_UNREACHABLE && args.code.includes(process.env.FAKE_STUDIO_UNREACHABLE)) {
    luau(args.code);
    return { isError: true, content: [{ type: 'text', text: 'Network action ExecuteLuau.runCode sent to DMN_ID_EDIT failed - Target is not reachable' }] };
  }
  if (name === 'execute_luau') return text(luau(args.code));
  if (name === 'screen_capture') return { content: [{ type: 'image', data: 'A'.repeat(20000) }] };
  return text('');
}

readline.createInterface({ input: process.stdin }).on('line', (line) => {
  const message = JSON.parse(line);
  if (message.id === undefined || process.env.FAKE_STUDIO_SILENT === 'true') return;
  const result = message.method === 'tools/call' ? call(message.params.name, message.params.arguments) : {};
  process.stdout.write(`${JSON.stringify({ jsonrpc: '2.0', id: message.id, result })}\n`);
});
