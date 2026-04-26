import '../models/character_feature.dart';
import '../models/class_data.dart';
import 'feature_hydration_service.dart';
import 'feature_service.dart';

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

      final current = overlays[assetClass.id] ?? assetClass;
      overlays[assetClass.id] = _mergeClassOverlay(current, importedClass);
    }

    return [
      for (final assetClass in assetClasses) overlays[assetClass.id]!,
      ...unmatchedImported,
    ];
  }

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
    );
  }

  static ClassData _hydrateStandaloneClass(ClassData importedClass) {
    final features = <int, List<CharacterFeature>>{};
    for (final entry in importedClass.features.entries) {
      features[entry.key] = FeatureHydrationService.hydrateClassFeatures(
        entry.value,
        className: importedClass.name['en'] ?? importedClass.id,
      ).features;
    }

    return ClassData(
      id: importedClass.id,
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
