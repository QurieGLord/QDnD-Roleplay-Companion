/// Exact aliases for stored training; no fuzzy inference of a new proficiency.
class ProficiencyIdentity {
  static const skills = <String, String>{
    'акробатика': 'acrobatics',
    'уход за животными': 'animal-handling',
    'обращение с животными': 'animal-handling',
    'магия': 'arcana',
    'атлетика': 'athletics',
    'обман': 'deception',
    'история': 'history',
    'проницательность': 'insight',
    'запугивание': 'intimidation',
    'расследование': 'investigation',
    'анализ': 'investigation',
    'медицина': 'medicine',
    'природа': 'nature',
    'внимательность': 'perception',
    'восприятие': 'perception',
    'выступление': 'performance',
    'исполнение': 'performance',
    'убеждение': 'persuasion',
    'религия': 'religion',
    'ловкость рук': 'sleight-of-hand',
    'скрытность': 'stealth',
    'выживание': 'survival',
    'воровские инструменты': 'thieves-tools',
    'инструменты вора': 'thieves-tools',
    "thieves' tools": 'thieves-tools',
  };
  static String normalize(String value) {
    final normalized = value
        .toLowerCase()
        .trim()
        .replaceAll('ё', 'е')
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return skills[normalized] ?? normalized.replaceAll(' ', '-');
  }

  static bool contains(Iterable<String> values, String target) =>
      values.any((value) => normalize(value) == normalize(target));
}
