-- 010_hybrid_tests.sql
-- Tests for lahja.rrf_score() and the hybrid query pattern from 009.
-- Returns only failing cases: expect 0 rows.
-- Needs pgvector. On Supabase it is available; this enables it if it is not yet.
-- The 3-number vectors below are made up to test the SQL. They are not real embeddings.

create schema if not exists extensions;
create extension if not exists vector with schema extensions;

with rrf_cases(name, actual, expected) as (
  values
    ('both lists, rank 1',   lahja.rrf_score(1, 1),       2.0 / 61),
    ('keyword list only',    lahja.rrf_score(1, null),    1.0 / 61),
    ('vector list only',     lahja.rrf_score(null, 3),    1.0 / 63),
    ('in neither list',      lahja.rrf_score(null, null), 0.0),
    ('custom k',             lahja.rrf_score(1, 1, 10),   2.0 / 11),
    ('vector weighted 2x',   lahja.rrf_score(2, 2, 60, 1.0, 2.0), 3.0 / 62)
),
products(id, title, embedding) as (
  values
    ('p1', 'جلابية رجالي قطن',  '[1, 0, 0]'::extensions.vector),
    ('p2', 'ثوب رجالي أبيض',    '[0.9, 0.1, 0]'::extensions.vector),
    ('p3', 'عسل سدر يمني',      '[0, 0, 1]'::extensions.vector)
),
q as (
  select lahja.to_query('جلابية') as tq, '[1, 0, 0]'::extensions.vector as emb
),
keyword as (
  select p.id, row_number() over (order by lahja.rank(lahja.to_document(p.title), q.tq) desc) as r
  from products p, q
  where lahja.to_document(p.title) @@ q.tq
),
semantic as (
  select p.id, row_number() over (order by p.embedding operator(extensions.<=>) q.emb) as r
  from products p, q
),
hybrid as (
  select coalesce(k.id, s.id) as id,
         row_number() over (order by lahja.rrf_score(k.r, s.r) desc) as position
  from keyword k
  full join semantic s on s.id = k.id
)
select name, actual::text, expected::text
from rrf_cases
where abs(actual - expected) > 1e-9
union all
-- keyword search alone finds only p1; hybrid must rank p1, then p2 (same meaning), then p3
select 'hybrid order', string_agg(id, ',' order by position), 'p1,p2,p3'
from hybrid
having string_agg(id, ',' order by position) <> 'p1,p2,p3';
