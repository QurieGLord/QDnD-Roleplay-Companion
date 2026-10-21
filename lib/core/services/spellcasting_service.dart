import '../progression/class_spellcasting_profile.dart';
import '../magic/spell_preparation_rules.dart';
import 'dart:math' as math;
import '../models/character.dart';
import '../models/spell.dart';
import '../models/character_feature.dart';
import 'character_data_service.dart';
import 'gameplay_actions_service.dart';

/// Universal spellcasting mechanics calculator for ALL D&D 5e classes
class SpellcastingService {
  static List<int> availableSlotLevels(Character character, int spellLevel) => [
        for (int i = 0; i < character.spellSlots.length && i < 9; i++)
          if (i + 1 >= spellLevel && character.spellSlots[i] > 0) i + 1,
      ];

  static ResourcePool? _arcanumPool(Character character, int level) {
    if (character.classLevel('warlock') == 0 || level < 6) return null;
    return GameplayActionsService.arcanumFeature(character, level)
        ?.resourcePool;
  }

  static bool canCastWithoutSlot(Character character, Spell spell) =>
      spell.level == 0 ||
      character.spellMasterySpells.contains(spell.id) ||
      (character.signatureSpells.contains(spell.id) &&
          !(character.signatureSpellsUsed[spell.id] ?? false)) ||
      (_arcanumPool(character, spell.level)?.currentUses ?? 0) > 0;

  /// Apply the cost in memory; the caller persists cost and feedback together.
  static bool applyCast(Character character, Spell spell, {int slotLevel = 0}) {
    if (slotLevel < 0) return false;
    if (slotLevel > 0) {
      if (slotLevel < spell.level ||
          slotLevel > character.spellSlots.length ||
          slotLevel > 9 ||
          character.spellSlots[slotLevel - 1] <= 0) {
        return false;
      }
      character.spellSlots[slotLevel - 1]--;
      return true;
    }
    if (spell.level == 0 || character.spellMasterySpells.contains(spell.id)) {
      return true;
    }
    if (character.signatureSpells.contains(spell.id) &&
        !(character.signatureSpellsUsed[spell.id] ?? false)) {
      character.signatureSpellsUsed[spell.id] = true;
      return true;
    }
    final pool = _arcanumPool(character, spell.level);
    if (pool == null || pool.currentUses <= 0) return false;
    pool.use(1);
    return true;
  }

  /// Get the spellcasting ability for a class
  static String getSpellcastingAbility(String className) {
    // 1. Try to find class data from loaded compendium/assets
    try {
      final classData = CharacterDataService.getClassById(className);
      if (classData != null && classData.spellcasting != null) {
        return classData.spellcasting!.ability.toLowerCase();
      }
    } catch (e) {
      // Ignore lookup errors and fall back to hardcoded defaults
    }

    // 2. Fallback for standard classes if not loaded or missing info
    switch (className.toLowerCase()) {
      // Intelligence casters
      case 'wizard':
      case 'eldritch knight':
      case 'arcane trickster':
        return 'intelligence';

      // Wisdom casters
      case 'cleric':
      case 'druid':
      case 'ranger':
      case 'monk': // Ki-based, but uses Wisdom for some features
        return 'wisdom';

      // Charisma casters
      case 'bard':
      case 'sorcerer':
      case 'warlock':
      case 'paladin':
      case 'паладин': // Russian
        return 'charisma';

      // Non-spellcasters
      default:
        return 'none';
    }
  }

  /// Get the ability modifier for spellcasting
  static int getSpellcastingModifier(Character character) {
    final ability = getSpellcastingAbility(character.characterClass);

    switch (ability) {
      case 'intelligence':
        return character.abilityScores.intelligenceModifier;
      case 'wisdom':
        return character.abilityScores.wisdomModifier;
      case 'charisma':
        return character.abilityScores.charismaModifier;
      default:
        return 0;
    }
  }

  /// Calculate Spell Save DC: 8 + proficiency bonus + spellcasting modifier
  static int getSpellSaveDC(Character character) {
    return 8 + character.proficiencyBonus + getSpellcastingModifier(character);
  }

  /// Calculate Spell Attack Bonus: proficiency bonus + spellcasting modifier
  static int getSpellAttackBonus(Character character) {
    return character.proficiencyBonus + getSpellcastingModifier(character);
  }

