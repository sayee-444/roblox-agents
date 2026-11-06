// Keeps the documents honest: whatever exists in the plugin must be named where people look for it.
const { test } = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const skills = fs.readdirSync(path.join(root, 'plugins/roblox-world/skills'));
const help = spawnSync(process.execPath, [path.join(root, 'plugins/roblox-world/engine/tools/world.js'), 'help'], { encoding: 'utf8' }).stdout;
const commands = help.split('\n').map((line) => line.match(/^ {2}([a-z]+)/)).filter(Boolean).map((match) => match[1]);

test('the README names every skill', () => {
  const readme = read('README.md');
  assert.deepStrictEqual(skills.filter((skill) => !readme.includes(`\`${skill}\``)), []);
});

test('the function map names every skill and engine command', () => {
  const map = read('docs/functions.md');
  assert.deepStrictEqual(skills.filter((skill) => !map.includes(`\`${skill}\``)), []);
  assert.deepStrictEqual(commands.filter((command) => !map.includes(`\`${command}`)), []);
});

test('every skill description survives YAML, which an unquoted colon breaks', () => {
  for (const skill of skills) {
    const description = read(`plugins/roblox-world/skills/${skill}/SKILL.md`).match(/^description: (.*)$/m);
    assert.ok(description, `${skill} has no description`);
    const value = description[1].trim();
    const quoted = value.startsWith('"') || value.startsWith("'");
    assert.ok(quoted || !value.includes(': '), `${skill}: quote the description, because it holds a colon`);
  }
});
