import '../models/ability_scores.dart';
import '../models/background_data.dart';
import '../models/character.dart';
import '../models/character_class.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/combat_state.dart';
import '../models/condition.dart';
import '../models/death_saves.dart';
import '../models/item.dart';
import '../models/journal_note.dart';
import '../models/quest.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'qdnd_bundle_schema.dart';

class QdndBundleCodec {
  static Map<String, dynamic> characterToJson(Character character) {
    return {
      'id': character.id,
      'name': character.name,
      'avatarPath': character.avatarPath,
      'race': character.race,
      'characterClass': character.characterClass,
      'subclass': character.subclass,
      'level': character.level,
      'maxHp': character.maxHp,
      'currentHp': character.currentHp,
      'temporaryHp': character.temporaryHp,
      'abilityScores': character.abilityScores.toJson(),
      'background': character.background,
      'spellSlots': List<int>.from(character.spellSlots),
      'maxSpellSlots': List<int>.from(character.maxSpellSlots),
      'armorClass': character.armorClass,
      'speed': character.speed,
      'initiative': character.initiative,
      'proficientSkills': List<String>.from(character.proficientSkills),
      'savingThrowProficiencies':
          List<String>.from(character.savingThrowProficiencies),
      'personalityTraits': character.personalityTraits,
      'ideals': character.ideals,
      'bonds': character.bonds,
      'flaws': character.flaws,
      'backstory': character.backstory,
      'createdAt': character.createdAt.toIso8601String(),
      'updatedAt': character.updatedAt.toIso8601String(),
      'appearance': character.appearance,
      'knownSpells': List<String>.from(character.knownSpells),
      'preparedSpells': List<String>.from(character.preparedSpells),
      'maxPreparedSpells': character.maxPreparedSpells,
      'features': character.features
          .map((feature) => featureToJson(
                feature,
                policy: feature.sourceId == null
                    ? QdndBundleExportPolicy.snapshotOnly
                    : QdndBundleExportPolicy.referenceOnly,
              ))
          .toList(),
      'inventory': character.inventory
          .map((item) => itemToJson(
                item,
                policy: item.sourceId == null
                    ? QdndBundleExportPolicy.snapshotOnly
                    : QdndBundleExportPolicy.referenceOnly,
              ))
          .toList(),
      'combatState': character.combatState.toJson(),
      'deathSaves': character.deathSaves.toJson(),
      'activeConditions': character.activeConditions
          .map((condition) => condition.name)
          .toList(),
      'concentratingOn': character.concentratingOn,
      'hitDice': List<int>.from(character.hitDice),
      'maxHitDice': character.maxHitDice,
      'age': character.age,
      'gender': character.gender,
      'height': character.height,
      'weight': character.weight,
      'eyes': character.eyes,
      'hair': character.hair,
      'skin': character.skin,
      'appearanceDescription': character.appearanceDescription,
      'copperPieces': character.copperPieces,
      'silverPieces': character.silverPieces,
      'goldPieces': character.goldPieces,
      'platinumPieces': character.platinumPieces,
      'journalNotes':
          character.journalNotes.map((note) => note.toJson()).toList(),
      'quests': character.quests.map((quest) => quest.toJson()).toList(),
      'classes': character.classes.map((cls) => cls.toJson()).toList(),
      'expertSkills': List<String>.from(character.expertSkills),
      'wildShapeCharges': character.wildShapeCharges,
      'naturalRecoveryUsed': character.naturalRecoveryUsed,
      'isWildShaped': character.isWildShaped,
      'arcaneRecoveryUsed': character.arcaneRecoveryUsed,
      'spellMasterySpells': List<String>.from(character.spellMasterySpells),
      'signatureSpells': List<String>.from(character.signatureSpells),
      'signatureSpellsUsed': Map<String, bool>.from(
        character.signatureSpellsUsed,
      ),
      'channelDivinityCharges': character.channelDivinityCharges,
      'divineInterventionUsed': character.divineInterventionUsed,
      'favoredEnemies': List<String>.from(character.favoredEnemies),
      'naturalExplorers': List<String>.from(character.naturalExplorers),
      'beastName': character.beastName,
      'beastMaxHp': character.beastMaxHp,
      'beastCurrentHp': character.beastCurrentHp,
      'beastIcon': character.beastIcon,
      'isHuntersMarkActive': character.isHuntersMarkActive,
      'huntersMarkTarget': character.huntersMarkTarget,
      'isHiddenInPlainSight': character.isHiddenInPlainSight,
      'relentlessRageSaveDc': character.relentlessRageSaveDc,
      'isRaging': character.isRaging,
      'exhaustionLevel': character.exhaustionLevel,
    };
  }

