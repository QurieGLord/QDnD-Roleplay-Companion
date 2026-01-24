# QD&D - Architectural Reference

## 🏛️ Architectural Philosophy

### Core Principle: Universal, Data-Driven Design

QD&D follows a **zero-code-change architecture** for content expansion. Every game mechanic, class feature, spell, or item is represented through a universal data model that can be populated entirely through JSON.

**Success Metric**: If adding a new class (e.g., Artificer with Infusions) or a complex homebrew feature requires ANY code changes, the architecture has failed.

---

## 📊 Data Model Hierarchy

### Layer 1: Foundation Models

#### Character
```dart
class Character {
  String id;
  String name;
  String? portraitPath;

  // Core Identity
  Race race;
  Background background;
  List<ClassLevel> classes;  // Multiclassing support
  int level;  // Total level

  // Ability Scores
  AbilityScores abilityScores;

  // Derived Stats (calculated)
  int get proficiencyBonus;
  int get armorClass;
  int get initiative;
  int get speed;
  int get maxHitPoints;
  int currentHitPoints;
  int temporaryHitPoints;

  // Resources
  List<ResourcePool> resources;

  // Features
  List<CharacterFeature> features;
  List<Feat> feats;

  // Spellcasting
  SpellcastingInfo? spellcasting;
  List<Spell> knownSpells;
  List<Spell> preparedSpells;

  // Inventory
  Inventory inventory;

  // Metadata
  DateTime createdAt;
  DateTime lastModified;
  String sourceType;  // 'manual', 'fc5_import', 'template'
}
```

#### CompendiumSource
```dart
class CompendiumSource {
  String id;
  String name;
  DateTime importedAt;
  int itemCount;
  int spellCount;
}
```

#### AbilityScores
```dart
class AbilityScores {
  int strength;
  int dexterity;
  int constitution;
  int intelligence;
  int wisdom;
  int charisma;

  // Modifiers (calculated)
  int getModifier(AbilityType type);

  // With bonuses from features/items
  int getEffectiveScore(AbilityType type, Character character);
}
```

#### ClassLevel
```dart
class ClassLevel {
  String classId;
  String? subclassId;
  int level;

  // Hit points rolled for this level
  int hitPointsGained;

  // Choices made at this level
  List<FeatureChoice> choices;

  // Reference to class definition
  ClassDefinition get classDefinition;
}
```

---

### Layer 2: Universal Feature System

The **CharacterFeature** is the cornerstone of the architecture. It represents ANY ability, trait, or effect in D&D.

#### CharacterFeature (Abstract Base)
```dart
abstract class CharacterFeature {
  // === IDENTITY ===
  String id;
  Map<String, String> localizedName;         // {'en': 'Rage', 'ru': 'Ярость'}
  Map<String, String> localizedDescription;
  FeatureType type;                          // passive, action, toggle, resource
  SourceType source;                         // class, subclass, race, feat, item
  String sourceId;                           // Which class/race/etc?

  // === ACTIVATION ===
  List<ActivationTrigger> triggers;          // When can it be used?
  ActionType? actionType;                    // Action, Bonus Action, Reaction, Free
  List<ActivationCondition> conditions;      // Prerequisites to activate

  // === RESOURCE MANAGEMENT ===
  ResourceCost? cost;                        // What does it consume?
  RecoveryType recovery;                     // How is it recharged?
  int? maxUses;                              // Uses per rest/day
  int currentUses;

  // === EFFECTS ===
  List<CharacterModifier> modifiers;         // Stat changes, bonuses
  List<ConditionalEffect> conditionalEffects; // Context-dependent effects
  Duration? duration;                        // How long does it last?

  // === UI METADATA ===
  String? iconPath;
  Color? color;
  int displayOrder;
}
```

#### Feature Types

**1. PassiveFeature**
```dart
class PassiveFeature extends CharacterFeature {
  // Always active, no activation required
  // Examples: Unarmored Defense, Jack of All Trades, Danger Sense

  @override
  FeatureType get type => FeatureType.passive;
}
```

**2. ActionFeature**
```dart
class ActionFeature extends CharacterFeature {
  // Must be manually activated
  // Examples: Rage, Action Surge, Channel Divinity

  ActionType actionType;  // Action, Bonus Action, Reaction
  bool requiresConcentration;

  @override
  FeatureType get type => FeatureType.action;
}
```

