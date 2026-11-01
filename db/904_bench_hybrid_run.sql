-- 904_bench_hybrid_run.sql
-- Compares keyword search (b6) with vector-only (b7) and hybrid RRF (b8). Read-only.
--   b6: lahja.to_query() + lahja.rank(), the Slice 4 API
--   b7: vector search only: cosine distance, top 10
--   b8: hybrid: lahja.rrf_score() over b6 (top 50) and b7 (top 50)
-- Metrics are the same as 902. Vector search always returns results, so b7 and b8
-- never score on zero_rate and fill the top 3 even when nothing fits (see noise_at_3).
-- Requires 001 to 010, 900, 901 and 903 (run scripts/embed-fixtures.mjs to create 903).

with q as (
  select bq.id, bq.slice, bq.expected_ids, lahja.to_query(bq.query) as tq, qe.embedding as emb
  from bench.queries bq
  join bench.query_embeddings qe on qe.id = bq.id
),
keyword as (
  select q.id as query_id, p.id as product_id,
         row_number() over (partition by q.id order by lahja.rank(p.b6, q.tq) desc, p.id) as r
  from q join bench.products p on p.b6 @@ q.tq
),
semantic as (
  select q.id as query_id, pe.id as product_id,
         row_number() over (partition by q.id order by pe.embedding operator(extensions.<=>) q.emb, pe.id) as r
  from q cross join bench.product_embeddings pe
),
matches as (
  select query_id, 'b6' as config, product_id, r as rank from keyword
  union all
  select query_id, 'b7', product_id, r from semantic where r <= 10
  union all
  select query_id, 'b8', product_id,
         row_number() over (partition by query_id order by score desc, product_id)
  from (
    select coalesce(k.query_id, s.query_id) as query_id,
           coalesce(k.product_id, s.product_id) as product_id,
           lahja.rrf_score(k.r, s.r) as score
    from (select * from keyword where r <= 50) k
    full join (select * from semantic where r <= 50) s
      on s.query_id = k.query_id and s.product_id = k.product_id
  ) fused
),
per_query as (
  select q.id, q.slice, c.config,
         cardinality(q.expected_ids) > 0 as has_expected,
         (select min(m.rank) from matches m
           where m.query_id = q.id and m.config = c.config
             and m.product_id = any (q.expected_ids)) as first_hit,
         (select count(*) from matches m
           where m.query_id = q.id and m.config = c.config) as results,
         (select avg((not m.product_id = any (q.expected_ids))::int) from matches m
           where m.query_id = q.id and m.config = c.config and m.rank <= 3) as noise
  from q
  cross join (values ('b6'), ('b7'), ('b8')) as c(config)
)
select coalesce(slice, 'ALL') as slice,
       config,
       count(*) as queries,
       round(avg(case when has_expected then (coalesce(first_hit, 99) <= 3)::int end), 2) as hit_at_3,
       round(avg(case when has_expected then coalesce(1.0 / first_hit, 0) end), 2) as mrr,
       round(avg((results = 0)::int), 2) as zero_rate,
       round(avg(case when has_expected then noise end), 2) as noise_at_3
from per_query
group by grouping sets ((slice, config), (config))
order by slice is null, slice, config;
