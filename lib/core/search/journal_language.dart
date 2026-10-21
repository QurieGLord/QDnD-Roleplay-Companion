/// Bounded offline language assistance. Synonyms are deliberately domain-curated,
/// not an assertion that arbitrary sentences or proper names are understood.
class JournalLanguage {
  static const stopWords = {
    'на',
    'в',
    'во',
    'с',
    'со',
    'к',
    'у',
    'из',
    'и',
    'а',
    'но',
    'или',
    'для',
    'от',
    'по',
    'про',
    'об',
    'о',
    'это',
    'the',
    'a',
    'an',
    'on',
    'in',
    'at',
    'of',
    'to',
    'and',
    'or',
    'for',
    'about',
    'with',
    'from'
  };
  static const groups = [
    ['дорога', 'тракт', 'путь', 'road', 'route', 'path'],
    ['награда', 'вознаграждение', 'reward', 'payment'],
    ['задание', 'квест', 'поручение', 'quest', 'task', 'mission'],
    ['улика', 'зацепка', 'подсказка', 'clue', 'lead'],
    ['письмо', 'послание', 'letter', 'message'],
    ['враг', 'противник', 'enemy', 'foe', 'opponent'],
    ['оружие', 'weapon', 'armament'],
    ['меч', 'клинок', 'sword', 'blade'],
    ['город', 'town', 'city'],
    ['таверна', 'трактир', 'inn', 'tavern'],
    ['золото', 'золотой', 'gold', 'golden'],
    ['исцеление', 'лечение', 'heal', 'healing'],
    ['покупка', 'купить', 'purchase', 'buy', 'bought'],
    ['продажа', 'продать', 'sale', 'sell', 'sold'],
    ['персонаж', 'нпс', 'npc', 'character'],
    ['место', 'локация', 'location', 'place'],
  ];

  /// Inflection-oriented English normalization, not complete dictionary analysis.
  /// Regions prevent aggressive suffix stripping on short words.
  static String englishStem(String word) {
    if (!RegExp(r'^[a-z]+$').hasMatch(word) || word.length <= 2) return word;
    const irregular = {
      'children': 'child',
      'people': 'person',
      'men': 'man',
      'women': 'woman',
      'mice': 'mouse',
      'feet': 'foot',
      'teeth': 'tooth',
      'went': 'go',
      'gone': 'go',
      'found': 'find',
      'bought': 'buy',
      'sold': 'sell',
      'knives': 'knife',
      'lives': 'life',
      'wolves': 'wolf',
      'leaves': 'leaf',
      'dying': 'die',
      'lying': 'lie',
      'tying': 'tie'
    };
    if (irregular.containsKey(word)) return irregular[word]!;
    if (const {
      'news',
      'series',
      'species',
      'chaos',
      'this',
      'gas',
      'atlas',
      'bias',
      'cosmos'
    }.contains(word)) {
      return word;
    }
    bool vowel(String value) => RegExp(r'[aeiouy]').hasMatch(value);
    int region(String value) {
      for (var i = 1; i < value.length; i++) {
        if (vowel(value[i - 1]) && !vowel(value[i])) return i + 1;
      }
      return value.length;
    }

    var w = word;
    if (w.endsWith('sses')) {
      w = w.substring(0, w.length - 2);
    } else if (w.endsWith('ies') || w.endsWith('ied')) {
      w = '${w.substring(0, w.length - 3)}${w.length > 4 ? 'i' : 'ie'}';
    } else if (w.endsWith('s') &&
        !w.endsWith('ss') &&
        !w.endsWith('us') &&
        vowel(w.substring(0, w.length - 2))) {
      w = w.substring(0, w.length - 1);
    }
    for (final suffix in ['eedly', 'eed', 'ingly', 'edly', 'ing', 'ed']) {
      if (!w.endsWith(suffix)) continue;
      final start = w.length - suffix.length;
      if (suffix.startsWith('eed')) {
        if (start >= region(w)) w = '${w.substring(0, start)}ee';
      } else if (!const {
            'inning',
            'outing',
            'canning',
            'herring',
            'earring',
            'evening',
            'proceed',
            'exceed',
            'succeed'
          }.contains(w) &&
          vowel(w.substring(0, start))) {
        w = w.substring(0, start);
        if (w.endsWith('at') || w.endsWith('bl') || w.endsWith('iz')) {
          w += 'e';
        } else if (RegExp(r'(bb|dd|ff|gg|mm|nn|pp|rr|tt)$').hasMatch(w) &&
            w.length > 3) {
          w = w.substring(0, w.length - 1);
        } else if (region(w) >= w.length &&
            RegExp(r'[^aeiou][aeiou][^aeiouwxy]$').hasMatch(w)) {
          w += 'e';
        }
      }
      break;
    }
    if (w.length > 2 && w.endsWith('y') && !vowel(w[w.length - 2])) {
      w = '${w.substring(0, w.length - 1)}i';
    }
    // Match hoped/hope, magical/magic, quietly/quiet without stripping short roots.
    if (w.length > 4 && w.endsWith('ly')) w = w.substring(0, w.length - 2);
    if (w.length > 5 && w.endsWith('al')) w = w.substring(0, w.length - 2);
    if (w.length > 4 && w.endsWith('e') && region(w) < w.length - 1) {
      w = w.substring(0, w.length - 1);
    }
    return w;
  }

  /// Optimal-string-alignment distance with adjacent transpositions.
  static int distance(String a, String b, int limit) {
    if ((a.length - b.length).abs() > limit) return limit + 1;
    var before = List<int>.generate(b.length + 1, (i) => i);
    var twoBefore = List<int>.of(before);
    for (var i = 1; i <= a.length; i++) {
      final row = List<int>.filled(b.length + 1, 0)..[0] = i;
      var minimum = i;
      for (var j = 1; j <= b.length; j++) {
        final deletion = before[j] + 1, insertion = row[j - 1] + 1;
        final replacement = before[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        var value = deletion < insertion ? deletion : insertion;
        if (replacement < value) value = replacement;
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final transpose = twoBefore[j - 2] + 1;
          if (transpose < value) value = transpose;
        }
        row[j] = value;
        if (value < minimum) minimum = value;
      }
      if (minimum > limit) return limit + 1;
      twoBefore = before;
      before = row;
    }
    return before.last;
  }
}