**3. ToggleFeature**
```dart
class ToggleFeature extends CharacterFeature {
  // Can be turned on/off
  // Examples: Rage (while active), Bladesong, Hexblade's Curse

  bool isActive;
  Duration? duration;
  List<CharacterModifier> activeModifiers;

  @override
  FeatureType get type => FeatureType.toggle;
}
```

**4. ResourceFeature**
```dart
class ResourceFeature extends CharacterFeature {
  // Provides a pool of points to spend
  // Examples: Ki Points, Sorcery Points, Lay on Hands

  int maxPool;
  int currentPool;
  List<ResourceUse> uses;  // What can you spend it on?

  @override
  FeatureType get type => FeatureType.resource;
}
```

---

### Layer 3: Modifiers & Effects

#### CharacterModifier
```dart
class CharacterModifier {
  ModifierTarget target;  // What stat does it affect?
  ModifierType type;      // bonus, penalty, advantage, disadvantage, etc.
  dynamic value;          // +2, "proficiency_bonus", etc.

  // Conditions
  List<ModifierCondition> conditions;

  // Examples:
  // - Rage: +2 to melee damage (if using Strength)
  // - Bardic Inspiration: +1d6 to ability checks
  // - Shield spell: +5 AC (until start of next turn)
}

enum ModifierTarget {
  // Ability Scores
  strength, dexterity, constitution, intelligence, wisdom, charisma,

  // Combat Stats
  armorClass, initiative, speed,
  attackRoll, damageRoll,

  // Checks & Saves
  abilityCheck, savingThrow, skillCheck,

  // Spellcasting
  spellAttackRoll, spellSaveDC, spellDamage,

  // Resources
  maxHitPoints, hitDice,
  spellSlots, resourcePool,
}

enum ModifierType {
  flatBonus,        // +2 AC
  dice,             // +1d6 damage
  multiplier,       // x2 proficiency bonus
  advantage,        // Roll twice, take higher
  disadvantage,     // Roll twice, take lower
  reroll,           // Reroll once
  setMinimum,       // Minimum value of X
}
```

#### ConditionalEffect
```dart
class ConditionalEffect {
  String condition;  // "if wielding melee weapon", "if raging", etc.
  List<CharacterModifier> modifiers;

  // DSL for conditions
  EffectCondition parse(String condition);

  // Examples:
  // - "if wielding heavy armor": disadvantage on Stealth
  // - "if raging": resistance to physical damage
  // - "if hit by attack": can use reaction to reduce damage
}
```

---

### Layer 4: Resource Management

#### ResourcePool
```dart
class ResourcePool {
  String id;
  Map<String, String> localizedName;
  ResourceType type;
  RecoveryType recovery;

  int maximum;
  int current;

  // For spell slots
  int? spellLevel;

  // Linked to features
  String? linkedFeatureId;
}

enum ResourceType {
  // Standard
  spellSlot,         // Standard spellcasting (1-9th level)
  pactMagicSlot,     // Warlock-specific
  hitDice,

  // Class-specific
  ki,                // Monk
  sorceryPoints,     // Sorcerer
  superiorityDice,   // Battle Master Fighter
  bardicInspiration, // Bard
  layOnHandsPool,    // Paladin
  rageUses,          // Barbarian
  wildShapeUses,     // Druid
  channelDivinity,   // Cleric/Paladin
  actionSurge,       // Fighter
  infusionSlots,     // Artificer

  // Universal
  custom,            // Homebrew/other
}

enum RecoveryType {
  shortRest,
  longRest,
  dawn,
  dusk,
  perTurn,
  perMinute,
  rechargeOnRoll,    // e.g., 5-6 on d6
  manual,            // DM discretion
}
```

---

### Layer 5: Spellcasting System