  /// Get spellcasting ability name (localized)
  static String getSpellcastingAbilityName(String className,
      {bool russian = false}) {
    final ability = getSpellcastingAbility(className);

    if (russian) {
      switch (ability) {
        case 'intelligence':
          return 'Интеллект';
        case 'wisdom':
          return 'Мудрость';
        case 'charisma':
          return 'Харизма';
        default:
          return 'Нет';
      }
    } else {
      switch (ability) {
        case 'intelligence':
          return 'Intelligence';
        case 'wisdom':
          return 'Wisdom';
        case 'charisma':
          return 'Charisma';
        default:
          return 'None';
      }
    }
  }

  /// Check if a class is a spellcaster
  static bool isSpellcaster(String className) {
    return getSpellcastingAbility(className) != 'none';
  }

  /// Get maximum prepared spells for prepared casters
  static int getMaxPreparedSpells(Character character) {
    final entry = character.classes.where((c) => c.isPrimary).firstOrNull ??
        character.classes.firstOrNull;
    if (entry == null) return 0;
    try {
      final p = ClassSpellcastingProfile.resolve(character, entry.id),
          rules = p?.preparation;
      if (p == null ||
          rules == null ||
          rules.mode == SpellPreparationMode.known ||
          p.learningCircle == 0) {
        return 0;
      }
      return math.max(1, p.modifier + p.classLevel ~/ rules.divisor);
    } catch (_) {
      return 0;
    }
  }

  /// Get spellcasting type (prepared vs known)
  static String getSpellcastingType(String className) {
    switch (className.toLowerCase()) {
      case 'wizard':
      case 'cleric':
      case 'druid':
      case 'paladin':
      case 'паладин':
        return 'prepared';

      case 'bard':
      case 'sorcerer':
      case 'ranger':
      case 'eldritch knight':
      case 'arcane trickster':
        return 'known';

      case 'warlock':
        return 'pact_magic';

      default:
        return 'none';
    }
  }

  /// Get total spells known for a specific class and level (for "Known" casters)
  /// Returns 0 for Prepared casters (who know all or use spellbook).
  static int getSpellsKnownCount(String className, int level) {
    if (level < 1) return 0;

    switch (className.toLowerCase()) {
      case 'bard':
        // Bard: 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 15, 16, 18, 19, 19, 20, 22, 22, 22
        const table = [
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          14,
          15,
          15,
          16,
          18,
          19,
          19,
          20,
          22,
          22,
          22
        ];
        return table[level - 1];

      case 'sorcerer':
        // Sorcerer: 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 13, 14, 14, 15, 15, 15, 15
        const table = [
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          12,
          13,
          13,
          14,
          14,
          15,
          15,
          15,
          15
        ];
        return table[level - 1];

      case 'warlock':
        // Warlock: 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15
        const table = [
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          10,
          11,
          11,
          12,
          12,
          13,
          13,
          14,
          14,
          15,
          15
        ];
        return table[level - 1];

      case 'ranger':
        // Ranger: 0, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11
        const table = [
          0,
          2,
          3,
          3,
          4,
          4,
          5,
          5,
          6,
          6,
          7,
          7,
          8,
          8,
          9,
          9,
          10,
          10,
          11,
          11
        ];
        return table[level - 1];

      case 'rogue': // Arcane Trickster
      case 'arcane trickster':
        // AT: 0, 0, 3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 11, 12, 13
        const table = [
          0,
          0,
          3,
          4,
          4,
          4,
          5,
          6,
          6,
          7,
          8,
          8,
          9,
          10,
          10,
          11,
          11,
          11,
          12,
          13
        ];
        return table[level - 1];

      case 'fighter': // Eldritch Knight
      case 'eldritch knight':
        // EK: 0, 0, 3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 11, 12, 13 (Same as AT)
        const table = [
          0,
          0,
          3,
          4,
          4,
          4,
          5,
          6,
          6,
          7,
          8,
          8,
          9,
          10,
          10,
          11,
          11,
          11,
          12,
          13
        ];
        return table[level - 1];

      case 'wizard':
        // Wizard starts with 6, gains 2 per level.
        // This is a minimum; they can add more via scribing.
        return 6 + (level - 1) * 2;

      default:
        return 0;
    }
  }
}
