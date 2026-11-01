-- 007_search.sql
-- The public search API: one column, one query function, one rank function.
--
--   alter table products add column search tsvector
--     generated always as (lahja.to_document(title || ' ' || description)) stored;
--   create index on products using gin (search);
--
--   select p.*
--   from products p, lahja.to_query('بدي 3asal sidr') q
--   where p.search @@ q
--   order by lahja.rank(p.search, q) desc;
--
-- Every word is stored in three layers, each with a tsvector weight:
--   A  exact:    lahja.normalize(), no stemming          (strongest)
--   B  stemmed:  Postgres 'arabic' stemmer on normalised text
--   C  skeleton: lahja.skeleton() of Arabic-script words  (weakest)
-- Each query word may match through any layer, or through a lexicon synonym (B).
-- Query words are ANDed, so all of them must match some layer.
-- Requires 001, 003 and 005. Safe to run again.
-- After changing these functions, re-run 900 and 901.

-- Adds a weight to every lexeme of a tsquery: 'عسل' & 'سدر' -> 'عسل':A & 'سدر':A
create or replace function lahja.weighted(query tsquery, weight text)
returns tsquery
language sql
immutable
strict
parallel safe
as $$
  select case
    when query::text = '' then query
    else regexp_replace(query::text, '(''(?:[^'']|'''')*'')', '\1:' || weight, 'g')::tsquery
  end
$$;

create or replace function lahja.to_document(input text)
returns tsvector
language sql
immutable
strict
parallel safe
as $$
  select setweight(to_tsvector('simple'::regconfig, lahja.normalize(input)), 'A')
      || setweight(to_tsvector('arabic'::regconfig, lahja.normalize(input)), 'B')
      -- Latin words are left out of the skeleton layer: English product words
      -- would only add noise against Arabizi queries
      || setweight(to_tsvector('simple'::regconfig,
           lahja.skeleton(regexp_replace(lahja.normalize(input), '\S*[a-z]\S*', ' ', 'g'))), 'C')
$$;

create or replace function lahja.to_query(input text)
returns tsquery
language plpgsql
stable
strict
parallel safe
as $$
declare
  words  text[] := array_remove(string_to_array(lahja.strip_fillers(input), ' '), '');
  i      int := 1;
  unit   text;
  syn    text;
  part   tsquery;
  result tsquery := ''::tsquery;
begin
  while i <= coalesce(array_length(words, 1), 0) loop
    unit := words[i];
    -- two-word lexicon entries (باور بانك) are one unit
    if i < array_length(words, 1)
       and exists (select 1 from lahja.lexicon where word = words[i] || ' ' || words[i + 1]) then
      unit := words[i] || ' ' || words[i + 1];
      i := i + 1;
    end if;
    i := i + 1;

    part := lahja.weighted(plainto_tsquery('simple', unit), 'A')
         || lahja.weighted(plainto_tsquery('arabic', unit), 'B')
         || lahja.weighted(plainto_tsquery('simple', lahja.skeleton(unit)), 'C');
    for syn in
      select distinct other.word
      from lahja.lexicon mine
      join lahja.lexicon other on other.grp = mine.grp and other.kind = 'synonym'
      where mine.word = unit and mine.kind = 'synonym' and other.word <> unit
    loop
      part := part || lahja.weighted(plainto_tsquery('arabic', syn), 'B');
    end loop;
    result := result && part;
  end loop;
  return result;
end
$$;

-- Weights for D, C, B, A: exact matches count most, skeleton matches least.
create or replace function lahja.rank(document tsvector, query tsquery)
returns real
language sql
immutable
strict
parallel safe
as $$
  select ts_rank('{0.0, 0.1, 0.4, 1.0}'::real[], document, query)
$$;

comment on function lahja.to_document(text) is
  'Search document for a generated column: exact (A), stemmed (B) and skeleton (C) layers.';
comment on function lahja.to_query(text) is
  'Search query: fillers removed, each word matches exact, stemmed, skeleton or a lexicon synonym.';
comment on function lahja.rank(tsvector, tsquery) is
  'Relevance score: exact matches rank above stemmed, stemmed above skeleton.';
