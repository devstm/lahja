# Lahja

Smart Arabic search inside PostgreSQL and Supabase. Pure SQL, no external service, your data never leaves your database.

People write Arabic in many ways. Plain Postgres search only finds the first one:

| Shopper types | Plain Postgres | Lahja |
| --- | --- | --- |
| `عسل سدر` | ✅ | ✅ |
| `إبريق شاى` (letter variants) | ❌ | ✅ |
| `3asal sidr` (Arabizi) | ❌ | ✅ |
| `عسل سدير` (typo) | ❌ | ✅ |
| `بدي كندرة` (Levantine dialect) | ❌ | ✅ |
| `ahwe 3arabi` (dialect + Arabizi) | ❌ | ✅ |

## Quick start

Add one generated column and an index to your own table:

```sql
alter table products add column search tsvector
  generated always as (lahja.to_document(title || ' ' || coalesce(description, ''))) stored;

create index products_search_idx on products using gin (search);
```

Search:

```sql
select p.*
from products p, lahja.to_query('بدي 3asal sidr') q
where p.search @@ q
order by lahja.rank(p.search, q) desc
limit 20;
```

## Install

### Option 1: database.dev (after the package is published)

Lahja is a Trusted Language Extension. Follow the [dbdev documentation](https://supabase.github.io/dbdev/) to enable `pg_tle` and the `dbdev` client in your database, then:

```sql
select dbdev.install('devstm@lahja');
create extension "devstm@lahja" version '0.1.0';
```

### Option 2: run the SQL files

In the Supabase SQL editor (or any Postgres 14+), run these files from `db/` in order:

1. `001_normalize.sql`
2. `003_skeleton.sql`
3. `005_lexicon.sql`
4. `007_search.sql`
5. `009_hybrid.sql`

The even-numbered files (`002`, `004`, `006`, `008`, `010`) are tests. Each returns **0 rows** when everything works.

## How it works

`lahja.to_document()` stores every word in three layers, each with a weight:

| Layer | What | `بلاط` becomes | Weight |
| --- | --- | --- | --- |
| A | exact, after normalising | بلاط | 1.0 |
| B | stemmed by Postgres's Arabic stemmer | لاط | 0.4 |
| C | consonant skeleton (Arabic words only) | بلت | 0.1 |

`lahja.to_query()` removes filler words, then lets **each** query word match through any layer or through a lexicon synonym. All words must match. `lahja.rank()` scores exact matches highest, so the best match comes first even when the stemmer over-stems (Postgres stems both `بلاط` and `لاطي` to `لاط`).

**Normalising** folds spelling variants: diacritics, tatweel, أ إ آ ٱ → ا, ى → ي, ة → ه, ؤ → و, ئ → ي, Arabic and Persian digits, spacing, Latin case.

**The skeleton** keeps only consonants and merges letters that Arabizi writers do not tell apart, so `3asal` and `عسل` both become `عسل`, and `zeit zeitoon` and `زيت زيتون` both become `زت زتن`. It also catches vowel typos (`سدير` → `سدر`).

## API

| Function | Returns | Use |
| --- | --- | --- |
| `lahja.to_document(text)` | `tsvector` | In a generated column |
| `lahja.to_query(text)` | `tsquery` | The search text |
| `lahja.rank(tsvector, tsquery)` | `real` | `order by ... desc` |
| `lahja.rrf_score(keyword_rank, vector_rank, k, keyword_weight, vector_weight)` | `float8` | Hybrid keyword + vector search |
| `lahja.normalize(text)` | `text` | Spelling normalisation only |
| `lahja.skeleton(text)` | `text` | Consonant skeleton only |
| `lahja.strip_fillers(text)` | `text` | Removes filler words |

## Dialect lexicon

`lahja.lexicon` holds about 40 starter synonym groups (كندرة = جزمة = حذاء, كتلي = غلاية, جراب = كفر, …) and filler words (بدي, عايز, ابغى, منيح, …). Add your own, normalised:

```sql
insert into lahja.lexicon (word, grp) values
  (lahja.normalize('جلابية'), 'thobe'),
  (lahja.normalize('ثوب'), 'thobe');

insert into lahja.lexicon (word, grp, kind) values
  (lahja.normalize('لو سمحت'), 'please', 'filler');
```

Rows you add are kept when you re-run `005_lexicon.sql`, and, when Lahja is installed as an extension, they are included in `pg_dump` backups. Dropping the extension drops the lexicon table with your rows, so back them up first.

## Hybrid search (keyword + meaning)

Keyword search cannot know that `جلابية` and `ثوب` mean the same thing unless the lexicon says so. Vector embeddings can. `lahja.rrf_score()` merges both result lists by rank (Reciprocal Rank Fusion). You need pgvector and an embedding column filled by any multilingual model, for example `intfloat/multilingual-e5-small`. The full query pattern is at the top of [`db/009_hybrid.sql`](db/009_hybrid.sql).

## Benchmark

50 products and 50 queries in `fixtures/`, grouped by type. Hit@3 is the share of queries where a correct product is in the top 3.

| Version | Hit@3 | Wrong results in top 3 |
| --- | --- | --- |
| Plain Postgres `arabic` config | 0.65 | 0.03 |
| Lahja `to_query()` + `rank()` | 1.00 | 0.05 |

**Read this before quoting the numbers.** The test queries were seen while Lahja was being built, and the lexicon includes every dialect word they use. The score is inflated. A held-out query set is being written to measure real quality.

Run the benchmark: `db/900` to `db/902` in the SQL editor. The vector benchmark (`db/903`, `db/904`) needs embeddings from `scripts/embed-fixtures.mjs` and a Hugging Face token.

## Limits

- Different words for the same thing need a lexicon row or vector search.
- The skeleton ignores words shorter than 2 consonants (`shay` is not found through the skeleton).
- Arabizi has no single spelling standard; unusual spellings can fail.
- Postgres's Arabic stemmer is aggressive. Ranking keeps exact matches first, but stem-only matches can still add noise further down.
- Built and tested on Postgres 16. Every function is pure SQL or PL/pgSQL.

## Development

- `db/`: SQL files, numbered in apply order. Package files 001 to 899 (odd = code, even = tests), benchmark 900 and up.
- `fixtures/`: benchmark catalog and queries.
- `scripts/fixtures-to-sql.mjs`: regenerates `db/901_bench_seed.sql`.
- `scripts/build-package.mjs`: builds `package/` for database.dev from `db/`.
- `scripts/embed-fixtures.mjs`: generates vector embeddings for the benchmark.
