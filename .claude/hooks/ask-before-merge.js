#!/usr/bin/env node
// Claude Code runs this before each shell command. A merge enters main, so Claude Code itself asks the
// developer, whatever the model decides. It catches mistakes, and is not a security boundary.
let input = '';
process.stdin.on('data', (chunk) => { input += chunk; }).on('end', () => {
  const { tool_input: toolInput } = JSON.parse(input);
  if (!/\bgh\s+pr\s+merge\b/.test((toolInput && toolInput.command) || '')) return;
  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'ask',
      permissionDecisionReason: 'This merges a pull request into main. Approve only if you already said yes to this Implementation.',
    },
  }));
});
