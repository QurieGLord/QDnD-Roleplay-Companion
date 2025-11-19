import 'package:hive/hive.dart';
import 'ability_scores.dart';
import 'character_feature.dart';
import 'item.dart';

part 'character.g.dart';

@HiveType(typeId: 0)
class Character extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? avatarPath;

  @HiveField(3)
  String race;

  @HiveField(4)
  String characterClass;

  @HiveField(5)
  String? subclass;

  @HiveField(6)
  int level;

  @HiveField(7)
  int maxHp;

  @HiveField(8)
  int currentHp;

  @HiveField(9)
  int temporaryHp;

  @HiveField(10)
  AbilityScores abilityScores;

  @HiveField(11)
  String? background;

  @HiveField(12)
  List<int> spellSlots; // Current available slots

  @HiveField(13)
  List<int> maxSpellSlots; // Max slots by level

  @HiveField(14)
  int armorClass;

  @HiveField(15)
  int speed;

  @HiveField(16)
  int initiative;

  @HiveField(17)
  List<String> proficientSkills;

  @HiveField(18)
  List<String> savingThrowProficiencies;

  @HiveField(19)
  String? personalityTraits;

  @HiveField(20)
  String? ideals;

  @HiveField(21)
  String? bonds;

  @HiveField(22)
  String? flaws;

  @HiveField(23)
  String? backstory;

  @HiveField(24)
  DateTime createdAt;

  @HiveField(25)
  DateTime updatedAt;

  @HiveField(26)
  String? appearance; // Age, height, weight, eyes, skin, hair

  @HiveField(27)
  List<String> knownSpells; // IDs of known spells

  @HiveField(28)
  List<String> preparedSpells; // IDs of prepared spells

  @HiveField(29)
  int maxPreparedSpells; // Calculated: modifier + half level

  @HiveField(30)
  List<CharacterFeature> features; // Class features (Lay on Hands, Channel Divinity, etc.)

  @HiveField(31)
  List<Item> inventory; // Character's inventory (weapons, armor, gear, etc.)

  Character({
    required this.id,
    required this.name,
    this.avatarPath,
    required this.race,
    required this.characterClass,
    this.subclass,
    required this.level,
    required this.maxHp,
    required this.currentHp,
    this.temporaryHp = 0,
    required this.abilityScores,
    this.background,
    required this.spellSlots,
    required this.maxSpellSlots,
    this.armorClass = 10,
    this.speed = 30,
    this.initiative = 0,
    this.proficientSkills = const [],
    this.savingThrowProficiencies = const [],
    this.personalityTraits,
    this.ideals,
    this.bonds,
    this.flaws,
    this.backstory,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.appearance,
    List<String>? knownSpells,
    List<String>? preparedSpells,
    this.maxPreparedSpells = 0,
    List<CharacterFeature>? features,
    List<Item>? inventory,
  })  : knownSpells = knownSpells ?? [],
        preparedSpells = preparedSpells ?? [],
        features = features ?? [],
        inventory = inventory ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate proficiency bonus based on level
  int get proficiencyBonus {
    return ((level - 1) / 4).ceil() + 2;
  }

  // Calculate initiative bonus
  int get initiativeBonus {
    return abilityScores.dexterityModifier;
  }

  // Format modifier with + or -
  String formatModifier(int modifier) {
    return modifier >= 0 ? '+$modifier' : '$modifier';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarPath': avatarPath,
      'race': race,
      'characterClass': characterClass,
      'subclass': subclass,
      'level': level,
      'maxHp': maxHp,
      'currentHp': currentHp,
      'temporaryHp': temporaryHp,
      'abilityScores': abilityScores.toJson(),
      'background': background,
      'spellSlots': spellSlots,
      'maxSpellSlots': maxSpellSlots,
      'armorClass': armorClass,
      'speed': speed,
      'initiative': initiative,
      'proficientSkills': proficientSkills,
      'savingThrowProficiencies': savingThrowProficiencies,
      'personalityTraits': personalityTraits,
      'ideals': ideals,
      'bonds': bonds,
      'flaws': flaws,
      'backstory': backstory,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'appearance': appearance,
      'knownSpells': knownSpells,
      'preparedSpells': preparedSpells,
      'maxPreparedSpells': maxPreparedSpells,
      'features': features.map((f) => f.toJson()).toList(),
      'inventory': inventory.map((i) => i.toJson()).toList(),
    };
  }

  // Spell slot management methods
  void restoreSpellSlot(int level) {
    if (level > 0 && level <= maxSpellSlots.length) {
      if (spellSlots[level - 1] < maxSpellSlots[level - 1]) {
        spellSlots[level - 1]++;
        updatedAt = DateTime.now();
        save(); // Hive save
      }
    }
  }

  void useSpellSlot(int level) {
    if (level > 0 && level <= spellSlots.length) {
      if (spellSlots[level - 1] > 0) {
        spellSlots[level - 1]--;
        updatedAt = DateTime.now();
        save(); // Hive save
      }
    }
  }

  void longRest() {
    // Restore all HP
    currentHp = maxHp;
    temporaryHp = 0;

    // Restore all spell slots
    for (int i = 0; i < maxSpellSlots.length; i++) {
      spellSlots[i] = maxSpellSlots[i];
    }

    // Restore all features that recover on long rest
    for (var feature in features) {
      if (feature.resourcePool != null) {
        if (feature.resourcePool!.recoveryType == RecoveryType.longRest ||
            feature.resourcePool!.recoveryType == RecoveryType.shortRest) {
          feature.resourcePool!.restoreFull();
        }
      }
    }

    updatedAt = DateTime.now();
    // Note: Save manually after calling this method
  }

  void shortRest() {
    // Paladin doesn't restore spell slots on short rest
    // But can use hit dice to heal
    // TODO: Implement hit dice in future session

    // Restore features that recover on short rest
    for (var feature in features) {
      if (feature.resourcePool != null) {
        if (feature.resourcePool!.recoveryType == RecoveryType.shortRest) {
          feature.resourcePool!.restoreFull();
        }
      }
    }

    updatedAt = DateTime.now();
    // Note: Save manually after calling this method
  }
}
