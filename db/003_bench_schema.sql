-- 003_bench_schema.sql
-- Benchmark tables. Running this again drops and recreates them (test data only).
--   b0: built-in 'arabic' config on raw text (plain Postgres)
--   b1: 'simple' config on lahja.normalize(text)
-- Requires 001_normalize.sql.

create schema if not exists bench;

drop table if exists bench.products;
drop table if exists bench.queries;

create table bench.products (
  id          text primary key,
  title       text not null,
  title_en    text,
  category    text,
  brand       text,
  price       numeric,
  description text,
  -- generated columns need immutable expressions, so || is used instead of concat_ws()
  b0 tsvector generated always as (
    to_tsvector('arabic'::regconfig,
      title || ' ' || coalesce(title_en, '') || ' ' || coalesce(category, '') || ' ' ||
      coalesce(brand, '') || ' ' || coalesce(description, ''))
  ) stored,
  b1 tsvector generated always as (
    to_tsvector('simple'::regconfig, lahja.normalize(
      title || ' ' || coalesce(title_en, '') || ' ' || coalesce(category, '') || ' ' ||
      coalesce(brand, '') || ' ' || coalesce(description, '')))
  ) stored
);

create index products_b0_idx on bench.products using gin (b0);
create index products_b1_idx on bench.products using gin (b1);

create table bench.queries (
  id           text primary key,
  query        text not null,
  slice        text not null,
  -- empty array means no product should match (slice no_match)
  expected_ids text[] not null default '{}'
);
