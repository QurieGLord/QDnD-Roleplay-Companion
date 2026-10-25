import 'journal_graph.dart';

class JournalLinkAnalysis {
  JournalLinkAnalysis(this.automatic, this.ambiguous);
  final Set<String> automatic;
  final List<List<JournalEntity>> ambiguous;
}

class JournalMention {
  const JournalMention(this.start, this.end, this.entity);
  final int start, end;
  final JournalEntity entity;
}

class JournalLinks {
  static final _token = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
  static List<String> words(String text) => _token
      .allMatches(text.toLowerCase().replaceAll('ё', 'е'))
      .map((m) => m.group(0)!)
      .toList();
  static String normalized(String text) => words(text).join(' ');

  /// No fuzzy matching or synonyms here: lexical search must not merge identities.
  static JournalLinkAnalysis analyze(
          String text, List<JournalEntity> entities) =>
      JournalMatcher(entities).analyze(text);

  static const _stop = {
    'the',
    'a',
    'an',
    'we',
    'i',
    'he',
    'she',
    'they',
    'it',
    'our',
    'his',
    'her',
    'this',
    'that',
    'last',
    'first',
    'new',
    'old',
    'find',
    'meet',
    'met',
    'return',
    'deliver',
    'иногда',
    'потом',
    'после',
    'сегодня',
    'вчера',
    'мы',
    'я',
    'он',
    'она',
    'они',
    'это',
    'его',
    'найти',
    'передать',
    'вернуться',
    'поговорить',
    'новый',
    'старая',
    'письмо',
    'встретили',
    'встретить',
    'передали',
    'поговорили',
    'нашли',
    'узнали',
    'записали',
    'последние',
    'сессия',
    'запись',
    'задание',
    'note',
    'quest',
    'session',
    'letter',
    'road',
    'дорога',
    'на',
    'в',
    'с',
    'из',
    'у',
    'к',
    'и',
    'но',
    'а',
    'по',
    'для',
    'от',
    'со',
    'во',
    'да',
    'или',
    'не',
    'of',
    'and',
    'or',
    'in',
    'on',
    'at',
    'to',
    'from',
    'with',
    'for',
    'but',
    'not'
  };

  /// Bounded local suggestions; title/category and capitalization are clues only.
  static List<String> candidates(
      String title, String text, List<JournalEntity> known,
      {bool entityTitle = false}) {
    final result = <String>[];
    final knownNames =
        known.expand((e) => [e.name, ...e.aliases]).map(normalized).toSet();
    void add(String value) {
      value = value.trim();
      final tokens = words(value);
      if (tokens.isEmpty ||
          tokens.every(_stop.contains) ||
          value.length < 3 ||
          knownNames.contains(normalized(value)) ||
          analyze(value, known).automatic.isNotEmpty ||
          analyze(value, known).ambiguous.isNotEmpty ||
          result.any((s) => normalized(s) == normalized(value))) {
        return;
      }
      result.add(value);
    }

    if (entityTitle) add(title);
    final proper =
        RegExp(r'[A-ZА-ЯЁ][a-zа-яё]+(?:[ -][A-ZА-ЯЁ][a-zа-яё]+){0,2}');
    for (final m in proper.allMatches('$title\n$text')) {
      var value = m.group(0)!;
      final pieces = value.split(' ');
      while (pieces.isNotEmpty && _stop.contains(pieces.first.toLowerCase())) {
        pieces.removeAt(0);
      }
      value = pieces.join(' ');
      // A capitalized adjective may introduce a lower-case place noun.
      if (pieces.length == 1 &&
          RegExp(r'(ая|яя|ый|ий|ой|ое|ского|ской)$').hasMatch(value)) {
        final after = RegExp(r'^ +([а-яё]+)')
            .firstMatch(('$title\n$text').substring(m.end));
        if (after != null && !_stop.contains(after.group(1))) {
          value += ' ${after.group(1)}';
        }
      }
      add(value);
    }
    return result.take(4).toList();
  }
}

