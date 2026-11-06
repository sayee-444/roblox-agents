#!/usr/bin/env node
// Measures the plugin at three prices, and keeps every result so that a version or a technique can
// be compared with the one before it. See docs/benchmark.md.
//
//   node tools/benchmark.js cost                               Free: what the plugin adds to context
//   node tools/benchmark.js engine --place <name>              No tokens, needs Studio: time per engine step
//   node tools/benchmark.js agent <scenario|all> [--place <name>] [--label <technique>] [--runs 3]
//        [--model sonnet] [--budget 2] [--keep <dir>]          Spends tokens: a real agent run, graded
//   node tools/benchmark.js report                             Each measure's median, against the group before
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
const CLAUDE_MD = path.join(ROOT, 'CLAUDE.md');
const AGENT_MEASURES = ['contextStart', 'contextEnd', 'tokensSent', 'output', 'thinking', 'durationMin', 'toolCalls', 'errors', 'captures', 'costUsd'];
const CONTEXT_PARTS = ['agent', 'memoryRules', 'memoryFile', 'tools', 'pluginSkills', 'otherSkills', 'attachments', 'unattributed'].map((part) => `context.${part}`);
const COST_MEASURES = ['alwaysOn', 'onInvoke', 'memoryBytes', 'claudeMdBytes'];
const measuresOf = (name) => {
  if (name === 'cost') return COST_MEASURES;
  if (name === 'engine') return ['totalSec'];
  return [...AGENT_MEASURES, ...CONTEXT_PARTS];
};

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
  const shown = (value) => (Number.isInteger(value) ? value : Number(value.toFixed(3)));
  return measures.filter((name) => now[name] !== undefined).map((name) => {
    const value = now[name];
    if (!before || before[name] === undefined) return `${name} ${shown(value)} (first run)`;
    const delta = value - before[name];
    if (delta === 0) return `${name} ${shown(before[name])} -> ${shown(value)} (same)`;
    const change = before[name] === 0 ? `${delta > 0 ? '+' : ''}${shown(delta)}` : `${delta > 0 ? '+' : ''}${Math.round((delta / before[name]) * 100)}%`;
    return `${name} ${shown(before[name])} -> ${shown(value)} (${change})`;
  });
}

// Groups runs by plugin version and label, because one run says little and a version is what gets
// compared. Each group gives the median of each measure over the runs that hold it.
function groups(rows, measures) {
  const valueOf = (row, measure) => measure.split('.').reduce((value, key) => (value === undefined || value === null ? undefined : value[key]), row);
  const median = (values) => {
    const sorted = [...values].sort((a, b) => a - b);
    const middle = Math.floor(sorted.length / 2);
    return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  };
  // A Map keeps insertion order, so inserting a key again leaves the group that ran last at the end.
  const found = new Map();
  for (const row of rows) {
    const key = row.label ? `${row.version} ${row.label}` : row.version;
    const members = found.get(key) || [];
    found.delete(key);
    found.set(key, [...members, row]);
  }
  return [...found].map(([key, members]) => {
    const medians = {};
    for (const measure of measures) {
      const values = members.map((row) => valueOf(row, measure)).filter((value) => typeof value === 'number');
      if (values.length) medians[measure] = median(values);
    }
    return { key, runs: members.length, passed: members.filter((row) => row.passed).length, medians };
  });
}

// The group the newest one is judged against: the latest plain version before it, because a label
// marks a technique that was only tried and may never have shipped.
function baseline(all) {
  return all.slice(0, -1).reverse().find((group) => !group.key.includes(' '));
}

// Prints the newest group of one kind of result against its baseline.
function showComparison(name) {
  const rows = readResults().filter((row) => row.name === name);
  const measures = measuresOf(name);
  const all = groups(rows, measures);
  const now = all[all.length - 1];
  const before = baseline(all);
  const graded = rows.some((row) => row.passed !== undefined);
  const describe = (group) => `${group.key}, ${group.runs} run${group.runs === 1 ? '' : 's'}${graded ? `, ${group.passed} passed` : ''}`;
  console.log(`\n${name}: ${describe(now)}${before ? `, against ${describe(before)}` : ''}`);
  console.log(compare(before ? before.medians : null, now.medians, measures).map((line) => `  ${line}`).join('\n'));
  const failures = [...new Set(rows.filter((row) => (row.label ? `${row.version} ${row.label}` : row.version) === now.key).flatMap((row) => row.failures || []))];
  for (const failure of failures) console.log(`  failed: ${failure}`);
}

function readResults() {
  if (!fs.existsSync(RESULTS)) return [];
  return fs.readFileSync(RESULTS, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line));
}

// Appends a result, stamped with what was measured.
function record(name, result) {
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
  const result = { ...parseCost(details.stdout), memoryBytes: memoryBytes(), claudeMdBytes: fs.statSync(CLAUDE_MD).size };
  record('cost', result);
  showComparison('cost');
  for (const [name, part] of Object.entries(result.components)) console.log(`  ${name.padEnd(22)} always-on ${String(part.alwaysOn).padStart(4)}  on-invoke ${String(part.onInvoke).padStart(5)}`);
}

function benchEngine(place) {
  const dir = tempWorld();
  try {
    runWorld('new', dir, '--place', place, '--seed', '12345');
    const result = parseEngine(runWorld('run', '--place', place, '--project', dir));
    record('engine', result);
    showComparison('engine');
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
      label: flags.label,
      passed: failures.length === 0,
      failures,
      session,
      memoryBytes: memoryBytes(),
      costUsd: output.total_cost_usd,
      ...Object.fromEntries(AGENT_MEASURES.filter((key) => key !== 'costUsd').map((key) => [key, run[key]])),
      context: run.context,
      startTools: run.startTools,
      growth: run.growth,
      skills: run.skills,
      commands: run.commands,
    };
    record(`agent:${name}`, result);
    console.log(`${name}: ${result.passed ? 'PASSED' : 'FAILED'} | context ${run.contextStart} to ${run.contextEnd} | sent ${run.tokensSent} | output ${run.output} | ${run.toolCalls} tool calls | $${Number(output.total_cost_usd || 0).toFixed(3)}`);
    console.log(`  skills ${JSON.stringify(run.skills)}  commands ${JSON.stringify(run.commands)}`);
    for (const failure of failures) console.log(`  failed: ${failure}`);
    if (flags.keep) {
      fs.cpSync(dir, path.resolve(flags.keep), { recursive: true, errorOnExist: true, force: false });
      console.log(`  world kept in ${path.resolve(flags.keep)}`);
    }
    return result.passed;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function report() {
  const names = [...new Set(readResults().map((row) => row.name))];
  if (!names.length) console.log('No results yet.');
  names.forEach(showComparison);
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
      showComparison(`agent:${name}`);
    }
    process.exitCode = allPassed ? 0 : 1;
    return undefined;
  }
  console.error('Usage: node tools/benchmark.js <cost|engine --place <name>|agent <scenario|all> [--place <name>] [--label <technique>] [--runs 3] [--model sonnet] [--budget 2] [--keep <dir>]|report>');
  process.exitCode = 2;
  return undefined;
}

if (require.main === module) {
  try { main(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}

module.exports = { grade, parseCost, parseEngine, compare, groups, baseline };
