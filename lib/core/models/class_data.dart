import 'package:hive/hive.dart';
import 'package:xml/xml.dart';
import 'character_feature.dart';

part 'class_data.g.dart';

@HiveType(typeId: 33)
class ClassData {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, String> name;

  @HiveField(2)
  final Map<String, String> description;

  @HiveField(3)
  final int hitDie;

  @HiveField(4)
  final List<String> primaryAbilities;

  @HiveField(5)
  final List<String> savingThrowProficiencies;

  @HiveField(6)
  final ArmorProficiencies armorProficiencies;

  @HiveField(7)
  final WeaponProficiencies weaponProficiencies;

  @HiveField(8)
  final SkillProficiencies skillProficiencies;

  @HiveField(9)
  final List<SubclassData> subclasses;

  @HiveField(10)
  final int subclassLevel; // At what level you choose subclass

  @HiveField(11)
  final SpellcastingInfo? spellcasting;

  @HiveField(12)
  final Map<int, List<CharacterFeature>> features;

  @HiveField(13)
  final String? sourceId;

  /// Presence and provenance are separate from compatibility defaults.
  @HiveField(14, defaultValue: {})
  final Map<String, dynamic> rulesMetadata;

  @HiveField(15)
  final String? sourceDefinition;

  bool declares(String field) => rulesMetadata['declaredFields'] is List
      ? (rulesMetadata['declaredFields'] as List).contains(field)
      : sourceId == null;
  String get rulesEdition => rulesMetadata['edition'] as String? ?? 'unknown';

  /// Whether heroes can be built on these rules yet: the 2014 engine, or a
  /// book that does not say.
  ///
  /// TEMPORARY STOPGAP: the app has no built-in 2024 rules yet, so a class a
  /// book marks as 2024 can be listed but not played. When SRD 5.2 (2024) is
  /// built in, with the player's choice of edition, this check goes: replace
  /// it with the chosen edition, and drop the guards that use it (Prologue
  /// class pick, hero reconciliation, shelf leads). See
  /// docs/WORKING_VERSION_TODO.md, «Временная затычка 2024».
  bool get rulesPlayable => rulesEdition == 'unknown' || rulesEdition == '2014';

  ClassData({
    required this.id,
    required this.name,
    required this.description,
    required this.hitDie,
    required this.primaryAbilities,
    required this.savingThrowProficiencies,
    required this.armorProficiencies,
    required this.weaponProficiencies,
    required this.skillProficiencies,
    required this.subclasses,
    required this.subclassLevel,
    this.spellcasting,
    this.features = const {},
    this.sourceId,
    this.rulesMetadata = const {},
    this.sourceDefinition,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }

  factory ClassData.fromJson(Map<String, dynamic> json) {
    return ClassData(
      id: json['id'],
      name: Map<String, String>.from(json['name']),
      description: Map<String, String>.from(json['description']),
      hitDie: json['hitDie'],
      primaryAbilities: List<String>.from(json['primaryAbilities']),
      savingThrowProficiencies:
          List<String>.from(json['savingThrowProficiencies']),
      armorProficiencies:
          ArmorProficiencies.fromJson(json['armorProficiencies']),
      weaponProficiencies:
          WeaponProficiencies.fromJson(json['weaponProficiencies']),
      skillProficiencies:
          SkillProficiencies.fromJson(json['skillProficiencies']),
      subclasses: (json['subclasses'] as List)
          .map((s) => SubclassData.fromJson(s))
          .toList(),
      subclassLevel: json['subclassLevel'] ?? 1,
      spellcasting: json['spellcasting'] != null
          ? SpellcastingInfo.fromJson(json['spellcasting'])
          : null,
      features: _featuresFromJson(json['features'], json['id']),
      sourceId: json['sourceId'],
      rulesMetadata:
          Map<String, dynamic>.from(json['rulesMetadata'] as Map? ?? const {}),
      sourceDefinition: json['sourceDefinition'] as String?,
    );
  }

  static Map<int, List<CharacterFeature>> _featuresFromJson(
      dynamic value, String classId) {
    if (value == null) return {};
    if (value is! Map) {
      throw const FormatException('Class features must be a level map.');
    }
    final result = <int, List<CharacterFeature>>{};
    for (final entry in value.entries) {
      final level = int.tryParse(entry.key.toString());
      if (level == null ||
          level < 1 ||
          level > 20 ||
          result.containsKey(level) ||
          entry.value is! List) {
        throw FormatException('Invalid class feature level: ${entry.key}');
      }
      final ids = <String>{};
      result[level] = (entry.value as List).map((raw) {
        if (raw is! Map) {
          throw const FormatException('Class feature must be an object.');
        }
        final data = Map<String, dynamic>.from(raw);
        final name = data['name'] as Map?;
        final description = data['description'] as Map?;
        data['nameEn'] ??= name?['en'] ?? name?['ru'] ?? data['id'];
        data['nameRu'] ??= name?['ru'] ?? name?['en'] ?? data['id'];
        data['descriptionEn'] ??=
            description?['en'] ?? description?['ru'] ?? '';
        data['descriptionRu'] ??=
            description?['ru'] ?? description?['en'] ?? '';
        data['minLevel'] ??= level;
        data['associatedClass'] ??= classId;
        if (data['minLevel'] != level ||
            data['id'] is! String ||
            (data['id'] as String).isEmpty ||
            !ids.add(data['id'])) {
          throw FormatException(
              'Invalid or repeated class feature: ${data['id']}');
        }
        return CharacterFeature.fromJson(data);
      }).toList();
    }
    return result;
  }

  factory ClassData.fromFC5(XmlElement element, String sourceId) {
    final name = element.findElements('name').first.innerText;
    final hdStr = element.findElements('hd').firstOrNull?.innerText ?? '8';
    final hitDie = int.tryParse(hdStr) ?? 8;

    // Parse proficiencies is complex, simplifying for now
    final primaryAbilities = <String>[];

    final features = <int, List<CharacterFeature>>{};

    for (var autolevel in element.findElements('autolevel')) {
      final levelStr = autolevel.getAttribute('level');
      if (levelStr == null) continue;
      final level = int.tryParse(levelStr) ?? 0;
      if (level == 0) continue;

      if (!features.containsKey(level)) {
        features[level] = [];
      }

      // Skip subclasses for now in features map, they are usually separate
      if (autolevel.findElements('subclass').isNotEmpty) continue;

      for (var feature in autolevel.findElements('feature')) {
        final featureName =
            feature.findElements('name').firstOrNull?.innerText ?? '';
        final featureText =
            feature.findElements('text').map((e) => e.innerText).join('\n');

        if (featureName.isNotEmpty) {
          features[level]!.add(CharacterFeature(
            id: 'fc5_cls_${name.toLowerCase()}_${featureName.toLowerCase().replaceAll(' ', '_')}_$level',
            nameEn: featureName,
            nameRu: featureName,
            descriptionEn: featureText,
            descriptionRu: featureText,
            type: FeatureType.passive,
            minLevel: level,
            associatedClass: name,
            sourceId: sourceId,
          ));
        }
      }
    }

    return ClassData(
      id: name.toLowerCase().replaceAll(' ', '_'),
      name: {'en': name, 'ru': name},
      description: {'en': 'Imported from FC5', 'ru': 'Импортировано из FC5'},
      hitDie: hitDie,
      primaryAbilities: primaryAbilities,
      savingThrowProficiencies: [],
      armorProficiencies: ArmorProficiencies(),
      weaponProficiencies: WeaponProficiencies(),
      skillProficiencies: SkillProficiencies(choose: 0, from: []),
      subclasses: [],
      subclassLevel: 3,
      features: features,
      sourceId: sourceId,
      rulesMetadata: {
        'edition': 'unknown',
        'declaredFields': [
          if (element.findElements('hd').isNotEmpty) 'hitDie',
        ]
      },
      sourceDefinition: element.toXmlString(),
    );
  }
}

@HiveType(typeId: 35)
class ArmorProficiencies {
  @HiveField(0)
  final bool light;

