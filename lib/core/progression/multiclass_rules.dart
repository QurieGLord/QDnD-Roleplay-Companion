import 'class_spellcasting_profile.dart';
import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/class_data.dart';
import 'character_class_rules.dart';
import 'spell_progression.dart';

/// SRD 5.1, pp. 56–58. Separate from class creation and its starting grants.
class MulticlassRules {
  static const prerequisites = <String, List<List<String>>>{
    'barbarian': [
      ['strength']
    ],
    'bard': [
      ['charisma']
    ],
    'cleric': [
      ['wisdom']
    ],
    'druid': [
      ['wisdom']
    ],
    'fighter': [
      ['strength', 'dexterity']
    ],
    'monk': [
      ['dexterity'],
      ['wisdom']
    ],
    'paladin': [
      ['strength'],
      ['charisma']
    ],
    'ranger': [
      ['dexterity'],
      ['wisdom']
    ],
    'rogue': [
      ['dexterity']
    ],
    'sorcerer': [
      ['charisma']
    ],
    'warlock': [
      ['charisma']
    ],
    'wizard': [
      ['intelligence']
    ],
  };
  static bool? eligible(String classId, AbilityScores scores) {
    final rule = prerequisites[classId];
    if (rule == null) return null;
    final values = scores.toJson();
    return rule.every((alternatives) =>
        alternatives.any((ability) => (values[ability] as int) >= 13));
  }

  static List<String> unmet(Character hero, String newClassId) => {
        for (final id in {...hero.classes.map((c) => c.id), newClassId})
          if (eligible(id, hero.abilityScores) != true) id,
      }.toList();

  // Tokens describe training, not saving throws, starting skills or equipment.
  static const entryTraining = <String, List<String>>{
    'barbarian': ['armor:shield', 'weapon:simple', 'weapon:martial'],
    'bard': ['armor:light', 'skill:choose-one', 'instrument:choose-one'],
    'cleric': ['armor:light', 'armor:medium', 'armor:shield'],
    'druid': ['armor:light', 'armor:medium', 'armor:shield'],
    'fighter': [
      'armor:light',
      'armor:medium',
      'armor:shield',
      'weapon:simple',
      'weapon:martial'
    ],
    'monk': ['weapon:simple', 'weapon:shortsword'],
    'paladin': [
      'armor:light',
      'armor:medium',
      'armor:shield',
      'weapon:simple',
      'weapon:martial'
    ],
    'ranger': [
      'armor:light',
      'armor:medium',
      'armor:shield',
      'weapon:simple',
      'weapon:martial',
      'skill:choose-class-one'
    ],
    'rogue': ['armor:light', 'skill:choose-class-one', 'tool:thieves-tools'],
    'sorcerer': [],
    'warlock': ['armor:light', 'weapon:simple'],
    'wizard': [],
  };

  static SpellProgression spellCapacity(Character hero,
      {Map<String, ClassData> definitions = const {}}) {
    final casters = <ClassCasterLevel>[];
    for (final entry in hero.classes) {
      final data =
          definitions[entry.id] ?? CharacterClassRules.resolve(entry).data;
      if (data.rulesEdition != '2014') {
        throw StateError('An explicit supported edition is needed.');
      }
      final type =
          ClassSpellcastingProfile.resolve(hero, entry.id, definition: data)
                  ?.progression ??
              'none';
      final progression =
          CasterProgression.values.where((v) => v.name == type).firstOrNull;
      if (progression == null) throw StateError('Unknown caster progression.');
      casters.add(ClassCasterLevel(entry.id, entry.level, progression));
    }
    return SpellProgression.calculate(casters,
        edition: ProgressionEdition.srd2014);
  }

  /// FC5 stores remaining hit dice in the same order as the class list. Do not
  /// invent an allocation for an ambiguous old save or cap player extras.
  static List<int> advanceHitDice(Character before, String classId) {
    if (before.hitDice.length != before.classes.length ||
        before.hitDice.any((v) => v < 0)) {
      throw StateError('Hit dice need an explicit per-class allocation.');
    }
    final result = List<int>.from(before.hitDice);
    final index = before.classes.indexWhere((c) => c.id == classId);
    if (index < 0) {
      result.add(1);
    } else {
      result[index]++;
    }
    return result;
  }
}
