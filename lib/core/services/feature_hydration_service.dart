import '../models/character.dart';
import '../models/character_class.dart';
import '../models/character_feature.dart';
import 'feature_service.dart';
import 'fc5_imported_name_normalizer.dart';

enum FeatureHydrationDiagnosticSeverity { info, warning }

class FeatureHydrationDiagnostic {
  final FeatureHydrationDiagnosticSeverity severity;
  final String code;
  final String message;
  final String? context;

  const FeatureHydrationDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.context,
  });
}

class FeatureHydrationResult {
  final List<CharacterFeature> features;
  final List<FeatureHydrationDiagnostic> diagnostics;

  const FeatureHydrationResult({
    required this.features,
    this.diagnostics = const [],
  });
}

class FeatureHydrationService {
  static const Map<String, String> _classAliases = {
    'паладин': 'paladin',
    'воин': 'fighter',
    'варвар': 'barbarian',
    'монах': 'monk',
    'плут': 'rogue',
    'разбойник': 'rogue',
    'следопыт': 'ranger',
    'рейнджер': 'ranger',
    'друид': 'druid',
    'жрец': 'cleric',
    'клирик': 'cleric',
    'волшебник': 'wizard',
    'маг': 'wizard',
    'чародей': 'sorcerer',
    'колдун': 'warlock',
    'бард': 'bard',
  };

  static const Map<String, String> _subclassAliases = {
    'devotion': 'oath of devotion',
    'oath devotion': 'oath of devotion',
    'клятва преданности': 'oath of devotion',
    'oath of conquest': 'oath of conquest',
    'клятва покорения': 'oath of conquest',
    'life': 'life domain',
    'домен жизни': 'life domain',
    'land': 'circle of the land',
    'circle of the land': 'circle of the land',
  };

  static const Map<String, String> _resourceNameAliases = {
    'channel divinity': 'channel-divinity',
    'божественный канал': 'channel-divinity',
    'ki': 'ki',
    'ki points': 'ki',
    'ци': 'ki',
    'rage': 'rage',
    'ярость': 'rage',
    'bardic inspiration': 'bardic-inspiration',
    'бардовское вдохновение': 'bardic-inspiration',
    'wild shape': 'wild-shape',
    'дикий облик': 'wild-shape',
    'lay on hands': 'lay-on-hands',
    'наложение рук': 'lay-on-hands',
    'divine sense': 'divine-sense',
    'божественное чувство': 'divine-sense',
    'action surge': 'action-surge',
    'всплеск действий': 'action-surge',
    'second wind': 'second-wind',
    'второе дыхание': 'second-wind',
    'sorcery points': 'sorcery-points',
    'sorcery point': 'sorcery-points',
    'font of magic': 'sorcery-points',
    'единицы чародейства': 'sorcery-points',
    'источник магии': 'sorcery-points',
  };

  static const Set<String> _textOnlyMechanics = {
    'sneak attack',
    'скрытая атака',
    'arcane recovery',
    'магическое восстановление',
    'арканное восстановление',
    'natural recovery',
    'природное восстановление',
    'естественное восстановление',
  };

  static FeatureHydrationResult hydrateCharacter(Character character) {
    final diagnostics = <FeatureHydrationDiagnostic>[];
    final features = <CharacterFeature>[];

    for (final feature in character.features) {
      features.add(_copyFeature(feature));
    }

    final builtIns = FeatureService.getFeaturesForCharacter(character);
    _ensureBuiltIns(character, features, builtIns);

    for (var i = 0; i < features.length; i++) {
      final original = features[i];
      final hydrated = _hydrateFeature(
        original,
        character: character,
        builtIns: builtIns,
        diagnostics: diagnostics,
      );
      features[i] = hydrated;
    }

    _ensureResourcesForActions(character, features);

    final deduped = _dedupeFeatures(features, diagnostics: diagnostics);
    return FeatureHydrationResult(features: deduped, diagnostics: diagnostics);
  }

