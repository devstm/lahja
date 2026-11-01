-- 005_lexicon.sql
-- Dialect synonyms and filler words, and the functions that use them at query time.
--   lahja.lexicon: one row per (word, group). Words in the same group are synonyms.
--                  kind 'filler' marks words that carry no product meaning (بدي, عايز, منيح).
--   lahja.strip_fillers(text): removes filler words from a query.
--   lahja.dialect_query(text): builds a tsquery where each word also matches its synonyms.
-- Words are stored normalised. Users can add their own rows.
-- Requires 001_normalize.sql. Safe to run again: the starter rows are re-inserted
-- without duplicates and user rows are kept.

create table if not exists lahja.lexicon (
  word text not null,
  grp  text not null,
  kind text not null default 'synonym' check (kind in ('synonym', 'filler')),
  primary key (word, grp)
);

create index if not exists lexicon_word_idx on lahja.lexicon (word);

-- Starter rows come from this file; user rows do not. As an extension, only user rows
-- are included in backups, so a restore does not insert starter rows twice.
alter table lahja.lexicon add column if not exists is_starter boolean not null default false;

-- Starter data: general Arabic dialect vocabulary across product types, not tuned to any test set.
-- Ambiguous words are left out on purpose: براد (fridge in the Levant, teapot in Morocco),
-- لبن (milk in Egypt, yogurt in the Levant).
insert into lahja.lexicon (word, grp, kind, is_starter)
select lahja.normalize(word), grp, kind, true
from (values
  -- footwear
  ('حذاء', 'shoes', 'synonym'), ('كندرة', 'shoes', 'synonym'), ('جزمة', 'shoes', 'synonym'),
  ('صباط', 'shoes', 'synonym'), ('بوط', 'shoes', 'synonym'), ('بوت', 'shoes', 'synonym'),
  ('شبشب', 'slippers', 'synonym'), ('شحاطة', 'slippers', 'synonym'), ('زنوبة', 'slippers', 'synonym'),
  -- clothing
  ('بنطلون', 'trousers', 'synonym'), ('بنطال', 'trousers', 'synonym'), ('سروال', 'trousers', 'synonym'),
  ('جاكيت', 'jacket', 'synonym'), ('جاكيتة', 'jacket', 'synonym'), ('معطف', 'jacket', 'synonym'),
  ('قميص', 'shirt', 'synonym'), ('شميز', 'shirt', 'synonym'),
  ('حجاب', 'hijab', 'synonym'), ('طرحة', 'hijab', 'synonym'),
  ('شنطة', 'bag', 'synonym'), ('حقيبة', 'bag', 'synonym'), ('جنطة', 'bag', 'synonym'),
  -- phones and computers
  ('جوال', 'phone', 'synonym'), ('موبايل', 'phone', 'synonym'), ('هاتف', 'phone', 'synonym'),
  -- محمول is left out: it also means laptop in حاسوب محمول
  ('تلفون', 'phone', 'synonym'), ('تليفون', 'phone', 'synonym'),
  ('كفر', 'phone_case', 'synonym'), ('جراب', 'phone_case', 'synonym'),
  ('لابتوب', 'laptop', 'synonym'), ('حاسوب محمول', 'laptop', 'synonym'), ('كمبيوتر محمول', 'laptop', 'synonym'),
  ('كمبيوتر', 'computer', 'synonym'), ('حاسوب', 'computer', 'synonym'), ('حاسب', 'computer', 'synonym'),
  ('ماوس', 'mouse', 'synonym'), ('فأرة', 'mouse', 'synonym'),
  ('كيبورد', 'keyboard', 'synonym'), ('لوحة مفاتيح', 'keyboard', 'synonym'),
  ('سماعات', 'headphones', 'synonym'), ('هيدفون', 'headphones', 'synonym'), ('سماعة', 'headphones', 'synonym'),
  ('باور بانك', 'power_bank', 'synonym'), ('بطارية متنقلة', 'power_bank', 'synonym'), ('شاحن متنقل', 'power_bank', 'synonym'),
  ('تلفزيون', 'tv', 'synonym'), ('تلفاز', 'tv', 'synonym'),
  -- home and kitchen
  ('غلاية', 'kettle', 'synonym'), ('كتلي', 'kettle', 'synonym'), ('كاتل', 'kettle', 'synonym'),
  ('ثلاجة', 'fridge', 'synonym'), ('تلاجة', 'fridge', 'synonym'),
  ('طنجرة', 'pot', 'synonym'), ('حلة', 'pot', 'synonym'), ('قدر', 'pot', 'synonym'),
  ('مقلاة', 'pan', 'synonym'), ('طاوة', 'pan', 'synonym'), ('مقلاية', 'pan', 'synonym'),
  ('كوب', 'cup', 'synonym'), ('كاسة', 'cup', 'synonym'), ('كباية', 'cup', 'synonym'),
  ('فنجان', 'coffee_cup', 'synonym'), ('فنجال', 'coffee_cup', 'synonym'),
  ('مكيف', 'air_conditioner', 'synonym'), ('كونديشن', 'air_conditioner', 'synonym'), ('تكييف', 'air_conditioner', 'synonym'),
  ('بطانية', 'blanket', 'synonym'), ('حرام', 'blanket', 'synonym'), ('لحاف', 'blanket', 'synonym'),
  ('مخدة', 'pillow', 'synonym'), ('وسادة', 'pillow', 'synonym'),
  -- food and drink (Arabizi spellings included where common)
  ('قهوة', 'coffee', 'synonym'), ('ahwe', 'coffee', 'synonym'), ('ahweh', 'coffee', 'synonym'),
  ('2ahwe', 'coffee', 'synonym'), ('gahwa', 'coffee', 'synonym'), ('qahwa', 'coffee', 'synonym'),
  ('شاي', 'tea', 'synonym'), ('shay', 'tea', 'synonym'), ('chai', 'tea', 'synonym'),
  ('ماء', 'water', 'synonym'), ('مي', 'water', 'synonym'), ('مية', 'water', 'synonym'), ('مويه', 'water', 'synonym'),
  ('خبز', 'bread', 'synonym'), ('عيش', 'bread', 'synonym'),
  ('طماطم', 'tomato', 'synonym'), ('بندورة', 'tomato', 'synonym'), ('قوطة', 'tomato', 'synonym'),
  ('بطاطس', 'potato', 'synonym'), ('بطاطا', 'potato', 'synonym'),
  -- filler: wanting, asking, and vague quality words
  ('بدي', 'want', 'filler'), ('بدنا', 'want', 'filler'), ('بدك', 'want', 'filler'),
  ('عايز', 'want', 'filler'), ('عاوز', 'want', 'filler'), ('عايزة', 'want', 'filler'),
  ('ابغى', 'want', 'filler'), ('ابي', 'want', 'filler'), ('ودي', 'want', 'filler'),
  ('اريد', 'want', 'filler'), ('نريد', 'want', 'filler'), ('حابب', 'want', 'filler'),
  ('محتاج', 'want', 'filler'), ('ابحث', 'want', 'filler'), ('عن', 'want', 'filler'),
  ('منيح', 'quality', 'filler'), ('منيحة', 'quality', 'filler'), ('كويس', 'quality', 'filler'),
  ('كويسة', 'quality', 'filler'), ('زين', 'quality', 'filler'), ('حلو', 'quality', 'filler'),
  ('حلوة', 'quality', 'filler'), ('ممتاز', 'quality', 'filler'), ('رخيص', 'quality', 'filler')
) as starter(word, grp, kind)
on conflict (word, grp) do nothing;

