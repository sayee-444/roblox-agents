// Waits for a job running in the background in Studio. Pure, so it is tested without Studio.
// `poll` returns the job's status as JSON: { id, running, done, total, result, error }.

async function waitForJob(poll, options) {
  const { id, intervalMs = 2000, stallMs = 300000, onProgress = () => {} } = options;
  const now = options.now || Date.now;
  const sleep = options.sleep || ((ms) => new Promise((resolve) => { setTimeout(resolve, ms); }));
  let lastDone = 0;
  let lastChange = now();
  for (;;) {
    let status;
    try {
      status = JSON.parse(await poll());
    } catch (error) {
      // Studio does not answer while a heavy Chunk blocks it, and the job goes on.
      if (!error.message.includes('Target is not reachable')) throw error;
    }
    if (status) {
      if (status.id !== id) throw new Error(`Studio holds a different job (${status.id}) than the one started (${id})`);
      if (status.done !== lastDone) {
        lastDone = status.done;
        lastChange = now();
        onProgress(status.done, status.total);
      }
      if (status.error) throw new Error(`The job failed in Studio: ${status.error}`);
      if (!status.running) return status.result;
    }
    if (now() - lastChange >= stallMs) throw new Error(`The job made no progress for ${stallMs / 1000} s, at ${lastDone} done`);
    await sleep(intervalMs);
  }
}

module.exports = { waitForJob };
