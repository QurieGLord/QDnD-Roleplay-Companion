import 'package:hive/hive.dart';

part 'ability_scores.g.dart';

@HiveType(typeId: 1)
class AbilityScores extends HiveObject {
  @HiveField(0)
  int strength;

  @HiveField(1)
  int dexterity;

  @HiveField(2)
  int constitution;

  @HiveField(3)
  int intelligence;

  @HiveField(4)
  int wisdom;

  @HiveField(5)
  int charisma;

  AbilityScores({
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
  });

  // Calculate modifier from ability score
  int getModifier(int score) {
    return ((score - 10) / 2).floor();
  }

  int get strengthModifier => getModifier(strength);
  int get dexterityModifier => getModifier(dexterity);
  int get constitutionModifier => getModifier(constitution);
  int get intelligenceModifier => getModifier(intelligence);
  int get wisdomModifier => getModifier(wisdom);
  int get charismaModifier => getModifier(charisma);

  Map<String, dynamic> toJson() {
    return {
      'strength': strength,
      'dexterity': dexterity,
      'constitution': constitution,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
    };
  }

  factory AbilityScores.fromJson(Map<String, dynamic> json) {
    return AbilityScores(
      strength: json['strength'] ?? 10,
      dexterity: json['dexterity'] ?? 10,
      constitution: json['constitution'] ?? 10,
      intelligence: json['intelligence'] ?? 10,
      wisdom: json['wisdom'] ?? 10,
      charisma: json['charisma'] ?? 10,
    );
  }
}
