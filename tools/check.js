#!/usr/bin/env node
// Runs every check a merge depends on, and exits 0 only when all of them pass.
// Usage: node tools/check.js
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const MANIFEST = 'plugins/roblox-world/.claude-plugin/plugin.json';
const shell = (command) => spawnSync(command, { cwd: root, shell: true, encoding: 'utf8' });

// Installed copies stay on their version until it changes, so a plugin change without a bump never reaches them.
function versionBumped() {
  const changed = shell('git diff --name-only origin/main -- plugins/roblox-world');
  if (changed.status !== 0) return { ok: false, detail: `git could not compare with origin/main: ${changed.stderr.trim()}` };
  if (!changed.stdout.trim()) return { ok: true, detail: 'plugin unchanged' };
  const before = JSON.parse(shell(`git show origin/main:${MANIFEST}`).stdout).version;
  const now = JSON.parse(fs.readFileSync(path.join(root, MANIFEST), 'utf8')).version;
  return now === before
    ? { ok: false, detail: `the plugin changed, so bump "version" in ${MANIFEST} past ${before}` }
    : { ok: true, detail: `${before} to ${now}` };
}

const commands = [
  ['marketplace valid', 'claude plugin validate --strict .'],
  ['plugin valid', 'claude plugin validate --strict plugins/roblox-world'],
  ['guard tests', 'powershell -File tests/guard-tests.ps1'],
  ['node tests', 'node --test "tests/*.test.js"'],
];

let failed = 0;
for (const [name, command] of commands) {
  const run = shell(command);
  if (run.status === 0) console.log(`ok    ${name}`);
  else {
    failed += 1;
    console.log(`FAIL  ${name}: ${command}\n${run.stdout}${run.stderr}`);
  }
}
const version = versionBumped();
if (!version.ok) failed += 1;
console.log(`${version.ok ? 'ok   ' : 'FAIL '} version: ${version.detail}`);

console.log(failed ? `${failed} failed` : 'all passed');
process.exitCode = failed ? 1 : 0;
