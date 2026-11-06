const { test } = require('node:test');
const assert = require('node:assert');
const { grade, parseCost, parseEngine, compare, groups, baseline } = require('../tools/benchmark.js');

test('a version is compared with the version before, skipping techniques that were only tried', () => {
  const v12 = { key: '0.12.0' };
  const tried = { key: '0.12.0 no-memory' };
  const v13 = { key: '0.13.0' };
  assert.strictEqual(baseline([v12, tried, v13]), v12);
});

test('a technique is compared with the version it was tried on', () => {
  const v13 = { key: '0.13.0' };
  const first = { key: '0.13.0 warp' };
  const second = { key: '0.13.0 ridges' };
  assert.strictEqual(baseline([v13, first, second]), v13);
});

test('the newest group is the one that ran last, even when its version already had runs', () => {
  const rows = [
    { version: '0.13.0', passed: true, output: 10 },
    { version: '0.13.0', label: 'warp', passed: true, output: 6 },
    { version: '0.13.0', passed: true, output: 12 },
  ];
  assert.deepStrictEqual(groups(rows, ['output']).map((group) => group.key), ['0.13.0 warp', '0.13.0']);
});

test('the first group has nothing to compare with', () => {
  assert.strictEqual(baseline([{ key: '0.13.0' }]), undefined);
});

const run = { skills: { 'world-history': 1 }, commands: { generate: 1 }, toolCalls: 9, errors: 0, captures: 0 };

test('a run that did what the scenario expects passes', () => {
  const failures = grade(run, { skills: ['world-history'], commands: ['generate'], absentCommands: ['run', 'capture'], maxToolCalls: 10, maxErrors: 0, maxCaptures: 0 });
  assert.deepStrictEqual(failures, []);
});

test('a run names each thing it failed to do', () => {
  const failures = grade(run, { skills: ['world-debug'], commands: ['run'], absentCommands: ['generate'], maxToolCalls: 5 });
  assert.deepStrictEqual(failures, [
    'skill world-debug did not load',
    'command run did not run',
    'command generate ran and should not have',
    'tool calls 9, limit 5',
  ]);
});

test('a file can forbid several texts', () => {
  const failures = grade(run, { absentFiles: { 'plan.luau': ['seed = 1', 'seed = 2'] } }, { readFile: () => 'seed = 2' });
  assert.deepStrictEqual(failures, ['plan.luau still holds "seed = 2"']);
});

test('an expected answer and expected file text are graded from what the run produced', () => {
  const failures = grade(run, { answer: ['fork', 'mesa'], files: { 'docs/world/history.md': 'Removed River' }, absentFiles: { 'src/world/plan.luau': 'id = "river"' } }, {
    answer: 'The last change removed River fork.',
    readFile: (file) => (file === 'docs/world/history.md' ? 'nothing yet' : 'id = "river"'),
  });
  assert.deepStrictEqual(failures, [
    'answer does not mention mesa',
    'docs/world/history.md does not hold "Removed River"',
    'src/world/plan.luau still holds "id = "river""',
  ]);
});

test('the context cost is read from the report of claude plugin details', () => {
  const text = [
    'Projected token cost',
    '  Always-on:   ~527 tok   added to every session',
    '',
    'Per-component (rounded)',
    '  component             always-on  on-invoke',
    '  world-history               ~70       ~640',
    '  world                      ~100      ~1.8k',
    '',
    '  On-invoke cost is paid each time a skill or agent fires.',
  ].join('\n');
  assert.deepStrictEqual(parseCost(text), {
    alwaysOn: 527,
    onInvoke: 2440,
    components: { 'world-history': { alwaysOn: 70, onInvoke: 640 }, world: { alwaysOn: 100, onInvoke: 1800 } },
  });
});

test('the time of each engine step is read from the output of world.js', () => {
  const text = 'load (0.4 s): 21 modules match, pasted 0\ntest (1.2 s): 33 passed\ndescribe (0.1 s): \nregion mesa (0.0 s) is not a step\nTotal 5.7 s';
  assert.deepStrictEqual(parseEngine(text), { steps: { load: 0.4, test: 1.2, describe: 0.1 }, totalSec: 5.7 });
});

test('a comparison gives the change for each measure against the previous run', () => {
  const lines = compare({ output: 2000, toolCalls: 10, errors: 0 }, { output: 1500, toolCalls: 10, errors: 1 }, ['output', 'toolCalls', 'errors']);
  assert.deepStrictEqual(lines, ['output 2000 -> 1500 (-25%)', 'toolCalls 10 -> 10 (same)', 'errors 0 -> 1 (+1)']);
});

test('with no previous run a comparison only states the values', () => {
  assert.deepStrictEqual(compare(null, { output: 1500 }, ['output']), ['output 1500 (first run)']);
});

test('runs are grouped by version and label, and each group gives medians over the runs that hold the measure', () => {
  const rows = [
    { version: '0.12.0', passed: true, output: 100, context: { tools: 10 } },
    { version: '0.12.0', passed: false, output: 300, context: { tools: 30 } },
    { version: '0.12.0', passed: true, output: 200 },
    { version: '0.13.0', label: 'warp', passed: true, output: 50, context: { tools: 5 } },
    { version: '0.13.0', label: 'warp', passed: true, output: 70, context: { tools: 7 } },
  ];
  assert.deepStrictEqual(groups(rows, ['output', 'context.tools']), [
    { key: '0.12.0', runs: 3, passed: 2, medians: { output: 200, 'context.tools': 20 } },
    { key: '0.13.0 warp', runs: 2, passed: 2, medians: { output: 60, 'context.tools': 6 } },
  ]);
});
