// PreToolUse hook: blocks database CLIs in Bash commands.
// Exit code 2 tells Claude Code to refuse the command and show the reason to Claude.

const BLOCKED = new Set(['psql', 'pgcli', 'pg_dump', 'pg_restore', 'supabase']);
const WRAPPERS = new Set(['sudo', 'npx', 'pnpm', 'yarn', 'bunx', 'env', 'exec', 'time', 'xargs']);

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
  for (const segment of segments) {
    const words = segment.trim().split(/\s+/).filter(Boolean);
    for (const word of words) {
      if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(word) || WRAPPERS.has(word) || word.startsWith('-')) continue;
      const name = word.split('/').pop();
      if (BLOCKED.has(name)) {
        console.error(
          `Blocked "${name}": this project never runs database commands. ` +
            'Write the SQL to a file in db/ and let Saleh apply it in the Supabase SQL editor.'
        );
        process.exit(2);
      }
      break; // only the command word of each segment matters
    }
  }
  process.exit(0);
});
