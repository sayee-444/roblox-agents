// Merging enters main, so Claude Code itself asks the developer first, whatever the model decides.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const hook = path.join(root, '.claude/hooks/ask-before-merge.js');
const run = (tool_name, command) => spawnSync(process.execPath, [hook], {
  input: JSON.stringify({ tool_name, tool_input: { command } }),
  encoding: 'utf8',
});
const decision = (result) => (result.stdout.trim() ? JSON.parse(result.stdout).hookSpecificOutput.permissionDecision : 'none');

test('asks before a merge, alone or at the end of a longer command', () => {
  assert.strictEqual(decision(run('Bash', 'gh pr merge 51 --squash')), 'ask');
  assert.strictEqual(decision(run('Bash', 'node tools/check.js && gh pr merge feat/x --squash')), 'ask');
  assert.strictEqual(decision(run('PowerShell', 'gh pr merge 51')), 'ask');
});

test('stays out of the way of every other command', () => {
  for (const command of ['gh pr view 51', 'gh pr create --title x', 'git push origin feat/x', 'git merge main', 'echo merge']) {
    const result = run('Bash', command);
    assert.strictEqual(decision(result), 'none', command);
    assert.strictEqual(result.status, 0, command);
  }
});

test('the project settings run it on both shells', () => {
  const settings = JSON.parse(fs.readFileSync(path.join(root, '.claude/settings.json'), 'utf8'));
  const entry = settings.hooks.PreToolUse.find((item) => item.hooks.some((h) => h.command.includes('ask-before-merge.js')));
  assert.ok(entry, 'no hook entry');
  assert.match(entry.matcher, /Bash/);
  assert.match(entry.matcher, /PowerShell/);
});