  static CharacterFeature hydrateImportedFeature(
    CharacterFeature feature, {
    String? className,
    String? subclassName,
    List<FeatureHydrationDiagnostic>? diagnostics,
  }) {
    return _hydrateFeature(
      feature,
      className: className,
      subclassName: subclassName,
      diagnostics: diagnostics,
    );
  }

  static FeatureHydrationResult hydrateClassFeatures(
    Iterable<CharacterFeature> features, {
    String? className,
    String? subclassName,
  }) {
    final diagnostics = <FeatureHydrationDiagnostic>[];
    final hydrated = features
        .map(
          (feature) => _hydrateFeature(
            feature,
            className: className,
            subclassName: subclassName ?? feature.associatedSubclass,
            diagnostics: diagnostics,
          ),
        )
        .toList();

    return FeatureHydrationResult(
      features: _dedupeFeatures(hydrated, diagnostics: diagnostics),
      diagnostics: diagnostics,
    );
  }

  static String featureDedupeKey(CharacterFeature feature) =>
      _featureDedupeKey(feature);

  static bool matchesResourceId(CharacterFeature feature, String resourceId) {
    if (feature.resourcePool == null) return false;
    final featureId = _normalizeId(feature.id);
    final costId = _normalizeId(resourceId);
    return featureId == costId ||
        featureId.startsWith('$costId-') ||
        featureId.endsWith('-$costId') ||
        (costId == 'bardic-inspiration' &&
            featureId.startsWith('bardic-inspiration')) ||
        (costId == 'action-surge' && featureId.startsWith('action-surge')) ||
        (costId == 'channel-divinity' &&
            featureId.startsWith('channel-divinity'));
  }

  static bool featureMatchesBuiltIn(
    CharacterFeature imported,
    CharacterFeature builtIn,
  ) {
    final importedName = _canonicalFeatureName(imported.nameEn);
    final builtInName = _canonicalFeatureName(builtIn.nameEn);
    if (importedName == builtInName) return true;

    final importedResource = _resourceIdForName(imported.nameEn);
    final builtInResource = _resourceIdForName(builtIn.nameEn);
    return importedResource != null && importedResource == builtInResource;
  }

  static void _ensureBuiltIns(
    Character character,
    List<CharacterFeature> features,
    List<CharacterFeature> builtIns,
  ) {
    final existingKeys = features.map(_featureDedupeKey).toSet();

    for (final builtIn in builtIns) {
      final copy = _copyFeatureForCharacter(builtIn, character);
      final key = _featureDedupeKey(copy);
      if (existingKeys.add(key)) {
        features.add(copy);
      }
    }
  }