-- Removes filler words. Stable, not immutable: it reads lahja.lexicon.
create or replace function lahja.strip_fillers(input text)
returns text
language sql
stable
strict
parallel safe
as $$
  select coalesce(string_agg(w, ' ' order by n), '')
  from regexp_split_to_table(lahja.normalize(input), ' ') with ordinality as t(w, n)
  where not exists (
    select 1 from lahja.lexicon l where l.word = t.w and l.kind = 'filler'
  )
$$;

-- Each remaining word matches itself OR any word in its synonym groups; words are ANDed.
-- Two-word lexicon entries (باور بانك) are matched first, as one unit.
-- Uses the 'arabic' config, so it pairs with columns built as
-- to_tsvector('arabic', lahja.normalize(...)).
create or replace function lahja.dialect_query(input text)
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
    if i < array_length(words, 1)
       and exists (select 1 from lahja.lexicon where word = words[i] || ' ' || words[i + 1]) then
      unit := words[i] || ' ' || words[i + 1];
      i := i + 1;
    end if;
    i := i + 1;

    part := plainto_tsquery('arabic', unit);
    for syn in
      select distinct other.word
      from lahja.lexicon mine
      join lahja.lexicon other on other.grp = mine.grp and other.kind = 'synonym'
      where mine.word = unit and mine.kind = 'synonym' and other.word <> unit
    loop
      part := part || plainto_tsquery('arabic', syn);
    end loop;
    result := result && part;
  end loop;
  return result;
end
$$;

comment on function lahja.dialect_query(text) is
  'Query with filler words removed and each word expanded to its dialect synonyms.';
