import 'dart:convert';
import 'package:hive/hive.dart';

part 'character_class.g.dart';

@HiveType(typeId: 25) // Changed from 8 to 25 to avoid conflict with Item (8)
class CharacterClass extends HiveObject {
  @HiveField(0)
  String id; // Class ID (e.g., "paladin")

  @HiveField(1)
  String name; // Display name (e.g., "Paladin")

  @HiveField(2)
  int level; // Class level

  @HiveField(3)
  String? subclass; // Subclass ID (e.g., "oath_of_devotion")

  @HiveField(4)
  bool isPrimary; // Is this the starting class? (affects saving throws/skills)

  @HiveField(5)
  Map<String, dynamic>? rulesSnapshot;

  @HiveField(6, defaultValue: [])
  List<String> entryProficiencies;

  @HiveField(7, defaultValue: {})
  Map<String, dynamic> referenceData;

  CharacterClass({
    required this.id,
    required this.name,
    required this.level,
    this.subclass,
    this.isPrimary = false,
    this.rulesSnapshot,
    this.entryProficiencies = const [],
    this.referenceData = const {},
  });

  factory CharacterClass.fromJson(Map<String, dynamic> json) {
    return CharacterClass(
      id: json['id'],
      name: json['name'],
      level: json['level'],
      subclass: json['subclass'],
      isPrimary: json['isPrimary'] ?? false,
      entryProficiencies:
          List<String>.from(json['entryProficiencies'] as List? ?? []),
      referenceData: json['referenceData'] is Map
          ? Map<String, dynamic>.from(
              jsonDecode(jsonEncode(json['referenceData'])) as Map)
          : {},
      rulesSnapshot: json['rulesSnapshot'] == null
          ? null
          : Map<String, dynamic>.from(
              jsonDecode(jsonEncode(json['rulesSnapshot'])) as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'subclass': subclass,
      'isPrimary': isPrimary,
      'entryProficiencies': List<String>.of(entryProficiencies),
      'referenceData': jsonDecode(jsonEncode(referenceData)),
      if (rulesSnapshot != null)
        'rulesSnapshot': jsonDecode(jsonEncode(rulesSnapshot)),
    };
  }
}
