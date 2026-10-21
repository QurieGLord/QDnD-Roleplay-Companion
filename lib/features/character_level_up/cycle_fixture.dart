import 'package:hive/hive.dart';
import '../../core/magic/spellbook_state.dart';
import '../../core/magic/class_spell_grants.dart';

import '../../core/models/ability_scores.dart';
import '../../core/models/character.dart';
import '../../core/models/character_class.dart';
import '../../core/models/item.dart';
import '../../core/models/spell_slots_table.dart';
import '../../core/progression/character_class_rules.dart';
import '../../core/services/character_data_service.dart';
import '../../core/services/feature_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/storage_service.dart';

const levelUpCycleSeedKey = '_level_up_cycle_seed_20261010_v1';
const levelUpCycleIdPrefix = 'cycle-levelup-20261010-';

/// Used only by the separately installed, explicitly opted-in Cycle app.
/// The marker also respects a tester deliberately deleting a fixture hero.
Future<void> seedLevelUpCycle() async {
  if (StorageService.getSetting(levelUpCycleSeedKey) == true) return;
  // Validate the whole roster before writing the first character.
  final heroes = buildLevelUpCycleCharacters();
  for (final hero in heroes) {
    if (StorageService.getCharacter(hero.id) == null) {
      await StorageService.saveCharacter(hero);
    }
  }
  await Hive.box<Character>('characters').flush();
  if (StorageService.getSetting('locale_code') == null) {
    await StorageService.saveSetting('locale_code', 'ru');
  }
  await StorageService.saveSetting(levelUpCycleSeedKey, true);
  await Hive.box('settings').flush();
}

typedef _Preset = ({
  List<int> scores,
  List<String> skills,
  List<String> equipped,
  List<String> gear,
  String? subclass,
});

const _presets = <String, _Preset>{
  'barbarian': (
    scores: [16, 14, 15, 9, 13, 11],
    skills: ['perception', 'survival'],
    equipped: ['greataxe'],
    gear: ['handaxe', 'explorers_pack'],
    subclass: null
  ),
  'bard': (
    scores: [9, 15, 14, 11, 13, 16],
    skills: ['arcana', 'perception', 'persuasion'],
    equipped: ['rapier', 'leather_armor'],
    gear: ['dagger', 'entertainers_pack'],
    subclass: null
  ),
  'cleric': (
    scores: [15, 9, 14, 11, 16, 13],
    skills: ['insight', 'medicine'],
    equipped: ['mace', 'chain_mail', 'shield'],
    gear: ['holy_symbol', 'priests_pack'],
    subclass: 'life'
  ),
  'druid': (
    scores: [9, 14, 15, 11, 16, 13],
    skills: ['nature', 'animal-handling'],
    equipped: ['scimitar', 'leather_armor'],
    gear: ['spell_component_pouch', 'explorers_pack'],
    subclass: null
  ),
  'fighter': (
    scores: [16, 15, 14, 11, 13, 9],
    skills: ['acrobatics', 'perception'],
    equipped: ['longsword', 'chain_mail', 'shield'],
    gear: ['dungeoneers_pack'],
    subclass: null
  ),
  'monk': (
    scores: [11, 16, 14, 9, 15, 13],
    skills: ['acrobatics', 'stealth'],
    equipped: ['shortsword'],
    gear: ['explorers_pack'],
    subclass: null
  ),
  'paladin': (
    scores: [16, 11, 14, 9, 13, 15],
    skills: ['insight', 'religion'],
    equipped: ['longsword', 'chain_mail', 'shield'],
    gear: ['holy_symbol', 'explorers_pack'],
    subclass: null
  ),
  'ranger': (
    scores: [11, 16, 14, 9, 15, 13],
    skills: ['stealth', 'perception', 'survival'],
    equipped: ['shortsword', 'scale_mail'],
    gear: ['longbow', 'explorers_pack'],
    subclass: null
  ),
  'rogue': (
    scores: [9, 16, 14, 15, 13, 11],
    skills: ['acrobatics', 'sleight-of-hand', 'stealth', 'perception'],
    equipped: ['shortsword', 'leather_armor'],
    gear: ['shortbow', 'thieves_tools', 'dungeoneers_pack'],
    subclass: null
  ),
  'sorcerer': (
    scores: [9, 15, 14, 13, 11, 16],
    skills: ['arcana', 'persuasion'],
    equipped: ['dagger'],
    gear: ['spell_component_pouch', 'explorers_pack'],
    subclass: 'draconic'
  ),
  'warlock': (
    scores: [9, 15, 14, 13, 11, 16],
    skills: ['arcana', 'deception'],
    equipped: ['dagger', 'leather_armor'],
    gear: ['spell_component_pouch', 'scholars_pack'],
    subclass: 'fiend'
  ),
  'wizard': (
    scores: [9, 15, 14, 16, 13, 11],
    skills: ['arcana', 'investigation'],
    equipped: ['dagger'],
    gear: ['spellbook', 'spell_component_pouch', 'scholars_pack'],
    subclass: null
  ),
};

const _cantrips = <String, List<String>>{
  'bard': ['vicious-mockery', 'mage-hand'],
  'cleric': ['guidance', 'sacred-flame', 'thaumaturgy'],
  'druid': ['guidance', 'produce-flame'],
  'sorcerer': ['fire-bolt', 'ray-of-frost', 'mage-hand', 'minor-illusion'],
  'warlock': ['eldritch-blast', 'mage-hand'],
  'wizard': ['fire-bolt', 'mage-hand', 'prestidigitation'],
};

