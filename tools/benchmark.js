#!/usr/bin/env node
// Measures the plugin at three prices, and keeps every result so that a change can be compared
// with the run before it. See docs/benchmark.md.
//
//   node tools/benchmark.js cost                               Free: what the plugin adds to context
//   node tools/benchmark.js engine --place <name>              No tokens, needs Studio: time per engine step
//   node tools/benchmark.js agent <scenario|all> [--place <name>] [--model sonnet] [--budget 2] [--runs 1]
//                                                              Spends tokens: a real agent run, graded
//   node tools/benchmark.js report                             Latest result of each kind, against the one before
//
// `engine` and the scenarios marked `studio` overwrite the terrain of --place, so use a disposable place.
const { spawnSync } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { measure } = require('./measure-run.js');

const ROOT = path.resolve(__dirname, '..');
const PLUGIN = path.join(ROOT, 'plugins/roblox-world');
const WORLD = path.join(PLUGIN, 'engine/tools/world.js');
const RESULTS = path.join(ROOT, 'benchmarks/results.jsonl');
const MEMORY = path.join(os.homedir(), '.claude/agent-memory/roblox-world-world/MEMORY.md');
const AGENT_MEASURES = ['durationMin', 'output', 'cacheRead', 'contextEnd', 'toolCalls', 'errors', 'captures', 'costUsd'];
const COST_MEASURES = ['alwaysOn', 'onInvoke', 'memoryBytes'];

// Every way a run fell short of what its scenario expects. An empty list means it passed.
function grade(run, expect, produced = {}) {
  const failures = [];
  const limit = (label, value, max) => { if (max !== undefined && value > max) failures.push(`${label} ${value}, limit ${max}`); };
  for (const skill of expect.skills || []) if (!run.skills[skill]) failures.push(`skill ${skill} did not load`);
  for (const command of expect.commands || []) if (!run.commands[command]) failures.push(`command ${command} did not run`);
  for (const command of expect.absentCommands || []) if (run.commands[command]) failures.push(`command ${command} ran and should not have`);
  limit('tool calls', run.toolCalls, expect.maxToolCalls);
  limit('errors', run.errors, expect.maxErrors);
  limit('captures', run.captures, expect.maxCaptures);
  for (const word of expect.answer || []) {
    if (!String(produced.answer || '').toLowerCase().includes(word.toLowerCase())) failures.push(`answer does not mention ${word}`);
  }
  for (const [file, text] of Object.entries(expect.files || {})) {
    if (!produced.readFile(file).includes(text)) failures.push(`${file} does not hold "${text}"`);
  }
  for (const [file, text] of Object.entries(expect.absentFiles || {})) {
    if (produced.readFile(file).includes(text)) failures.push(`${file} still holds "${text}"`);
  }
  return failures;
}

function parseCost(text) {
  const tokens = (value) => (value.endsWith('k') ? Math.round(parseFloat(value) * 1000) : Number(value));
  const components = {};
  for (const [, name, alwaysOn, onInvoke] of text.matchAll(/^ {2}([\w-]+) +~([\d.]+k?) +~([\d.]+k?)$/gm)) {
    components[name] = { alwaysOn: tokens(alwaysOn), onInvoke: tokens(onInvoke) };
  }
  return {
    alwaysOn: Number((text.match(/Always-on: +~(\d+)/) || [])[1]),
    onInvoke: Object.values(components).reduce((sum, component) => sum + component.onInvoke, 0),
    components,
  };
}

function parseEngine(text) {
  const steps = {};
  for (const [, name, seconds] of text.matchAll(/^([a-z]+) \(([\d.]+) s\):/gm)) steps[name] = Number(seconds);
  return { steps, totalSec: Number((text.match(/^Total ([\d.]+) s/m) || [])[1]) };
}

function compare(before, now, measures) {
  return measures.map((name) => {
    const value = now[name];
    if (!before || before[name] === undefined) return `${name} ${value} (first run)`;
    const delta = value - before[name];
    if (delta === 0) return `${name} ${before[name]} -> ${value} (same)`;
    const change = before[name] === 0 ? `${delta > 0 ? '+' : ''}${delta}` : `${delta > 0 ? '+' : ''}${Math.round((delta / before[name]) * 100)}%`;
    return `${name} ${before[name]} -> ${value} (${change})`;
  });
}

