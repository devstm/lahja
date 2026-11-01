-- 008_search_tests.sql
-- Tests for lahja.to_document(), lahja.to_query() and lahja.rank().
-- Returns only failing cases: expect 0 rows.

with match_cases(name, product, query, should_match) as (
  values
    ('exact',                 'عسل سدر يمني',          'عسل سدر',       true),
    ('stemmed',               'بلاط سيراميك',          'بلاطة',         true),
    ('arabizi',               'عسل سدر يمني',          '3asal sidr',    true),
    ('typo',                  'عسل سدر يمني',          'عسل سدير',      true),
    ('article',               'البلاط الإيطالي',        'بلاط',          true),
    ('filler words',          'عسل سدر يمني',          'بدي عسل منيح',  true),
    ('lexicon synonym',       'حذاء رياضي رجالي',      'كندرة',         true),
    ('arabizi and synonym',   'قهوة عربية بالهيل',     'ahwe 3arabi',   true),
    ('english',               'Yemeni Sidr Honey',     'sidr honey',    true),
    ('all words required',    'عسل سدر يمني',          'عسل زيتون',     false),
    ('unrelated',             'عسل سدر يمني',          'بلاط',          false),
    ('only fillers',          'عسل سدر يمني',          'بدي منيح',      false)
),
-- for each query, the "better" product must rank above the "worse" one
rank_cases(name, query, better, worse) as (
  values
    ('exact above stem-only',     'بلاط', 'بلاط سيراميك',  'لاطي'),
    ('exact above skeleton-only', 'سدر',  'عسل سدر',       'عسل سدير'),
    ('stem above skeleton-only',  'بلاطة', 'بلاط سيراميك', 'بلوط')
)
select name, query, should_match::text as expected,
       (lahja.to_document(product) @@ lahja.to_query(query))::text as actual
from match_cases
where (lahja.to_document(product) @@ lahja.to_query(query)) is distinct from should_match
union all
select name, query, 'better ranks higher',
       format('better=%s worse=%s',
              lahja.rank(lahja.to_document(better), lahja.to_query(query)),
              lahja.rank(lahja.to_document(worse), lahja.to_query(query)))
from rank_cases
where not (lahja.rank(lahja.to_document(better), lahja.to_query(query))
           > lahja.rank(lahja.to_document(worse), lahja.to_query(query)));