/// Reused for the whole journal during one save: aliases are normalized once.
class JournalMatcher {
  JournalMatcher(List<JournalEntity> entities) {
    for (final entity in entities) {
      for (final alias in [entity.name, ...entity.aliases]) {
        final words = JournalLinks.words(alias).map(_identityWord).toList();
        if (words.isEmpty) continue;
        if (words.length > _maximum) _maximum = words.length;
        final list = _patterns.putIfAbsent(words.join(' '), () => []);
        if (!list.any((e) => e.id == entity.id)) list.add(entity);
      }
    }
  }
  final _patterns = <String, List<JournalEntity>>{};
  int _maximum = 0;
  static String _identityWord(String word) {
    if (!RegExp(r'^[а-я]+$').hasMatch(word)) return word;
    // Names require nominal endings. A general verb stemmer would turn Элиан
    // into Элиа, while Элиану would stay Элиан, breaking a trusted identity.
    for (final ending in [
      'иями',
      'ями',
      'ами',
      'ого',
      'ему',
      'ому',
      'ыми',
      'ими',
      'ией',
      'иям',
      'ием',
      'ая',
      'яя',
      'ой',
      'ей',
      'ый',
      'ий',
      'ое',
      'ые',
      'ие',
      'ую',
      'юю',
      'ом',
      'ем',
      'ам',
      'ям',
      'ах',
      'ях',
      'ов',
      'ев',
      'ия',
      'ья',
      'ию',
      'ью',
      'а',
      'я',
      'у',
      'ю',
      'е',
      'и',
      'ы',
      'о',
      'ь',
      'й'
    ]) {
      if (word.endsWith(ending) && word.length - ending.length >= 3) {
        return word.substring(0, word.length - ending.length);
      }
    }
    return word;
  }

  /// Where each trusted name sits in [text], so it can be drawn in its
  /// kind's colour. Ambiguous names are left unmarked.
  List<JournalMention> mentions(String text) {
    final folded = text.toLowerCase().replaceAll('ё', 'е');
    if (folded.length != text.length) return const [];
    final tokens = JournalLinks._token.allMatches(folded).toList();
    final words = [for (final t in tokens) _identityWord(t.group(0)!)];
    final found = <(int, int), JournalEntity>{};
    for (var start = 0; start < words.length; start++) {
      var key = '';
      for (var length = 1;
          length <= _maximum && start + length <= words.length;
          length++) {
        key = key.isEmpty ? words[start] : '$key ${words[start + length - 1]}';
        final matches = _patterns[key];
        if (matches != null && matches.length == 1) {
          found[(start, length)] = matches.single;
        }
      }
    }
    final result = <JournalMention>[];
    var reached = 0;
    final ranges = found.keys.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.compareTo(a.$2));
    for (final range in ranges) {
      if (range.$1 < reached) continue;
      result.add(JournalMention(tokens[range.$1].start,
          tokens[range.$1 + range.$2 - 1].end, found[range]!));
      reached = range.$1 + range.$2;
    }
    return result;
  }

  JournalLinkAnalysis analyze(String text) {
    final words = JournalLinks.words(text).map(_identityWord).toList();
    final occurrences = <(int, int), List<JournalEntity>>{};
    for (var start = 0; start < words.length; start++) {
      var key = '';
      for (var length = 1;
          length <= _maximum && start + length <= words.length;
          length++) {
        key = key.isEmpty ? words[start] : '$key ${words[start + length - 1]}';
        final matches = _patterns[key];
        if (matches != null) occurrences[(start, length)] = matches;
      }
    }
    final ranges = occurrences.keys.toList();
    for (final small in ranges) {
      if (ranges.any((large) =>
          large.$2 > small.$2 &&
          large.$1 <= small.$1 &&
          large.$1 + large.$2 >= small.$1 + small.$2)) {
        occurrences.remove(small);
      }
    }
    final automatic = <String>{};
    final ambiguous = <List<JournalEntity>>[];
    for (final matches in occurrences.values) {
      if (matches.length == 1) {
        automatic.add(matches.single.id);
      } else if (!ambiguous.any((g) =>
          g.map((e) => e.id).toSet().containsAll(matches.map((e) => e.id)))) {
        ambiguous.add(matches);
      }
    }
    return JournalLinkAnalysis(automatic, ambiguous);
  }
}
