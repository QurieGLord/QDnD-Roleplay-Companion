import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'ability_scores.dart';
import 'character_feature.dart';
import 'character_class.dart';
import 'item.dart';
import 'combat_state.dart';
import 'death_saves.dart';
import 'condition.dart';
import 'journal_note.dart';
import 'quest.dart';

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

  // Legacy single-class field. Kept for backward compatibility and "Main Class" display.
  @HiveField(4)
  String characterClass;

  // Legacy subclass field.
  @HiveField(5)
  String? subclass;

  // Total character level.
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

  @HiveField(32)
  CombatState combatState;

  @HiveField(33)
  DeathSaves deathSaves;

  @HiveField(34)
  List<ConditionType> activeConditions;

  @HiveField(35)
  String? concentratingOn; // Spell ID if concentrating

  @HiveField(36)
  List<int> hitDice; // Remaining hit dice by class level

  @HiveField(37)
  int maxHitDice; // Total hit dice (= level)

  // Detailed physical appearance fields
  @HiveField(38)
  String? age;

  @HiveField(39)
  String? gender;

  @HiveField(40)
  String? height;

  @HiveField(41)
  String? weight;

  @HiveField(42)
  String? eyes;

  @HiveField(43)
  String? hair;

  @HiveField(44)
  String? skin;

  @HiveField(45)
  String? appearanceDescription; // Detailed description

  // Currency (in copper pieces for easy conversion)
  @HiveField(46)
  int copperPieces;

  @HiveField(47)
  int silverPieces;

  @HiveField(48)
  int goldPieces;

  @HiveField(49)
  int platinumPieces;

  // Journal Fields (Simplified)
  @HiveField(50)
  List<JournalNote> journalNotes;

  @HiveField(51)
  List<Quest> quests;

  // Multiclassing Support
  @HiveField(52)
  List<CharacterClass> classes;

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
    CombatState? combatState,
    DeathSaves? deathSaves,
    List<ConditionType>? activeConditions,
    this.concentratingOn,
    List<int>? hitDice,
    int? maxHitDice,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.eyes,
    this.hair,
    this.skin,
    this.appearanceDescription,
    this.copperPieces = 0,
    this.silverPieces = 0,
    this.goldPieces = 0,
    this.platinumPieces = 0,
    List<JournalNote>? journalNotes,
    List<Quest>? quests,
    List<CharacterClass>? classes,
  })  : knownSpells = knownSpells ?? [],
        preparedSpells = preparedSpells ?? [],
        features = features ?? [],
        inventory = inventory ?? [],
        combatState = combatState ?? CombatState(),
        deathSaves = deathSaves ?? DeathSaves(),
        activeConditions = activeConditions ?? [],
        hitDice = hitDice ?? [level],
        maxHitDice = maxHitDice ?? level,
        journalNotes = journalNotes ?? [],
        quests = quests ?? [],
        classes = classes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
          // Migration/Sync Logic:
          // If classes list is empty but we have legacy single class data, populate it.
          if (this.classes.isEmpty && this.characterClass.isNotEmpty) {
            this.classes.add(CharacterClass(
              id: this.characterClass.toLowerCase(),
              name: this.characterClass,
              level: this.level,
              subclass: this.subclass,
              isPrimary: true,
            ));
          }
        }

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
      'combatState': combatState.toJson(),
      'deathSaves': deathSaves.toJson(),
      'activeConditions': activeConditions.map((c) => c.name).toList(),
      'concentratingOn': concentratingOn,
      'hitDice': hitDice,
      'maxHitDice': maxHitDice,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'eyes': eyes,
      'hair': hair,
      'skin': skin,
      'appearanceDescription': appearanceDescription,
      'copperPieces': copperPieces,
      'silverPieces': silverPieces,
      'goldPieces': goldPieces,
      'platinumPieces': platinumPieces,
      'journalNotes': journalNotes.map((n) => n.toJson()).toList(),
      'quests': quests.map((q) => q.toJson()).toList(),
    };
  }

  // Journal Notes
  void addJournalNote(JournalNote note) {
    journalNotes.add(note);
    updatedAt = DateTime.now();
    save();
  }

  void updateJournalNote(JournalNote note) {
    final index = journalNotes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      note.updatedAt = DateTime.now();
      journalNotes[index] = note;
      updatedAt = DateTime.now();
      save();
    }
  }

  void deleteJournalNote(String noteId) {
    journalNotes.removeWhere((n) => n.id == noteId);
    updatedAt = DateTime.now();
    save();
  }

  // Quests
  void addQuest(Quest quest) {
    quests.add(quest);
    updatedAt = DateTime.now();
    save();
  }

  void updateQuest(Quest quest) {
    final index = quests.indexWhere((q) => q.id == quest.id);
    if (index != -1) {
      quests[index] = quest;
      updatedAt = DateTime.now();
      save();
    }
  }

  void completeQuest(String questId) {
    final quest = quests.firstWhere((q) => q.id == questId);
    quest.status = QuestStatus.completed;
    quest.completedAt = DateTime.now();
    updatedAt = DateTime.now();
    save();
  }

  void failQuest(String questId) {
    final quest = quests.firstWhere((q) => q.id == questId);
    quest.status = QuestStatus.failed;
    quest.completedAt = DateTime.now();
    updatedAt = DateTime.now();
    save();
  }

  void deleteQuest(String questId) {
    quests.removeWhere((q) => q.id == questId);
    updatedAt = DateTime.now();
    save();
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

    // Restore hit dice (half of max, minimum 1)
    final toRestore = (maxHitDice / 2).ceil();
    restoreHitDice(toRestore);

    // Clear death saves
    deathSaves.reset();

    // Clear conditions (some may persist - for now clear all)
    activeConditions = [];

    // Break concentration
    concentratingOn = null;

    updatedAt = DateTime.now();
    // Note: Save manually after calling this method
  }

  void shortRest() {
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

  // HP Management Methods
  Future<void> takeDamage(int damage, {String? source}) async {
    if (temporaryHp > 0) {
      if (damage <= temporaryHp) {
        temporaryHp -= damage;
      } else {
        final overflow = damage - temporaryHp;
        temporaryHp = 0;
        currentHp -= overflow;
      }
    } else {
      currentHp -= damage;
    }

    if (currentHp < 0) currentHp = 0;

    // Add to combat log
    if (combatState.isInCombat) {
      combatState.totalDamageTaken += damage;
      combatState.addLogEntry(CombatLogEntry(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        type: CombatLogType.damage,
        amount: damage,
        description: source != null ? 'Damage from $source' : 'Damage taken',
        round: combatState.currentRound,
      ));
    }

    // Check concentration
    if (concentratingOn != null) {
      final dc = (damage / 2).floor().clamp(10, 99);
      if (combatState.isInCombat) {
        combatState.addLogEntry(CombatLogEntry(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          type: CombatLogType.concentrationCheck,
          amount: dc,
          description: 'Concentration check required (DC $dc)',
          round: combatState.currentRound,
        ));
      }
    }

    updatedAt = DateTime.now();
    await save();
  }

  Future<void> heal(int healing, {String? source}) async {
    // Apply healing
    final newHp = currentHp + healing;
    currentHp = newHp > maxHp ? maxHp : newHp;

    // Reset death saves if healing from 0 HP
    if (currentHp > 0 && deathSaves.isActive) {
      deathSaves.reset();
    }

    // Add to combat log (same as takeDamage)
    if (combatState.isInCombat) {
      combatState.totalHealing += healing;
      combatState.addLogEntry(CombatLogEntry(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        type: CombatLogType.healing,
        amount: healing,
        description: source != null ? 'Healed by $source' : 'Healing received',
        round: combatState.currentRound,
      ));
    }

    updatedAt = DateTime.now();
    await save();
  }

  void addTemporaryHp(int amount) {
    // Temp HP doesn't stack, take higher value
    if (amount > temporaryHp) {
      temporaryHp = amount;
      updatedAt = DateTime.now();
      save();
    }
  }

  // Condition Management
  void addCondition(ConditionType condition) {
    if (!activeConditions.contains(condition)) {
      activeConditions = List.from(activeConditions)..add(condition);

      if (combatState.isInCombat) {
        combatState.addLogEntry(CombatLogEntry(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          type: CombatLogType.conditionAdded,
          description: 'Gained ${condition.displayName}',
          round: combatState.currentRound,
        ));
      }

      updatedAt = DateTime.now();
      save();
    }
  }

  void removeCondition(ConditionType condition) {
    if (activeConditions.contains(condition)) {
      activeConditions = List.from(activeConditions)..remove(condition);

      if (combatState.isInCombat) {
        combatState.addLogEntry(CombatLogEntry(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          type: CombatLogType.conditionRemoved,
          description: 'Removed ${condition.displayName}',
          round: combatState.currentRound,
        ));
      }

      updatedAt = DateTime.now();
      save();
    }
  }

  // Hit Dice Management
  void spendHitDie() {
    if (hitDice.isNotEmpty && hitDice.first > 0) {
      hitDice = List.from(hitDice);
      hitDice[0]--;
      updatedAt = DateTime.now();
      save();
    }
  }

  void restoreHitDice(int amount) {
    final currentTotal = hitDice.fold(0, (sum, dice) => sum + dice);
    final toRestore = amount.clamp(0, maxHitDice - currentTotal);

    if (toRestore > 0 && hitDice.isNotEmpty) {
      hitDice = List.from(hitDice);
      hitDice[0] += toRestore;
      updatedAt = DateTime.now();
      save();
    }
  }

  // Armor Class Calculation
  void recalculateAC() {
    int baseAC = 10;
    int dexMod = abilityScores.dexterityModifier;
    int totalAC = baseAC;

    // Find equipped armor and shield
    Item? equippedArmor;
    Item? equippedShield;

    for (var item in inventory) {
      if (item.isEquipped && item.type == ItemType.armor && item.armorProperties != null) {
        if (item.armorProperties!.armorType == ArmorType.shield) {
          equippedShield = item;
        } else {
          equippedArmor = item;
        }
      }
    }

    // Calculate AC from armor
    if (equippedArmor != null && equippedArmor.armorProperties != null) {
      final armorProps = equippedArmor.armorProperties!;
      totalAC = armorProps.baseAC;

      // Add DEX modifier based on armor type
      if (armorProps.addDexModifier) {
        if (armorProps.maxDexBonus != null) {
          totalAC += dexMod.clamp(-10, armorProps.maxDexBonus!);
        } else {
          totalAC += dexMod; // Full DEX for light armor
        }
      }
    } else {
      // No armor = 10 + DEX
      totalAC = 10 + dexMod;
    }

    // Add shield bonus
    if (equippedShield != null && equippedShield.armorProperties != null) {
      totalAC += equippedShield.armorProperties!.baseAC;
    }

    armorClass = totalAC;
    updatedAt = DateTime.now();
  }
}
