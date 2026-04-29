// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/character.dart';
import '../models/character_feature.dart';

/// Service for managing character class features
/// Loads features from JSON and assigns them to characters based on class/level
class FeatureService {
  static final Map<String, CharacterFeature> _features = {};
  static bool _initialized = false;

  /// Expose a list of all loaded features for fuzzy searches
  static List<CharacterFeature> get allFeatures => _features.values.toList();

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

  /// Map Russian subclass names to English (for FC5 import compatibility)
  static final Map<String, String> _subclassNameMapping = {
    // Paladin Oaths
    'клятва покорения': 'oath of conquest',
    'клятва преданности': 'oath of devotion',
    'клятва древних': 'oath of the ancients',
    'клятва мести': 'oath of vengeance',
    'клятва короны': 'oath of the crown',
    'клятва искупления': 'oath of redemption',
    'клятва славы': 'oath of glory',
    'клятва стражей': 'oath of the watchers',
    // Note: Add other subclass mappings as needed
  };

  /// Normalize class name to English lowercase for comparison
  static String _normalizeClassName(String className) {
    final normalized = className.toLowerCase().trim();
    return _classNameMapping[normalized] ??
        _subclassNameMapping[normalized] ??
        normalized;
  }

  static bool _isPlaceholderFeature(CharacterFeature feature) {
    final id = feature.id.toLowerCase();
    return id.startsWith('primal-path-improvement-');
  }

  /// Initialize the service by loading all features from JSON
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // Load Unified Feature Registry
      await _loadFeaturesFromAsset('assets/data/features/srd_features.json');