#### SpellcastingInfo
```dart
class SpellcastingInfo {
  SpellcastingType type;           // standard, pact_magic, innate
  AbilityType spellcastingAbility; // INT, WIS, CHA

  // Spell knowledge
  SpellKnowledgeType knowledgeType; // prepared, known, spellbook
  int? spellsKnownCount;
  int? spellsPreparedCount;

  // Slots
  Map<int, int> spellSlots;        // {1: 4, 2: 3, 3: 2} = 4x1st, 3x2nd, 2x3rd
  Map<int, int> slotsUsed;

  // Warlock-specific
  int? pactMagicSlots;
  int? pactMagicLevel;

  // Sorcerer-specific
  int? sorceryPoints;
  List<Metamagic>? metamagicOptions;

  // Spell lists
  List<String> classSpellListIds;
  List<String> alwaysPreparedSpellIds;  // Domain spells, Oath spells, etc.

  // Abilities
  bool ritualCasting;
  bool canUseScrolls;
}

enum SpellcastingType {
  standard,      // Cleric, Wizard, Druid, etc.
  pactMagic,     // Warlock
  innate,        // Some racial traits
}

enum SpellKnowledgeType {
  prepared,      // Cleric, Druid, Paladin (choose from full list)
  known,         // Bard, Sorcerer, Warlock (fixed known spells)
  spellbook,     // Wizard (can learn unlimited, prepare subset)
}
```

#### Spell
```dart
class Spell {
  String id;
  Map<String, String> localizedName;
  Map<String, String> localizedDescription;

  int level;  // 0-9 (0 = cantrip)
  School school;
  CastingTime castingTime;
  Range range;
  List<Component> components;  // V, S, M
  String? materialComponents;
  Duration duration;
  bool concentration;
  bool ritual;

  // Damage/Healing
  DiceFormula? baseDamage;
  Map<int, DiceFormula>? damageBySlotLevel;  // Upcast scaling
  DamageType? damageType;

  // Saving Throw
  AbilityType? savingThrow;

  // Targets
  int targetCount;
  String targetType;  // creature, object, point in space

  // Spell Lists
  List<String> classLists;  // Which classes can learn this?

  // Source
  String source;  // PHB, XGE, TCoE, etc.
}
```

---

### Layer 6: Class & Subclass Definitions

#### ClassDefinition
```dart
class ClassDefinition {
  String id;
  Map<String, String> localizedName;
  Map<String, String> localizedDescription;

  // Core Stats
  int hitDie;
  AbilityType primaryAbility;
  List<AbilityType> savingThrowProficiencies;

  // Proficiencies
  List<ArmorType> armorProficiencies;
  List<WeaponType> weaponProficiencies;
  List<String> toolProficiencies;

  // Skills
  int skillChoices;
  List<Skill> skillOptions;

  // Spellcasting
  SpellcastingProgression? spellcastingProgression;

  // Features by level
  Map<int, List<FeatureGrant>> featuresByLevel;

  // Subclasses
  int subclassLevel;  // Level when subclass is chosen
  List<String> subclassIds;

  // Multiclassing
  MulticlassRequirements? multiclassRequirements;
}

class FeatureGrant {
  String featureId;
  int count;  // For features with multiple uses
  FeatureChoice? choice;  // If player must choose (e.g., Fighting Style)
}

class FeatureChoice {
  String choiceId;
  Map<String, String> localizedPrompt;
  List<String> options;  // List of feature IDs to choose from
  int count;  // How many to pick
}
```

#### SubclassDefinition
```dart
class SubclassDefinition {
  String id;
  String parentClassId;
  Map<String, String> localizedName;
  Map<String, String> localizedDescription;

  // Features by level (relative to class level, not subclass level)
  Map<int, List<FeatureGrant>> featuresByLevel;

  // Additional spell lists
  Map<int, List<String>>? expandedSpells;  // Warlock, Cleric, Paladin
}
```

---

### Layer 7: Inventory System

