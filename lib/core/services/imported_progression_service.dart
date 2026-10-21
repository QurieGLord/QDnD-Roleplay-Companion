import '../models/character_feature.dart';
import '../models/class_data.dart';
import 'feature_hydration_service.dart';
import 'feature_service.dart';
import 'catalog_definition_signature.dart';

enum ClassLibraryRelation { newClass, partialExtension, competingVariant }

class ClassLibraryAssessment {
  const ClassLibraryAssessment(this.relation, this.differences);
  final ClassLibraryRelation relation;
  final List<String> differences;
}

class ImportedProgressionService {
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

  static List<ClassData> overlayImportedClasses({
    required List<ClassData> assetClasses,
    required List<ClassData> importedClasses,
  }) {
    final overlays = {
      for (final assetClass in assetClasses) assetClass.id: assetClass,
    };
    final unmatchedImported = <ClassData>[];

    for (final importedClass in importedClasses) {
      final assetClass = _findMatchingAssetClass(assetClasses, importedClass);
      if (assetClass == null) {
        unmatchedImported.add(_hydrateStandaloneClass(importedClass));
        continue;
      }

      final assessment = assessClass(assetClass, importedClass);
      if (assessment.relation == ClassLibraryRelation.competingVariant) {
        // Keep an independently identified imported definition. Its name alone
        // is never permission to graft changed mechanics onto every hero.
        unmatchedImported.add(_hydrateStandaloneClass(importedClass,
            id: importedClass.id == assetClass.id
                ? '${importedClass.sourceId ?? 'unresolved'}::${importedClass.id}'
                : null));
        continue;
      }
      final current = overlays[assetClass.id] ?? assetClass;
      overlays[assetClass.id] = _mergeClassOverlay(current, importedClass);
    }

    return [
      for (final assetClass in assetClasses) overlays[assetClass.id]!,
      ...unmatchedImported,
    ];
  }

  /// Structural classification, not a guessed edition or a claim that all
  /// imported prose has executable semantics. Missing fields remain unknown.
  static ClassLibraryAssessment assessClass(
      ClassData? base, ClassData incoming) {
    if (base == null || _classKey(base) != _classKey(incoming)) {
      return const ClassLibraryAssessment(ClassLibraryRelation.newClass, []);
    }
    final differences = <String>[];
    if (incoming.rulesMetadata.isEmpty && incoming.sourceId != null) {
      differences.add('unverifiedDefinition');
    }
    if (base.declares('hitDie') &&
        incoming.declares('hitDie') &&
        base.hitDie != incoming.hitDie) {
      differences.add('hitDie');
    }
    if (base.rulesEdition != 'unknown' &&
        incoming.rulesEdition != 'unknown' &&
        base.rulesEdition != incoming.rulesEdition) {
      differences.add('edition');
    }
    if (base.spellcasting != null &&
        incoming.spellcasting != null &&
        (base.spellcasting!.type != incoming.spellcasting!.type ||
            base.spellcasting!.ability != incoming.spellcasting!.ability)) {
      differences.add('spellcasting');
    }
    final byId = {
      for (final row in base.features.values)
        for (final feature in row) feature.id: feature
    };
    for (final row in incoming.features.values) {
      for (final feature in row) {
        final original = byId[feature.id] ??
            [
              ...base.features.values.expand((f) => f),
              ...FeatureService.getFeaturesForLevel(
                  classId: base.id,
                  level: feature.minLevel,
                  subclassId: feature.associatedSubclass),
            ]
                .where((candidate) =>
                    FeatureHydrationService.featureDedupeKey(candidate) ==
                    FeatureHydrationService.featureDedupeKey(feature))
                .firstOrNull;
        if (original != null &&
            original.minLevel == feature.minLevel &&
            CatalogDefinitionSignature.of(original.toJson()) !=
                CatalogDefinitionSignature.of(feature.toJson())) {
          differences.add('featureDefinition:${feature.id}');
        }
        if (original != null &&
            original.associatedSubclass == feature.associatedSubclass &&
            original.minLevel != feature.minLevel) {
          differences.add('featureLevel:${feature.id}');
        }
      }
    }
    return ClassLibraryAssessment(
        differences.isEmpty
            ? ClassLibraryRelation.partialExtension
            : ClassLibraryRelation.competingVariant,
        List.unmodifiable(differences));
  }

  static ClassData? matchingClass(
          Iterable<ClassData> candidates, ClassData incoming) =>
      candidates
          .where((base) => _classKey(base) == _classKey(incoming))
          .firstOrNull;

