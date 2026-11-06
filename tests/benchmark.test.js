const { test } = require('node:test');
const assert = require('node:assert');
const { grade, parseCost, parseEngine, compare } = require('../tools/benchmark.js');

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
