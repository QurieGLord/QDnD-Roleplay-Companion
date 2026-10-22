import '../magic/magic_slots.dart';
import '../magic/class_action_state.dart';
import 'dart:math' as math;

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'ability_scores.dart';
import 'armor_class_parts.dart';
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

  int _armorClass;

  @HiveField(14)
  int get armorClass => _armorClass;

  /// A direct edit pins the effective value until explicitly cleared.
  set armorClass(int value) {
    armorClassOverride = value;
    usesAutomaticArmorClass = false;
    _armorClass = value;
  }

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
  List<CharacterFeature>
      features; // Class features (Lay on Hands, Channel Divinity, etc.)

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

  @HiveField(53)
  List<String> expertSkills;

  @HiveField(54)
  int wildShapeCharges;

  @HiveField(55, defaultValue: false)
  bool naturalRecoveryUsed;

  @HiveField(56, defaultValue: false)
  bool isWildShaped;

  @HiveField(57, defaultValue: false)
  bool arcaneRecoveryUsed;

  @HiveField(58, defaultValue: [])
  List<String> spellMasterySpells;

  @HiveField(59, defaultValue: [])
  List<String> signatureSpells;

  @HiveField(60, defaultValue: {})
  Map<String, bool> signatureSpellsUsed;

  @HiveField(61, defaultValue: 0)
  int channelDivinityCharges;

  @HiveField(62, defaultValue: false)
  bool divineInterventionUsed;

  @HiveField(63, defaultValue: [])
  List<String> favoredEnemies;

  @HiveField(64, defaultValue: [])
  List<String> naturalExplorers;

  @HiveField(65)
  String? beastName;

  @HiveField(66)
  int? beastMaxHp;

  @HiveField(67)
  int? beastCurrentHp;

  @HiveField(68)
  String? beastIcon;

  @HiveField(69, defaultValue: false)
  bool isHuntersMarkActive;

  @HiveField(70)
  String? huntersMarkTarget;

  @HiveField(71, defaultValue: false)
  bool isHiddenInPlainSight;

  @HiveField(73, defaultValue: 10)
  int relentlessRageSaveDc;

  @HiveField(74, defaultValue: false)
  bool isRaging;

  @HiveField(75)
  int? armorClassOverride;

  @HiveField(76, defaultValue: false)
  bool isFrenzied;

  // Legacy files only have effective AC. Preserve it until the player chooses
  // calculation; new characters explicitly store automatic mode.
  @HiveField(77, defaultValue: false)
  bool usesAutomaticArmorClass;

  @HiveField(78, defaultValue: false)
  bool isReckless;

  @HiveField(79, defaultValue: false)
  bool isHidden;

  @HiveField(80, defaultValue: false)
  bool isSacredWeaponActive;

  /// PHB p.291 – Exhaustion (0-6; 6 = dead)
  @HiveField(72, defaultValue: 0)
  int _exhaustionLevel = 0;

  int get exhaustionLevel => _exhaustionLevel;
  set exhaustionLevel(int value) {
    _exhaustionLevel = value.clamp(0, 6);
  }

  /// Additive map payload: older Hive readers can skip it safely.
  @HiveField(81, defaultValue: {})
  Map<String, dynamic> journalData;

  /// Source-owned spell lists; an empty payload is a legacy, unassigned sheet.
  @HiveField(82, defaultValue: {})
  Map<String, dynamic> spellbookData;

  @HiveField(83, defaultValue: {})
  Map<String, dynamic> magicData;

  @HiveField(84, defaultValue: {})
  Map<String, dynamic> advancementData;

  static int _initialWildShapeCharges(
      String primary, int level, List<CharacterClass>? classes) {
    bool druid(String value) =>
        {'druid', 'друид'}.contains(value.trim().toLowerCase());
    final own = classes == null || classes.isEmpty
        ? (druid(primary) ? level : 0)
        : classes
            .where((c) => druid(c.id) || druid(c.name))
            .fold<int>(0, (n, c) => n + c.level);
    return own >= 2 ? 2 : 0;
  }

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
    required List<int> spellSlots,
    required List<int> maxSpellSlots,
    int armorClass = 10,
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
    Map<String, dynamic>? journalData,
    Map<String, dynamic>? spellbookData,
    Map<String, dynamic>? magicData,
    Map<String, dynamic>? advancementData,
    List<CharacterClass>? classes,
    List<String>? expertSkills,
    int? wildShapeCharges,
    this.naturalRecoveryUsed = false,
    this.isWildShaped = false,
    this.arcaneRecoveryUsed = false,
    List<String>? spellMasterySpells,
    List<String>? signatureSpells,
    Map<String, bool>? signatureSpellsUsed,
    this.channelDivinityCharges = 0,
    this.divineInterventionUsed = false,
    List<String>? favoredEnemies,
    List<String>? naturalExplorers,
    this.beastName,
    this.beastMaxHp,
    this.beastCurrentHp,
    this.beastIcon,
    this.isHuntersMarkActive = false,
    this.huntersMarkTarget,
    this.isHiddenInPlainSight = false,
    this.relentlessRageSaveDc = 10,
    this.isRaging = false,
    this.armorClassOverride,
    this.isFrenzied = false,
    this.usesAutomaticArmorClass = true,
    this.isReckless = false,
    this.isHidden = false,
    this.isSacredWeaponActive = false,
    int exhaustionLevel = 0,
  })  : _armorClass = armorClass,
        _exhaustionLevel = exhaustionLevel,
        spellSlots = List<int>.from(spellSlots),
        maxSpellSlots = List<int>.from(maxSpellSlots),
        knownSpells = List<String>.from(knownSpells ?? []),
        preparedSpells = List<String>.from(preparedSpells ?? []),
        features = (features ?? [])
            .map((feature) => feature.copyForCharacter())
            .toList(),
        inventory = inventory ?? [],
        combatState = combatState ?? CombatState(),
        deathSaves = deathSaves ?? DeathSaves(),
        activeConditions = activeConditions ?? [],
        hitDice = hitDice ?? [level],
        maxHitDice = maxHitDice ?? level,
        journalNotes = journalNotes ?? [],
        quests = quests ?? [],
        journalData = journalData ?? {},
        spellbookData = spellbookData ?? {},
        magicData = magicData ?? {},
        wildShapeCharges = wildShapeCharges ??
            _initialWildShapeCharges(characterClass, level, classes),
        advancementData = advancementData ?? {},
        classes = classes ?? [],
        expertSkills = expertSkills ?? [],
        spellMasterySpells = spellMasterySpells ?? [],
        signatureSpells = signatureSpells ?? [],
        signatureSpellsUsed = signatureSpellsUsed ?? {},
        favoredEnemies = favoredEnemies ?? [],
        naturalExplorers = naturalExplorers ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    // Migration/Sync Logic:
    if (!usesAutomaticArmorClass && armorClassOverride == null) {
      armorClassOverride = _armorClass;
    }
    if (armorClassOverride != null) usesAutomaticArmorClass = false;
    // If classes list is empty but we have legacy single class data, populate it.
    if (this.classes.isEmpty && characterClass.isNotEmpty) {
      this.classes.add(
            CharacterClass(
              id: characterClass.toLowerCase(),
              name: characterClass,
              level: level,
              subclass: subclass,
              isPrimary: true,
            ),
          );
    }

    // Fix stale class levels: for single-class characters, the primary
    // class level must always equal the global character level.
    // This repairs characters that leveled up before this sync was added.
    if (this.classes.length == 1 && this.classes.first.level != level) {
      this.classes.first.level = level;
    }
  }

  // Calculate proficiency bonus based on level
  int get proficiencyBonus {
    return 2 + ((level - 1) ~/ 4);
  }

  static String _normalizeFeatureId(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[\s_]+'), '-');
  }

  bool hasFeatureId(String featureId) {
    final normalizedTarget = _normalizeFeatureId(featureId);
    return features.any(
      (feature) => _normalizeFeatureId(feature.id) == normalizedTarget,
    );
  }

  bool hasSavingThrowProficiency(String savingThrowId) {
    final normalizedTarget = _normalizeFeatureId(savingThrowId);
    return savingThrowProficiencies.any(
      (proficiency) => _normalizeFeatureId(proficiency) == normalizedTarget,
    );
  }

  bool get hasBarbarianUnarmoredDefense =>
      characterClass.toLowerCase() == 'barbarian' ||
      characterClass.toLowerCase() == 'варвар' ||
      hasFeatureId('barbarian-unarmored-defense');

  bool get hasRelentlessRage =>
      classLevel('barbarian') >= 11 && hasFeatureId('relentless-rage');

  bool get hasFeralInstinct =>
      classLevel('barbarian') >= 7 && hasFeatureId('feral-instinct');

  int get constitutionSavingThrowBonus {
    final proficiency =
        hasSavingThrowProficiency('constitution') ? proficiencyBonus : 0;
    return abilityScores.constitutionModifier + proficiency;
  }

  // Calculate initiative bonus
  int get initiativeBonus {
    return abilityScores.dexterityModifier;
  }

  // Format modifier with + or -
  String formatModifier(int modifier) {
    return modifier >= 0 ? '+$modifier' : '$modifier';
  }

  int getMaxChannelDivinityCharges() {
    final clericLevel = classLevel('cleric');
    final clericUses = clericLevel < 2
        ? 0
        : clericLevel < 6
            ? 1
            : clericLevel < 18
                ? 2
                : 3;
    final paladinUses = classLevel('paladin') >= 3 ? 1 : 0;
    return math.max(clericUses, paladinUses);
  }

  void resetRelentlessRageSaveDc() {
    relentlessRageSaveDc = 10;
  }

  void increaseRelentlessRageSaveDc([int amount = 5]) {
    relentlessRageSaveDc += amount;
  }

  @override
  Future<void> save() async {
    // Persistence is not a gameplay action: do not grant stats or replace AC.
    updatedAt = DateTime.now();
    return super.save();
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
      'armorClassOverride': armorClassOverride,
      'usesAutomaticArmorClass': usesAutomaticArmorClass,
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
      'journalData': journalData,
      'spellbookData': spellbookData,
      'magicData': magicData,
      'advancementData': advancementData,
      'expertSkills': expertSkills,
      'wildShapeCharges': wildShapeCharges,
      'naturalRecoveryUsed': naturalRecoveryUsed,
      'isWildShaped': isWildShaped,
      'spellMasterySpells': spellMasterySpells,
      'signatureSpells': signatureSpells,
      'signatureSpellsUsed': signatureSpellsUsed,
      'channelDivinityCharges': channelDivinityCharges,
      'divineInterventionUsed': divineInterventionUsed,
      'favoredEnemies': favoredEnemies,
      'naturalExplorers': naturalExplorers,
      'beastName': beastName,
      'beastMaxHp': beastMaxHp,
      'beastCurrentHp': beastCurrentHp,
      'beastIcon': beastIcon,
      'isHuntersMarkActive': isHuntersMarkActive,
      'huntersMarkTarget': huntersMarkTarget,
      'isHiddenInPlainSight': isHiddenInPlainSight,
      'relentlessRageSaveDc': relentlessRageSaveDc,
      'isRaging': isRaging,
      'isFrenzied': isFrenzied,
      'isReckless': isReckless,
      'isHidden': isHidden,
      'isSacredWeaponActive': isSacredWeaponActive,
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

  // Spell slot edits use the actual remainder, including table-granted extras.
  void setSpellSlotCount(int level, int count) {
    if (level < 1 || level > 9) return;
    while (spellSlots.length < level) {
      spellSlots.add(0);
    }
    while (maxSpellSlots.length < level) {
      maxSpellSlots.add(0);
    }
    spellSlots[level - 1] = math.max(0, count);
  }

  void restoreSpellSlot(int level) {
    if (level < 1 || level > 9) return;
    final current = level <= spellSlots.length ? spellSlots[level - 1] : 0;
    setSpellSlotCount(level, current + 1);
    save();
  }

  void useSpellSlot(int level) {
    if (level < 1 || level > spellSlots.length) return;
    if (spellSlots[level - 1] <= 0) return;
    spellSlots[level - 1]--;
    save();
  }

  /// An automatic recovery is one event, not one save per restored slot.
  void recoverSpellSlots(Map<int, int> amounts) {
    for (final entry in amounts.entries) {
      final level = entry.key;
      if (level < 1 || level > maxSpellSlots.length || entry.value <= 0) {
        continue;
      }
      final current = level <= spellSlots.length ? spellSlots[level - 1] : 0;
      final normalMax = maxSpellSlots[level - 1];
      if (current < normalMax) {
        setSpellSlotCount(level, math.min(normalMax, current + entry.value));
      }
    }
  }

  void _restoreSpellSlots() {
    while (spellSlots.length < maxSpellSlots.length) {
      spellSlots.add(0);
    }

    for (int i = 0; i < maxSpellSlots.length; i++) {
      spellSlots[i] = math.max(spellSlots[i], math.max(0, maxSpellSlots[i]));
    }
  }

  int classLevel(String id) {
    const aliases = {
      'варвар': 'barbarian',
      'бард': 'bard',
      'жрец': 'cleric',
      'друид': 'druid',
      'воин': 'fighter',
      'монах': 'monk',
      'паладин': 'paladin',
      'следопыт': 'ranger',
      'плут': 'rogue',
      'чародей': 'sorcerer',
      'колдун': 'warlock',
      'волшебник': 'wizard',
    };
    String canonical(String value) =>
        aliases[value.toLowerCase().trim()] ?? value.toLowerCase().trim();
    return classes
        .where((c) => canonical(c.id) == id || canonical(c.name) == id)
        .fold(0, (sum, c) => sum + c.level);
  }

  void _restoreWildShapeCharges() {
    if (classLevel('druid') >= 2) {
      wildShapeCharges = math.max(wildShapeCharges, 2);
    }
  }

  static bool isChannelDivinityResource(CharacterFeature feature) =>
      feature.resourcePool != null &&
      const {
        'channel-divinity',
        'channel_divinity',
        'channel-divinity-1-rest',
        'channel-divinity-2-rest',
        'channel-divinity-3-rest',
      }.contains(feature.id);

  List<CharacterFeature> get channelDivinityResources =>
      features.where(isChannelDivinityResource).toList();

  CharacterFeature? get channelDivinityResource {
    final candidates = channelDivinityResources;
    candidates.sort((a, b) => b.minLevel.compareTo(a.minLevel));
    return candidates.firstOrNull;
  }

  // Keep the formerly visible value until an explicit resource action.
  int get editableChannelDivinityCharges => classLevel('cleric') >= 2
      ? channelDivinityCharges
      : channelDivinityResource?.resourcePool?.currentUses ??
          channelDivinityCharges;

  void setChannelDivinityCharges(int value) {
    channelDivinityCharges = math.max(0, value);
    for (final feature in channelDivinityResources) {
      feature.resourcePool!.setCurrentUses(channelDivinityCharges);
    }
  }

  bool consumeChannelDivinity({int amount = 1, ResourcePool? source}) {
    final current = source?.currentUses ?? channelDivinityCharges;
    if (amount <= 0 || current < amount) return false;
    setChannelDivinityCharges(current - amount);
    return true;
  }

  void acquireChannelDivinity({
    required bool previouslyAvailable,
    required int previousCurrent,
  }) {
    if (channelDivinityResources.isEmpty) return;
    setChannelDivinityCharges(
      previouslyAvailable
          ? previousCurrent
          : math.max(previousCurrent, getMaxChannelDivinityCharges()),
    );
  }

  void _restoreChannelDivinity({required bool longRest}) {
    final pool = channelDivinityResource?.resourcePool;
    final recovery = pool?.recoveryType ?? RecoveryType.shortRest;
    if (recovery != RecoveryType.shortRest &&
        !(longRest && recovery == RecoveryType.longRest)) {
      return;
    }
    var current = math.max(
      channelDivinityCharges,
      pool?.maxUses ?? getMaxChannelDivinityCharges(),
    );
    for (final feature in channelDivinityResources) {
      current = math.max(current, feature.resourcePool!.currentUses);
    }
    setChannelDivinityCharges(current);
  }

  void longRest() {
    currentHp = math.max(currentHp, math.max(0, maxHp));
    if (magicData.isNotEmpty) {
      MagicSlots.expireCreated(this);
      MagicSlots.read(this).recover(short: false).applyTo(this);
    } else {
      _restoreSpellSlots();
    }
    for (final feature in features) {
      final pool = feature.resourcePool;
      if (!isChannelDivinityResource(feature) &&
          pool != null &&
          (pool.recoveryType == RecoveryType.longRest ||
              pool.recoveryType == RecoveryType.shortRest)) {
        pool.restoreFull();
      }
    }
    _restoreWildShapeCharges();
    _restoreChannelDivinity(longRest: true);
    ClassActionState.longRest(this);
    naturalRecoveryUsed = false;
    arcaneRecoveryUsed = false;
    signatureSpellsUsed.updateAll((_, __) => false);
    restoreHitDice(math.max(1, maxHitDice ~/ 2), persist: false);
    // Conditions, exhaustion, temporary HP, form, concentration and active
    // effects are player-managed. Rest does not silently clear their marks.
    updatedAt = DateTime.now();
  }

  void shortRest() {
    for (final feature in features) {
      final pool = feature.resourcePool;
      if (!isChannelDivinityResource(feature) &&
          pool?.recoveryType == RecoveryType.shortRest) {
        pool!.restoreFull();
      }
    }
    // Mixed Pact/Spellcasting slots need separate pools. Do not reset the
    // normal shared slots of a multiclass character as though all were Pact.
    if (magicData.isNotEmpty) {
      MagicSlots.read(this).recover(short: true).applyTo(this);
    } else if (classes.length == 1 && classLevel('warlock') > 0) {
      _restoreSpellSlots();
    }
    _restoreWildShapeCharges();
    _restoreChannelDivinity(longRest: false);
    signatureSpellsUsed.updateAll((_, __) => false);

    updatedAt = DateTime.now();
  }

  void endRage() {
    if (isFrenzied) exhaustionLevel++;
    isRaging = false;
    isFrenzied = false;
  }

  // HP Management Methods
  Future<void> takeDamage(
    int damage, {
    String? source,
    bool persist = true,
  }) async {
    if (damage <= 0) return;
    int remainingDamage = damage;

    // 1. Temporary HP absorbs damage first, regardless of form
    if (temporaryHp > 0) {
      if (remainingDamage <= temporaryHp) {
        temporaryHp -= remainingDamage;
        remainingDamage = 0;
      } else {
        remainingDamage -= temporaryHp;
        temporaryHp = 0;
      }
    }

    if (remainingDamage > 0) {
      // 2. If Wild Shaped, damage goes to beast HP
      if (isWildShaped && beastCurrentHp != null) {
        if (remainingDamage < beastCurrentHp!) {
          beastCurrentHp = beastCurrentHp! - remainingDamage;
          remainingDamage = 0;
        } else {
          remainingDamage -= beastCurrentHp!;
          beastCurrentHp = 0;
          isWildShaped = false; // Form drops when Beast HP reaches 0
        }
      }

      // 3. Any remaining damage hits the true form HP
      if (remainingDamage > 0) {
        currentHp -= remainingDamage;
      }
    }

    if (currentHp < 0) currentHp = 0;
    if (currentHp == 0 && !(hasRelentlessRage && isRaging)) {
      endRage();
    }

    // Add to combat log
    if (combatState.isInCombat) {
      combatState.totalDamageTaken += damage;
      combatState.addLogEntry(
        CombatLogEntry(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          type: CombatLogType.damage,
          amount: damage,
          description: source != null ? 'Damage from $source' : 'Damage taken',
          round: combatState.currentRound,
        ),
      );
    }

    // Check concentration
    if (concentratingOn != null) {
      final dc = math.max(10, damage ~/ 2);
      if (combatState.isInCombat) {
        combatState.addLogEntry(
          CombatLogEntry(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            type: CombatLogType.concentrationCheck,
            amount: dc,
            description: 'Concentration check required (DC $dc)',
            round: combatState.currentRound,
          ),
        );
      }
    }

    updatedAt = DateTime.now();
    if (persist) await save();
  }

  Future<void> heal(int healing, {String? source, bool persist = true}) async {
    if (healing <= 0) return;
    final previousHp = currentHp;
    // Apply healing to current form
    if (isWildShaped && beastCurrentHp != null && beastMaxHp != null) {
      final newHp = beastCurrentHp! + healing;
      beastCurrentHp = math.max(beastCurrentHp!, math.min(newHp, beastMaxHp!));
    } else {
      final newHp = currentHp + healing;
      currentHp = math.max(currentHp, math.min(newHp, maxHp));
    }

    // Reset death saves if healing from 0 HP
    if (previousHp == 0 && currentHp > 0) {
      deathSaves.reset();
      combatState.resetDeathSaveTracking();
    }

    // Add to combat log (same as takeDamage)
    if (combatState.isInCombat) {
      combatState.totalHealing += healing;
      combatState.addLogEntry(
        CombatLogEntry(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          type: CombatLogType.healing,
          amount: healing,
          description:
              source != null ? 'Healed by $source' : 'Healing received',
          round: combatState.currentRound,
        ),
      );
    }

    updatedAt = DateTime.now();
    if (persist) await save();
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
  void addCondition(ConditionType condition, {bool persist = true}) {
    if (!activeConditions.contains(condition)) {
      activeConditions = List.from(activeConditions)..add(condition);

      if (combatState.isInCombat) {
        combatState.addLogEntry(
          CombatLogEntry(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            type: CombatLogType.conditionAdded,
            description: 'Gained ${condition.displayName}',
            round: combatState.currentRound,
          ),
        );
      }

      updatedAt = DateTime.now();
      if (persist) save();
    }
  }

  void removeCondition(ConditionType condition, {bool persist = true}) {
    if (activeConditions.contains(condition)) {
      activeConditions = List.from(activeConditions)
        ..removeWhere((c) => c == condition);

      if (combatState.isInCombat) {
        combatState.addLogEntry(
          CombatLogEntry(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            type: CombatLogType.conditionRemoved,
            description: 'Removed ${condition.displayName}',
            round: combatState.currentRound,
          ),
        );
      }

      updatedAt = DateTime.now();
      if (persist) save();
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

  void restoreHitDice(int amount, {bool persist = true}) {
    if (amount > 0 && hitDice.length == classes.length) {
      var remaining = math.max(0, amount);
      hitDice = List<int>.of(hitDice);
      for (var i = 0; i < hitDice.length && remaining > 0; i++) {
        final gain =
            math.min(remaining, math.max(0, classes[i].level - hitDice[i]));
        hitDice[i] += gain;
        remaining -= gain;
      }
      updatedAt = DateTime.now();
      if (persist) save();
    }
  }

  // Armor Class Calculation
  void clearArmorClassOverride() {
    armorClassOverride = null;
    usesAutomaticArmorClass = true;
    recalculateAC();
  }

  void recalculateAC() {
    _armorClass = armorClassOverride ?? calculatedArmorClass;
    updatedAt = DateTime.now();
  }

  int get calculatedArmorClass =>
      armorClassParts(this).fold(0, (sum, part) => sum + part.value);
}
