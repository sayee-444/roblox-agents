// A long operation runs as a background job in Studio, and world.js polls it. Studio stops answering
// while a heavy Chunk is calculated, so a poll that fails this way must not end the wait.
const { test } = require('node:test');
const assert = require('node:assert');
const { waitForJob } = require('../plugins/roblox-world/engine/tools/job.js');

// Answers each poll from a script, on a clock that only the wait moves.
function scripted(answers) {
  const clock = { t: 0 };
  let next = 0;
  return {
    poll: async () => {
      const answer = answers[Math.min(next, answers.length - 1)];
      next += 1;
      if (answer instanceof Error) throw answer;
      return JSON.stringify({ id: 'a', ...answer });
    },
    options: { id: 'a', intervalMs: 1000, stallMs: 5000, now: () => clock.t, sleep: async (ms) => { clock.t += ms; } },
  };
}

const unreachable = new Error('execute_luau: Target is not reachable (ExecuteLuau.runCode)');

test('returns what the job returned, once it stops running', async () => {
  const { poll, options } = scripted([{ running: true, done: 1, total: 2 }, { running: false, done: 2, total: 2, result: 'generated 2 Chunks' }]);
  assert.strictEqual(await waitForJob(poll, options), 'generated 2 Chunks');
});

test('keeps waiting while Studio is too busy to answer', async () => {
  const { poll, options } = scripted([unreachable, unreachable, { running: false, done: 1, total: 1, result: 'done' }]);
  assert.strictEqual(await waitForJob(poll, options), 'done');
});

test('fails with the error the job raised', async () => {
  const { poll, options } = scripted([{ running: false, done: 0, total: 1, error: 'plan is invalid' }]);
  await assert.rejects(waitForJob(poll, options), /plan is invalid/);
});

test('fails on any other error from a poll', async () => {
  const { poll, options } = scripted([new Error('Studio closed')]);
  await assert.rejects(waitForJob(poll, options), /Studio closed/);
});

test('gives up when the job makes no progress for the whole stall time', async () => {
  const { poll, options } = scripted([{ running: true, done: 3, total: 9 }]);
  await assert.rejects(waitForJob(poll, options), /no progress/i);
});

test('progress restarts the stall time, so a long job is not cut short', async () => {
  const answers = [];
  for (let done = 0; done < 20; done += 1) answers.push({ running: true, done, total: 20 });
  answers.push({ running: false, done: 20, total: 20, result: 'all' });
  const { poll, options } = scripted(answers);
  assert.strictEqual(await waitForJob(poll, options), 'all');
});

test('fails when Studio holds a different job than the one started', async () => {
  const { poll, options } = scripted([{ running: true, done: 0, total: 1 }]);
  await assert.rejects(waitForJob(poll, { ...options, id: 'b' }), /different job/i);
});

test('reports each change of progress', async () => {
  const seen = [];
  const { poll, options } = scripted([{ running: true, done: 1, total: 2 }, { running: true, done: 1, total: 2 }, { running: false, done: 2, total: 2, result: 'ok' }]);
  await waitForJob(poll, { ...options, onProgress: (done, total) => seen.push(`${done}/${total}`) });
  assert.deepStrictEqual(seen, ['1/2', '2/2']);
});