  static Character characterFromJson(Map<String, dynamic> json) {
    final characterJson = _map(json['character']) ?? json;
    final level = _int(characterJson['level'], fallback: 1);

    return Character(
      id: characterJson['id'] as String? ?? '',
      name: characterJson['name'] as String? ?? 'Imported Character',
      avatarPath: characterJson['avatarPath'] as String?,
      race: characterJson['race'] as String? ?? 'Human',
      characterClass: characterJson['characterClass'] as String? ?? 'Fighter',
      subclass: characterJson['subclass'] as String?,
      level: level,
      maxHp: _int(characterJson['maxHp'], fallback: 1),
      currentHp: _int(characterJson['currentHp'], fallback: 1),
      temporaryHp: _int(characterJson['temporaryHp']),
      abilityScores: AbilityScores.fromJson(
        _map(characterJson['abilityScores']) ?? const {},
      ),
      background: characterJson['background'] as String?,
      spellSlots: _intList(characterJson['spellSlots'], minLength: 9),
      maxSpellSlots: _intList(characterJson['maxSpellSlots'], minLength: 9),
      armorClass: _int(characterJson['armorClass'], fallback: 10),
      speed: _int(characterJson['speed'], fallback: 30),
      initiative: _int(characterJson['initiative']),
      proficientSkills: _stringList(characterJson['proficientSkills']),
      savingThrowProficiencies:
          _stringList(characterJson['savingThrowProficiencies']),
      personalityTraits: characterJson['personalityTraits'] as String?,
      ideals: characterJson['ideals'] as String?,
      bonds: characterJson['bonds'] as String?,
      flaws: characterJson['flaws'] as String?,
      backstory: characterJson['backstory'] as String?,
      createdAt: _date(characterJson['createdAt']),
      updatedAt: _date(characterJson['updatedAt']),
      appearance: characterJson['appearance'] as String?,
      knownSpells: _stringList(characterJson['knownSpells']),
      preparedSpells: _stringList(characterJson['preparedSpells']),
      maxPreparedSpells: _int(characterJson['maxPreparedSpells']),
      features: _mapList(characterJson['features'])
          .map(CharacterFeature.fromJson)
          .toList(),
      inventory:
          _mapList(characterJson['inventory']).map(Item.fromJson).toList(),
      combatState: CombatState.fromJson(
        _map(characterJson['combatState']) ?? const {},
      ),
      deathSaves: DeathSaves.fromJson(
        _map(characterJson['deathSaves']) ?? const {},
      ),
      activeConditions: _stringList(characterJson['activeConditions'])
          .map(_conditionFromName)
          .whereType<ConditionType>()
          .toList(),
      concentratingOn: characterJson['concentratingOn'] as String?,
      hitDice: _intList(characterJson['hitDice'], fallback: [level]),
      maxHitDice: _int(characterJson['maxHitDice'], fallback: level),
      age: characterJson['age'] as String?,
      gender: characterJson['gender'] as String?,
      height: characterJson['height'] as String?,
      weight: characterJson['weight'] as String?,
      eyes: characterJson['eyes'] as String?,
      hair: characterJson['hair'] as String?,
      skin: characterJson['skin'] as String?,
      appearanceDescription: characterJson['appearanceDescription'] as String?,
      copperPieces: _int(characterJson['copperPieces']),
      silverPieces: _int(characterJson['silverPieces']),
      goldPieces: _int(characterJson['goldPieces']),
      platinumPieces: _int(characterJson['platinumPieces']),
      journalNotes: _mapList(characterJson['journalNotes'])
          .map(JournalNote.fromJson)
          .toList(),
      quests: _mapList(characterJson['quests']).map(Quest.fromJson).toList(),
      classes: _mapList(characterJson['classes'])
          .map(CharacterClass.fromJson)
          .toList(),
      expertSkills: _stringList(characterJson['expertSkills']),
      wildShapeCharges: _int(characterJson['wildShapeCharges'], fallback: 2),
      naturalRecoveryUsed: characterJson['naturalRecoveryUsed'] == true,
      isWildShaped: characterJson['isWildShaped'] == true,
      arcaneRecoveryUsed: characterJson['arcaneRecoveryUsed'] == true,
      spellMasterySpells: _stringList(characterJson['spellMasterySpells']),
      signatureSpells: _stringList(characterJson['signatureSpells']),
      signatureSpellsUsed: Map<String, bool>.from(
        _map(characterJson['signatureSpellsUsed']) ?? const {},
      ),
      channelDivinityCharges: _int(characterJson['channelDivinityCharges']),
      divineInterventionUsed: characterJson['divineInterventionUsed'] == true,
      favoredEnemies: _stringList(characterJson['favoredEnemies']),
      naturalExplorers: _stringList(characterJson['naturalExplorers']),
      beastName: characterJson['beastName'] as String?,
      beastMaxHp: characterJson['beastMaxHp'] as int?,
      beastCurrentHp: characterJson['beastCurrentHp'] as int?,
      beastIcon: characterJson['beastIcon'] as String?,
      isHuntersMarkActive: characterJson['isHuntersMarkActive'] == true,
      huntersMarkTarget: characterJson['huntersMarkTarget'] as String?,
      isHiddenInPlainSight: characterJson['isHiddenInPlainSight'] == true,
      relentlessRageSaveDc: _int(
        characterJson['relentlessRageSaveDc'],
        fallback: 10,
      ),
      isRaging: characterJson['isRaging'] == true,
      exhaustionLevel: _int(characterJson['exhaustionLevel']),
    );
  }

