// PreToolUse hook: blocks database CLIs in Bash commands.
// Exit code 2 tells Claude Code to refuse the command and show the reason to Claude.

const BLOCKED = new Set(['psql', 'pgcli', 'pg_dump', 'pg_restore', 'supabase']);
// Commands that only read or print text. A blocked name in their arguments is just text.
const TEXT_ONLY = new Set(['git', 'grep', 'rg', 'cat', 'echo', 'printf', 'ls', 'head', 'tail', 'wc', 'less', 'diff']);

let raw = '';
process.stdin.on('data', (chunk) => (raw += chunk));
process.stdin.on('end', () => {
  let command = '';
  try {
    command = JSON.parse(raw)?.tool_input?.command ?? '';
  } catch {
    process.exit(0);
  }

  // Split into simple commands on ; & | newlines and subshell brackets.
  const segments = command.split(/[;&|\n()`]|\$\(/);
  // Every word is checked, so wrappers (sudo -u postgres, pnpm dlx, npm exec)
  // and quoted shells (bash -c "...") cannot hide a blocked CLI.
  for (const segment of segments) {
    const words = segment
      .trim()
      .split(/\s+/)
      .map((word) => word.replace(/^['"]+|['"]+$/g, ''))
      .filter(Boolean);
    const commandWord = words.find((word) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(word));
    if (!commandWord || TEXT_ONLY.has(commandWord.split('/').pop())) continue;
    for (const word of words) {
      const name = word.split('/').pop();
      if (BLOCKED.has(name)) {
        console.error(
          `Blocked "${name}": this project never runs database commands. ` +
            'Write the SQL to a file in db/ and let Saleh apply it in the Supabase SQL editor.'
        );
        process.exit(2);
      }
    }
  }
  process.exit(0);
});
