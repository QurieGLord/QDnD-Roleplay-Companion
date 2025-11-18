import 'package:hive/hive.dart';

part 'character_spell.g.dart';

@HiveType(typeId: 3)
class CharacterSpell extends HiveObject {
  @HiveField(0)
  String spellId;

  @HiveField(1)
  bool isPrepared; // For classes that prepare spells

  @HiveField(2)
  bool isAlwaysPrepared; // Domain/Oath spells

  @HiveField(3)
  String source; // "Class", "Subclass", "Race", "Feat"

  CharacterSpell({
    required this.spellId,
    this.isPrepared = false,
    this.isAlwaysPrepared = false,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'spellId': spellId,
      'isPrepared': isPrepared,
      'isAlwaysPrepared': isAlwaysPrepared,
      'source': source,
    };
  }

  factory CharacterSpell.fromJson(Map<String, dynamic> json) {
    return CharacterSpell(
      spellId: json['spellId'],
      isPrepared: json['isPrepared'] ?? false,
      isAlwaysPrepared: json['isAlwaysPrepared'] ?? false,
      source: json['source'],
    );
  }
}
