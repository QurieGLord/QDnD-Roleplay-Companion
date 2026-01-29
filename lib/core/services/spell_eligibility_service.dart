import '../models/character.dart';
import '../models/spell.dart';
import 'character_data_service.dart';

/// Universal spell eligibility checker for ALL D&D 5e classes
/// This service determines which spells a character can learn/prepare
/// based on class, level, subclass, and other factors
class SpellEligibilityService {
  /// Map Russian class names to English (for FC5 import compatibility)
  static final Map<String, String> _classNameMapping = {
    'паладин': 'paladin',
    'воин': 'fighter',
    'варвар': 'barbarian',
    'монах': 'monk',
    'плут': 'rogue',
    'следопыт': 'ranger',
    'друид': 'druid',
    'жрец': 'cleric',
    'волшебник': 'wizard',
    'чародей': 'sorcerer',
    'колдун': 'warlock',
    'бард': 'bard',
    'изобретатель': 'artificer',
  };

  /// Normalize class name to English lowercase for comparison
  static String _normalizeClassName(String className) {
    final normalized = className.toLowerCase().trim();
    return _classNameMapping[normalized] ?? normalized;
  }

  /// Check if a character can learn/prepare a given spell
  static SpellEligibilityResult checkEligibility(Character character, Spell spell) {
    final className = _normalizeClassName(character.characterClass);
    final charLevel = character.level;

    // 1. Check if spell is available to character's class
    if (!_isSpellAvailableToClass(spell, character)) {
      return SpellEligibilityResult(
        canLearn: false,
        reason: 'Spell not available to ${character.characterClass}',
        reasonRu: 'Заклинание недоступно для класса ${character.characterClass}',
      );
    }

    // 2. Check character level requirements
    final minLevel = _getMinimumCharacterLevel(className, spell.level);
    if (charLevel < minLevel) {
      return SpellEligibilityResult(
        canLearn: false,
        canLearnAtLevel: minLevel,
        reason: 'Available at level $minLevel',
        reasonRu: 'Доступно на $minLevel уровне',
      );
    }

    // 3. Check subclass-specific restrictions (Arcane Trickster, Eldritch Knight)
    final subclassCheck = _checkSubclassRestrictions(character, spell);
    if (!subclassCheck.canLearn) {
      return subclassCheck;
    }

    // 4. Spell is available!
    return SpellEligibilityResult(
      canLearn: true,
      reason: 'Available to learn',
      reasonRu: 'Доступно для изучения',
      spellcastingType: _getSpellcastingType(className),
      isAlwaysPrepared: _isAlwaysPrepared(character, spell),
    );
  }

  /// Get all spells available to a character (for Almanac filtering)
  static List<Spell> getAvailableSpells(Character character, List<Spell> allSpells) {
    return allSpells.where((spell) {
      final result = checkEligibility(character, spell);
      return result.canLearn || result.canLearnAtLevel != null;
    }).toList();
  }

  /// Get spells available to learn RIGHT NOW (current level)
  static List<Spell> getLearnableSpells(Character character, List<Spell> allSpells) {
    return allSpells.where((spell) {
      final result = checkEligibility(character, spell);
      return result.canLearn;
    }).toList();
  }

