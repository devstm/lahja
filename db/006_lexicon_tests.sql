-- 006_lexicon_tests.sql
-- Tests for lahja.strip_fillers() and lahja.dialect_query(). Returns only failing cases: expect 0 rows.
-- Each dialect case checks whether a query matches a product text built the same way as
-- real search columns: to_tsvector('arabic', lahja.normalize(text)).

with filler_cases(name, input, expected) as (
  values
    ('levantine want',   'بدي عسل منيح',   'عسل'),
    ('egyptian want',    'عايز سماعات',    'سماعات'),
    ('gulf want',        'ابغى جوال زين',  'جوال'),
    ('no fillers',       'عسل سدر',        'عسل سدر'),
    ('only fillers',     'بدي منيح',       '')
),
dialect_cases(name, query, product_text, should_match) as (
  values
    ('levantine shoes',      'كندرة',          'حذاء رياضي رجالي للجري',     true),
    ('egyptian shoes',       'جزمة',           'حذاء رياضي رجالي للجري',     true),
    ('gulf kettle',          'كتلي',           'غلاية كهربائية 1.7 لتر',     true),
    ('egyptian phone case',  'جراب موبايل',    'كفر جوال سامسونج شفاف',      true),
    ('levantine phone',      'تلفون سامسونج',  'جوال سامسونج جالكسي',        true),
    ('arabizi coffee',       'ahwe',           'قهوة عربية بالهيل',          true),
    ('filler and synonym',   'بدي كندرة',      'حذاء رياضي رجالي للجري',     true),
    ('plain word unchanged', 'عسل',            'عسل سدر يمني',               true),
    ('two-word entry',       'باور بانك',      'بطارية متنقلة 20000',        true),
    ('phone is not laptop',  'جوال',           'لابتوب لينوفو حاسوب محمول',  false),
    ('synonym is not magic', 'كندرة',          'عسل سدر يمني',               false),
    ('all words required',   'كندرة جلد',      'حذاء رياضي رجالي للجري',     false)
)
select name, input as query, expected::text as expected, lahja.strip_fillers(input) as actual
from filler_cases
where lahja.strip_fillers(input) is distinct from expected
union all
select name, query, should_match::text,
       (to_tsvector('arabic', lahja.normalize(product_text)) @@ lahja.dialect_query(query))::text
from dialect_cases
where (to_tsvector('arabic', lahja.normalize(product_text)) @@ lahja.dialect_query(query)) is distinct from should_match;
