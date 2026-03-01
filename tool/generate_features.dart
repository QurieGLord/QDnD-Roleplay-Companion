// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Helper to join array of strings into one string.
String joinDesc(dynamic descLines) {
  if (descLines is List) {
    return descLines.join('\n');
  }
  return descLines.toString();
}

// Resource Configuration Map
final Map<String, Map<String, dynamic>> resourceConfig = {
  // Paladin
  'lay-on-hands': {
    'currentUses': 5,
    'maxUses': 5,
    'recoveryType': 'longRest',
    'calculationFormula': 'level * 5',
    'forcedType': 'resource_pool'
  },
  'divine-sense': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'longRest',
    'calculationFormula': '1 + cha_mod',
    'forcedType': 'resource_pool'
  },
  'channel-divinity-paladin': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'channel-divinity-1-rest': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'channel-divinity-2-rest': {
    'currentUses': 2,
    'maxUses': 2,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'channel-divinity-3-rest': {
    'currentUses': 3,
    'maxUses': 3,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'cleansing-touch': {
    'forcedType': 'action',
    'usageCostId': 'lay-on-hands',
    'consumptionAmount': 5
  },

  // Fighter
  'second-wind': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'action-surge-1-use': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'action-surge-2-uses': {
    'currentUses': 2,
    'maxUses': 2,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },
  'indomitable-1-use': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'longRest',
    'forcedType': 'resource_pool'
  },
  'indomitable-2-uses': {
    'currentUses': 2,
    'maxUses': 2,
    'recoveryType': 'longRest',
    'forcedType': 'resource_pool'
  },
  'indomitable-3-uses': {
    'currentUses': 3,
    'maxUses': 3,
    'recoveryType': 'longRest',
    'forcedType': 'resource_pool'
  },

  // Barbarian
  'rage': {
    'currentUses': 2,
    'maxUses': 2,
    'recoveryType': 'longRest',
    'calculationFormula':
        'level < 3 ? 2 : (level < 6 ? 3 : (level < 12 ? 4 : (level < 17 ? 5 : (level < 20 ? 6 : 99))))',
    'forcedType': 'resource_pool'
  },

  // Bard
  'bardic-inspiration-d6': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'longRest',
    'calculationFormula': 'cha_mod',
    'forcedType': 'resource_pool'
  },
  'bardic-inspiration-d8': {
    'currentUses': 1, 'maxUses': 1, 'recoveryType': 'shortRest',
    'calculationFormula': 'cha_mod', // Font of Inspiration at lvl 5
    'forcedType': 'resource_pool'
  },
  'bardic-inspiration-d10': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'calculationFormula': 'cha_mod',
    'forcedType': 'resource_pool'
  },
  'bardic-inspiration-d12': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'calculationFormula': 'cha_mod',
    'forcedType': 'resource_pool'
  },

  // Druid
  'wild-shape': {
    'currentUses': 2,
    'maxUses': 2,
    'recoveryType': 'shortRest',
    'forcedType': 'resource_pool'
  },

  // Monk
  'ki': {
    'currentUses': 1,
    'maxUses': 1,
    'recoveryType': 'shortRest',
    'calculationFormula': 'level',
    'forcedType': 'resource_pool'
  },
  // Monk Ki Features (Consumption)
  'flurry-of-blows': {'forcedType': 'bonus_action', 'usageCostId': 'ki'},
  'patient-defense': {'forcedType': 'bonus_action', 'usageCostId': 'ki'},
  'step-of-the-wind': {'forcedType': 'bonus_action', 'usageCostId': 'ki'},
  'stunning-strike': {'forcedType': 'free', 'usageCostId': 'ki'},
  'deflect-missiles': {'forcedType': 'reaction', 'usageCostId': 'ki'},
  'diamond-soul': {'forcedType': 'free', 'usageCostId': 'ki'},
  'empty-body': {
    'forcedType': 'action',
    'usageCostId': 'ki',
    'consumptionAmount': 4
  },

  // Sorcerer
  'sorcery-points': {
    'currentUses': 2,
    'maxUses': 2,
    'recoveryType': 'longRest',
    'calculationFormula': 'level',
    'forcedType': 'resource_pool'
  },
  'flexible-casting': {
    'forcedType': 'bonus_action',
    'usageCostId': 'sorcery-points'
  },
  'metamagic-1': {'forcedType': 'free', 'usageCostId': 'sorcery-points'},
  'metamagic-2': {'forcedType': 'free', 'usageCostId': 'sorcery-points'},
  'metamagic-3': {'forcedType': 'free', 'usageCostId': 'sorcery-points'},
  'metamagic-4': {'forcedType': 'free', 'usageCostId': 'sorcery-points'},

  // Specific Overrides
  'divine-smite': {'forcedType': 'free'},
  'primeval-awareness': {'forcedType': 'action'},
};