  static Map<String, dynamic> itemToJson(
    Item item, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    final json = Map<String, dynamic>.from(item.toJson());
    json['exportPolicy'] = policy.name;
    if (policy == QdndBundleExportPolicy.referenceOnly) {
      json['descriptionEn'] = '';
      json['descriptionRu'] = '';
      json['customImagePath'] = null;
    }
    return json;
  }

  static Map<String, dynamic> spellToJson(
    Spell spell, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    final json = Map<String, dynamic>.from(spell.toJson());
    json['exportPolicy'] = policy.name;
    if (policy == QdndBundleExportPolicy.referenceOnly) {
      json['descriptionEn'] = '';
      json['descriptionRu'] = '';
      json['materialComponents'] = null;
      json['materialComponentsRu'] = null;
      json['atHigherLevelsEn'] = null;
      json['atHigherLevelsRu'] = null;
    }
    return json;
  }

  static Map<String, dynamic> featureToJson(
    CharacterFeature feature, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    final json = Map<String, dynamic>.from(feature.toJson());
    json['sourceId'] = feature.sourceId;
    json['exportPolicy'] = policy.name;
    if (policy == QdndBundleExportPolicy.referenceOnly) {
      json['descriptionEn'] = '';
      json['descriptionRu'] = '';
    }
    return json;
  }

  static Map<String, dynamic> raceToJson(
    RaceData race, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    return {
      'exportPolicy': policy.name,
      'id': race.id,
      'name': race.name,
      'description': policy == QdndBundleExportPolicy.referenceOnly
          ? {'en': '', 'ru': ''}
          : race.description,
      'speed': race.speed,
      'abilityScoreIncreases': race.abilityScoreIncreases,
      'languages': race.languages,
      'proficiencies': race.proficiencies,
      'traits': race.traits.map(featureToJson).toList(),
      'subraces': race.subraces.map(subraceToJson).toList(),
      'size': race.size,
      'sourceId': race.sourceId,
    };
  }