  /// Get spells that will be available in the future
  static List<Spell> getFutureSpells(Character character, List<Spell> allSpells) {
    return allSpells.where((spell) {
      final result = checkEligibility(character, spell);
      return !result.canLearn && result.canLearnAtLevel != null;
    }).toList();
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================

  /// Check if spell is in the class's spell list
  static bool _isSpellAvailableToClass(Spell spell, Character character) {
    final normalizedClassName = _normalizeClassName(character.characterClass);
    final normalizedSubclass = character.subclass != null ? _normalizeClassName(character.subclass!) : null;

    // Check base class availability
    if (spell.availableToClasses.any((c) => _normalizeClassName(c) == normalizedClassName)) {
      return true;
    }

    // Check subclass availability (e.g., "Eldritch Knight", "Arcane Trickster")
    if (normalizedSubclass != null && spell.availableToClasses.any((c) => _normalizeClassName(c) == normalizedSubclass)) {
      return true;
    }

    // Special case: Oath spells for Paladins (future implementation)
    // TODO: Check oath-specific spell lists when subclass data is added

    return false;
  }

  /// Get minimum character level to access a spell level
  static int _getMinimumCharacterLevel(String className, int spellLevel) {
    // Cantrips available at level 1 for all spellcasters
    if (spellLevel == 0) return 1;

    // 1. Try dynamic lookup via CharacterDataService
    final classData = CharacterDataService.getClassById(className);
    if (classData != null && classData.spellcasting != null) {
      final type = classData.spellcasting!.type;
      switch (type) {
        case 'full': return _fullCasterSpellLevelProgression[spellLevel] ?? 99;
        case 'half': return _halfCasterSpellLevelProgression[spellLevel] ?? 99;
        case 'third': return _thirdCasterSpellLevelProgression[spellLevel] ?? 99;
        case 'pact': return _fullCasterSpellLevelProgression[spellLevel] ?? 99;
        default: return 99;
      }
    }

    switch (className) {
      // FULL CASTERS (Wizard, Cleric, Druid, Bard, Sorcerer)
      case 'wizard':
      case 'cleric':
      case 'druid':
      case 'bard':
      case 'sorcerer':
        return _fullCasterSpellLevelProgression[spellLevel] ?? 99;

      // HALF CASTERS (Paladin, Ranger)
      case 'paladin':
      case 'паладин':
      case 'ranger':
        return _halfCasterSpellLevelProgression[spellLevel] ?? 99;

      // THIRD CASTERS (Eldritch Knight, Arcane Trickster)
      case 'eldritch knight':
      case 'arcane trickster':
        return _thirdCasterSpellLevelProgression[spellLevel] ?? 99;

      // WARLOCK (Pact Magic - same progression as full casters but different mechanic)
      case 'warlock':
        return _fullCasterSpellLevelProgression[spellLevel] ?? 99;

      // Non-spellcasters
      default:
        return 99;
    }
  }

  /// Check subclass-specific school restrictions
  static SpellEligibilityResult _checkSubclassRestrictions(Character character, Spell spell) {
    final subclass = character.subclass?.toLowerCase();

    // Arcane Trickster: Most spells must be Illusion or Enchantment
    if (subclass == 'arcane trickster') {
      // At 3rd, 8th, 14th, 20th level they can learn ANY wizard spell
      final flexLevels = [3, 8, 14, 20];
      if (flexLevels.contains(character.level)) {
        return SpellEligibilityResult(canLearn: true, reason: 'Free choice level', reasonRu: 'Уровень свободного выбора');
      }

      // Otherwise must be Illusion or Enchantment
      if (spell.school != 'Illusion' && spell.school != 'Enchantment') {
        return SpellEligibilityResult(
          canLearn: false,
          reason: 'Arcane Trickster: Must be Illusion or Enchantment (except at levels 3, 8, 14, 20)',
          reasonRu: 'Таинственный плут: Только школы Иллюзии и Очарования (кроме уровней 3, 8, 14, 20)',
        );
      }
    }

    // Eldritch Knight: Most spells must be Abjuration or Evocation
    if (subclass == 'eldritch knight') {
      // At 3rd, 8th, 14th, 20th level they can learn ANY wizard spell
      final flexLevels = [3, 8, 14, 20];
      if (flexLevels.contains(character.level)) {
        return SpellEligibilityResult(canLearn: true, reason: 'Free choice level', reasonRu: 'Уровень свободного выбора');
      }

      // Otherwise must be Abjuration or Evocation
      if (spell.school != 'Abjuration' && spell.school != 'Evocation') {
        return SpellEligibilityResult(
          canLearn: false,
          reason: 'Eldritch Knight: Must be Abjuration or Evocation (except at levels 3, 8, 14, 20)',
          reasonRu: 'Мистический рыцарь: Только школы Ограждения и Воплощения (кроме уровней 3, 8, 14, 20)',
        );
      }
    }

    return SpellEligibilityResult(canLearn: true, reason: 'OK', reasonRu: 'OK');
  }

  /// Determine spellcasting type for the class
  static SpellcastingType _getSpellcastingType(String className) {
    // 1. Try dynamic lookup
    final classData = CharacterDataService.getClassById(className);
    if (classData != null && classData.spellcasting != null) {
      final type = classData.spellcasting!.type;
      // Map string type to enum
      switch (type) {
        case 'full':
          if (classData.id == 'warlock') return SpellcastingType.pactMagic;
          if (['wizard', 'cleric', 'druid', 'paladin', 'artificer'].contains(classData.id)) {
             return SpellcastingType.prepared;
          }
          return SpellcastingType.known;
          
        case 'half':
           if (classData.id == 'paladin') return SpellcastingType.prepared;
           return SpellcastingType.known; 
           
        case 'third':
           return SpellcastingType.known; 
           
        case 'pact':
           return SpellcastingType.pactMagic;
           
        default:
           return SpellcastingType.none;
      }
    }

    switch (className) {
      // Prepared casters (can prepare from full class list)
      case 'wizard':
      case 'cleric':
      case 'druid':
      case 'paladin':
      case 'паладин':
        return SpellcastingType.prepared;

      // Known casters (learn fixed number, always have them available)
      case 'bard':
      case 'sorcerer':
      case 'ranger':
      case 'eldritch knight':
      case 'arcane trickster':
        return SpellcastingType.known;

      // Warlock uses Pact Magic (special case)
      case 'warlock':
        return SpellcastingType.pactMagic;

      default:
        return SpellcastingType.none;
    }
  }

  /// Check if spell is always prepared (Oath spells, Domain spells, etc)
  static bool _isAlwaysPrepared(Character character, Spell spell) {
    // TODO: Implement when we have subclass spell lists
    // - Paladin Oath spells
    // - Cleric Domain spells
    // - Warlock Mystic Arcanum
    return false;
  }

  // ============================================================
  // SPELL LEVEL PROGRESSION TABLES (from PHB)
  // ============================================================

  /// Full caster spell level progression (Wizard, Cleric, Druid, Bard, Sorcerer, Warlock)
  static const Map<int, int> _fullCasterSpellLevelProgression = {
    1: 1,  // 1st level spells at character level 1
    2: 3,  // 2nd level spells at character level 3
    3: 5,  // 3rd level spells at character level 5
    4: 7,  // 4th level spells at character level 7
    5: 9,  // 5th level spells at character level 9
    6: 11, // 6th level spells at character level 11
    7: 13, // 7th level spells at character level 13
    8: 15, // 8th level spells at character level 15
    9: 17, // 9th level spells at character level 17
  };

  /// Half caster spell level progression (Paladin, Ranger)
  static const Map<int, int> _halfCasterSpellLevelProgression = {
    1: 2,  // 1st level spells at character level 2
    2: 5,  // 2nd level spells at character level 5
    3: 9,  // 3rd level spells at character level 9
    4: 13, // 4th level spells at character level 13
    5: 17, // 5th level spells at character level 17
  };

  /// Third caster spell level progression (Eldritch Knight, Arcane Trickster)
  static const Map<int, int> _thirdCasterSpellLevelProgression = {
    1: 3,  // 1st level spells at character level 3
    2: 7,  // 2nd level spells at character level 7
    3: 13, // 3rd level spells at character level 13
    4: 19, // 4th level spells at character level 19
  };
}

// ============================================================
// RESULT CLASSES
// ============================================================

/// Result of spell eligibility check
class SpellEligibilityResult {
  final bool canLearn;
  final int? canLearnAtLevel; // If not learnable now, at what level it becomes available
  final String reason;
  final String reasonRu;
  final SpellcastingType? spellcastingType;
  final bool isAlwaysPrepared;

  SpellEligibilityResult({
    required this.canLearn,
    this.canLearnAtLevel,
    required this.reason,
    required this.reasonRu,
    this.spellcastingType,
    this.isAlwaysPrepared = false,
  });
}

/// Type of spellcasting system used by the class
enum SpellcastingType {
  none,       // Non-spellcaster (Barbarian, Fighter, Rogue - base classes)
  prepared,   // Prepared casters: Wizard, Cleric, Druid, Paladin
  known,      // Known casters: Bard, Sorcerer, Ranger, Warlock, Eldritch Knight, Arcane Trickster
  pactMagic,  // Warlock's unique system
}
