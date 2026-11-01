-- 003_skeleton.sql
-- Consonant skeletons: Arabic and Arabizi words reduced to the consonants they share.
--   3asal -> عسل      عسل -> عسل
--   zeit zeitoon -> زت زتن      زيت زيتون -> زت زتن
-- Vowels (a e i o u, ا و ي) are dropped because Arabizi spells them inconsistently.
-- Letters that Arabizi writers do not tell apart are merged:
--   ص->س  ض->د  ط->ت  ظ ذ->ز  ث->ت  ق->ك  ح->ه
-- Requires 001_normalize.sql. Safe to run again.
-- After changing these functions, re-run 900 and 901.

create or replace function lahja.skeleton_word(word text)
returns text
language plpgsql
immutable
strict
parallel safe
as $$
declare
  w text := word;
begin
  if w ~ '[a-z]' then
    -- Arabizi word
    if w in ('al', 'el', 'il') then
      return '';
    end if;
    w := regexp_replace(w, '^(al|el|il)-', '');
    w := replace(w, 'sh', 'ش');
    w := replace(w, 'ch', 'ش');
    w := replace(w, 'kh', 'خ');
    w := replace(w, 'gh', 'غ');
    w := replace(w, 'th', 'ت');
    w := replace(w, 'dh', 'ز');
    -- b p t j g d r z s f v q k c x l m n h 3 7 5 6 9
    w := translate(w, 'bptjgdrzsfvqkcxlmnh37569', 'ببتججدرزسففككككلمنهعهختك');
    -- drop vowels, 2, 8 and anything else that is not an Arabic letter
    w := regexp_replace(w, '[^ء-ي]', '', 'g');
  elsif w ~ '[ء-ي]' then
    -- Arabic word (already normalised): drop the article when 2+ letters follow
    w := regexp_replace(w, '^ال(?=..)', '');
    w := translate(w, 'صضطظذثقح', 'سدتززتكه');
    w := regexp_replace(w, '[^ء-ي0-9]', '', 'g');
  else
    -- numbers and other tokens stay as they are
    return w;
  end if;

  w := translate(w, 'اويءى', '');               -- drop long vowels and hamza
  w := regexp_replace(w, '(.)\1+', '\1', 'g');  -- collapse doubled letters
  if length(w) >= 3 then
    w := regexp_replace(w, 'ه$', '');           -- drop final ه (taa marbuta after normalize)
  end if;
  return w;
end
$$;

-- Skeleton of a whole text. Words that shrink below 2 letters are dropped,
-- because one-letter skeletons match too much.
create or replace function lahja.skeleton(input text)
returns text
language sql
immutable
strict
parallel safe
as $$
  select coalesce(string_agg(s, ' ' order by n), '')
  from (
    select n, lahja.skeleton_word(w) as s
    from regexp_split_to_table(lahja.normalize(input), ' ') with ordinality as t(w, n)
  ) words
  where length(s) >= 2
$$;

comment on function lahja.skeleton(text) is
  'Consonant skeleton of Arabic or Arabizi text, for matching across scripts and spellings.';
