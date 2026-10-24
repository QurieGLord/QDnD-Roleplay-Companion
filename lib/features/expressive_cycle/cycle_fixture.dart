import 'dart:math' as math;
import 'package:hive/hive.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/character.dart';
import '../../core/models/journal_note.dart';
import '../../core/models/quest.dart';
import '../../core/models/spell.dart';
import '../../core/models/spell_slots_table.dart';
import '../../core/progression/advancement_choice.dart';
import '../../core/progression/advancement_choice_catalog.dart';
import '../../core/progression/character_class_rules.dart';
import '../../core/progression/feature_evolution.dart';
import '../../core/progression/proficiency_identity.dart';
import '../../core/services/feature_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/spellcasting_service.dart';
import '../../core/services/storage_service.dart';
import '../character_level_up/cycle_fixture.dart';

const expressiveCycleSeedKey = '_expressive_cycle_seed_20261011_v1';
const expressiveCycleIdPrefix = 'cycle-expressive-20261011-';

/// Opted in only by the separate Cycle package. Reopening never replaces edits
/// or deliberately deleted heroes; interrupted first seeding can safely resume.
Future<void> seedExpressiveCycle() async {
  if (StorageService.getSetting(expressiveCycleSeedKey) == true) return;
  final roster = buildExpressiveCycleCharacters();
  for (final hero in roster) {
    if (StorageService.getCharacter(hero.id) == null) {
      await StorageService.saveCharacter(hero);
    }
  }
  await Hive.box<Character>('characters').flush();
  if (StorageService.getSetting('locale_code') == null) {
    await StorageService.saveSetting('locale_code', 'ru');
  }
  await StorageService.saveSetting(expressiveCycleSeedKey, true);
  await Hive.box('settings').flush();
}

const veteranCycleSeedKey = '_veteran_cycle_seed_20261024_v1';
const veteranCycleIdPrefix = 'cycle-veteran-20261024-';

/// Late-game heroes spread over levels 15–20, so thresholds such as the
/// 17th-level Arcanum or 18th-level Spell Mastery show both sides.
const veteranCycleLevels = {
  'barbarian': 20,
  'bard': 17,
  'cleric': 18,
  'druid': 16,
  'fighter': 15,
  'monk': 19,
  'paladin': 18,
  'ranger': 15,
  'rogue': 17,
  'sorcerer': 19,
  'warlock': 16,
  'wizard': 20,
};

/// Opted in only by the separate Cycle package, like [seedExpressiveCycle].
Future<void> seedVeteranCycle() async {
  await _retireLevelOneCycle();
  if (StorageService.getSetting(veteranCycleSeedKey) == true) return;
  final roster = buildExpressiveCycleCharacters(
      levels: veteranCycleLevels, idPrefix: veteranCycleIdPrefix);
  for (final hero in roster) {
    if (StorageService.getCharacter(hero.id) == null) {
      await StorageService.saveCharacter(hero);
    }
  }
  await Hive.box<Character>('characters').flush();
  if (StorageService.getSetting('locale_code') == null) {
    await StorageService.saveSetting('locale_code', 'ru');
  }
  await StorageService.saveSetting(veteranCycleSeedKey, true);
  await Hive.box('settings').flush();
}

const _retiredLevelOneKey = '_veteran_cycle_retired_level_one_20261024_v1';

/// The veteran Cycle replaces the level-one Cycle on the same device: its
/// heroes are removed once, and only those (matched by their seed prefix),
/// so veterans, the data-class hero and personal heroes stay.
Future<void> _retireLevelOneCycle() async {
  if (StorageService.getSetting(_retiredLevelOneKey) == true) return;
  final box = Hive.box<Character>('characters');
  for (final id in box.keys.whereType<String>().toList()) {
    if (id.startsWith(levelUpCycleIdPrefix)) {
      await StorageService.deleteCharacter(id);
    }
  }
  await box.flush();
  await StorageService.saveSetting(_retiredLevelOneKey, true);
}

const _preferences = [
  'dragon-ancestor-red---fire-damage',
  'pact-of-the-tome',
  'hunters-prey-colossus-slayer',
  'defensive-tactics-escape-the-horde',
  'multiattack-volley',
  'superior-hunters-defense-evasion',
  'metamagic-quickened-spell',
  'metamagic-twinned-spell',
  'metamagic-subtle-spell',
  'metamagic-heightened-spell',
  'eldritch-invocation-agonizing-blast',
  'eldritch-invocation-devils-sight',
  'eldritch-invocation-mask-of-many-faces',
  'eldritch-invocation-mire-the-mind',
  'eldritch-invocation-minions-of-chaos',
  'eldritch-invocation-ascendant-step',
  'eldritch-invocation-witch-sight',
  'eldritch-invocation-master-of-myriad-forms',
];
int _priority(String id) {
  final index = _preferences.indexOf(id);
  return index < 0 ? 1000 : index;
}

