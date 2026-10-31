-- 001_normalize.sql
-- lahja.normalize(text): folds the many ways Arabic is written into one search form.
-- Apply in the Supabase SQL editor. Safe to run again.
-- After changing this function, re-run 003 and 004: stored search columns do not
-- recompute when the function changes.

create schema if not exists lahja;

create or replace function lahja.normalize(input text)
returns text
language sql
immutable
strict
parallel safe
as $$
  select btrim(
    regexp_replace(
      lower(
        translate(
          -- 1. remove diacritics (U+064B to U+0652), superscript alef (U+0670),
          --    tatweel (U+0640) and invisible direction and joiner marks
          regexp_replace(input, '[\u064B-\u0652\u0670\u0640\u200C-\u200F]', '', 'g'),
          -- 2. fold letter variants and digits
          --    أ إ آ ٱ -> ا   ى -> ي   ة -> ه   ؤ -> و   ئ -> ي   Persian ک ی -> ك ي
          --    Arabic-Indic and Persian digits -> 0 to 9
          'أإآٱىةؤئکی٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
          'اااايهويكي01234567890123456789'
        )
      ),
      -- 3. collapse all whitespace into single spaces
      '\s+', ' ', 'g'
    )
  )
$$;

comment on function lahja.normalize(text) is
  'Folds Arabic spelling variants, diacritics and digits into one form for search.';
