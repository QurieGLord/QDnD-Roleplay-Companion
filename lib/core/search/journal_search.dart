import 'journal_language.dart';

/// Offline lexical search shared by the character journal and its UI preview.
/// Stems broaden word-form matches, never establish identity or story links.
class JournalSearch {
  JournalSearch(String query) : _terms = _queryTerms(query);
  final List<String> _terms;
  static final _words = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
  static Iterable<String> tokens(String text) => _words
      .allMatches(text.toLowerCase().replaceAll('ё', 'е'))
      .map((m) => m.group(0)!);
  static List<String> _queryTerms(String text) {
    final all = tokens(text).toList();
    final meaningful =
        all.where((w) => !JournalLanguage.stopWords.contains(w)).toList();
    return meaningful.isEmpty ? all : meaningful;
  }

  static String stem(String word) => RegExp(r'^[а-я]+$').hasMatch(word)
      ? RussianWordStem.of(word)
      : JournalLanguage.englishStem(word);
  static final _synonyms = [
    for (final group in JournalLanguage.groups) group.map(stem).toSet()
  ];

  bool matches(Iterable<String> fields) => score(fields) > 0;

  /// First field is the title; exact matches rank above inflections, synonyms and typos.
  int score(Iterable<String> fields) {
    if (_terms.isEmpty) return 1;
    final values = fields.toList();
    final words = values.expand(tokens).toSet();
    final title = values.isEmpty ? <String>{} : tokens(values.first).toSet();
    final stems = words.map(stem).toSet();
    var score = 0;
    for (final term in _terms) {
      final root = stem(term);
      if (words.contains(term)) {
        score += title.contains(term) ? 120 : 90;
        continue;
      }
      if (root.length >= 3 && stems.contains(root)) {
        score += 75;
        continue;
      }
      final numeric = int.tryParse(term) != null;
      if (!numeric &&
          term.length >= 3 &&
          words.any((w) => w.startsWith(term))) {
        score += 65;
        continue;
      }
      if (!numeric &&
          _synonyms.any((g) => g.contains(root) && g.any(stems.contains))) {
        score += 45;
        continue;
      }
      final contrast = {
        'north',
        'south',
        'east',
        'west',
        'northern',
        'southern',
        'eastern',
        'western',
        'север',
        'юг',
        'восток',
        'запад',
        'северный',
        'южный',
        'восточный',
        'западный'
      }.map(stem).toSet();
      if (!numeric && term.length >= 4 && !contrast.contains(root)) {
        final limit = term.length >= 8 ? 2 : 1;
        if (words.any((w) =>
                w.length >= 4 &&
                JournalLanguage.distance(term, w, limit) <= limit) ||
            (root.length >= 4 &&
                stems.any((w) =>
                    w.length >= 4 &&
                    JournalLanguage.distance(root, w, limit) <= limit))) {
          score += 20;
          continue;
        }
      }
      return 0;
    }
    return score;
  }
}

/// Russian Snowball region/suffix rules, with ё/е normalization.
/// Spec: https://snowballstem.org/algorithms/russian/stemmer.html
/// This is stemming, not dictionary lemmatization or semantic understanding.
class RussianWordStem {
  static final _russian = RegExp(r'^[а-я]+$');
  static const _vowels = 'аеиоуыэюя';
  static final _gerund =
      _Suffixes('ив ивши ившись ыв ывши ывшись', 'в вши вшись');
  static final _reflexive = _Suffixes('ся сь');
  static final _adjective = _Suffixes(
      'ее ие ые ое ими ыми ей ий ый ой ем им ым ом его ого ему ому их ых ую юю ая яя ою ею');
  static final _participle = _Suffixes('ивш ывш ующ', 'ем нн вш ющ щ');
  static final _verb = _Suffixes(
      'ила ыла ена ейте уйте ите или ыли ей уй ил ыл им ым ен ило ыло ено ят ует уют ит ыт ены ить ыть ишь ую ю',
      'ла на ете йте ли й л ем н ло но ет ют ны ть ешь нно');
  static final _noun = _Suffixes(
      'а ев ов ие ье е иями ями ами еи ии и ией ей ой ий й иям ям ием ем ам ом о у ах иях ях ы ь ию ью ю ия ья я');
  static final _derivation = _Suffixes('ост ость');
  static final _superlative = _Suffixes('ейш ейше');

  static String of(String input) {
    var word = input.toLowerCase().replaceAll('ё', 'е');
    if (!_russian.hasMatch(word)) return word;
    final vowel = word.split('').indexWhere(_vowels.contains);
    if (vowel < 0) return word;
    final rv = vowel + 1;
    final r2 = _region(word, _region(word, 0));

    var changed = _gerund.remove(word, rv);
    if (changed != word) {
      word = changed;
    } else {
      word = _reflexive.remove(word, rv);
      changed = _adjective.remove(word, rv);
      if (changed != word) {
        word = _participle.remove(changed, rv);
      } else {
        changed = _verb.remove(word, rv);
        word = changed != word ? changed : _noun.remove(word, rv);
      }
    }
    if (word.endsWith('и') && word.length - 1 >= rv) {
      word = word.substring(0, word.length - 1);
    }
    word = _derivation.remove(word, r2);
    if (word.endsWith('нн') && word.length - 1 >= rv) {
      word = word.substring(0, word.length - 1);
    } else {
      changed = _superlative.remove(word, rv);
      if (changed != word) {
        word = changed;
        if (word.endsWith('нн') && word.length - 1 >= rv) {
          word = word.substring(0, word.length - 1);
        }
      } else if (word.endsWith('ь') && word.length - 1 >= rv) {
        word = word.substring(0, word.length - 1);
      }
    }
    return word;
  }

  static int _region(String word, int from) {
    for (var i = from + 1; i < word.length; i++) {
      if (_vowels.contains(word[i - 1]) && !_vowels.contains(word[i])) {
        return i + 1;
      }
    }
    return word.length;
  }
}

class _Suffixes {
  _Suffixes(String unconditional, [String conditional = ''])
      : _conditional =
            conditional.isEmpty ? <String>{} : conditional.split(' ').toSet(),
        _all = [
          ...unconditional.split(' '),
          if (conditional.isNotEmpty) ...conditional.split(' ')
        ]..sort((a, b) => b.length.compareTo(a.length));
  final Set<String> _conditional;
  final List<String> _all;

  String remove(String word, int region) {
    for (final suffix in _all) {
      final start = word.length - suffix.length;
      if (start < region || !word.endsWith(suffix)) continue;
      if (_conditional.contains(suffix) &&
          (start <= region || !'ая'.contains(word[start - 1]))) {
        continue;
      }
      return word.substring(0, start);
    }
    return word;
  }
}