void _choose(Character hero, AdvancementChoice choice, int level) {
  final eligible =
      choice.options.where((o) => o.available(hero, level)).where((o) {
    if (choice.kind == AdvancementChoiceKind.skillProficiency) {
      return !ProficiencyIdentity.contains(hero.proficientSkills, o.id);
    }
    return o.feature != null && !hero.hasFeatureId(o.id);
  }).toList()
        ..sort((a, b) {
          final priority = _priority(a.id).compareTo(_priority(b.id));
          return priority == 0 ? a.id.compareTo(b.id) : priority;
        });
  final selected = eligible.take(choice.count).map((o) => o.id).toList();
  choice.applyTo(hero, selected, level); // Reject incomplete fixture choices.
}

void _add(Character hero, CharacterClassRules rules, String id) {
  final f = rules.feature(id) ?? FeatureService.getFeatureById(id);
  if (f == null) throw StateError('Missing Cycle feature: $id');
  FeatureEvolution.acquire(hero.features, f, referenceFor: rules.feature);
}

void _improve(Character hero) {
  final priorities = switch (hero.characterClass) {
    'monk' || 'ranger' => ['dexterity', 'wisdom', 'constitution'],
    'paladin' => ['strength', 'charisma', 'constitution'],
    'barbarian' || 'fighter' => ['strength', 'constitution', 'dexterity'],
    'rogue' => ['dexterity', 'constitution', 'intelligence'],
    'cleric' || 'druid' => ['wisdom', 'constitution', 'dexterity'],
    'wizard' => ['intelligence', 'constitution', 'dexterity'],
    _ => ['charisma', 'constitution', 'dexterity'],
  };
  final scores = hero.abilityScores.toJson();
  var points = 2;
  for (final key in [...priorities, ...scores.keys]) {
    final gain = math.min(points, math.max(0, 20 - (scores[key] as int)));
    scores[key] = (scores[key] as int) + gain;
    points -= gain;
    if (points == 0) break;
  }
  if (points != 0) throw StateError('Cycle ASI cannot be allocated');
  hero.abilityScores = AbilityScores.fromJson(scores);
}

List<Spell> _eligible(String classId, int ceiling, {bool secrets = false}) {
  final spells = (secrets
          ? SpellService.getAllSpells()
          : SpellService.getSpellsForClass(classId))
      .where((s) => s.level > 0 && s.level <= ceiling)
      .toList();
  spells.sort((a, b) =>
      a.level != b.level ? b.level.compareTo(a.level) : a.id.compareTo(b.id));
  return spells;
}

void _learn(Character hero, int count, int ceiling, {bool secrets = false}) {
  final spells = _eligible(hero.characterClass, ceiling, secrets: secrets)
      .where((s) => !hero.knownSpells.contains(s.id))
      .take(count)
      .toList();
  if (spells.length != count) {
    throw StateError(
        'Incomplete Cycle spell choices: ${hero.characterClass} / $count / $ceiling');
  }
  hero.knownSpells.addAll(spells.map((s) => s.id));
}

