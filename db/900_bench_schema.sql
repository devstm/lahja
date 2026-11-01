-- 900_bench_schema.sql
-- Benchmark tables. Running this again drops and recreates them (test data only).
--   b0: built-in 'arabic' config on raw text (plain Postgres)
--   b1: 'simple' config on lahja.normalize(text)
--   b2: built-in 'arabic' config (with stemming) on lahja.normalize(text)
--   b3: consonant skeleton of the Arabic fields (title_en left out), for Arabizi and typos
--   b6: lahja.to_document(), the public search API from 007
-- Requires 001, 003, 005 and 007.

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
  ) stored,
  b2 tsvector generated always as (
    to_tsvector('arabic'::regconfig, lahja.normalize(
      title || ' ' || coalesce(title_en, '') || ' ' || coalesce(category, '') || ' ' ||
      coalesce(brand, '') || ' ' || coalesce(description, '')))
  ) stored,
  b3 tsvector generated always as (
    to_tsvector('simple'::regconfig, lahja.skeleton(
      title || ' ' || coalesce(category, '') || ' ' ||
      coalesce(brand, '') || ' ' || coalesce(description, '')))
  ) stored,
  b6 tsvector generated always as (
    lahja.to_document(
      title || ' ' || coalesce(title_en, '') || ' ' || coalesce(category, '') || ' ' ||
      coalesce(brand, '') || ' ' || coalesce(description, ''))
  ) stored
);

create index products_b0_idx on bench.products using gin (b0);
create index products_b1_idx on bench.products using gin (b1);
create index products_b2_idx on bench.products using gin (b2);
create index products_b3_idx on bench.products using gin (b3);
create index products_b6_idx on bench.products using gin (b6);

create table bench.queries (
  id           text primary key,
  query        text not null,
  slice        text not null,
  -- empty array means no product should match (slice no_match)
  expected_ids text[] not null default '{}'
);
