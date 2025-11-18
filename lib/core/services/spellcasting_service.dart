import '../models/character.dart';

/// Universal spellcasting mechanics calculator for ALL D&D 5e classes
class SpellcastingService {
  /// Get the spellcasting ability for a class
  static String getSpellcastingAbility(String className) {
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
  static String getSpellcastingAbilityName(String className, {bool russian = false}) {
    final ability = getSpellcastingAbility(className);

    if (russian) {
      switch (ability) {
        case 'intelligence': return 'Интеллект';
        case 'wisdom': return 'Мудрость';
        case 'charisma': return 'Харизма';
        default: return 'Нет';
      }
    } else {
      switch (ability) {
        case 'intelligence': return 'Intelligence';
        case 'wisdom': return 'Wisdom';
        case 'charisma': return 'Charisma';
        default: return 'None';
      }
    }
  }

  /// Check if a class is a spellcaster
  static bool isSpellcaster(String className) {
    return getSpellcastingAbility(className) != 'none';
  }

  /// Get maximum prepared spells for prepared casters
  static int getMaxPreparedSpells(Character character) {
    final className = character.characterClass.toLowerCase();

    switch (className) {
      // Prepared casters: modifier + level (or half level for half casters)
      case 'wizard':
      case 'cleric':
      case 'druid':
        return getSpellcastingModifier(character) + character.level;

      case 'paladin':
      case 'паладин':
        final calc = getSpellcastingModifier(character) + (character.level ~/ 2);
        return calc < 1 ? 1 : calc; // Minimum 1

      // Known casters don't prepare
      case 'bard':
      case 'sorcerer':
      case 'ranger':
      case 'warlock':
      case 'eldritch knight':
      case 'arcane trickster':
        return 0; // They don't prepare spells

      default:
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
}
