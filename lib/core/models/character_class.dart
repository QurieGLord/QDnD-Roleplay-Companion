import 'package:hive/hive.dart';

part 'character_class.g.dart';

@HiveType(typeId: 8) // Next available TypeId
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

  CharacterClass({
    required this.id,
    required this.name,
    required this.level,
    this.subclass,
    this.isPrimary = false,
  });

  factory CharacterClass.fromJson(Map<String, dynamic> json) {
    return CharacterClass(
      id: json['id'],
      name: json['name'],
      level: json['level'],
      subclass: json['subclass'],
      isPrimary: json['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'subclass': subclass,
      'isPrimary': isPrimary,
    };
  }
}