void main() async {
  final stopwatch = Stopwatch()..start();
  print('🚀 Starting Unified Feature Registry generation...');

  // ... (Paths logic omitted for brevity as it remains same)
  // 1. Define Paths
  final projectRoot = Directory.current.path;
  final srdPath = p.join(projectRoot, 'docs', 'SRD', '2014');
  final srdRuPath = p.join(projectRoot, 'docs', 'SRD', 'ru');
  final outDir = Directory(p.join(projectRoot, 'assets', 'data', 'features'));

  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  // 2. Load Source Data
  print('📦 Loading SRD Features JSON...');
  final featuresEnData =
      await _loadJson(p.join(srdPath, '5e-SRD-Features.json')) as List;

  // 3. Load Shadow File (Translations)
  print('🇷🇺 Loading Shadow File (Features Translations)...');
  final featuresRuData = await _loadJson(
      p.join(srdRuPath, '5e-SRD-Features_RU.json'),
      optional: true) as List?;

  // Index Russian Features
  final featuresRuMap = <String, Map<String, dynamic>>{};
  if (featuresRuData != null) {
    for (var f in featuresRuData) {
      featuresRuMap[f['index'] as String] = f as Map<String, dynamic>;
    }
    print('   > Loaded ${featuresRuMap.length} localized features.');
  }

  // 4. Transform Features
  print('🔨 Processing ${featuresEnData.length} features...');
  final outputList = <Map<String, dynamic>>[];

  for (var fEn in featuresEnData) {
    final index = fEn['index'] as String;

    // --- Basic Info ---
    final nameEn = fEn['name'] as String;
    final descEn = joinDesc(fEn['desc']);

    // --- Localization ---
    final shadowFeature = featuresRuMap[index];

    final nameRu =
        shadowFeature != null ? shadowFeature['name'] as String : nameEn;

    final descRu = shadowFeature != null && shadowFeature['desc'] != null
        ? joinDesc(shadowFeature['desc'])
        : descEn;

    // --- Metadata ---
    final minLevel = fEn['level'] as int? ?? 1;

    String? associatedClass;
    if (fEn['class'] != null) {
      associatedClass = fEn['class']['name'];
    }

    String? associatedSubclass;
    if (fEn['subclass'] != null) {
      associatedSubclass = fEn['subclass']['name'];
    }

    // --- Inference & Formatting ---
    String type = 'passive';
    String? actionEconomy;
    String? iconName = 'star';
    String? usageCostId;
    String? usageInputMode;
    Map<String, dynamic>? resourcePool;
    Map<String, dynamic>? consumption;

    // Apply Resource Config
    if (resourceConfig.containsKey(index)) {
      final config = resourceConfig[index]!;
      resourcePool = Map.from(config); // Copy to avoid modifying const

      if (resourcePool.containsKey('forcedType')) {
        type = resourcePool['forcedType'] as String;
        // Map forced type to action economy if applicable
        if (type == 'action' ||
            type == 'bonus_action' ||
            type == 'reaction' ||
            type == 'free') {
          actionEconomy = type == 'free' ? 'free' : type;
        }
        resourcePool.remove('forcedType'); // Clean up

        if (resourcePool.containsKey('usageCostId')) {
          usageCostId = resourcePool['usageCostId'] as String;
          resourcePool.remove('usageCostId');
        }

        if (resourcePool.containsKey('usageInputMode')) {
          usageInputMode = resourcePool['usageInputMode'] as String;
          resourcePool.remove('usageInputMode');
        }

        if (resourcePool.containsKey('consumptionAmount')) {
          final amount = resourcePool['consumptionAmount'] as int;
          if (usageCostId != null) {
            consumption = {'resourceId': usageCostId, 'amount': amount};
          }
          resourcePool.remove('consumptionAmount');
        }

        if (resourcePool.isEmpty) resourcePool = null; // Remove empty pool
      } else {
        // Fallback heuristic if no forcedType
        type = (resourcePool['recoveryType'] == 'shortRest' ||
                resourcePool['recoveryType'] == 'longRest')
            ? 'resource_pool'
            : 'action';
      }
    }

    // Heuristics for Type and Icon
    final lowerName = nameEn.toLowerCase();
    final lowerDesc = descEn.toLowerCase();

    if (index.startsWith('fighting-style-') ||
        index.contains('-fighting-style-')) {
      type = 'passive';
      iconName = _getFightingStyleIcon(index);
      associatedClass = 'Optional';
    } else if (index.startsWith('channel-divinity') ||
        lowerName.contains('channel divinity')) {
      // Force action for Channel Divinity options if not already a resource pool
      if (resourcePool != null && type == 'resource_pool') {
        iconName = 'auto_awesome';
      } else {
        type = 'action';
        actionEconomy = 'action';
        iconName = 'auto_awesome';
      }
    } else if (lowerName.contains('spellcasting')) {
      type = 'passive';
      iconName = 'auto_fix_high';
    } else if (lowerName.contains('unarmored defense')) {
      type = 'passive';
      iconName = 'shield';
    } else if (lowerName.contains('extra attack')) {
      type = 'passive';
      iconName = 'filter_2';
    } else {
      // Generic Icon logic based on class
      if (associatedClass == 'Barbarian') {
        iconName = 'fitness_center';
      } else if (associatedClass == 'Bard') {
        iconName = 'music_note';
      } else if (associatedClass == 'Cleric') {
        iconName = 'health_and_safety';
      } else if (associatedClass == 'Druid') {
        iconName = 'nature';
      } else if (associatedClass == 'Fighter') {
        iconName = 'swords';
      } else if (associatedClass == 'Monk') {
        iconName = 'self_improvement';
      } else if (associatedClass == 'Paladin') {
        iconName = 'shield';
      } else if (associatedClass == 'Ranger') {
        iconName = 'gps_fixed';
      } else if (associatedClass == 'Rogue') {
        iconName = 'visibility_off';
      } else if (associatedClass == 'Sorcerer') {
        iconName = 'bolt';
      } else if (associatedClass == 'Warlock') {
        iconName = 'psychology';
      } else if (associatedClass == 'Wizard') {
        iconName = 'menu_book';
      }
    }

    // Heuristic: Infer Action/Bonus Action/Reaction from description if NOT already set
    if (type == 'passive' && resourcePool == null) {
      if (lowerDesc.contains('as a bonus action') ||
          lowerName.contains('bonus action')) {
        type = 'bonus_action';
        actionEconomy = 'bonus_action';
      } else if (lowerDesc.contains('as a reaction') ||
          lowerName.contains('reaction') ||
          lowerDesc.contains('use your reaction')) {
        type = 'reaction';
        actionEconomy = 'reaction';
      } else if (lowerDesc.contains('as an action') ||
          lowerDesc.contains('use an action') ||
          lowerDesc.contains('use your action')) {
        type = 'action';
        actionEconomy = 'action';
      } else if (lowerDesc.contains('starting at 2nd level, when you hit')) {
        // Divine Smite style trigger
        type = 'free';
        actionEconomy = 'free';
        iconName = 'flash_on';
      }
    }

    // --- Final Hardcode Overrides & Safety Checks ---

    // 1. Explicit Overrides
    final finalOverrides = {
      'divine-smite': 'free',
      'cleansing-touch': 'action',
      'primeval-awareness': 'action',
      'turn-the-unholy': 'action',
      'nature-s-wrath': 'action',
      'abjure-enemy': 'action',
      'sacred-weapon': 'action',
      'turn-undead': 'action',
    };

    if (finalOverrides.containsKey(index)) {
      type = finalOverrides[index]!;
      if (type == 'action') actionEconomy = 'action';
      if (type == 'free') actionEconomy = 'free';
    }

    // 2. Channel Divinity Catch-all
    else if (index.startsWith('channel-divinity')) {
      if (index == 'channel-divinity' || index.contains('-rest')) {
        type = 'resource_pool';
        // If somehow missed by resourceConfig, default it
        resourcePool ??= {
          'currentUses': 1,
          'maxUses': 1,
          'recoveryType': 'shortRest'
        };
      } else {
        // Consumers (actions)
        type = 'action';
        actionEconomy = 'action';
        iconName = 'auto_awesome';
        usageCostId = 'channel-divinity';
      }
    }

    // 3. Resource Link Safety: If it has a resource, it CANNOT be passive.
    if (resourcePool != null && type == 'passive') {
      type =
          'action'; // Default to action to ensure visibility in active trackers
    }

    // 4. Debug Print
    // if (index == 'divine-smite' || index.startsWith('channel-divinity') || index == 'cleansing-touch') {
    //   print('DEBUG: $index -> Final Type: $type');
    // }

    // Special cleanups for display names
    // e.g. "Fighting Style: Archery" -> "Archery"
    var cleanNameEn = nameEn;
    var cleanNameRu = nameRu;

    if (index.startsWith('fighting-style-') ||
        index.contains('-fighting-style-')) {
      cleanNameEn = cleanNameEn.replaceAll('Fighting Style: ', '');
      cleanNameRu = cleanNameRu
          .replaceAll('Боевой Стиль: ', '')
          .replaceAll('Боевой стиль: ', '');
    }

    // --- SAFETY NET: Force data for critical features ---
    if (index == 'flurry-of-blows' ||
        index == 'patient-defense' ||
        index == 'step-of-the-wind') {
      usageCostId = 'ki';
      type = 'bonus_action'; // Force type
    }
    if (index.startsWith('channel-divinity-') && !index.contains('rest')) {
      usageCostId = 'channel-divinity'; // Link to parent
      type = 'action';
    }
    if (index == 'lay-on-hands-action') {
      usageCostId = 'lay-on-hands';
      usageInputMode = 'slider';
    }

    final outMap = {
      'id': index,
      'nameEn': cleanNameEn,
      'nameRu': cleanNameRu,
      'descriptionEn': descEn,
      'descriptionRu': descRu,
      'type': type,
      'minLevel': minLevel,
      'associatedClass': associatedClass,
      'associatedSubclass': associatedSubclass,
      'requiresRest': resourcePool != null,
      'actionEconomy': actionEconomy,
      'iconName': iconName,
      'resourcePool': resourcePool,
      'usageCostId': usageCostId,
      'usageInputMode': usageInputMode,
      'consumption': consumption,
    };

    outputList.add(outMap);
  }

  // --- Virtual Features Injection ---
  // These are "Action" counterparts to Resource Pools (e.g. Lay on Hands is a pool, but we need an action button)
  final virtualFeatures = [
    {
      'id': 'rage-action',
      'nameEn': 'Rage',
      'nameRu': 'Ярость',
      'type': 'bonus_action',
      'usageCostId': 'rage',
      'associatedClass': 'Barbarian',
      'iconName': 'fitness_center',
      'actionEconomy': 'bonus_action',
      'descEn': 'Enter a rage as a bonus action.',
      'descRu': 'Впасть в ярость бонусным действием.'
    },
    {
      'id': 'bardic-inspiration-action',
      'nameEn': 'Bardic Inspiration',
      'nameRu': 'Бардовское Вдохновение',
      'type': 'bonus_action',
      'usageCostId': 'bardic-inspiration',
      'associatedClass': 'Bard',
      'iconName': 'music_note',
      'actionEconomy': 'bonus_action',
      'descEn':
          'Use a bonus action to give a creature a Bardic Inspiration die.',
      'descRu':
          'Использовать бонусное действие, чтобы дать существу кость Бардовского Вдохновения.'
    },
    {
      'id': 'wild-shape-action',
      'nameEn': 'Wild Shape',
      'nameRu': 'Дикий Облик',
      'type': 'action',
      'usageCostId': 'wild-shape',
      'associatedClass': 'Druid',
      'iconName': 'nature',
      'actionEconomy': 'action',
      'descEn':
          'Magically assume the shape of a beast that you have seen before.',
      'descRu':
          'Магическим образом принять облик зверя, которого вы видели ранее.'
    },
    {
      'id': 'second-wind-action',
      'nameEn': 'Second Wind',
      'nameRu': 'Второе Дыхание',
      'type': 'bonus_action',
      'usageCostId': 'second-wind',
      'associatedClass': 'Fighter',
      'iconName': 'healing',
      'actionEconomy': 'bonus_action',
      'descEn': 'Regain hit points equal to 1d10 + your fighter level.',
      'descRu':
          'Восстановить хиты в количестве, равном 1d10 + ваш уровень воина.'
    },
    {
      'id': 'divine-sense-action',
      'nameEn': 'Divine Sense',
      'nameRu': 'Божественное Чувство',
      'type': 'action',
      'usageCostId': 'divine-sense',
      'associatedClass': 'Paladin',
      'iconName': 'auto_awesome',
      'actionEconomy': 'action',
      'descEn': 'Detect celestial, fiend, or undead within 60 feet.',
      'descRu':
          'Обнаружить небожителей, исчадий или нежить в пределах 60 футов.'
    },
    {
      'id': 'lay-on-hands-action',
      'nameEn': 'Lay on Hands',
      'nameRu': 'Наложение Рук',
      'type': 'action',
      'usageCostId': 'lay-on-hands',
      'associatedClass': 'Paladin',
      'iconName': 'healing',
      'actionEconomy': 'action',
      'usageInputMode': 'slider',
      'descEn': 'Touch a creature to restore hit points from your pool.',
      'descRu': 'Коснуться существа, чтобы восстановить хиты из вашего пула.'
    },
  ];

  for (var vf in virtualFeatures) {
    outputList.add({
      'id': vf['id'],
      'nameEn': vf['nameEn'],
      'nameRu': vf['nameRu'],
      'descriptionEn': vf['descEn'],
      'descriptionRu': vf['descRu'],
      'type': vf['type'],
      'minLevel': 1, // Simplified
      'associatedClass': vf['associatedClass'],
      'requiresRest': false,
      'actionEconomy': vf['actionEconomy'],
      'iconName': vf['iconName'],
      'usageCostId': vf['usageCostId'],
      'usageInputMode': vf['usageInputMode'],
    });
  }
  print('✨ Injected ${virtualFeatures.length} virtual action features.');

  // 5. Write to File
  const encoder = JsonEncoder.withIndent('  ');
  final outFile = File(p.join(outDir.path, 'srd_features.json'));
  await outFile.writeAsString(encoder.convert(outputList));

  print(
      '✅ Done! Generated ${outputList.length} features in ${stopwatch.elapsedMilliseconds}ms.');
}

String _getFightingStyleIcon(String id) {
  if (id.contains('archery')) return 'gps_fixed';
  if (id.contains('defense')) return 'shield';
  if (id.contains('dueling')) return 'swords';
  if (id.contains('great-weapon')) return 'fitness_center';
  if (id.contains('protection')) return 'security';
  if (id.contains('two-weapon')) return 'call_split';
  return 'sports_martial_arts';
}

Future<dynamic> _loadJson(String path, {bool optional = false}) async {
  final file = File(path);
  if (!await file.exists()) {
    if (optional) {
      print('   ⚠️ Info: Optional shadow file not found: ${p.basename(path)}');
      return null;
    }
    throw Exception('File not found: $path');
  }
  try {
    return jsonDecode(await file.readAsString());
  } catch (e) {
    if (optional) {
      print(
          '   ⚠️ Warning: Failed to parse optional file ${p.basename(path)}: $e');
      return null;
    }
    throw Exception('Failed to parse $path: $e');
  }
}