  static ClassData _mergeClassOverlay(
    ClassData base,
    ClassData importedClass,
  ) {
    final subclasses = [...base.subclasses];
    final subclassKeys = subclasses.map(_subclassKey).toSet();

    for (final subclass in importedClass.subclasses) {
      if (subclassKeys.add(_subclassKey(subclass))) {
        subclasses.add(subclass);
      }
    }

    final features = <int, List<CharacterFeature>>{
      for (final entry in base.features.entries)
        entry.key: List.of(entry.value),
    };

    for (final entry in importedClass.features.entries) {
      final level = entry.key;
      final target = features.putIfAbsent(level, () => []);
      final existingKeys =
          target.map(FeatureHydrationService.featureDedupeKey).toSet();

      final hydrated = FeatureHydrationService.hydrateClassFeatures(
        entry.value,
        className: base.name['en'] ?? base.id,
      ).features;

      for (final feature in hydrated) {
        if (_matchesBuiltInAtLevel(base.id, level, feature)) {
          continue;
        }

        final key = FeatureHydrationService.featureDedupeKey(feature);
        if (existingKeys.add(key)) {
          target.add(feature);
        }
      }
    }

    return ClassData(
      id: base.id,
      name: base.name,
      description: base.description,
      hitDie: base.hitDie,
      primaryAbilities: base.primaryAbilities,
      savingThrowProficiencies: base.savingThrowProficiencies,
      armorProficiencies: base.armorProficiencies,
      weaponProficiencies: base.weaponProficiencies,
      skillProficiencies: base.skillProficiencies,
      subclasses: subclasses,
      subclassLevel: base.subclassLevel,
      spellcasting: base.spellcasting,
      features: features,
      sourceId: base.sourceId,
      rulesMetadata: {
        ...base.rulesMetadata,
        'contributingSources': [
          ...?base.rulesMetadata['contributingSources'] as List?,
          if (importedClass.sourceId != null) importedClass.sourceId,
        ]
      },
      sourceDefinition: base.sourceDefinition,
    );
  }

  static ClassData _hydrateStandaloneClass(ClassData importedClass,
      {String? id}) {
    final features = <int, List<CharacterFeature>>{};
    for (final entry in importedClass.features.entries) {
      features[entry.key] = FeatureHydrationService.hydrateClassFeatures(
        entry.value,
        className: importedClass.name['en'] ?? importedClass.id,
      ).features;
    }

    return ClassData(
      id: id ?? importedClass.id,
      name: importedClass.name,
      description: importedClass.description,
      hitDie: importedClass.hitDie,
      primaryAbilities: importedClass.primaryAbilities,
      savingThrowProficiencies: importedClass.savingThrowProficiencies,
      armorProficiencies: importedClass.armorProficiencies,
      weaponProficiencies: importedClass.weaponProficiencies,
      skillProficiencies: importedClass.skillProficiencies,
      subclasses: importedClass.subclasses,
      subclassLevel: importedClass.subclassLevel,
      spellcasting: importedClass.spellcasting,
      features: features,
      sourceId: importedClass.sourceId,
      rulesMetadata: importedClass.rulesMetadata,
      sourceDefinition: importedClass.sourceDefinition,
    );
  }

  static bool _matchesBuiltInAtLevel(
    String classId,
    int level,
    CharacterFeature importedFeature,
  ) {
    final subclassId = importedFeature.associatedSubclass;
    final candidates = FeatureService.getFeaturesForLevel(
      classId: classId,
      level: level,
      subclassId: subclassId,
    );

    return candidates.any(
      (candidate) =>
          FeatureHydrationService.featureMatchesBuiltIn(
            importedFeature,
            candidate,
          ) ||
          FeatureHydrationService.featureDedupeKey(importedFeature) ==
              FeatureHydrationService.featureDedupeKey(candidate),
    );
  }

  static ClassData? _findMatchingAssetClass(
    List<ClassData> assetClasses,
    ClassData importedClass,
  ) {
    final importedKey = _classKey(importedClass);
    for (final assetClass in assetClasses) {
      if (_classKey(assetClass) == importedKey) {
        return assetClass;
      }
    }
    return null;
  }

  static String _classKey(ClassData classData) {
    final names = [
      classData.id,
      ...classData.name.values,
    ];
    for (final name in names) {
      final normalized = _normalizeLoose(name);
      final aliased = _classAliases[normalized] ?? normalized;
      if (_classAliases.containsValue(aliased)) return aliased;
    }
    return _normalizeLoose(classData.name['en'] ?? classData.id)
        .replaceAll(' ', '_');
  }

  static String _subclassKey(SubclassData subclass) {
    return [
      subclass.id,
      ...subclass.name.values,
    ]
        .map(_normalizeLoose)
        .map((value) => value.replaceFirst('oath of ', ''))
        .join('|');
  }

  static String _normalizeLoose(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
