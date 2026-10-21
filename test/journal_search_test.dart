import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/search/journal_search.dart';

void main() {
  group('Journal lexical search', () {
    test('Finds the reported road quest in different Russian cases', () {
      for (final query in ['дорога', 'дороге', 'дорогой', 'дорогу', 'ДОРОГА']) {
        expect(
            JournalSearch(query).matches(['Угроза на северной дороге']), isTrue,
            reason: query);
      }
      expect(
          JournalSearch('северная дорога')
              .matches(['Угроза на северной дороге']),
          isTrue);
      expect(
          JournalSearch('дорога южная').matches(['Угроза на северной дороге']),
          isFalse);
    });

    test('Normalizes punctuation, whitespace, case and ё', () {
      expect(JournalSearch('  ЕЛКА! ').matches(['Нашли у ёлки']), isTrue);
      expect(
          JournalSearch('ЛЕСНАЯ, ГАВАНЬ').matches(['Письмо из Лесной гавани']),
          isTrue);
      expect(JournalSearch('  ').matches([]), isTrue);
    });

    test('Matches words in separate fields without requiring query order', () {
      expect(
          JournalSearch('пристань элиан')
              .matches(['Элиан', 'Встретить у пристани']),
          isTrue);
      expect(
          JournalSearch('улика').matches(['Запись', 'обычный текст', 'улики']),
          isTrue);
    });

    test('Short fragments and numbers do not match arbitrary substrings', () {
      expect(JournalSearch('на').matches(['северная']), isFalse);
      expect(JournalSearch('на').matches(['Угроза на дороге']), isTrue);
      expect(JournalSearch('50').matches(['450 золотых']), isFalse);
      expect(JournalSearch('450').matches(['450 золотых']), isTrue);
      expect(JournalSearch('дор').matches(['дороге']), isTrue);
    });

    test(
        'English search retains case-insensitive whole-word and prefix matching',
        () {
      expect(JournalSearch('ROAD').matches(['Threat on the northern road']),
          isTrue);
      expect(JournalSearch('wood').matches(['Woodland Haven']), isTrue);
      expect(
          JournalSearch('road southern').matches(['Northern road']), isFalse);
    });

    test('Preserves names with letters outside the RU/EN alphabets', () {
      expect(JournalSearch('Éowyn').matches(['Письмо от Éowyn']), isTrue);
      expect(JournalSearch('Mithrandír').matches(['Mithrandír']), isTrue);
    });

    test(
        'Curated synonyms and bounded typos match without becoming universal semantics',
        () {
      expect(JournalSearch('тракт').matches(['дорога']), isTrue);
      expect(JournalSearch('дроога').matches(['дорога']), isTrue);
      expect(JournalSearch('судьба').matches(['дорога']), isFalse);
    });
  });

  test('English inflections, irregulars, synonyms and transpositions', () {
    for (final pair in [
      ('road', 'roads'),
      ('story', 'stories'),
      ('child', 'children'),
      ('find', 'found'),
      ('fight', 'fighting'),
      ('sword', 'blade'),
      ('raod', 'road')
    ]) {
      expect(JournalSearch(pair.$1).matches([pair.$2]), isTrue,
          reason: '$pair');
    }
    expect(JournalSearch('450').matches(['451 gold']), isFalse);
    expect(JournalSearch('road').score(['road']),
        greaterThan(JournalSearch('road').score(['path'])));
  });

  group('Russian stem regions and suffix families', () {
    test('Keeps non-Russian tokens and preserves the first vowel', () {
      expect(RussianWordStem.of('road'), 'road');
      expect(RussianWordStem.of('450'), '450');
      expect(RussianWordStem.of('в'), 'в');
      expect(RussianWordStem.of('я'), 'я');
      expect(RussianWordStem.of('КД'), 'кд');
    });

    test('Uses noun, adjective, verb, reflexive and superlative rules', () {
      final expected = {
        'дорога': 'дорог',
        'дороге': 'дорог',
        'дорогой': 'дорог',
        'пристани': 'пристан',
        'гавани': 'гаван',
        'лесной': 'лесн',
        'северная': 'северн',
        'северной': 'северн',
        'важности': 'важност',
        'важностью': 'важност',
        'бегавшая': 'бега',
        'валялся': 'валя',
        'пакетом': 'пакет',
        'пакеты': 'пакет',
        'павловной': 'павловн',
        'падающего': 'пада',
        'наилучший': 'наилучш',
      };
      for (final entry in expected.entries) {
        expect(RussianWordStem.of(entry.key), entry.value, reason: entry.key);
      }
    });
  });
}