function readResults() {
  if (!fs.existsSync(RESULTS)) return [];
  return fs.readFileSync(RESULTS, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
}

// Appends a result, stamped with what was measured, and returns the previous result of the same name.
function record(name, result) {
  const previous = readResults().filter((row) => row.name === name).pop() || null;
  const git = (args) => spawnSync('git', args, { cwd: ROOT, encoding: 'utf8' }).stdout.trim();
  const row = {
    name,
    date: new Date().toISOString(),
    commit: git(['rev-parse', '--short', 'HEAD']),
    uncommitted: git(['status', '--porcelain', '--', '.', ':!benchmarks/results.jsonl']) !== '',
    claudeVersion: spawnSync('claude --version', { shell: true, encoding: 'utf8' }).stdout.trim(),
    version: JSON.parse(fs.readFileSync(path.join(PLUGIN, '.claude-plugin/plugin.json'), 'utf8')).version,
    ...result,
  };
  fs.appendFileSync(RESULTS, `${JSON.stringify(row)}\n`);
  return previous;
}

function memoryBytes() {
  return fs.existsSync(MEMORY) ? fs.statSync(MEMORY).size : 0;
}

function runWorld(...args) {
  const run = spawnSync(process.execPath, [WORLD, ...args], { encoding: 'utf8', timeout: 600000 });
  if (run.status !== 0) throw new Error(`world.js ${args.join(' ')} failed:\n${run.stdout}${run.stderr}`);
  return run.stdout;
}

function tempWorld() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'roblox-benchmark-'));
}

function benchCost() {
  const details = spawnSync(`claude --plugin-dir "${PLUGIN}" plugin details roblox-world`, { shell: true, encoding: 'utf8' });
  if (details.status !== 0) throw new Error(`claude plugin details failed:\n${details.stdout}${details.stderr}`);
  const result = { ...parseCost(details.stdout), memoryBytes: memoryBytes() };
  const previous = record('cost', result);
  console.log(compare(previous, result, COST_MEASURES).join('\n'));
  for (const [name, part] of Object.entries(result.components)) console.log(`  ${name.padEnd(22)} always-on ${String(part.alwaysOn).padStart(4)}  on-invoke ${String(part.onInvoke).padStart(5)}`);
}