  static CharacterFeature _hydrateFeature(
    CharacterFeature feature, {
    Character? character,
    List<CharacterFeature>? builtIns,
    String? className,
    String? subclassName,
    List<FeatureHydrationDiagnostic>? diagnostics,
  }) {
    final associatedClass = feature.associatedClass ?? className;
    final associatedSubclass = feature.associatedSubclass ?? subclassName;
    final textResourceId = _resourceIdFromText(feature);
    final ownResourceId = _resourceIdForName(feature.nameEn);
    final isImported = _isImportedFeature(feature);
    final textOnly = _isKnownTextOnly(feature);

    final builtIn = character == null
        ? null
        : _findBuiltInEquivalent(feature, builtIns ?? const []);

    if (ownResourceId != null) {
      if (builtIn?.resourcePool != null) {
        final copied = _copyFeatureForCharacter(builtIn!, character!);
        _addDiagnostic(
          diagnostics,
          FeatureHydrationDiagnosticSeverity.info,
          'feature_mechanic_matched',
          'Imported feature "${feature.nameEn}" was matched to built-in mechanics.',
          context: feature.nameEn,
        );
        return feature.isOptional
            ? _copyFeature(copied, isOptional: true)
            : copied;
      }

      final syntheticResource = _syntheticResourceFeature(
        ownResourceId,
        feature,
        character: character,
        associatedClass: associatedClass,
        associatedSubclass: associatedSubclass,
      );
      if (syntheticResource != null) {
        _addDiagnostic(
          diagnostics,
          FeatureHydrationDiagnosticSeverity.info,
          'feature_resource_mechanized',
          'Feature "${feature.nameEn}" was imported as a resource pool.',
          context: feature.nameEn,
        );
        return syntheticResource;
      }
    }

    if (textResourceId != null && ownResourceId != textResourceId) {
      _addDiagnostic(
        diagnostics,
        FeatureHydrationDiagnosticSeverity.info,
        'feature_partially_mechanized',
        'Feature "${feature.nameEn}" was imported as an action that consumes $textResourceId.',
        context: feature.nameEn,
      );
      return _copyFeature(
        feature,
        type: _featureTypeForAction(_actionEconomyFromText(feature)),
        associatedClass: associatedClass,
        associatedSubclass: associatedSubclass,
        actionEconomy: _actionEconomyFromText(feature),
        consumption: FeatureConsumption(
          resourceId: textResourceId,
          amount: _resourceCostFromText(feature),
        ),
        usageCostId: textResourceId,
      );
    }

    if (builtIn != null) {
      final copied = _copyFeatureForCharacter(builtIn, character!);
      _addDiagnostic(
        diagnostics,
        FeatureHydrationDiagnosticSeverity.info,
        'feature_mechanic_matched',
        'Imported feature "${feature.nameEn}" was matched to built-in mechanics.',
        context: feature.nameEn,
      );
      return feature.isOptional
          ? _copyFeature(copied, isOptional: true)
          : copied;
    }

    if (isImported && !textOnly) {
      _addDiagnostic(
        diagnostics,
        FeatureHydrationDiagnosticSeverity.info,
        'feature_text_only',
        'Feature "${feature.nameEn}" was imported as text only.',
        context: feature.nameEn,
      );
    }

    return _copyFeature(
      feature,
      associatedClass: associatedClass,
      associatedSubclass: associatedSubclass,
    );
  }

  static CharacterFeature? _findBuiltInEquivalent(
    CharacterFeature feature,
    List<CharacterFeature> builtIns,
  ) {
    final candidates = builtIns
        .where((builtIn) => featureMatchesBuiltIn(feature, builtIn))
        .toList()
      ..sort((a, b) => b.minLevel.compareTo(a.minLevel));

    if (candidates.isEmpty) return null;

    final featureClass = _normalizeClass(feature.associatedClass ?? '');
    final featureSubclass =
        _normalizeSubclass(feature.associatedSubclass ?? '');
    for (final candidate in candidates) {
      final candidateClass = _normalizeClass(candidate.associatedClass ?? '');
      final candidateSubclass =
          _normalizeSubclass(candidate.associatedSubclass ?? '');
      if (featureClass.isNotEmpty &&
          candidateClass.isNotEmpty &&
          featureClass != candidateClass) {
        continue;
      }
      if (featureSubclass.isNotEmpty &&
          candidateSubclass.isNotEmpty &&
          featureSubclass != candidateSubclass) {
        continue;
      }
      return candidate;
    }

    return candidates.first;
  }

  static void _ensureResourcesForActions(
    Character character,
    List<CharacterFeature> features,
  ) {
    final costIds = features
        .map((feature) => feature.usageCostId)
        .whereType<String>()
        .toSet();

    for (final costId in costIds) {
      final hasPool =
          features.any((feature) => matchesResourceId(feature, costId));
      if (hasPool) continue;

      final synthetic = _syntheticResourceFeature(
        costId,
        null,
        character: character,
      );
      if (synthetic != null) {
        features.add(synthetic);
      }
    }
  }

