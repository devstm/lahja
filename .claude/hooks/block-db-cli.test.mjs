// Run: node .claude/hooks/block-db-cli.test.mjs
import { spawnSync } from 'node:child_process';

const hook = new URL('./block-db-cli.mjs', import.meta.url).pathname;
const cases = [
  ['ps' + 'ql -c "select 1"', 2],
  ['cd db && ps' + 'ql postgres://x', 2],
  ['DATABASE_URL=x npx supa' + 'base db push', 2],
  ['echo hi; /usr/bin/pg_' + 'dump mydb', 2],
  ['ls $(ps' + 'ql --version)', 2],
  ['git commit -m "add supa' + 'base notes"', 0],
  ['cat docs/supa' + 'base.md', 0],
  ['grep -r ps' + 'ql README.md', 0],
  ['node bench/run.ts', 0],
  ['sudo -u postgres ps' + 'ql', 2],
  ['pnpm dlx supa' + 'base db push', 2],
  ['npm exec supa' + 'base', 2],
  ['bash -c "ps' + 'ql -c \'drop table products\'"', 2],
  ['echo ok | xargs ps' + 'ql', 2],
  ['git log --oneline', 0],
  ['ls db/', 0],
];
let failed = 0;
for (const [command, expected] of cases) {
  const r = spawnSync('node', [hook], { input: JSON.stringify({ tool_input: { command } }) });
  const ok = r.status === expected;
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  exit=${r.status} expected=${expected}  ${command}`);
}
process.exit(failed ? 1 : 0);
