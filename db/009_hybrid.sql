-- 009_hybrid.sql
-- Hybrid search: merge keyword results (lahja.to_query) with vector results (pgvector)
-- using Reciprocal Rank Fusion (RRF). Keyword search finds exact words, spellings and
-- Arabizi; vector search finds products with the same meaning but different words
-- (جلابية -> ثوب). RRF only looks at the rank in each list, so the two scores never
-- need to be on the same scale.
--
-- This file does not need pgvector. Your table needs it for the embedding column:
--
--   create extension if not exists vector with schema extensions;
--   alter table products add column embedding extensions.vector(384);
--   -- fill embedding with any multilingual model, for example intfloat/multilingual-e5-small
--
-- Hybrid query (:text is the search text, :embedding its vector from the same model):
--
--   with q as (
--     select lahja.to_query(:text) as tq, :embedding::extensions.vector as emb
--   ),
--   keyword as (
--     select p.id, row_number() over (order by lahja.rank(p.search, q.tq) desc) as r
--     from products p, q
--     where p.search @@ q.tq
--     order by r
--     limit 50
--   ),
--   semantic as (
--     select p.id, row_number() over (order by p.embedding operator(extensions.<=>) q.emb) as r
--     from products p, q
--     order by r
--     limit 50
--   )
--   select coalesce(k.id, s.id) as id, lahja.rrf_score(k.r, s.r) as score
--   from keyword k
--   full join semantic s on s.id = k.id
--   order by score desc
--   limit 20;
--
-- Requires 001. Safe to run again.

-- RRF score for one item. A rank is 1 for the best result; null means the item
-- is not in that list. k = 60 is the usual default: larger k flattens the
-- difference between top ranks. Weights let you trust one list more.
create or replace function lahja.rrf_score(
  keyword_rank   bigint,
  vector_rank    bigint,
  k              int    default 60,
  keyword_weight float8 default 1.0,
  vector_weight  float8 default 1.0
)
returns float8
language sql
immutable
parallel safe
as $$
  select coalesce(keyword_weight / (k + keyword_rank), 0)
       + coalesce(vector_weight / (k + vector_rank), 0)
$$;

comment on function lahja.rrf_score(bigint, bigint, int, float8, float8) is
  'Reciprocal Rank Fusion score from a keyword rank and a vector rank (null = not found).';