  static CharacterFeature? _syntheticResourceFeature(
    String? resourceId,
    CharacterFeature? source, {
    Character? character,
    String? associatedClass,
    String? associatedSubclass,
  }) {
    if (resourceId == null) return null;

    final classId = _normalizeClass(
      associatedClass ??
          source?.associatedClass ??
          character?.characterClass ??
          '',
    );
    final level = character == null
        ? source?.minLevel ?? 1
        : _classLevel(character, classId.ifEmpty(character.characterClass));

    switch (resourceId) {
      case 'channel-divinity':
        if (classId == 'paladin' && level < 3) return null;
        if (classId == 'cleric' && level < 2) return null;
        return _resourceFeature(
          id: classId == 'cleric'
              ? 'channel-divinity-1-rest'
              : 'channel-divinity',
          nameEn: 'Channel Divinity',
          nameRu: 'Божественный канал',
          descriptionEn: source?.descriptionEn ??
              'Use divine energy to fuel class or subclass effects.',
          descriptionRu: source?.descriptionRu ??
              'Используйте божественную энергию для эффектов класса или подкласса.',
          minLevel: classId == 'cleric' ? 2 : 3,
          associatedClass: _displayClass(classId, associatedClass),
          associatedSubclass: associatedSubclass ?? source?.associatedSubclass,
          currentUses: _channelDivinityUses(classId, level),
          maxUses: _channelDivinityUses(classId, level),
          recoveryType: RecoveryType.shortRest,
          iconName: 'auto_awesome',
        );
      case 'ki':
        if (classId == 'monk' && level < 2) return null;
        return _resourceFeature(
          id: 'ki',
          nameEn: 'Ki',
          nameRu: 'Ци',
          descriptionEn:
              source?.descriptionEn ?? 'Ki points fuel monk features.',
          descriptionRu:
              source?.descriptionRu ?? 'Очки ци питают умения монаха.',
          minLevel: 2,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: level,
          maxUses: level,
          recoveryType: RecoveryType.shortRest,
          calculationFormula: 'level',
          iconName: 'self_improvement',
        );
      case 'rage':
        return _resourceFeature(
          id: 'rage',
          nameEn: 'Rage',
          nameRu: 'Ярость',
          descriptionEn:
              source?.descriptionEn ?? 'Enter rage as a bonus action.',
          descriptionRu:
              source?.descriptionRu ?? 'Впасть в ярость бонусным действием.',
          minLevel: 1,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: _rageUses(level),
          maxUses: _rageUses(level),
          recoveryType: RecoveryType.longRest,
          calculationFormula:
              'level < 3 ? 2 : (level < 6 ? 3 : (level < 12 ? 4 : (level < 17 ? 5 : (level < 20 ? 6 : 99))))',
          iconName: 'fitness_center',
        );
      case 'bardic-inspiration':
        final maxUses = character == null
            ? 1
            : character.abilityScores.charismaModifier.clamp(1, 99).toInt();
        return _resourceFeature(
          id: 'bardic-inspiration',
          nameEn: 'Bardic Inspiration',
          nameRu: 'Бардовское вдохновение',
          descriptionEn:
              source?.descriptionEn ?? 'Use inspiration dice to aid allies.',
          descriptionRu: source?.descriptionRu ??
              'Используйте кости вдохновения, чтобы помогать союзникам.',
          minLevel: 1,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: maxUses,
          maxUses: maxUses,
          recoveryType:
              level >= 5 ? RecoveryType.shortRest : RecoveryType.longRest,
          iconName: 'music_note',
        );
      case 'wild-shape':
        return _resourceFeature(
          id: 'wild-shape',
          nameEn: 'Wild Shape',
          nameRu: 'Дикий облик',
          descriptionEn:
              source?.descriptionEn ?? 'Assume the shape of a beast.',
          descriptionRu: source?.descriptionRu ?? 'Примите облик зверя.',
          minLevel: 2,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: 2,
          maxUses: 2,
          recoveryType: RecoveryType.shortRest,
          iconName: 'nature',
        );
      case 'lay-on-hands':
        final maxUses = level * 5;
        return _resourceFeature(
          id: 'lay-on-hands',
          nameEn: 'Lay on Hands',
          nameRu: 'Наложение рук',
          descriptionEn: source?.descriptionEn ?? 'A pool of healing power.',
          descriptionRu: source?.descriptionRu ?? 'Запас целительной силы.',
          minLevel: 1,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: maxUses,
          maxUses: maxUses,
          recoveryType: RecoveryType.longRest,
          calculationFormula: 'level * 5',
          iconName: 'shield',
        );
      case 'divine-sense':
        final maxUses = character == null
            ? 1
            : (1 + character.abilityScores.charismaModifier)
                .clamp(1, 99)
                .toInt();
        return _resourceFeature(
          id: 'divine-sense',
          nameEn: 'Divine Sense',
          nameRu: 'Божественное чувство',
          descriptionEn: source?.descriptionEn ??
              'Sense strong celestial, fiendish, or undead presence.',
          descriptionRu: source?.descriptionRu ??
              'Ощутите сильное присутствие небожителей, исчадий или нежити.',
          minLevel: 1,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: maxUses,
          maxUses: maxUses,
          recoveryType: RecoveryType.longRest,
          calculationFormula: '1 + cha_mod',
          iconName: 'shield',
        );
      case 'action-surge':
        final maxUses = level >= 17 ? 2 : 1;
        return _resourceFeature(
          id: level >= 17 ? 'action-surge-2-uses' : 'action-surge-1-use',
          nameEn:
              level >= 17 ? 'Action Surge (2 uses)' : 'Action Surge (1 use)',
          nameRu: 'Всплеск действий',
          descriptionEn: source?.descriptionEn ??
              'Take one additional action on your turn.',
          descriptionRu: source?.descriptionRu ??
              'Совершите одно дополнительное действие в свой ход.',
          minLevel: level >= 17 ? 17 : 2,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: maxUses,
          maxUses: maxUses,
          recoveryType: RecoveryType.shortRest,
          iconName: 'swords',
        );
      case 'second-wind':
        return _resourceFeature(
          id: 'second-wind',
          nameEn: 'Second Wind',
          nameRu: 'Второе дыхание',
          descriptionEn:
              source?.descriptionEn ?? 'Regain hit points as a bonus action.',
          descriptionRu:
              source?.descriptionRu ?? 'Восстановите хиты бонусным действием.',
          minLevel: 1,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: 1,
          maxUses: 1,
          recoveryType: RecoveryType.shortRest,
          iconName: 'swords',
        );
      case 'sorcery-points':
        final maxUses = level < 2 ? 0 : level;
        if (maxUses <= 0) return null;
        return _resourceFeature(
          id: 'sorcery-points',
          nameEn: 'Sorcery Points',
          nameRu: 'Единицы чародейства',
          descriptionEn: source?.descriptionEn ??
              'Points used to fuel Font of Magic and Metamagic.',
          descriptionRu: source?.descriptionRu ??
              'Единицы для Источника магии и Метамагии.',
          minLevel: 2,
          associatedClass: _displayClass(classId, associatedClass),
          currentUses: maxUses,
          maxUses: maxUses,
          recoveryType: RecoveryType.longRest,
          calculationFormula: 'level',
          iconName: 'bolt',
        );
      default:
        return null;
    }
  }