/// Curated single-class test sheets, constructed from the bundled personal
/// snapshots. This prepares fixtures; it does not claim to exercise 19 wizard
/// confirmations or to complete the application's remaining source binding.
/// [levels] caps a class below 20 (the veteran Cycle spreads 15–20).
List<Character> buildExpressiveCycleCharacters(
        {Map<String, int> levels = const {},
        String idPrefix = expressiveCycleIdPrefix}) =>
    buildLevelUpCycleCharacters().map((hero) {
      final id = hero.characterClass;
      final top = (levels[id] ?? 20).clamp(1, 20);
      final rules = CharacterClassRules.resolve(hero.classes.single);
      final subclass = rules.data.subclasses.first.id;
      hero.id = '$idPrefix$id';
      hero.name = 'Cycle · ${rules.data.getName('ru')}';
      hero.subclass = subclass;
      hero.classes.single.subclass = subclass;
      hero.features = [];
      final optionIds = {
        for (final f in rules.definitions) ...?f.options,
        for (final f in rules.definitions)
          if (f.id.startsWith('circle-of-the-land-')) f.id,
      };
      final catalog = AdvancementChoiceCatalog(rules.definitions);
      for (var level = 1; level <= top; level++) {
        hero.level = level;
        hero.classes.single.level = level;
        final acquired = rules
            .atLevel(level, subclass)
            .where((f) => !optionIds.contains(f.id))
            .toList();
        for (final f in acquired) {
          FeatureEvolution.acquire(hero.features, f,
              referenceFor: rules.feature);
        }
        for (final f in acquired
            .where((f) => f.id.contains('ability-score-improvement'))) {
          // One allocation per table event, independent from descriptive variants.
          if (f.minLevel == level) _improve(hero);
        }
        if (id == 'fighter' && level == 1) {
          _add(hero, rules, 'fighter-fighting-style-defense');
        }
        if (id == 'fighter' && level == 10) {
          _add(hero, rules, 'fighter-fighting-style-protection');
        }
        if (id == 'paladin' && level == 2) {
          _add(hero, rules, 'fighting-style-defense');
        }
        if (id == 'ranger' && level == 2) {
          _add(hero, rules, 'ranger-fighting-style-defense');
        }
        if (id == 'druid' && level == 3) {
          _add(hero, rules, 'circle-of-the-land-forest');
        }
        for (final choice in catalog.forLevel(
            classId: id, level: level, features: acquired)) {
          _choose(hero, choice, level);
        }
        for (final parent in acquired.where(
            (f) => AdvancementChoiceCatalog.legacyChoices.contains(f.id))) {
          if (parent.options?.isNotEmpty != true) {
            throw StateError('Missing Cycle choice: ${parent.id}');
          }
          _choose(
              hero,
              AdvancementChoice(
                  id: parent.id,
                  kind: AdvancementChoiceKind.feature,
                  count: 1,
                  options: [
                    for (final option in parent.options!)
                      AdvancementOption(option,
                          feature: rules.feature(option),
                          minimumClassLevel:
                              rules.feature(option)?.minLevel ?? 0)
                  ]),
              level);
        }
        if ((id == 'bard' && [3, 10].contains(level)) ||
            (id == 'rogue' && level == 6)) {
          final skills = hero.proficientSkills
              .where((s) => !ProficiencyIdentity.contains(hero.expertSkills, s))
              .take(2)
              .toList();
          if (skills.length != 2) {
            throw StateError('Incomplete Cycle expertise: $id');
          }
          hero.expertSkills.addAll(skills);
        }
        if (id == 'ranger') {
          if (level == 6) hero.favoredEnemies.add('undead');
          if (level == 14) hero.favoredEnemies.add('dragons');
          if (level == 6) hero.naturalExplorers.add('coast');
          if (level == 10) hero.naturalExplorers.add('mountain');
        }
        final slots = SpellSlotsTable.getSlots(
            level, rules.data.spellcasting?.type ?? 'none');
        final ceiling = slots.length;
        if (level > 1 && ceiling > 0) {
          final gain = id == 'wizard'
              ? 2
              : SpellcastingService.getSpellsKnownCount(id, level) -
                  SpellcastingService.getSpellsKnownCount(id, level - 1);
          if (gain > 0) {
            _learn(hero, gain, ceiling,
                secrets: id == 'bard' && [10, 14, 18].contains(level));
          }
          if (id == 'bard' && level == 6) {
            _learn(hero, 2, ceiling, secrets: true);
          }
        }
      }
      if (id == 'barbarian' && hero.hasFeatureId('primal-champion')) {
        hero.abilityScores = hero.abilityScores.copyWith(
            strength: math.min(24, hero.abilityScores.strength + 4),
            constitution: math.min(24, hero.abilityScores.constitution + 4));
      }
      const cantripCounts = {
        'bard': 4,
        'cleric': 5,
        'druid': 5,
        'sorcerer': 6,
        'warlock': 4,
        'wizard': 5
      };
      final cantrips = SpellService.getSpellsForClass(id)
          .where((s) => s.level == 0)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final existingCantrips = hero.knownSpells
          .where((s) => SpellService.getSpellById(s)?.level == 0)
          .length;
      final needed = (cantripCounts[id] ?? 0) - existingCantrips;
      final additions = cantrips
          .where((s) => !hero.knownSpells.contains(s.id))
          .take(needed)
          .toList();
      if (additions.length != needed) {
        throw StateError('Incomplete Cycle cantrips: $id');
      }
      hero.knownSpells.addAll(additions.map((s) => s.id));
      final slots =
          SpellSlotsTable.getSlots(top, rules.data.spellcasting?.type ?? 'none');
      hero.spellSlots = List.of(slots);
      hero.maxSpellSlots = List.of(slots);
      if (['cleric', 'druid', 'paladin'].contains(id)) {
        hero.knownSpells = {
          ...hero.knownSpells,
          ..._eligible(id, slots.length).map((s) => s.id)
        }.toList();
      }
      if (id == 'warlock') {
        // An Arcanum of circle n arrives at warlock level 2n - 1.
        for (var circle = 6; circle <= 9 && top >= circle * 2 - 1; circle++) {
          final spell = SpellService.getSpellsForClass(id)
              .where((s) => s.level == circle)
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          if (spell.isEmpty) {
            throw StateError('Missing Cycle Arcanum spell: $circle');
          }
          hero.knownSpells.add(spell.first.id);
        }
      }
      if (id == 'wizard') {
        String at(int circle, int index) => hero.knownSpells
            .where((s) => SpellService.getSpellById(s)?.level == circle)
            .elementAt(index);
        hero.spellMasterySpells = top >= 18 ? [at(1, 0), at(2, 0)] : [];
        hero.signatureSpells = top >= 20 ? [at(3, 0), at(3, 1)] : [];
        hero.signatureSpellsUsed = {
          for (final s in hero.signatureSpells) s: false
        };
      }
      hero.maxPreparedSpells =
          math.max(0, SpellcastingService.getMaxPreparedSpells(hero));
      hero.preparedSpells = hero.maxPreparedSpells > 0
          ? hero.knownSpells
              .where((s) => (SpellService.getSpellById(s)?.level ?? 0) > 0)
              .toList()
              .reversed
              .take(hero.maxPreparedSpells)
              .toList()
          : [];
      FeatureService.updateFeatureMaxUses(hero);
      for (final f in hero.features) {
        final pool = f.resourcePool;
        if (pool != null) pool.currentUses = pool.maxUses;
      }
      hero.setChannelDivinityCharges(hero.getMaxChannelDivinityCharges());
      hero.wildShapeCharges = id == 'druid' ? 2 : 0;
      hero.maxHp = rules.data.hitDie +
          hero.abilityScores.constitutionModifier +
          (top - 1) *
              (rules.data.hitDie ~/ 2 +
                  1 +
                  hero.abilityScores.constitutionModifier) +
          (id == 'sorcerer' ? top : 0);
      hero.currentHp = hero.maxHp;
      hero.hitDice = [top];
      hero.maxHitDice = top;
      hero.speed = id == 'monk'
          ? 60
          : id == 'barbarian'
              ? 40
              : 30;
      hero.goldPieces = 450;
      hero.backstory =
          'Тестовый персонаж $top-го уровня для проверки обновлённого листа. '
          'Подкласс: ${rules.data.subclasses.first.getName('ru')}. '
          'ОЗ и ресурсы заполнены. Выборы заданы для демонстрации; лист можно свободно изменять. '
          'Изменения сохраняются после перезапуска.';
      hero.recalculateAC();
      _journal(hero);
      return hero;
    }).toList();

