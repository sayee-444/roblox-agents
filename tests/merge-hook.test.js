// Merging enters main, so Claude Code itself asks the developer first, and says in words what they approve.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const hook = path.join(root, '.claude/hooks/ask-before-merge.js');
const MERGE = 'node tools/check.js && gh pr merge 52 --squash';
const PLAIN = 'Esto mete a main el botón nuevo, y te lo pregunto porque tú apruebas cada fusión.';

// Stands in for the GitHub CLI, so these tests need no network.
function pathWithGh(answer) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fake-gh-'));
  const body = answer === null ? '@exit /b 1' : `@echo ${JSON.stringify(answer)}`;
  fs.writeFileSync(path.join(dir, 'gh.cmd'), `${body}\r\n`);
  fs.writeFileSync(path.join(dir, 'gh'), answer === null ? '#!/bin/sh\nexit 1\n' : `#!/bin/sh\ncat <<'EOF'\n${JSON.stringify(answer)}\nEOF\n`, { mode: 0o755 });
  const key = Object.keys(process.env).find((name) => name.toUpperCase() === 'PATH');
  return { ...process.env, [key]: `${dir}${path.delimiter}${process.env[key]}` };
}

const GITHUB = { title: 'fix: make the merge button clear', changedFiles: 3, additions: 60, deletions: 10, url: 'https://github.com/o/r/pull/52' };

function run(command, description, env = pathWithGh(GITHUB), tool_name = 'Bash') {
  const result = spawnSync(process.execPath, [hook], {
    input: JSON.stringify({ tool_name, tool_input: { command, description } }),
    encoding: 'utf8',
    env,
  });
  assert.strictEqual(result.status, 0, result.stderr);
  if (!result.stdout.trim()) return { decision: 'none', reason: '' };
  const { permissionDecision, permissionDecisionReason } = JSON.parse(result.stdout).hookSpecificOutput;
  return { decision: permissionDecision, reason: permissionDecisionReason };
}

test('the button says in plain words what enters main, beside the facts from GitHub', () => {
  const { decision, reason } = run(MERGE, PLAIN);
  assert.strictEqual(decision, 'ask');
  assert.ok(reason.startsWith(PLAIN), reason);
  for (const fact of ['#52', GITHUB.title, '3 files', '+60', '-10', GITHUB.url]) assert.ok(reason.includes(fact), fact);
});

test('it still asks when GitHub does not answer, and says so', () => {
  const { decision, reason } = run(MERGE, PLAIN, pathWithGh(null));
  assert.strictEqual(decision, 'ask');
  assert.ok(reason.startsWith(PLAIN), reason);
  assert.ok(reason.includes('#52'), reason);
  assert.ok(reason.includes('did not answer'), reason);
});

test('a short merge command is enough, with or without the check before it', () => {
  for (const command of ['gh pr merge 52', 'gh pr merge 52 --squash', 'gh pr merge 52 --merge', MERGE]) {
    assert.strictEqual(run(command, PLAIN).decision, 'ask', command);
  }
  assert.strictEqual(run('gh pr merge 52', PLAIN, undefined, 'PowerShell').decision, 'ask');
});

test('a merge mixed into a longer command is sent back, so no button shows it', () => {
  const long = 'node tools/check.js 2>&1 | tail -3 && gh pr merge 52 --squash; git switch main && git pull';
  for (const command of [long, 'git status; gh pr merge 52', 'gh pr merge --help']) {
    const { decision, reason } = run(command, PLAIN);
    assert.strictEqual(decision, 'deny', command);
    assert.ok(reason.includes('gh pr merge <number>'), reason);
  }
});

test('a merge without a plain explanation is sent back', () => {
  for (const description of [undefined, '', 'Merge PR 52']) {
    const { decision, reason } = run(MERGE, description);
    assert.strictEqual(decision, 'deny', String(description));
    assert.ok(reason.includes('plain words'), reason);
  }
});

test('stays out of the way of every other command', () => {
  for (const command of ['gh pr view 51', 'gh pr create --title x', 'git push origin feat/x', 'git merge main', 'echo merge']) {
    assert.strictEqual(run(command, PLAIN).decision, 'none', command);
  }
});

test('the project settings run it on both shells', () => {
  const settings = JSON.parse(fs.readFileSync(path.join(root, '.claude/settings.json'), 'utf8'));
  const entry = settings.hooks.PreToolUse.find((item) => item.hooks.some((h) => h.command.includes('ask-before-merge.js')));
  assert.ok(entry, 'no hook entry');
  assert.match(entry.matcher, /Bash/);
  assert.match(entry.matcher, /PowerShell/);
});