  @HiveField(1)
  final bool medium;

  @HiveField(2)
  final bool heavy;

  @HiveField(3)
  final bool shields;

  ArmorProficiencies({
    this.light = false,
    this.medium = false,
    this.heavy = false,
    this.shields = false,
  });

  factory ArmorProficiencies.fromJson(Map<String, dynamic> json) {
    return ArmorProficiencies(
      light: json['light'] ?? false,
      medium: json['medium'] ?? false,
      heavy: json['heavy'] ?? false,
      shields: json['shields'] ?? false,
    );
  }

  bool get isNotEmpty => light || medium || heavy || shields;

  List<String> toList() {
    final list = <String>[];
    if (light) list.add('Light Armor');
    if (medium) list.add('Medium Armor');
    if (heavy) list.add('Heavy Armor');
    if (shields) list.add('Shields');
    return list;
  }
}

@HiveType(typeId: 36)
class WeaponProficiencies {
  @HiveField(0)
  final bool simple;

  @HiveField(1)
  final bool martial;

  @HiveField(2)
  final List<String> specific; // e.g., ["longsword", "shortsword"]

  WeaponProficiencies({
    this.simple = false,
    this.martial = false,
    this.specific = const [],
  });

  factory WeaponProficiencies.fromJson(Map<String, dynamic> json) {
    return WeaponProficiencies(
      simple: json['simple'] ?? false,
      martial: json['martial'] ?? false,
      specific: List<String>.from(json['specific'] ?? []),
    );
  }

  bool get isNotEmpty => simple || martial || specific.isNotEmpty;

  List<String> toList() {
    final list = <String>[];
    if (simple) list.add('Simple Weapons');
    if (martial) list.add('Martial Weapons');
    if (specific.isNotEmpty) list.addAll(specific);
    return list;
  }
}

@HiveType(typeId: 37)
class SkillProficiencies {
  @HiveField(0)
  final int choose;

  @HiveField(1)
  final List<String> from;

  SkillProficiencies({
    required this.choose,
    required this.from,
  });

  factory SkillProficiencies.fromJson(Map<String, dynamic> json) {
    return SkillProficiencies(
      choose: json['choose'],
      from: List<String>.from(json['from']),
    );
  }

  bool get isNotEmpty => from.isNotEmpty;
}

@HiveType(typeId: 34)
class SubclassData {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, String> name;

  @HiveField(2)
  final Map<String, String> description;

  SubclassData({
    required this.id,
    required this.name,
    required this.description,
  });

  String getName(String locale) {
    return name[locale] ?? name['en'] ?? id;
  }

  String getDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }

  factory SubclassData.fromJson(Map<String, dynamic> json) {
    return SubclassData(
      id: json['id'],
      name: Map<String, String>.from(json['name']),
      description: Map<String, String>.from(json['description']),
    );
  }
}

@HiveType(typeId: 38)
class SpellcastingInfo {
  @HiveField(0)
  final String ability; // 'intelligence', 'wisdom', 'charisma'

  @HiveField(1)
  final String type; // 'full', 'half', 'third', 'pact'

  SpellcastingInfo({
    required this.ability,
    required this.type,
  });

  factory SpellcastingInfo.fromJson(Map<String, dynamic> json) {
    return SpellcastingInfo(
      ability: json['ability'],
      type: json['type'],
    );
  }

  bool get isPactMagic => type == 'pact';
}
