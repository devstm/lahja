# Lahja

Open-source package that adds smart Arabic search to any PostgreSQL or Supabase database: normalisation, Arabizi, dialect words, and later hybrid keyword and vector ranking.

Owner: Saleh. Saleh reviews and tests every step by hand. Claude writes the code.

## Hard constraints

- Pure SQL and PL/pgSQL only, so the package installs on Supabase through pg_tle and database.dev. No C code, no custom compiled extensions.
- Development runs against test databases only, never production data.
- Saleh applies every SQL file by hand in the Supabase Dashboard SQL editor.
- Scripts that connect to a database only run read-only queries (`select`), never DDL or writes.
- Make specific, targeted changes. No full-file rewrites unless Saleh asks.
- Never commit secrets. Connection strings live in `.env`, which is git-ignored.

## Do not touch

- `fixtures/catalog.csv` and `fixtures/queries.csv` are the benchmark fixtures. Change them only with Saleh's approval, and never to make a score look better.
- `.claude/settings.json` holds the permission rules. Change it only when Saleh asks.

## Working process (every slice)

1. Plan: propose the slice plan; wait for Saleh's approval.
2. Build: write the code on a branch named `slice-N-<topic>`.
3. Review: run `/code-review` on the diff, fix real findings.
4. Pull request: open it with test steps Saleh can follow by hand.
5. Stop. Saleh tests in Supabase and merges. The next slice starts only after his approval.
6. Update the slice status below.

## Layout

- `fixtures/`: benchmark catalog (50 products) and test queries (50 queries, each with a slice and expected product ids)
- `db/`: SQL files, numbered in the order Saleh applies them. Package functions first, then the benchmark. `006_bench_seed.sql` is generated: never edit it by hand
- `scripts/fixtures-to-sql.mjs`: regenerates `db/006_bench_seed.sql` from `fixtures/` (run after any approved fixture change)
- The benchmark is pure SQL (`db/005` to `db/007`) and runs in the Supabase SQL editor
- Benchmark tuning must not target specific test queries. Saleh keeps a private held-out query set to check for overfitting

## Slice status

| Slice | Topic | Status |
| --- | --- | --- |
| 0 | Repo setup, rules, fixtures | Done |
| 1 | `lahja.normalize()` and baseline benchmark | Done |
| 2 | Stemming and Arabizi consonant skeletons | In review |
| 3 | Dialect and synonym dictionary | Not started |
| 4 | Ranking and hybrid vector search | Not started |
| 5 | Packaging for database.dev | Not started |

## Style

- SQL: lowercase keywords, snake_case names, every function `immutable` and `parallel safe` where possible.
- Writing (docs, PRs, comments): plain English, short sentences, no em dashes.