  static CharacterFeature _resourceFeature({
    required String id,
    required String nameEn,
    required String nameRu,
    required String descriptionEn,
    required String descriptionRu,
    required int minLevel,
    required String? associatedClass,
    String? associatedSubclass,
    required int currentUses,
    required int maxUses,
    required RecoveryType recoveryType,
    String? calculationFormula,
    String? iconName,
  }) {
    return CharacterFeature(
      id: id,
      nameEn: nameEn,
      nameRu: nameRu,
      descriptionEn: descriptionEn,
      descriptionRu: descriptionRu,
      type: FeatureType.resourcePool,
      minLevel: minLevel,
      associatedClass: associatedClass,
      associatedSubclass: associatedSubclass,
      requiresRest: true,
      iconName: iconName,
      resourcePool: ResourcePool(
        currentUses: currentUses,
        maxUses: maxUses,
        recoveryType: recoveryType,
        calculationFormula: calculationFormula,
      ),
    );
  }

  static List<CharacterFeature> _dedupeFeatures(
    Iterable<CharacterFeature> features, {
    List<FeatureHydrationDiagnostic>? diagnostics,
  }) {
    final byKey = <String, CharacterFeature>{};
    for (final feature in features) {
      final key = _featureDedupeKey(feature);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = feature;
        continue;
      }

      final winner = _mechanicScore(feature) > _mechanicScore(existing)
          ? feature
          : existing;
      final loser = identical(winner, feature) ? existing : feature;
      byKey[key] = winner;

      if (_isImportedFeature(loser)) {
        _addDiagnostic(
          diagnostics,
          FeatureHydrationDiagnosticSeverity.info,
          'feature_duplicate_removed',
          'Imported duplicate feature "${loser.nameEn}" was replaced by mechanical feature "${winner.nameEn}".',
          context: loser.nameEn,
        );
      }
    }