  static RaceData raceFromJson(Map<String, dynamic> json) {
    return RaceData(
      id: json['id'] as String? ?? '',
      name: Map<String, String>.from(_map(json['name']) ?? const {}),
      description:
          Map<String, String>.from(_map(json['description']) ?? const {}),
      speed: _int(json['speed'], fallback: 30),
      abilityScoreIncreases: Map<String, int>.from(
          _map(json['abilityScoreIncreases']) ?? const {}),
      languages: _stringList(json['languages']),
      proficiencies: _stringList(json['proficiencies']),
      traits: _mapList(json['traits']).map(CharacterFeature.fromJson).toList(),
      subraces: _mapList(json['subraces']).map(subraceFromJson).toList(),
      size: json['size'] as String? ?? 'Medium',
      sourceId: json['sourceId'] as String?,
    );
  }

  static Map<String, dynamic> subraceToJson(SubraceData subrace) {
    return {
      'id': subrace.id,
      'name': subrace.name,
      'additionalAbilityScores': subrace.additionalAbilityScores,
      'additionalTraits': subrace.additionalTraits.map(featureToJson).toList(),
    };
  }

  static SubraceData subraceFromJson(Map<String, dynamic> json) {
    return SubraceData(
      id: json['id'] as String? ?? '',
      name: Map<String, String>.from(_map(json['name']) ?? const {}),
      additionalAbilityScores: Map<String, int>.from(
          _map(json['additionalAbilityScores']) ?? const {}),
      additionalTraits: _mapList(json['additionalTraits'])
          .map(CharacterFeature.fromJson)
          .toList(),
    );
  }

  static Map<String, dynamic> classToJson(
    ClassData classData, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    return {
      'exportPolicy': policy.name,
      'id': classData.id,
      'name': classData.name,
      'description': policy == QdndBundleExportPolicy.referenceOnly
          ? {'en': '', 'ru': ''}
          : classData.description,
      'hitDie': classData.hitDie,
      'primaryAbilities': classData.primaryAbilities,
      'savingThrowProficiencies': classData.savingThrowProficiencies,
      'armorProficiencies': armorProficienciesToJson(
        classData.armorProficiencies,
      ),
      'weaponProficiencies': weaponProficienciesToJson(
        classData.weaponProficiencies,
      ),
      'skillProficiencies': skillProficienciesToJson(
        classData.skillProficiencies,
      ),
      'subclasses': classData.subclasses.map(subclassToJson).toList(),
      'subclassLevel': classData.subclassLevel,
      'spellcasting': classData.spellcasting == null
          ? null
          : spellcastingToJson(classData.spellcasting!),
      'features': classData.features.map(
        (level, features) => MapEntry(
          '$level',
          features.map(featureToJson).toList(),
        ),
      ),
      'sourceId': classData.sourceId,
    };
  }

  static ClassData classFromJson(Map<String, dynamic> json) {
    return ClassData(
      id: json['id'] as String? ?? '',
      name: Map<String, String>.from(_map(json['name']) ?? const {}),
      description:
          Map<String, String>.from(_map(json['description']) ?? const {}),
      hitDie: _int(json['hitDie'], fallback: 8),
      primaryAbilities: _stringList(json['primaryAbilities']),
      savingThrowProficiencies: _stringList(json['savingThrowProficiencies']),
      armorProficiencies: ArmorProficiencies.fromJson(
        _map(json['armorProficiencies']) ?? const {},
      ),
      weaponProficiencies: WeaponProficiencies.fromJson(
        _map(json['weaponProficiencies']) ?? const {},
      ),
      skillProficiencies: SkillProficiencies.fromJson(
        _map(json['skillProficiencies']) ?? const {'choose': 0, 'from': []},
      ),
      subclasses:
          _mapList(json['subclasses']).map(SubclassData.fromJson).toList(),
      subclassLevel: _int(json['subclassLevel'], fallback: 1),
      spellcasting: json['spellcasting'] == null
          ? null
          : SpellcastingInfo.fromJson(_map(json['spellcasting'])!),
      features: _classFeaturesFromJson(_map(json['features']) ?? const {}),
      sourceId: json['sourceId'] as String?,
    );
  }