      // Load subclass specific features (keep hardcoded ONLY for complex logic not yet JSON-ified)
      _loadSubclassFeatures();
    } catch (e) {
      print('❌ Error loading features: $e');
      // Fallback to hardcoded list if manifest fails (e.g. during testing or some build configurations)
      try {
        await _loadFeaturesFromAsset(
          'assets/data/features/paladin_features.json',
        );
        _loadSubclassFeatures();
      } catch (e2) {
        print('❌ Error loading fallback features: $e2');
      }
    }

    print(
      '🔧 FeatureService.init() completed. Loaded ${_features.length} features',
    );
    _initialized = true;
  }

  static Future<void> _loadFeaturesFromAsset(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = json.decode(jsonString);

      for (var jsonFeature in jsonList) {
        try {
          final feature = CharacterFeature.fromJson(jsonFeature);
          _features[feature.id] = feature;
        } catch (e) {
          print('❌ Error parsing feature in $path: $e');
        }
      }
    } catch (e) {
      print('❌ Error reading feature file $path: $e');
    }
  }

  // _inferClassFromPath removed (no longer needed)

  /// Get features available strictly at a specific level for a specific class/subclass
  /// Used for Level Up preview to avoid showing features from other classes/subclasses
  static List<CharacterFeature> getFeaturesForLevel({
    required String classId,
    required int level,
    String? subclassId,
  }) {
    final normalizedClass = _normalizeClassName(classId);
    final normalizedSubclass =
        subclassId != null ? _normalizeClassName(subclassId) : null;

    return _features.values.where((f) {
      if (_isPlaceholderFeature(f)) return false;
      if (f.isOptional) return false;

      // 1. Strict Level Check
      if (f.minLevel != level) return false;

      // 2. Strict Class Check
      // If feature has no associated class, it's global (like Racial traits),
      // but usually we only want class features here.
      if (f.associatedClass == null) return false;

      final featureClass = _normalizeClassName(f.associatedClass!);
      if (featureClass != normalizedClass) return false;

      // 3. Strict Subclass Check
      // - If feature has NO subclass -> it is a base class feature (keep it)
      // - If feature HAS subclass -> it MUST match the character's subclass
      if (f.associatedSubclass != null) {
        final featureSubclass = _normalizeClassName(f.associatedSubclass!);
        if (featureSubclass != normalizedSubclass) return false;
      }

      return true;
    }).toList();
  }

  /// Get all features available for a character at their current level
  static List<CharacterFeature> getFeaturesForCharacter(Character character) {
    final characterClassName = _normalizeClassName(character.characterClass);
    final characterSubclassName = character.subclass != null
        ? _normalizeClassName(character.subclass!)
        : '';

    print(
      '🔧 getFeaturesForCharacter: normalized class "${character.characterClass}" -> "$characterClassName"',
    );
    if (character.subclass != null) {
      print(
        '🔧 getFeaturesForCharacter: normalized subclass "${character.subclass}" -> "$characterSubclassName"',
      );
    }

    return _features.values.where((feature) {
      if (_isPlaceholderFeature(feature)) return false;
      if (feature.isOptional) return false;

      // Check if feature belongs to this class
      if (feature.associatedClass != null) {
        final featureClassName = _normalizeClassName(feature.associatedClass!);
        if (featureClassName != characterClassName) {
          return false;
        }
      }

      // Check if feature belongs to this subclass
      if (feature.associatedSubclass != null) {
        final featureSubclassName = _normalizeClassName(
          feature.associatedSubclass!,
        );
        if (featureSubclassName != characterSubclassName) {
          return false;
        }
      }

      // Check if character level is sufficient
      if (character.level < feature.minLevel) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Calculate max uses for a resource pool based on character stats
  static int calculateMaxUses(Character character, String? formula) {
    if (formula == null || formula.isEmpty) return 0;

    try {
      final resolved = _replaceFormulaVariables(
        formula.toLowerCase().trim(),
        character,
      );
      return _evaluateFormulaExpression(resolved);
    } catch (e) {
      return 0;
    }
  }

  static String _replaceFormulaVariables(String formula, Character character) {
    return formula
        .replaceAll('level', character.level.toString())
        .replaceAll(
          'cha_mod',
          character.abilityScores.charismaModifier.toString(),
        )
        .replaceAll(
          'wis_mod',
          character.abilityScores.wisdomModifier.toString(),
        )
        .replaceAll(
          'int_mod',
          character.abilityScores.intelligenceModifier.toString(),
        )
        .replaceAll('prof_bonus', character.proficiencyBonus.toString());
  }

  static int _evaluateFormulaExpression(String expression) {
    var f = expression.replaceAll(' ', '');
    f = _stripOuterParentheses(f);

    if (f.startsWith('max(') && f.endsWith(')')) {
      final inner = f.substring(4, f.length - 1);
      final parts = _splitTopLevel(inner, ',');
      if (parts.length == 2) {
        return math.max(
          _evaluateFormulaExpression(parts[0]),
          _evaluateFormulaExpression(parts[1]),
        );
      }
    }

    final ternaryIndex = _findTopLevelQuestionMark(f);
    if (ternaryIndex != -1) {
      final colonIndex = _findMatchingColon(f, ternaryIndex);
      if (colonIndex != -1) {
        final condition = f.substring(0, ternaryIndex);
        final whenTrue = f.substring(ternaryIndex + 1, colonIndex);
        final whenFalse = f.substring(colonIndex + 1);
        return _evaluateCondition(condition)
            ? _evaluateFormulaExpression(whenTrue)
            : _evaluateFormulaExpression(whenFalse);
      }
    }

    return _evaluateSimpleMath(f);
  }

  static bool _evaluateCondition(String condition) {
    final c = _stripOuterParentheses(condition.replaceAll(' ', ''));
    const operators = ['>=', '<=', '==', '!=', '>', '<'];

    for (final op in operators) {
      final index = c.indexOf(op);
      if (index != -1) {
        final left = c.substring(0, index);
        final right = c.substring(index + op.length);
        final leftValue = _evaluateSimpleMath(left);
        final rightValue = _evaluateSimpleMath(right);

        switch (op) {
          case '>=':
            return leftValue >= rightValue;
          case '<=':
            return leftValue <= rightValue;
          case '==':
            return leftValue == rightValue;
          case '!=':
            return leftValue != rightValue;
          case '>':
            return leftValue > rightValue;
          case '<':
            return leftValue < rightValue;
        }
      }
    }

    return _evaluateSimpleMath(c) != 0;
  }

  static String _stripOuterParentheses(String expression) {
    var result = expression;
    while (result.startsWith('(') &&
        result.endsWith(')') &&
        _hasBalancedParentheses(result.substring(1, result.length - 1))) {
      result = result.substring(1, result.length - 1);
    }
    return result;
  }

  static bool _hasBalancedParentheses(String expression) {
    int depth = 0;
    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
        if (depth < 0) return false;
      }
    }
    return depth == 0;
  }

  static int _findTopLevelQuestionMark(String expression) {
    int depth = 0;
    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if (char == '?' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  static int _findMatchingColon(String expression, int questionMarkIndex) {
    int depth = 0;
    int nestedTernaries = 0;
    for (int i = questionMarkIndex + 1; i < expression.length; i++) {
      final char = expression[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if (char == '?' && depth == 0) {
        nestedTernaries++;
      } else if (char == ':' && depth == 0) {
        if (nestedTernaries == 0) {
          return i;
        }
        nestedTernaries--;
      }
    }
    return -1;
  }

  static List<String> _splitTopLevel(String expression, String separator) {
    final parts = <String>[];
    var buffer = StringBuffer();
    int depth = 0;

    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }

      if (char == separator && depth == 0) {
        parts.add(buffer.toString());
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
    }

    parts.add(buffer.toString());
    return parts;
  }

  /// Simple math expression evaluator (handles +, -, *, /)
  static int _evaluateSimpleMath(String expression) {
    expression = expression.replaceAll(' ', '');

    // Handle multiplication and division first
    while (expression.contains('*') || expression.contains('/')) {
      final multMatch = RegExp(r'(\d+)\*(\d+)').firstMatch(expression);
      final divMatch = RegExp(r'(\d+)/(\d+)').firstMatch(expression);

      if (multMatch != null) {
        final result =
            int.parse(multMatch.group(1)!) * int.parse(multMatch.group(2)!);
        expression = expression.replaceFirst(
          multMatch.group(0)!,
          result.toString(),
        );
      } else if (divMatch != null) {
        final result =
            int.parse(divMatch.group(1)!) ~/ int.parse(divMatch.group(2)!);
        expression = expression.replaceFirst(
          divMatch.group(0)!,
          result.toString(),
        );
      }
    }

    // Handle addition and subtraction
    int result = 0;
    String currentOp = '+';
    String currentNumber = '';

    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];

      if (char == '+' || char == '-') {
        if (currentNumber.isNotEmpty) {
          if (currentOp == '+') {
            result += int.parse(currentNumber);
          } else {
            result -= int.parse(currentNumber);
          }
          currentNumber = '';
        }
        currentOp = char;
      } else {
        currentNumber += char;
      }
    }

    // Handle last number
    if (currentNumber.isNotEmpty) {
      if (currentOp == '+') {
        result += int.parse(currentNumber);
      } else {
        result -= int.parse(currentNumber);
      }
    }

    return result;
  }

  /// Get a feature by ID
  static CharacterFeature? getFeatureById(String id) {
    return _features[id];
  }

  /// Add features to a character (called during character creation or level up)
  static void addFeaturesToCharacter(Character character) {
    print(
      '🔧 addFeaturesToCharacter() called for ${character.name} (${character.characterClass} level ${character.level})',
    );
    print('🔧 Character currently has ${character.features.length} features');

    final availableFeatures = getFeaturesForCharacter(character);
    print(
      '🔧 Found ${availableFeatures.length} available features for this character',
    );

    // Only add features that the character doesn't already have
    int addedCount = 0;
    for (var feature in availableFeatures) {
      if (_isPlaceholderFeature(feature)) continue;

      final hasFeature = character.features.any((f) => f.id == feature.id);
      if (!hasFeature) {
        // --- PRUNING OLD VERSIONS (Deduplication) ---
        if (feature.id.startsWith('bardic-inspiration') ||
            feature.id == 'bardic_inspiration') {
          // Remove any existing bardic inspiration features to prevent duplicate resource pools
          character.features.removeWhere(
            (f) =>
                f.id.startsWith('bardic-inspiration') ||
                f.id == 'bardic_inspiration',
          );
        }

        // Create a copy of the feature with calculated max uses
        // For features with null formula, use the template's maxUses value
        int maxUses = feature.resourcePool?.calculationFormula != null
            ? calculateMaxUses(
                character,
                feature.resourcePool!.calculationFormula,
              )
            : (feature.resourcePool?.maxUses ?? 0);

        // Defensive: resource_pool type features must have at least 1 use
        if (feature.resourcePool != null && maxUses <= 0) {
          print('⚠️ maxUses=$maxUses for ${feature.id}, forcing to 1');
          maxUses = 1;
        }
        print('🔧 Adding feature: ${feature.nameEn} (max uses: $maxUses)');

        final featureCopy = CharacterFeature(
          id: feature.id,
          nameEn: feature.nameEn,
          nameRu: feature.nameRu,
          descriptionEn: feature.descriptionEn,
          descriptionRu: feature.descriptionRu,
          type: feature.type,
          minLevel: feature.minLevel,
          associatedClass: feature.associatedClass,
          associatedSubclass: feature.associatedSubclass,
          requiresRest: feature.requiresRest,
          actionEconomy: feature.actionEconomy,
          iconName: feature.iconName,
          consumption: feature.consumption,
          usageCostId: feature.usageCostId,
          usageInputMode: feature.usageInputMode,
          options: feature.options != null ? List.from(feature.options!) : null,
          isOptional: feature.isOptional,
          resourcePool: feature.resourcePool != null
              ? ResourcePool(
                  currentUses: maxUses,
                  maxUses: maxUses,
                  recoveryType: feature.resourcePool!.recoveryType,
                  calculationFormula: feature.resourcePool!.calculationFormula,
                )
              : null,
        );

        character.features.add(featureCopy);
        addedCount++;
      }
    }

    print(
      '🔧 Added $addedCount new features. Character now has ${character.features.length} total features',
    );
  }

  /// Update feature max uses when character levels up or stats change
  static void updateFeatureMaxUses(Character character) {
    for (var feature in character.features) {
      if (feature.resourcePool != null &&
          feature.resourcePool!.calculationFormula != null) {
        final newMax = calculateMaxUses(
          character,
          feature.resourcePool!.calculationFormula,
        );
        feature.resourcePool!.maxUses = newMax;

        // Unlimited pools should stay full, otherwise only cap downwards.
        if (newMax >= 99) {
          feature.resourcePool!.currentUses = newMax;
        } else if (feature.resourcePool!.currentUses > newMax) {
          feature.resourcePool!.currentUses = newMax;
        }
      }
    }
  }

  // ============================================================
  // SUBCLASS SPECIFIC FEATURES (Temporary Hardcode)
  // ============================================================

  static void _loadSubclassFeatures() {
    // ============================================================
    // OATH OF CONQUEST (Клятва Покорения) - Channel Divinity Options
    // ============================================================

    // Conquering Presence
    _features['conquering_presence'] = CharacterFeature(
      id: 'conquering_presence',
      nameEn: 'Conquering Presence',
      nameRu: 'Покоряющее присутствие',
      descriptionEn:
          'You can use your Channel Divinity to exude a terrifying presence. As an action, you force each creature of your choice that you can see within 30 feet of you to make a Wisdom saving throw. On a failed save, a creature becomes frightened of you for 1 minute. The frightened creature can repeat this saving throw at the end of each of its turns, ending the effect on itself on a success.',
      descriptionRu:
          'Вы можете использовать ваш Божественный канал, чтобы источать ужасающее присутствие. Действием вы можете заставить каждое существо по вашему выбору в пределах 30 футов совершить спасбросок Мудрости. При провале существо становится испуганным на 1 минуту. Испуганное существо может повторять этот спасбросок в конце каждого своего хода, оканчивая этот эффект на себе при успехе.',
      type: FeatureType.action,
      minLevel: 3,
      associatedClass: 'Paladin',
      associatedSubclass: 'Oath of Conquest',
      requiresRest: false, // Uses Channel Divinity pool
      actionEconomy: 'action',
      iconName: 'psychology_alt',
      resourcePool: null, // Uses the main Channel Divinity pool
      usageCostId: 'channel-divinity',
    );

    // Guided Strike
    _features['guided_strike'] = CharacterFeature(
      id: 'guided_strike',
      nameEn: 'Guided Strike',
      nameRu: 'Направленный удар',
      descriptionEn:
          'You can use your Channel Divinity to strike with supernatural accuracy. When you make an attack roll, you can use your Channel Divinity to gain a +10 bonus to the roll. You make this choice after you see the roll, but before the DM says whether the attack hits or misses.',
      descriptionRu:
          'Вы можете использовать свой Божественный канал, чтобы наносить удары со сверхъестественной точностью. Когда вы проводите атаку, вы можете использовать свой Божественный канал, чтобы получить бонус +10 к этому броску. Вы можете использовать это свойство уже после того, как увидите результат броска, но обязаны сделать выбор до того, как Мастер объявит о попадании или промахе атаки.',
      type: FeatureType.action,
      minLevel: 3,
      associatedClass: 'Paladin',
      associatedSubclass: 'Oath of Conquest',
      requiresRest: false, // Uses Channel Divinity pool
      actionEconomy: 'free',
      iconName: 'gps_fixed',
      resourcePool: null, // Uses the main Channel Divinity pool
      usageCostId: 'channel-divinity',
    );

    // Note: Add other oath-specific Channel Divinity options when needed
  }
}