void _journal(Character hero) {
  hero.journalNotes = [
    JournalNote(
        id: 'letter',
        title: 'Письмо из Лесной гавани',
        isPinned: true,
        category: NoteCategory.story,
        tags: ['улика', 'письмо'],
        content:
            'Элиан ждёт нас у старой пристани в Лесной гавани. Капитан Альдрен оставил ему письмо.'),
    JournalNote(
        id: 'meeting',
        title: 'Встреча на пристани',
        category: NoteCategory.npc,
        tags: ['Альдрен'],
        content:
            'Альдрен попросил найти сына Элиана и передать письмо в Лесной гавани.'),
  ];
  hero.quests = [
    Quest(
        id: 'elian',
        title: 'Найти Элиана',
        description: 'Передать Элиану письмо Альдрена в Лесной гавани.',
        objectives: [
          QuestObjective(description: 'Прочитать письмо', isCompleted: true),
          QuestObjective(description: 'Расспросить смотрителя пристани'),
          QuestObjective(description: 'Передать письмо Элиану')
        ])
  ];
  final graph = JournalGraph(entities: [
    JournalEntity(id: 'elian', name: 'Элиан', aliases: ['Elian']),
    JournalEntity(id: 'aldren', name: 'Альдрен', aliases: ['Aldren']),
    JournalEntity(
        id: 'haven',
        name: 'Лесная гавань',
        kind: JournalEntityKind.place,
        aliases: ['Woodland Haven']),
  ]);
  JournalService.reconcile(hero, graph);
  hero.journalData = graph.toJson();
}