    return byKey.values.toList()
      ..sort((a, b) {
        final levelCompare = a.minLevel.compareTo(b.minLevel);
        if (levelCompare != 0) return levelCompare;
        return a.nameEn.compareTo(b.nameEn);
      });
  }

  static int _mechanicScore(CharacterFeature feature) {
    var score = 0;
    if (feature.resourcePool != null) score += 5;
    if (feature.usageCostId != null) score += 4;
    if (feature.type != FeatureType.passive) score += 2;
    if (!_isImportedFeature(feature)) score += 1;
    return score;
  }

  static String _featureDedupeKey(CharacterFeature feature) {
    final resourceId = feature.usageCostId ??
        _resourceIdForName(feature.nameEn) ??
        (feature.resourcePool == null
            ? null
            : _resourceIdFromFeatureId(feature.id));
    if (feature.resourcePool != null && resourceId != null) {
      return 'resource:$resourceId';
    }
    if (feature.usageCostId != null) {
      return 'action:${_normalizeId(feature.usageCostId!)}:${_canonicalFeatureName(feature.nameEn)}';
    }
    return [
      'feature',
      _normalizeClass(feature.associatedClass ?? ''),
      _normalizeSubclass(feature.associatedSubclass ?? ''),
      _canonicalFeatureName(feature.nameEn),
    ].join(':');
  }

  static CharacterFeature _copyFeatureForCharacter(
    CharacterFeature feature,
    Character character,
  ) {
    var maxUses = feature.resourcePool?.calculationFormula != null
        ? FeatureService.calculateMaxUses(
            character,
            feature.resourcePool!.calculationFormula,
          )
        : feature.resourcePool?.maxUses;

    if (feature.resourcePool != null && (maxUses == null || maxUses <= 0)) {
      maxUses = 1;
    }

    return _copyFeature(
      feature,
      resourcePool: feature.resourcePool == null
          ? null
          : ResourcePool(
              currentUses: maxUses!,
              maxUses: maxUses,
              recoveryType: feature.resourcePool!.recoveryType,
              calculationFormula: feature.resourcePool!.calculationFormula,
            ),
    );
  }

  static CharacterFeature _copyFeature(
    CharacterFeature feature, {
    String? id,
    String? nameEn,
    String? nameRu,
    String? descriptionEn,
    String? descriptionRu,
    FeatureType? type,
    ResourcePool? resourcePool,
    int? minLevel,
    String? associatedClass,
    String? associatedSubclass,
    bool? requiresRest,
    String? actionEconomy,
    String? iconName,
    FeatureConsumption? consumption,
    String? sourceId,
    String? usageCostId,
    String? usageInputMode,
    List<String>? options,
    bool? isOptional,
  }) {
    return CharacterFeature(
      id: id ?? feature.id,
      nameEn: nameEn ?? feature.nameEn,
      nameRu: nameRu ?? feature.nameRu,
      descriptionEn: descriptionEn ?? feature.descriptionEn,
      descriptionRu: descriptionRu ?? feature.descriptionRu,
      type: type ?? feature.type,
      resourcePool: resourcePool ??
          (feature.resourcePool == null
              ? null
              : ResourcePool(
                  currentUses: feature.resourcePool!.currentUses,
                  maxUses: feature.resourcePool!.maxUses,
                  recoveryType: feature.resourcePool!.recoveryType,
                  calculationFormula: feature.resourcePool!.calculationFormula,
                )),
      minLevel: minLevel ?? feature.minLevel,
      associatedClass: associatedClass ?? feature.associatedClass,
      associatedSubclass: associatedSubclass ?? feature.associatedSubclass,
      requiresRest: requiresRest ?? feature.requiresRest,
      actionEconomy: actionEconomy ?? feature.actionEconomy,
      iconName: iconName ?? feature.iconName,
      consumption: consumption ?? feature.consumption,
      sourceId: sourceId ?? feature.sourceId,
      usageCostId: usageCostId ?? feature.usageCostId,
      usageInputMode: usageInputMode ?? feature.usageInputMode,
      options: options ??
          (feature.options == null ? null : List.of(feature.options!)),
      isOptional: isOptional ?? feature.isOptional,
    );
  }

  static String? _resourceIdFromText(CharacterFeature feature) {
    final text = _normalizeLoose(
      '${feature.nameEn} ${feature.descriptionEn} ${feature.nameRu} ${feature.descriptionRu}',
    );
    final nameResource = _resourceIdForName(feature.nameEn);

    if (text.contains('channel divinity') ||
        text.contains('божественный канал')) {
      return nameResource == 'channel-divinity' ? null : 'channel-divinity';
    }
    if (text.contains('ki point') ||
        text.contains('ki points') ||
        text.contains('spend 1 ki') ||
        text.contains('очко ци') ||
        text.contains('очки ци')) {
      return nameResource == 'ki' ? null : 'ki';
    }
    if (text.contains('bardic inspiration') ||
        text.contains('бардовское вдохновение')) {
      return nameResource == 'bardic-inspiration' ? null : 'bardic-inspiration';
    }
    if (text.contains('wild shape') || text.contains('дикий облик')) {
      return nameResource == 'wild-shape' ? null : 'wild-shape';
    }
    if (text.contains('sorcery point') ||
        text.contains('sorcery points') ||
        (text.contains('единиц') && text.contains('чародей'))) {
      return nameResource == 'sorcery-points' ? null : 'sorcery-points';
    }
    if (text.contains('lay on hands') || text.contains('наложение рук')) {
      return nameResource == 'lay-on-hands' ? null : 'lay-on-hands';
    }
    if (text.contains('divine sense') ||
        text.contains('божественное чувство')) {
      return nameResource == 'divine-sense' ? null : 'divine-sense';
    }
    if (text.contains('rage') && !text.contains('relentless rage')) {
      return nameResource == 'rage' ? null : 'rage';
    }
    return null;
  }

  static String? _resourceIdForName(String name) {
    return _resourceNameAliases[_canonicalFeatureName(name)];
  }

  static String? _resourceIdFromFeatureId(String id) {
    final normalized = _normalizeId(id);
    for (final resourceId in _resourceNameAliases.values.toSet()) {
      if (normalized == resourceId || normalized.startsWith('$resourceId-')) {
        return resourceId;
      }
    }
    return null;
  }

  static bool _isKnownTextOnly(CharacterFeature feature) {
    final text = _normalizeLoose('${feature.nameEn} ${feature.nameRu}');
    return _textOnlyMechanics.any(text.contains);
  }

  static String _actionEconomyFromText(CharacterFeature feature) {
    final text = _normalizeLoose(
      '${feature.nameEn} ${feature.descriptionEn} ${feature.descriptionRu}',
    );
    if (text.contains('bonus action') || text.contains('бонусным действием')) {
      return 'bonus_action';
    }
    if (text.contains('reaction') || text.contains('реакци')) {
      return 'reaction';
    }
    if (text.contains('when you') || text.contains('когда вы')) {
      return 'free';
    }
    if (text.contains('as an action') ||
        text.contains('use your action') ||
        text.contains('действием') ||
        text.contains('в качестве действия')) {
      return 'action';
    }
    return 'action';
  }

  static int _resourceCostFromText(CharacterFeature feature) {
    final text = _normalizeLoose(
      '${feature.nameEn} ${feature.descriptionEn} ${feature.descriptionRu}',
    );
    const words = {
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
    };

    final numeric = RegExp(r'(spend|expend|costs?)\s+(\d+)').firstMatch(text);
    if (numeric != null) {
      return int.tryParse(numeric.group(2)!)?.clamp(1, 99).toInt() ?? 1;
    }

    for (final entry in words.entries) {
      if (text.contains('spend ${entry.key}') ||
          text.contains('expend ${entry.key}') ||
          text.contains('costs ${entry.key}')) {
        return entry.value;
      }
    }

    return 1;
  }

  static FeatureType _featureTypeForAction(String economy) {
    switch (economy) {
      case 'bonus_action':
        return FeatureType.bonusAction;
      case 'reaction':
        return FeatureType.reaction;
      case 'free':
        return FeatureType.free;
      default:
        return FeatureType.action;
    }
  }

  static int _classLevel(Character character, String classIdOrName) {
    final target = _normalizeClass(classIdOrName);
    for (final characterClass in character.classes) {
      if (_characterClassMatches(characterClass, target)) {
        return characterClass.level;
      }
    }
    return character.level;
  }

  static bool _characterClassMatches(
      CharacterClass characterClass, String target) {
    final id = _normalizeClass(characterClass.id);
    final name = _normalizeClass(characterClass.name);
    return id == target || name == target;
  }

  static int _channelDivinityUses(String classId, int level) {
    if (classId == 'cleric') {
      if (level < 6) return 1;
      if (level < 18) return 2;
      return 3;
    }
    return 1;
  }

  static int _rageUses(int level) {
    if (level >= 20) return 99;
    if (level >= 17) return 6;
    if (level >= 12) return 5;
    if (level >= 6) return 4;
    if (level >= 3) return 3;
    return 2;
  }

  static String? _displayClass(String normalizedClass, String? fallback) {
    if (fallback != null && fallback.isNotEmpty) return fallback;
    switch (normalizedClass) {
      case 'paladin':
        return 'Paladin';
      case 'cleric':
        return 'Cleric';
      case 'monk':
        return 'Monk';
      case 'barbarian':
        return 'Barbarian';
      case 'bard':
        return 'Bard';
      case 'druid':
        return 'Druid';
      case 'fighter':
        return 'Fighter';
      case 'sorcerer':
        return 'Sorcerer';
      default:
        return fallback;
    }
  }

  static String _canonicalFeatureName(String value) {
    var result = _normalizeLoose(
      FC5ImportedNameNormalizer.normalizedDisplayName(value),
    );
    result = result.replaceFirst(RegExp(r'\s*\([^)]*\)$'), '');
    return result.trim();
  }

  static String _normalizeClass(String value) {
    final normalized = _normalizeLoose(value);
    return _classAliases[normalized] ?? normalized;
  }

  static String _normalizeSubclass(String value) {
    final normalized = _normalizeLoose(value);
    return _subclassAliases[normalized] ?? normalized;
  }

  static String _normalizeId(String value) {
    return _normalizeLoose(value).replaceAll(' ', '-');
  }

  static String _normalizeLoose(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isImportedFeature(CharacterFeature feature) {
    return feature.id.startsWith('fc5_') || feature.sourceId != null;
  }

  static void _addDiagnostic(
    List<FeatureHydrationDiagnostic>? diagnostics,
    FeatureHydrationDiagnosticSeverity severity,
    String code,
    String message, {
    String? context,
  }) {
    diagnostics?.add(
      FeatureHydrationDiagnostic(
        severity: severity,
        code: code,
        message: message,
        context: context,
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