const _firstCircle = <String, List<String>>{
  'bard': ['healing-word', 'faerie-fire', 'thunderwave', 'sleep'],
  'cleric': ['bless', 'cure-wounds', 'healing-word', 'guiding-bolt'],
  'druid': ['cure-wounds', 'entangle', 'faerie-fire', 'thunderwave'],
  'sorcerer': ['magic-missile', 'shield'],
  'warlock': ['armor-of-agathys', 'hellish-rebuke'],
  'wizard': [
    'magic-missile',
    'shield',
    'detect-magic',
    'mage-armor',
    'sleep',
    'find-familiar'
  ],
};

/// Preferred spells must exist in the actual loaded class catalogue. A missing
/// preference is replaced deterministically, never with another class's spell.
List<String> _spells(String classId, int circle, List<String> preferred) {
  final eligible = SpellService.getSpellsForClass(classId)
      .where((s) => s.level == circle)
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final ids = eligible.map((s) => s.id).toSet();
  final selected = <String>{...preferred.where(ids.contains)};
  for (final spell in eligible) {
    if (selected.length >= preferred.length) break;
    selected.add(spell.id);
  }
  if (selected.length != preferred.length) {
    throw StateError('Incomplete Cycle spell catalogue: $classId / $circle');
  }
  return selected.toList();
}

List<Character> buildLevelUpCycleCharacters() => _presets.entries.map((entry) {
      final id = entry.key;
      final preset = entry.value;
      final data = CharacterDataService.getClassById(id);
      if (data == null) throw StateError('Missing Cycle class: $id');
      final rules = CharacterClassRules.capture(data);
      final scores = preset.scores;
      final abilities = AbilityScores(
          strength: scores[0],
          dexterity: scores[1],
          constitution: scores[2],
          intelligence: scores[3],
          wisdom: scores[4],
          charisma: scores[5]);
      final slots =
          SpellSlotsTable.getSlots(1, data.spellcasting?.type ?? 'none');
      final cantrips = _spells(id, 0, _cantrips[id] ?? const []);
      final chosen = _spells(id, 1, _firstCircle[id] ?? const []);
      final preparedCaster = ['cleric', 'druid', 'wizard'].contains(id);
      final allFirst = ['cleric', 'druid'].contains(id)
          ? SpellService.getSpellsForClass(id)
              .where((s) => s.level == 1)
              .map((s) => s.id)
              .toList()
          : chosen;
      final hp = data.hitDie +
          abilities.constitutionModifier +
          (id == 'sorcerer' ? 1 : 0);
      final hero = Character(
        id: '$levelUpCycleIdPrefix$id',
        name: 'Cycle · ${data.getName('ru')}',
        race: 'human',
        background: 'soldier',
        characterClass: id,
        subclass: preset.subclass,
        level: 1,
        maxHp: hp,
        currentHp: hp,
        abilityScores: abilities,
        spellSlots: slots,
        maxSpellSlots: slots,
        classes: [
          CharacterClass(
              id: id,
              name: data.getName('en'),
              level: 1,
              subclass: preset.subclass,
              isPrimary: true)
        ],
        proficientSkills: ['athletics', 'intimidation', ...preset.skills],
        savingThrowProficiencies: List.of(data.savingThrowProficiencies),
        knownSpells: [...cantrips, ...allFirst],
        preparedSpells: preparedCaster ? chosen.take(4).toList() : [],
        maxPreparedSpells: preparedCaster ? 4 : 0,
        features: rules
            .atLevel(1, preset.subclass)
            // This reference action has no use before Wild Shape is acquired.
            .where((f) => f.id != 'wild-shape-action')
            .toList(),
        hitDice: [1],
        maxHitDice: 1,
        wildShapeCharges: 0,
        goldPieces: 10,
        expertSkills: id == 'rogue' ? ['stealth', 'perception'] : [],
        favoredEnemies: id == 'ranger' ? ['beasts'] : [],
        naturalExplorers: id == 'ranger' ? ['forest'] : [],
        inventory: [...preset.equipped, ...preset.gear].map((itemId) {
          final template = ItemService.getItemById(itemId);
          if (template == null) {
            throw StateError('Missing Cycle equipment: $itemId');
          }
          return Item.fromJson(template.toJson())
            ..isEquipped = preset.equipped.contains(itemId);
        }).toList(),
        backstory:
            'Тестовый персонаж Cycle для проверки листа и повышения уровня. '
            'Человек, предыстория «Солдат». Изменения сохраняются после перезапуска.',
      );
      rules.attachTo(hero.classes.single);
      final book = SpellbookState.read(hero.spellbookData);
      for (final spell in hero.knownSpells) {
        book.setKnown('class:$id', spell, true);
      }
      for (final spell in hero.preparedSpells) {
        book.setPrepared('class:$id', spell, true);
      }
      hero.spellbookData = book.toJson();
      ClassSpellGrants.apply(hero, id);
      final optionId = switch (id) {
        'fighter' => 'fighter-fighting-style-defense',
        'sorcerer' => 'dragon-ancestor-red---fire-damage',
        _ => null,
      };
      if (optionId != null) {
        final option =
            rules.feature(optionId) ?? FeatureService.getFeatureById(optionId);
        if (option == null) throw StateError('Missing Cycle choice: $optionId');
        hero.features.add(option.copyForCharacter());
      }
      FeatureService.updateFeatureMaxUses(hero);
      for (final feature in hero.features) {
        final pool = feature.resourcePool;
        if (pool != null) pool.currentUses = pool.maxUses;
      }
      hero.recalculateAC();
      return hero;
    }).toList();
