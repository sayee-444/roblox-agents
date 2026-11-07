// A stand-in for Studio's MCP server, so the engine's command line can be tested without Studio.
// It appends each tool call to FAKE_STUDIO_LOG, one name per line.
//   FAKE_STUDIO_STALE=true       terrain was written since the last rebuild of the render
//   FAKE_STUDIO_MISSES=<n>       the first n listings report no open place
//   FAKE_STUDIO_PLACES=<a,b>     the places open, P when not set
//   FAKE_STUDIO_SILENT=true      nothing is ever answered
//   FAKE_STUDIO_CELLS=<n>        the terrain cells a place holds
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
