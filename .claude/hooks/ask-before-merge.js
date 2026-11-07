#!/usr/bin/env node
// Claude Code runs this before each shell command. A merge enters main, so Claude Code itself asks the
// developer, whatever the model decides. It catches mistakes, and is not a security boundary.
// The developer must understand the button: the model explains it in their language, and GitHub supplies the facts.
const { spawnSync } = require('node:child_process');

const READABLE = /^\s*(?:node\s+tools[\\/]check\.js\s*&&\s*)?gh\s+pr\s+merge\s+(\d+)(?:\s+--(?:squash|merge|rebase))?\s*$/;
const MIN_EXPLANATION = 40;

function answer(permissionDecision, permissionDecisionReason) {
  console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision, permissionDecisionReason } }));
}

function facts(number) {
  const view = spawnSync(`gh pr view ${number} --json title,changedFiles,additions,deletions,url`, { shell: true, encoding: 'utf8' });
  try {
    const pr = JSON.parse(view.stdout);
    return `Pull request #${number}: ${pr.title}\n${pr.changedFiles} files, +${pr.additions} -${pr.deletions}\n${pr.url}`;
  } catch {
    return `Pull request #${number}. GitHub did not answer, so its title and size are missing here.`;
  }
}

let input = '';
process.stdin.on('data', (chunk) => { input += chunk; }).on('end', () => {
  const { command = '', description = '' } = JSON.parse(input).tool_input || {};
  if (!/\bgh\s+pr\s+merge\b/.test(command)) return;
  const readable = command.match(READABLE);
  if (!readable) {
    answer('deny', 'Merge alone, as: node tools/check.js && gh pr merge <number> --squash. Run anything else in another call, so the developer can read what they approve.');
  } else if (description.trim().length < MIN_EXPLANATION) {
    answer('deny', "Say in `description`, in the developer's language and in plain words, what enters main and why you ask. Their button shows it.");
  } else {
    answer('ask', `${description.trim()}\n\n${facts(readable[1])}`);
  }
});