#### Inventory
```dart
class Inventory {
  // Equipped Items (slots)
  EquipmentSlot<Weapon?> mainHand;
  EquipmentSlot<Weapon?> offHand;
  EquipmentSlot<Armor?> armor;
  EquipmentSlot<Shield?> shield;
  EquipmentSlot<Item?> head;
  EquipmentSlot<Item?> neck;
  EquipmentSlot<Item?> back;
  EquipmentSlot<Item?> ring1;
  EquipmentSlot<Item?> ring2;
  EquipmentSlot<Item?> belt;
  EquipmentSlot<Item?> boots;

  // Backpack
  List<InventoryItem> items;

  // Currency
  Currency currency;

  // Calculated
  double get totalWeight;
  int get armorClassBonus;
  List<CharacterModifier> get itemModifiers;
}

class InventoryItem {
  Item item;
  int quantity;
  bool isAttuned;  // For magic items
}

class Item {
  String id;
  Map<String, String> localizedName;
  Map<String, String> localizedDescription;

  ItemCategory category;
  double weight;
  int valueInCopper;
  String? imagePath;

  // For magic items
  Rarity? rarity;
  bool requiresAttunement;
  List<CharacterModifier>? modifiers;

  // For weapons
  DiceFormula? damage;
  DamageType? damageType;
  List<WeaponProperty>? properties;

  // For armor
  int? armorClass;
  int? maxDexBonus;
  bool? stealthDisadvantage;
}
```

---

## 🔄 Data Flow Architecture

### 1. Character Loading
```
App Start
  ↓
Hive.openBox<Character>('characters')
  ↓
Load CharacterProvider (state management)
  ↓
Character List Screen
  ↓ (tap character)
Character Sheet Screen
  ↓
Calculate all derived stats
  ↓
Display with real-time updates
```

### 2. Feature Activation
```
User taps "Rage" button
  ↓
ActionFeature.activate()
  ↓
Check conditions (has uses remaining?)
  ↓
Consume resource (rageUses - 1)
  ↓
Apply modifiers (damage +2, resistance to physical)
  ↓
Update UI
  ↓
Save to Hive
```

### 3. Spell Casting
```
User casts "Fireball" (3rd level slot)
  ↓
Check if prepared/known
  ↓
Check if has slot available
  ↓
Consume slot (3rd level: 3 → 2)
  ↓
Display spell effect
  ↓
Roll damage (8d6)
  ↓
Save to Hive
```

### 4. FC5 Import
```
User selects .xml file
  ↓
FC5Parser.parse(xmlContent)
  ↓
Extract character data
  ↓
Map to Character model
  ↓
Validate & resolve references
  ↓
Save to Hive
  ↓
Display in character list
```

---

## 🗂️ File Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart                 # MaterialApp with theme
│   └── router.dart              # Navigation routes
├── models/
│   ├── character/
│   │   ├── character.dart
│   │   ├── ability_scores.dart
│   │   ├── class_level.dart
│   │   └── proficiencies.dart
│   ├── features/
│   │   ├── character_feature.dart
│   │   ├── passive_feature.dart
│   │   ├── action_feature.dart
│   │   ├── toggle_feature.dart
│   │   └── resource_feature.dart
│   ├── modifiers/
│   │   ├── character_modifier.dart
│   │   └── conditional_effect.dart
│   ├── resources/
│   │   └── resource_pool.dart
│   ├── spellcasting/
│   │   ├── spellcasting_info.dart
│   │   ├── spell.dart
│   │   └── metamagic.dart
│   ├── inventory/
│   │   ├── inventory.dart
│   │   ├── item.dart
│   │   ├── weapon.dart
│   │   └── armor.dart
│   ├── definitions/
│   │   ├── class_definition.dart
│   │   ├── subclass_definition.dart
│   │   ├── race_definition.dart
│   │   └── background_definition.dart
│   └── enums/
│       └── ... (all enums)
├── services/
│   ├── storage/
│   │   ├── hive_service.dart
│   │   └── adapters/
│   ├── data_loader/
│   │   ├── json_loader.dart
│   │   └── asset_loader.dart
│   ├── fc5/
│   │   ├── fc5_parser.dart
│   │   └── fc5_exporter.dart
│   └── calculators/
│       ├── stat_calculator.dart
│       ├── ac_calculator.dart
│       └── modifier_calculator.dart
├── providers/
│   ├── character_provider.dart
│   ├── theme_provider.dart
│   ├── locale_provider.dart
│   └── dice_roller_provider.dart
├── screens/
│   ├── splash/
│   ├── character_list/
│   ├── character_sheet/
│   ├── character_creation/
│   ├── spell_almanac/
│   └── settings/
├── widgets/
│   ├── character_card.dart
│   ├── stat_block.dart
│   ├── spell_slot_tracker.dart
│   ├── dice_roller.dart
│   └── ... (reusable components)
├── theme/
│   ├── app_theme.dart
│   ├── color_schemes/
│   │   ├── monokai.dart
│   │   ├── gruvbox.dart
│   │   └── ...
│   └── animations/
│       └── app_animations.dart
└── l10n/
    ├── app_en.arb
    └── app_ru.arb
