import 'package:hive/hive.dart';

part 'spell.g.dart';

@HiveType(typeId: 2)
class Spell extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nameEn;

  @HiveField(2)
  String nameRu;

  @HiveField(3)
  int level; // 0 = cantrip, 1-9 = spell level

  @HiveField(4)
  String school; // Abjuration, Conjuration, etc.

  @HiveField(5)
  String castingTime;

  @HiveField(6)
  String range;

  @HiveField(7)
  String duration;

  @HiveField(8)
  bool concentration;

  @HiveField(9)
  bool ritual;

  @HiveField(10)
  List<String> components; // V, S, M

  @HiveField(11)
  String? materialComponents;
  
  @HiveField(17)
  String? materialComponentsRu;

  @HiveField(12)
  String descriptionEn;

  @HiveField(13)
  String descriptionRu;

  @HiveField(14)
  List<String> availableToClasses;

  @HiveField(15)
  String? atHigherLevelsEn;
  
  @HiveField(16)
  String? atHigherLevelsRu;

  Spell({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.range,
    required this.duration,
    required this.concentration,
    required this.ritual,
    required this.components,
    this.materialComponents,
    this.materialComponentsRu,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.availableToClasses,
    this.atHigherLevelsEn,
    this.atHigherLevelsRu,
  });

  String getName(String locale) {
    return locale == 'ru' ? nameRu : nameEn;
  }

  String getDescription(String locale) {
    return locale == 'ru' ? descriptionRu : descriptionEn;
  }
  
  String? getAtHigherLevels(String locale) {
    return locale == 'ru' ? atHigherLevelsRu : atHigherLevelsEn;
  }

  String? getMaterialComponents(String locale) {
    return locale == 'ru' ? materialComponentsRu : materialComponents;
  }

  String get levelText {
    if (level == 0) return 'Cantrip';
    return 'Level $level';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameRu': nameRu,
      'level': level,
      'school': school,
      'castingTime': castingTime,
      'range': range,
      'duration': duration,
      'concentration': concentration,
      'ritual': ritual,
      'components': components,
      'materialComponents': materialComponents,
      'materialComponentsRu': materialComponentsRu,
      'descriptionEn': descriptionEn,
      'descriptionRu': descriptionRu,
      'availableToClasses': availableToClasses,
      'atHigherLevelsEn': atHigherLevelsEn,
      'atHigherLevelsRu': atHigherLevelsRu,
    };
  }

  factory Spell.fromJson(Map<String, dynamic> json) {
    return Spell(
      id: json['id'],
      nameEn: json['nameEn'],
      nameRu: json['nameRu'],
      level: json['level'],
      school: json['school'],
      castingTime: json['castingTime'],
      range: json['range'],
      duration: json['duration'],
      concentration: json['concentration'] ?? false,
      ritual: json['ritual'] ?? false,
      components: List<String>.from(json['components'] ?? []),
      materialComponents: json['materialComponents'],
      materialComponentsRu: json['materialComponentsRu'],
      descriptionEn: json['descriptionEn'],
      descriptionRu: json['descriptionRu'],
      availableToClasses: List<String>.from(json['availableToClasses'] ?? []),
      atHigherLevelsEn: json['atHigherLevelsEn'] ?? json['atHigherLevels'], // Fallback for old key
      atHigherLevelsRu: json['atHigherLevelsRu'],
    );
  }
}
