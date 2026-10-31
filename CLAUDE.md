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
- `db/`: SQL files, numbered in the order Saleh applies them (from Slice 1)
- `bench/`: benchmark runner in TypeScript (from Slice 1)

## Slice status

| Slice | Topic | Status |
| --- | --- | --- |
| 0 | Repo setup, rules, fixtures | In review |
| 1 | `arabic_normalize()` and baseline benchmark | Not started |
| 2 | Arabizi and dialect dictionaries | Not started |
| 3 | Ranking and hybrid vector search | Not started |
| 4 | Packaging for database.dev | Not started |

## Style

- SQL: lowercase keywords, snake_case names, every function `immutable` and `parallel safe` where possible.
- Writing (docs, PRs, comments): plain English, short sentences, no em dashes.
