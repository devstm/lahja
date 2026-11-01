-- 004_skeleton_tests.sql
-- Tests for lahja.skeleton(). Returns only failing cases: expect 0 rows.
-- Pairs show an Arabizi or misspelled input meeting its Arabic form.

with cases(name, input, expected) as (
  values
    ('arabizi 3',             '3asal',          'عسل'),
    ('arabic',                'عسل',            'عسل'),
    ('arabizi 3 inside',      'za3tar',         'زعتر'),
    ('arabic',                'زعتر',           'زعتر'),
    ('arabizi two words',     'zeit zeitoon',   'زت زتن'),
    ('arabic two words',      'زيت زيتون',      'زت زتن'),
    ('arabizi with number',   'ayfon 15',       'فن 15'),
    ('arabic with number',    'ايفون 15',       'فن 15'),
    ('arabizi 7',             '7aleeb',         'هلب'),
    ('arabic ح',              'حليب',           'هلب'),
    ('arabizi 5',             '5ubz',           'خبز'),
    ('arabic خ',              'خبز',            'خبز'),
    ('arabizi q',             'qahwa',          'كه'),
    ('arabic ق and ة',        'قهوة',           'كه'),
    ('vowel typo',            'سدير',           'سدر'),
    ('arabizi sidr',          'sidr',           'سدر'),
    ('missing alef',          'باور بنك',       'بر بنك'),
    ('with alef',             'باور بانك',      'بر بنك'),
    ('article removed',       'المدرسة',        'مدرس'),
    ('no article',            'مدرسة',          'مدرس'),
    ('ط and ص merged',        'شنطة صغيرة',     'شنت سغر'),
    ('arabizi el dropped',    'el shanta',      'شنت'),
    ('one letter dropped',    'shay',           ''),
    ('empty string',          '',               ''),
    ('null stays null',       null,             null)
)
select name, input, expected, lahja.skeleton(input) as actual
from cases
where lahja.skeleton(input) is distinct from expected;
