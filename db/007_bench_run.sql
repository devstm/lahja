-- 007_bench_run.sql
-- Runs every benchmark query against each config. Read-only.
--   b0: plain Postgres 'arabic' config on raw text
--   b1: normalise only
--   b2: normalise + stem
--   b3: consonant skeleton only
--   b4: b2 results first, then products only the skeleton found (the Slice 2 candidate)
-- Metrics:
--   hit_at_3:  share of queries with an expected product in the top 3
--   mrr:       mean of 1 / rank of the first expected product (0 when missing)
--   zero_rate: share of queries that returned no results
-- The no_match slice has no expected products: only zero_rate applies there
-- (1.00 is the ideal score), and it is left out of the hit_at_3 and mrr totals.
-- Requires 001 to 006.

with q as (
  select id, query, slice, expected_ids,
         plainto_tsquery('arabic', query)                          as tq0,
         plainto_tsquery('simple', lahja.normalize(query))         as tq1,
         plainto_tsquery('arabic', lahja.normalize(query))         as tq2,
         plainto_tsquery('simple', lahja.skeleton(query))          as tq3
  from bench.queries
),
scored as (
  select q.id as query_id, 'b0' as config, p.id as product_id, ts_rank(p.b0, q.tq0) as score
  from q join bench.products p on p.b0 @@ q.tq0
  union all
  select q.id, 'b1', p.id, ts_rank(p.b1, q.tq1)
  from q join bench.products p on p.b1 @@ q.tq1
  union all
  select q.id, 'b2', p.id, ts_rank(p.b2, q.tq2)
  from q join bench.products p on p.b2 @@ q.tq2
  union all
  select q.id, 'b3', p.id, ts_rank(p.b3, q.tq3)
  from q join bench.products p on p.b3 @@ q.tq3
),
-- b4: b2 matches score 10 + rank (always ahead; ts_rank stays far below 10), skeleton-only matches score their rank
b4 as (
  select query_id, 'b4' as config, product_id, max(score + case when config = 'b2' then 10 else 0 end) as score
  from scored
  where config in ('b2', 'b3')
  group by query_id, product_id
),
matches as (
  select query_id, config, product_id,
         row_number() over (partition by query_id, config order by score desc, product_id) as rank
  from (select * from scored union all select * from b4) all_scores
),
per_query as (
  select q.id, q.slice, c.config,
         cardinality(q.expected_ids) > 0 as has_expected,
         (select min(m.rank) from matches m
           where m.query_id = q.id and m.config = c.config
             and m.product_id = any (q.expected_ids)) as first_hit,
         (select count(*) from matches m
           where m.query_id = q.id and m.config = c.config) as results
  from q
  cross join (values ('b0'), ('b1'), ('b2'), ('b3'), ('b4')) as c(config)
)
select coalesce(slice, 'ALL') as slice,
       config,
       count(*) as queries,
       round(avg(case when has_expected then (coalesce(first_hit, 99) <= 3)::int end), 2) as hit_at_3,
       round(avg(case when has_expected then coalesce(1.0 / first_hit, 0) end), 2) as mrr,
       round(avg((results = 0)::int), 2) as zero_rate
from per_query
group by grouping sets ((slice, config), (config))
order by slice is null, slice, config;