function benchEngine(place) {
  const dir = tempWorld();
  try {
    runWorld('new', dir, '--place', place, '--seed', '12345');
    const result = parseEngine(runWorld('run', '--place', place, '--project', dir));
    const previous = record('engine', result);
    console.log(compare(previous, result, ['totalSec']).join('\n'));
    for (const [step, seconds] of Object.entries(result.steps)) console.log(`  ${step.padEnd(12)} ${seconds} s`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function setUp(kind, dir, place) {
  if (kind === 'empty') return;
  runWorld('new', dir, '--place', place || 'NoPlace', '--seed', '12345');
  if (kind === 'world-with-history') fs.copyFileSync(path.join(ROOT, 'benchmarks/history-fixture.md'), path.join(dir, 'docs/world/history.md'));
  if (kind === 'generated-world') runWorld('run', '--place', place, '--project', dir);
}

function findTranscript(session) {
  const projects = path.join(os.homedir(), '.claude/projects');
  for (const folder of fs.readdirSync(projects)) {
    const file = path.join(projects, folder, `${session}.jsonl`);
    if (fs.existsSync(file)) return file;
  }
  throw new Error(`No transcript found for session ${session}`);
}

function benchAgent(name, scenario, flags) {
  const place = flags.place;
  if (scenario.studio && !place) throw new Error(`${name} writes terrain, so it needs --place <a disposable place>`);
  const fill = (text) => text.split('{place}').join(place);
  const dir = tempWorld();
  try {
    setUp(scenario.setup, dir, place);
    const session = crypto.randomUUID();
    const model = flags.model || 'sonnet';
    // The agent runs alone: only the project's settings, so the developer's other plugins cost it nothing.
    const claude = `claude -p --plugin-dir "${PLUGIN}" --agent roblox-world:world --model ${model} --session-id ${session}`
      + ` --setting-sources project --strict-mcp-config --permission-mode bypassPermissions --max-budget-usd ${flags.budget || 2} --output-format json`;
    const started = spawnSync(claude, { cwd: dir, shell: true, encoding: 'utf8', input: fill(scenario.prompt), timeout: 900000 });
    let output = {};
    try { output = JSON.parse(started.stdout); } catch { output = { result: started.stdout }; }
    const run = measure(findTranscript(session));
    const readFile = (file) => { try { return fs.readFileSync(path.join(dir, file), 'utf8'); } catch { return ''; } };
    const expect = JSON.parse(fill(JSON.stringify(scenario.expect)));
    const failures = grade(run, expect, { answer: output.result, readFile });
    if (started.status !== 0) failures.unshift(`claude exited with ${started.status}`);
    const result = {
      model,
      passed: failures.length === 0,
      failures,
      session,
      memoryBytes: memoryBytes(),
      costUsd: output.total_cost_usd,
      ...Object.fromEntries(AGENT_MEASURES.filter((key) => key !== 'costUsd').map((key) => [key, run[key]])),
      skills: run.skills,
      commands: run.commands,
    };
    const previous = record(`agent:${name}`, result);
    console.log(`\n${name}: ${result.passed ? 'PASSED' : 'FAILED'} on ${model}`);
    for (const failure of failures) console.log(`  - ${failure}`);
    console.log(compare(previous, result, AGENT_MEASURES).map((line) => `  ${line}`).join('\n'));
    console.log(`  skills ${JSON.stringify(run.skills)}  commands ${JSON.stringify(run.commands)}`);
    return result.passed;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function report() {
  const rows = readResults();
  const names = [...new Set(rows.map((row) => row.name))];
  if (!names.length) console.log('No results yet.');
  for (const name of names) {
    const same = rows.filter((row) => row.name === name);
    const now = same[same.length - 1];
    const before = same[same.length - 2] || null;
    const measures = name === 'cost' ? COST_MEASURES : name === 'engine' ? ['totalSec'] : AGENT_MEASURES;
    const state = now.passed === undefined ? '' : now.passed ? ' PASSED' : ` FAILED: ${now.failures.join('; ')}`;
    console.log(`\n${name} at ${now.commit}${now.uncommitted ? '+' : ''}, plugin ${now.version}, ${now.date.slice(0, 10)}${state}`);
    console.log(compare(before, now, measures).map((line) => `  ${line}`).join('\n'));
  }
}

function main() {
  const argv = process.argv.slice(2);
  const flags = {};
  const positional = [];
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i].startsWith('--')) { flags[argv[i].slice(2)] = argv[i + 1]; i += 1; } else positional.push(argv[i]);
  }
  const [command, target] = positional;
  if (command === 'cost') return benchCost();
  if (command === 'report') return report();
  if (command === 'engine') {
    if (!flags.place) throw new Error('engine writes terrain, so it needs --place <a disposable place>');
    return benchEngine(flags.place);
  }
  if (command === 'agent') {
    const scenarios = JSON.parse(fs.readFileSync(path.join(ROOT, 'benchmarks/scenarios.json'), 'utf8'));
    const names = target === 'all' ? Object.keys(scenarios) : [target];
    let allPassed = true;
    for (const name of names) {
      if (!scenarios[name]) throw new Error(`Unknown scenario "${name}". Scenarios: ${Object.keys(scenarios).join(', ')}`);
      for (let n = 0; n < Number(flags.runs || 1); n += 1) allPassed = benchAgent(name, scenarios[name], flags) && allPassed;
    }
    process.exitCode = allPassed ? 0 : 1;
    return undefined;
  }
  console.error('Usage: node tools/benchmark.js <cost|engine --place <name>|agent <scenario|all> [--place <name>] [--model sonnet] [--budget 2] [--runs 1]|report>');
  process.exitCode = 2;
  return undefined;
}

if (require.main === module) {
  try { main(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}

module.exports = { grade, parseCost, parseEngine, compare };
