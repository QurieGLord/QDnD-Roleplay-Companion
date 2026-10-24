import 'package:hive/hive.dart';

import '../../core/models/ability_scores.dart';
import '../../core/models/character.dart';
import '../../core/models/character_class.dart';
import '../../core/models/class_data.dart';
import '../../core/progression/character_class_rules.dart';
import '../../core/services/storage_service.dart';
import 'cycle_fixture.dart';

const customClassCycleSeedKey = '_expressive_cycle_custom_seed_20261023_v1';
const customClassCycleId = '${expressiveCycleIdPrefix}rune-guard';

/// A thirteenth Cycle hero whose class arrives as data, the way a
/// third-party book or a homebrew import does: the sheet must draw it with
/// the universal kit, never with a built-in class panel.
Future<void> seedCustomClassCycle() async {
  if (StorageService.getSetting(customClassCycleSeedKey) == true) return;
  if (StorageService.getCharacter(customClassCycleId) == null) {
    await StorageService.saveCharacter(buildCustomClassCycleCharacter());
  }
  await Hive.box<Character>('characters').flush();
  await StorageService.saveSetting(customClassCycleSeedKey, true);
  await Hive.box('settings').flush();
}

const _classId = 'rune-guard';

Map<String, dynamic> _feature(String id, String ru, String en, String dRu, String dEn,
        {String type = 'passive', Map<String, dynamic>? pool, Map<String, dynamic>? cost, String? economy, String? icon}) =>
    {
      'id': id,
      'nameRu': ru,
      'nameEn': en,
      'descriptionRu': dRu,
      'descriptionEn': dEn,
      'type': type,
      if (pool != null) 'resourcePool': pool,
      if (cost != null) 'consumption': cost,
      if (economy != null) 'actionEconomy': economy,
      if (icon != null) 'iconName': icon,
    };

Map<String, dynamic> _pool(int uses, String recovery) =>
    {'currentUses': uses, 'maxUses': uses, 'recoveryType': recovery};

ClassData _runeGuard() => ClassData.fromJson({
      'id': _classId,
      'name': {'ru': 'Рунный страж', 'en': 'Rune Guard'},
      'description': {
        'ru': 'Сторонний класс: воин, вырезающий руны на оружии и доспехах.',
        'en': 'A third-party class: a warrior who carves runes into arms and armour.'
      },
      'hitDie': 10,
      'primaryAbilities': ['strength', 'wisdom'],
      'savingThrowProficiencies': ['strength', 'constitution'],
      'armorProficiencies': {'light': true, 'medium': true, 'heavy': true, 'shields': true},
      'weaponProficiencies': {'simple': true, 'martial': true},
      'skillProficiencies': {
        'choose': 2,
        'from': ['athletics', 'history', 'insight', 'perception']
      },
      'subclasses': [
        {
          'id': 'oath-of-stone',
          'name': {'ru': 'Клятва камня', 'en': 'Oath of Stone'},
          'description': {'ru': 'Руны камня делают стража неподвижной горой.', 'en': 'Runes of stone make the guard an unmoving mountain.'}
        }
      ],
      'subclassLevel': 3,
      'features': {
        '1': [
          _feature('rune-guard-runes', 'Руны', 'Runes',
              'Вырежьте руну на оружии или доспехе — она питает умения ниже. Число рун: 2 на 1 уровне, 3 на 3, 4 на 7, 5 на 13, 6 на 18. Руны возвращаются после короткого или длительного отдыха.',
              'Carve a rune into a weapon or armour; it powers the abilities below. Runes: 2 at level 1, 3 at 3, 4 at 7, 5 at 13, 6 at 18. They return on a short or long rest.',
              type: 'resource_pool', pool: _pool(3, 'shortRest'), icon: 'rune'),
          _feature('rune-guard-rune-strike', 'Рунный удар', 'Rune Strike',
              'При попадании оружием потратьте руну: цель получает дополнительно 2к6 силового урона.',
              'When you hit with a weapon, spend a rune: the target takes an extra 2d6 force damage.',
              type: 'action', cost: {'resourceId': 'rune-guard-runes', 'amount': 1}, economy: 'free'),
          _feature('rune-guard-stone-weight', 'Тяжесть камня', 'Weight of Stone',
              'Преимущество на спасброски и проверки против того, чтобы вас сбили с ног или переместили против воли.',
              'Advantage on saves and checks against being knocked prone or moved against your will.',
              icon: 'shield'),
          _feature('rune-guard-rune-reading', 'Чтение рун', 'Rune Reading',
              'Вы понимаете любые письмена, если касаетесь их.', 'You understand any writing you touch.',
              icon: 'book'),
        ],
        '2': [
          _feature('rune-guard-stone-skin', 'Каменная кожа', 'Stone Skin',
              'Реакцией поглотите урон из запаса каменной кожи. Запас равен уровню стража × 3 и восстанавливается после длительного отдыха.',
              'As a reaction, absorb damage from your stone skin reserve. The reserve equals your level × 3 and returns on a long rest.',
              type: 'resource_pool', pool: {..._pool(15, 'longRest'), 'calculationFormula': 'level * 3'}, economy: 'reaction'),
        ],
        '3': [
          _feature('rune-guard-ward', 'Оберег', 'Ward',
              'Бонусным действием потратьте руну: союзники в 10 фт. от вас получают +2 к КД на минуту (10 раундов).',
              'As a bonus action, spend a rune: allies within 10 ft. gain +2 AC for a minute (10 rounds).',
              type: 'toggle', cost: {'resourceId': 'rune-guard-runes', 'amount': 1}, economy: 'bonus_action', icon: 'shield'),
        ],
        '11': [
          _feature('rune-guard-living-mountain', 'Живая гора', 'Living Mountain',
              'Сопротивление дробящему урону.', 'Resistance to bludgeoning damage.', icon: 'peaks'),
        ],
      },
    });

Character buildCustomClassCycleCharacter() {
  final data = _runeGuard();
  final rules = CharacterClassRules.capture(data);
  const level = 5;
  final features = [
    for (final entry in data.features.entries)
      for (final f in entry.value) f,
  ]..sort((a, b) => a.minLevel.compareTo(b.minLevel));
  return Character(
    id: customClassCycleId,
    name: 'Cycle · Свой класс',
    race: 'human',
    background: 'soldier',
    characterClass: _classId,
    subclass: 'oath-of-stone',
    level: level,
    maxHp: 47,
    currentHp: 47,
    abilityScores: AbilityScores(strength: 16, dexterity: 12, constitution: 15, intelligence: 10, wisdom: 14, charisma: 9),
    spellSlots: const [],
    maxSpellSlots: const [],
    classes: [
      CharacterClass(
          id: _classId,
          name: 'Rune Guard',
          level: level,
          subclass: 'oath-of-stone',
          isPrimary: true,
          rulesSnapshot: rules.snapshot)
    ],
    proficientSkills: ['athletics', 'perception'],
    savingThrowProficiencies: ['strength', 'constitution'],
    knownSpells: [],
    preparedSpells: [],
    maxPreparedSpells: 0,
    features: features,
  )
    ..hitDice = [level]
    ..maxHitDice = level
    ..backstory = 'Тестовый персонаж стороннего класса: заряды, запас, кости, режим и пассивы '
        'собраны из данных и рисуются универсальным набором.';
}
