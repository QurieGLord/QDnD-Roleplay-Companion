class ClassData {
  final String id;
  final Map<String, String> name;
  final Map<String, String> description;
  final int hitDie;
  final List<String> primaryAbilities;
  final List<String> savingThrowProficiencies;
  final ArmorProficiencies armorProficiencies;
  final WeaponProficiencies weaponProficiencies;
  final SkillProficiencies skillProficiencies;
  final List<SubclassData> subclasses;
  final int subclassLevel; // At what level you choose subclass
  final SpellcastingInfo? spellcasting;

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
      savingThrowProficiencies: List<String>.from(json['savingThrowProficiencies']),
      armorProficiencies: ArmorProficiencies.fromJson(json['armorProficiencies']),
      weaponProficiencies: WeaponProficiencies.fromJson(json['weaponProficiencies']),
      skillProficiencies: SkillProficiencies.fromJson(json['skillProficiencies']),
      subclasses: (json['subclasses'] as List)
          .map((s) => SubclassData.fromJson(s))
          .toList(),
      subclassLevel: json['subclassLevel'] ?? 1,
      spellcasting: json['spellcasting'] != null
          ? SpellcastingInfo.fromJson(json['spellcasting'])
          : null,
    );
  }
}

class ArmorProficiencies {
  final bool light;
  final bool medium;
  final bool heavy;
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

class WeaponProficiencies {
  final bool simple;
  final bool martial;
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

class SkillProficiencies {
  final int choose;
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

class SubclassData {
  final String id;
  final Map<String, String> name;
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

class SpellcastingInfo {
  final String ability; // 'intelligence', 'wisdom', 'charisma'
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
}
