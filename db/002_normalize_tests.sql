-- 002_normalize_tests.sql
-- Tests for lahja.normalize(). Returns only failing cases: expect 0 rows.

with cases(name, input, expected) as (
  values
    ('diacritics',            'عسل سِدر',          'عسل سدر'),
    ('full tashkeel',         'مُحَمَّد',           'محمد'),
    ('superscript alef',      'الرَّحْمٰنِ',         'الرحمن'),
    ('tatweel',               'ســـلام',           'سلام'),
    ('hamza below',           'إبريق',             'ابريق'),
    ('hamza above',           'أحمد',              'احمد'),
    ('madda',                 'آمنة',              'امنه'),
    ('wasla',                 'ٱلله',              'الله'),
    ('alef maqsura',          'مستشفى',            'مستشفي'),
    ('taa marbuta',           'مدرسة',             'مدرسه'),
    ('waw hamza',             'مؤمن',              'مومن'),
    ('yaa hamza',             'مسائل',             'مسايل'),
    ('persian kaf',           'کتاب',              'كتاب'),
    ('persian yaa',           'علی',               'علي'),
    ('arabic-indic digits',   '٢٥٠ غرام',          '250 غرام'),
    ('persian digits',        '۱۲۳',               '123'),
    ('extra spaces',          '  عسل   سدر  ',     'عسل سدر'),
    ('tabs and newlines',     E'عسل\tسدر\n',       'عسل سدر'),
    ('zero-width non-joiner', E'سما\u200Cعات',     'سماعات'),
    ('right-to-left mark',    E'\u200Fعسل',        'عسل'),
    ('latin lowercase',       'iPhone 15',         'iphone 15'),
    ('mixed script',          'Bluetooth سماعات',  'bluetooth سماعات'),
    ('arabizi unchanged',     '3asal sidr',        '3asal sidr'),
    ('plain text unchanged',  'عسل سدر',           'عسل سدر'),
    ('empty string',          '',                  ''),
    ('null stays null',       null,                null)
)
select name, input, expected, lahja.normalize(input) as actual
from cases
where lahja.normalize(input) is distinct from expected;
