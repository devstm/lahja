-- 005_bench_run.sql
-- Runs every benchmark query against b0 and b1. Read-only.
--   hit_at_3:  share of queries with an expected product in the top 3
--   mrr:       mean of 1 / rank of the first expected product (0 when missing)
--   zero_rate: share of queries that returned no results
-- The no_match slice has no expected products: only zero_rate applies there
-- (1.00 is the ideal score), and it is left out of the hit_at_3 and mrr totals.
-- Requires 001 to 004.

with matches as (
  select q.id as query_id, 'b0' as config, p.id as product_id,
         row_number() over (
           partition by q.id
           order by ts_rank(p.b0, plainto_tsquery('arabic', q.query)) desc, p.id
         ) as rank
  from bench.queries q
  join bench.products p on p.b0 @@ plainto_tsquery('arabic', q.query)
  union all
  select q.id, 'b1', p.id,
         row_number() over (
           partition by q.id
           order by ts_rank(p.b1, plainto_tsquery('simple', lahja.normalize(q.query))) desc, p.id
         )
  from bench.queries q
  join bench.products p on p.b1 @@ plainto_tsquery('simple', lahja.normalize(q.query))
),
per_query as (
  select q.id, q.slice, c.config,
         cardinality(q.expected_ids) > 0 as has_expected,
         (select min(m.rank) from matches m
           where m.query_id = q.id and m.config = c.config
             and m.product_id = any (q.expected_ids)) as first_hit,
         (select count(*) from matches m
           where m.query_id = q.id and m.config = c.config) as results
  from bench.queries q
  cross join (values ('b0'), ('b1')) as c(config)
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
