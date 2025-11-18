import '../models/character.dart';
import '../models/character_feature.dart';

/// Service for managing character class features
/// Loads features from JSON and assigns them to characters based on class/level
class FeatureService {
  static final Map<String, CharacterFeature> _features = {};
  static bool _initialized = false;

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
    // TODO: Add other subclass mappings as needed
  };

  /// Normalize class name to English lowercase for comparison
  static String _normalizeClassName(String className) {
    final normalized = className.toLowerCase().trim();
    return _classNameMapping[normalized] ?? _subclassNameMapping[normalized] ?? normalized;
  }

  /// Initialize the service by loading all features from JSON
  static Future<void> init() async {
    if (_initialized) return;

    // TODO: Load features from assets/data/features.json when implemented
    // For now, we'll add them programmatically
    _loadPaladinFeatures();

    print('🔧 FeatureService.init() completed. Loaded ${_features.length} features');
    _initialized = true;
  }

  /// Get all features available for a character at their current level
  static List<CharacterFeature> getFeaturesForCharacter(Character character) {
    final characterClassName = _normalizeClassName(character.characterClass);
    final characterSubclassName = character.subclass != null ? _normalizeClassName(character.subclass!) : '';

    print('🔧 getFeaturesForCharacter: normalized class "${character.characterClass}" -> "$characterClassName"');
    if (character.subclass != null) {
      print('🔧 getFeaturesForCharacter: normalized subclass "${character.subclass}" -> "$characterSubclassName"');
    }

    return _features.values.where((feature) {
      // Check if feature belongs to this class
      if (feature.associatedClass != null) {
        final featureClassName = _normalizeClassName(feature.associatedClass!);
        if (featureClassName != characterClassName) {
          return false;
        }
      }

      // Check if feature belongs to this subclass
      if (feature.associatedSubclass != null) {
        final featureSubclassName = _normalizeClassName(feature.associatedSubclass!);
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

    // Parse formulas like "level * 5", "1 + cha_mod", "prof_bonus * 2", etc.
    try {
      String f = formula.toLowerCase();

      // Replace variables with actual values
      f = f.replaceAll('level', character.level.toString());
      f = f.replaceAll('cha_mod', character.abilityScores.charismaModifier.toString());
      f = f.replaceAll('wis_mod', character.abilityScores.wisdomModifier.toString());
      f = f.replaceAll('int_mod', character.abilityScores.intelligenceModifier.toString());
      f = f.replaceAll('prof_bonus', character.proficiencyBonus.toString());

      // Simple math evaluation (only handles +, -, *, /)
      return _evaluateSimpleMath(f);
    } catch (e) {
      return 0;
    }
  }

  /// Simple math expression evaluator (handles +, -, *, /)
  static int _evaluateSimpleMath(String expression) {
    expression = expression.replaceAll(' ', '');

    // Handle multiplication and division first
    while (expression.contains('*') || expression.contains('/')) {
      final multMatch = RegExp(r'(\d+)\*(\d+)').firstMatch(expression);
      final divMatch = RegExp(r'(\d+)/(\d+)').firstMatch(expression);

      if (multMatch != null) {
        final result = int.parse(multMatch.group(1)!) * int.parse(multMatch.group(2)!);
        expression = expression.replaceFirst(multMatch.group(0)!, result.toString());
      } else if (divMatch != null) {
        final result = int.parse(divMatch.group(1)!) ~/ int.parse(divMatch.group(2)!);
        expression = expression.replaceFirst(divMatch.group(0)!, result.toString());
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
    print('🔧 addFeaturesToCharacter() called for ${character.name} (${character.characterClass} level ${character.level})');
    print('🔧 Character currently has ${character.features.length} features');

    final availableFeatures = getFeaturesForCharacter(character);
    print('🔧 Found ${availableFeatures.length} available features for this character');

    // Only add features that the character doesn't already have
    int addedCount = 0;
    for (var feature in availableFeatures) {
      final hasFeature = character.features.any((f) => f.id == feature.id);
      if (!hasFeature) {
        // Create a copy of the feature with calculated max uses
        // For features with null formula, use the template's maxUses value
        final maxUses = feature.resourcePool?.calculationFormula != null
            ? calculateMaxUses(character, feature.resourcePool!.calculationFormula)
            : (feature.resourcePool?.maxUses ?? 0);
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

    print('🔧 Added $addedCount new features. Character now has ${character.features.length} total features');
  }

  /// Update feature max uses when character levels up or stats change
  static void updateFeatureMaxUses(Character character) {
    for (var feature in character.features) {
      if (feature.resourcePool != null && feature.resourcePool!.calculationFormula != null) {
        final newMax = calculateMaxUses(character, feature.resourcePool!.calculationFormula);
        feature.resourcePool!.maxUses = newMax;

        // If current uses exceed new max, cap it
        if (feature.resourcePool!.currentUses > newMax) {
          feature.resourcePool!.currentUses = newMax;
        }
      }
    }
  }

  // ============================================================
  // PALADIN FEATURES
  // ============================================================

  static void _loadPaladinFeatures() {
    // Lay on Hands
    _features['lay_on_hands'] = CharacterFeature(
      id: 'lay_on_hands',
      nameEn: 'Lay on Hands',
      nameRu: 'Наложение рук',
      descriptionEn: 'Your blessed touch can heal wounds. You have a pool of healing power that replenishes when you take a long rest. With that pool, you can restore a total number of hit points equal to your paladin level × 5.',
      descriptionRu: 'Ваше благословенное прикосновение может исцелять раны. У вас есть запас целительной силы, который восстанавливается после длительного отдыха. С помощью этого запаса вы можете восстановить общее количество хитов, равное вашему уровню паладина × 5.',
      type: FeatureType.action,
      minLevel: 1,
      associatedClass: 'Paladin',
      requiresRest: true,
      actionEconomy: 'action',
      iconName: 'healing',
      resourcePool: ResourcePool(
        currentUses: 0,
        maxUses: 0,
        recoveryType: RecoveryType.longRest,
        calculationFormula: 'level * 5',
      ),
    );

    // Divine Sense
    _features['divine_sense'] = CharacterFeature(
      id: 'divine_sense',
      nameEn: 'Divine Sense',
      nameRu: 'Божественное чувство',
      descriptionEn: 'The presence of strong evil registers on your senses like a noxious odor, and powerful good rings like heavenly music in your ears. As an action, you can open your awareness to detect such forces. Until the end of your next turn, you know the location of any celestial, fiend, or undead within 60 feet of you that is not behind total cover.',
      descriptionRu: 'Присутствие сильного зла регистрируется вашими чувствами как ядовитый запах, а могущественное добро звучит как небесная музыка в ваших ушах. Вы можете действием открыть свою осведомленность для обнаружения таких сил. До конца вашего следующего хода вы знаете местоположение любого небожителя, исчадия или нежити в пределах 60 футов от вас, который не находится за полным укрытием.',
      type: FeatureType.action,
      minLevel: 1,
      associatedClass: 'Paladin',
      requiresRest: true,
      actionEconomy: 'action',
      iconName: 'visibility',
      resourcePool: ResourcePool(
        currentUses: 0,
        maxUses: 0,
        recoveryType: RecoveryType.longRest,
        calculationFormula: '1 + cha_mod',
      ),
    );

    // Channel Divinity (base feature - each oath has specific options)
    _features['channel_divinity'] = CharacterFeature(
      id: 'channel_divinity',
      nameEn: 'Channel Divinity',
      nameRu: 'Божественный канал',
      descriptionEn: 'You gain the ability to channel divine energy directly from your deity, using that energy to fuel magical effects. Each Channel Divinity option provided by your oath explains how to use it. When you use your Channel Divinity, you choose which option to use. You must then finish a short or long rest to use your Channel Divinity again.',
      descriptionRu: 'Вы получаете способность направлять божественную энергию непосредственно от вашего божества, используя эту энергию для создания магических эффектов. Каждый вариант Божественного канала, предоставленный вашей клятвой, объясняет, как его использовать. Когда вы используете свой Божественный канал, вы выбираете, какой вариант использовать. Затем вы должны закончить короткий или длительный отдых, чтобы снова использовать свой Божественный канал.',
      type: FeatureType.action,
      minLevel: 3,
      associatedClass: 'Paladin',
      requiresRest: true,
      actionEconomy: 'action',
      iconName: 'auto_awesome',
      resourcePool: ResourcePool(
        currentUses: 0,
        maxUses: 1,
        recoveryType: RecoveryType.shortRest,
        calculationFormula: null, // Fixed at 1 use
      ),
    );

    // ============================================================
    // OATH OF CONQUEST (Клятва Покорения) - Channel Divinity Options
    // ============================================================

    // Conquering Presence
    _features['conquering_presence'] = CharacterFeature(
      id: 'conquering_presence',
      nameEn: 'Conquering Presence',
      nameRu: 'Покоряющее присутствие',
      descriptionEn: 'You can use your Channel Divinity to exude a terrifying presence. As an action, you force each creature of your choice that you can see within 30 feet of you to make a Wisdom saving throw. On a failed save, a creature becomes frightened of you for 1 minute. The frightened creature can repeat this saving throw at the end of each of its turns, ending the effect on itself on a success.',
      descriptionRu: 'Вы можете использовать ваш Божественный канал, чтобы источать ужасающее присутствие. Действием вы можете заставить каждое существо по вашему выбору в пределах 30 футов совершить спасбросок Мудрости. При провале существо становится испуганным на 1 минуту. Испуганное существо может повторять этот спасбросок в конце каждого своего хода, оканчивая этот эффект на себе при успехе.',
      type: FeatureType.action,
      minLevel: 3,
      associatedClass: 'Paladin',
      associatedSubclass: 'Oath of Conquest',
      requiresRest: false, // Uses Channel Divinity pool
      actionEconomy: 'action',
      iconName: 'psychology_alt',
      resourcePool: null, // Uses the main Channel Divinity pool
    );

    // Guided Strike
    _features['guided_strike'] = CharacterFeature(
      id: 'guided_strike',
      nameEn: 'Guided Strike',
      nameRu: 'Направленный удар',
      descriptionEn: 'You can use your Channel Divinity to strike with supernatural accuracy. When you make an attack roll, you can use your Channel Divinity to gain a +10 bonus to the roll. You make this choice after you see the roll, but before the DM says whether the attack hits or misses.',
      descriptionRu: 'Вы можете использовать свой Божественный канал, чтобы наносить удары со сверхъестественной точностью. Когда вы проводите атаку, вы можете использовать свой Божественный канал, чтобы получить бонус +10 к этому броску. Вы можете использовать это свойство уже после того, как увидите результат броска, но обязаны сделать выбор до того, как Мастер объявит о попадании или промахе атаки.',
      type: FeatureType.action,
      minLevel: 3,
      associatedClass: 'Paladin',
      associatedSubclass: 'Oath of Conquest',
      requiresRest: false, // Uses Channel Divinity pool
      actionEconomy: 'free',
      iconName: 'gps_fixed',
      resourcePool: null, // Uses the main Channel Divinity pool
    );

    // TODO: Add other oath-specific Channel Divinity options when needed
    // - Sacred Weapon (Devotion)
    // - Turn the Unholy (Devotion)
    // - Nature's Wrath (Ancients)
    // - Turn the Faithless (Ancients)
    // - Abjure Enemy (Vengeance)
    // - Vow of Enmity (Vengeance)
    // etc.
  }
}