  static Map<String, dynamic> backgroundToJson(
    BackgroundData background, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    return {
      'exportPolicy': policy.name,
      'id': background.id,
      'name': background.name,
      'description': policy == QdndBundleExportPolicy.referenceOnly
          ? {'en': '', 'ru': ''}
          : background.description,
      'skillProficiencies': background.skillProficiencies,
      'toolProficiencies': background.toolProficiencies,
      'languages': background.languages,
      'feature': backgroundFeatureToJson(background.feature, policy: policy),
      'equipment': background.equipment,
      'sourceId': background.sourceId,
    };
  }

  static BackgroundData backgroundFromJson(Map<String, dynamic> json) {
    return BackgroundData(
      id: json['id'] as String? ?? '',
      name: Map<String, String>.from(_map(json['name']) ?? const {}),
      description:
          Map<String, String>.from(_map(json['description']) ?? const {}),
      skillProficiencies: _stringList(json['skillProficiencies']),
      toolProficiencies: _stringListMap(json['toolProficiencies']),
      languages: _int(json['languages']),
      feature: BackgroundFeature.fromJson(
        _map(json['feature']) ??
            const {
              'name': {'en': '', 'ru': ''},
              'description': {'en': '', 'ru': ''},
            },
      ),
      equipment: _stringListMap(json['equipment']),
      sourceId: json['sourceId'] as String?,
    );
  }

  static Map<String, dynamic> backgroundFeatureToJson(
    BackgroundFeature feature, {
    QdndBundleExportPolicy policy = QdndBundleExportPolicy.embedded,
  }) {
    return {
      'name': feature.name,
      'description': policy == QdndBundleExportPolicy.referenceOnly
          ? {'en': '', 'ru': ''}
          : feature.description,
    };
  }

  static Map<String, dynamic> armorProficienciesToJson(
    ArmorProficiencies proficiencies,
  ) {
    return {
      'light': proficiencies.light,
      'medium': proficiencies.medium,
      'heavy': proficiencies.heavy,
      'shields': proficiencies.shields,
    };
  }

  static Map<String, dynamic> weaponProficienciesToJson(
    WeaponProficiencies proficiencies,
  ) {
    return {
      'simple': proficiencies.simple,
      'martial': proficiencies.martial,
      'specific': proficiencies.specific,
    };
  }

  static Map<String, dynamic> skillProficienciesToJson(
    SkillProficiencies proficiencies,
  ) {
    return {
      'choose': proficiencies.choose,
      'from': proficiencies.from,
    };
  }

  static Map<String, dynamic> subclassToJson(SubclassData subclass) {
    return {
      'id': subclass.id,
      'name': subclass.name,
      'description': subclass.description,
    };
  }

  static Map<String, dynamic> spellcastingToJson(
    SpellcastingInfo spellcasting,
  ) {
    return {
      'ability': spellcasting.ability,
      'type': spellcasting.type,
    };
  }

  static Map<int, List<CharacterFeature>> _classFeaturesFromJson(
    Map<String, dynamic> json,
  ) {
    final features = <int, List<CharacterFeature>>{};
    for (final entry in json.entries) {
      final level = int.tryParse(entry.key);
      if (level == null) continue;
      features[level] =
          _mapList(entry.value).map(CharacterFeature.fromJson).toList();
    }
    return features;
  }

  static List<int> _intList(
    Object? value, {
    int minLength = 0,
    List<int>? fallback,
  }) {
    final result = value is List
        ? value.map((entry) => _int(entry)).toList()
        : List<int>.from(fallback ?? const []);
    while (result.length < minLength) {
      result.add(0);
    }
    return result;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return [];
    return value.map((entry) => entry.toString()).toList();
  }

  static Map<String, List<String>> _stringListMap(Object? value) {
    final map = _map(value);
    if (map == null) return {};
    return map.map(
      (key, entry) => MapEntry(
        key,
        entry is List ? entry.map((item) => item.toString()).toList() : [],
      ),
    );
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static ConditionType? _conditionFromName(String value) {
    return ConditionType.values.cast<ConditionType?>().firstWhere(
          (condition) => condition?.name == value,
          orElse: () => null,
        );
  }
}