```

---

## 🎨 UI Component Architecture

### Atomic Design Approach

**Atoms**: Basic building blocks
- Buttons, icons, text styles, colors

**Molecules**: Simple combinations
- StatBlock (ability score + modifier)
- ResourceCounter (current/max with +/- buttons)
- SpellSlotIndicator (filled/empty circles)

**Organisms**: Complex components
- CharacterCard (list item)
- SpellCard (detailed spell info)
- FeatureCard (expandable feature description)

**Templates**: Screen layouts
- CharacterSheetTemplate (expandable header + tabs)
- WizardTemplate (stepper + nav buttons)

**Pages**: Complete screens
- CharacterListScreen
- CharacterSheetScreen
- SpellAlmanacScreen

---

## 🔐 Data Validation & Constraints

### Character Creation Constraints
```dart
class CharacterValidator {
  // Ability Score Rules
  static const int MIN_ABILITY_SCORE = 1;
  static const int MAX_ABILITY_SCORE = 20;  // 30 with magic items
  static const int STANDARD_ARRAY = [15, 14, 13, 12, 10, 8];

  // Multiclassing
  static bool canMulticlass(Character character, String newClassId) {
    var classDef = getClassDefinition(newClassId);
    return classDef.multiclassRequirements?.isMet(character) ?? false;
  }

  // Spell Preparation
  static int maxPreparedSpells(Character character) {
    var spellcastingAbility = character.spellcasting?.spellcastingAbility;
    var modifier = character.abilityScores.getModifier(spellcastingAbility);
    return character.level + modifier;
  }
}
```

---

## 🚀 Performance Optimization

### 1. Lazy Loading
- Character list loads only metadata initially
- Full character data loaded on demand
- Spell Almanac uses virtualized scrolling

### 2. Caching
- Class/race/spell definitions cached in memory
- Images cached with flutter_cache_manager

### 3. Computed Properties
```dart
class Character {
  // Memoized calculations
  late final int proficiencyBonus = _calculateProficiencyBonus();
  late final int armorClass = _calculateAC();

  // Only recalculate when dependencies change
  void _invalidateCache() {
    // Clear memoized values
  }
}
```

---

## 🧪 Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Stat calculations (AC, modifiers, etc.)
- FC5 parser with real XML examples

### Widget Tests
- Character card rendering
- Spell slot tracker interactions
- Dice roller animations

### Integration Tests
- Character creation flow
- FC5 import/export roundtrip
- Spell casting workflow

---

## 📦 Third-Party Dependencies

```yaml
dependencies:
  flutter: ^3.24.0

  # State Management
  provider: ^6.1.0

  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # JSON Parsing
  json_annotation: ^4.8.1

  # XML Parsing (FC5)
  xml: ^6.5.0

  # Localization
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

  # UI
  animations: ^2.0.11
  flutter_animate: ^4.5.0

  # Images
  flutter_cache_manager: ^3.3.1
  image_picker: ^1.0.7

  # Utilities
  uuid: ^4.3.3
  path_provider: ^2.1.2

dev_dependencies:
  build_runner: ^2.4.8
  hive_generator: ^2.0.1
  json_serializable: ^6.7.1
  flutter_test:
    sdk: flutter
```

---

## ✅ Architecture Validation Checklist

Before Session 1 begins, validate:

- [x] Universal feature system can represent ALL class mechanics
- [x] Resource pools extensible for custom types
- [x] Modifier system handles all stat changes
- [x] Spell system supports standard + Pact Magic + Sorcery Points
- [x] Inventory system calculates AC from equipment
- [x] FC5 import/export preserves all data
- [x] Bilingual support baked into all models
- [x] Offline-first design (no network dependencies)
- [x] Hive models defined with type adapters
- [x] UI components decoupled from specific classes

---

**Last Updated**: Session 0 - 2025-11-06
**Status**: Architecture Defined, Ready for Implementation
