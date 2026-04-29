import '../models/background_data.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/item.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'character_data_service.dart';
import 'feature_hydration_service.dart';
import 'feature_service.dart';
import 'fc5_imported_name_normalizer.dart';
import 'item_service.dart';
import 'spell_service.dart';
import 'storage_service.dart';
import 'fc5_parser.dart';

class FC5ContentIdentityService {
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
    'изобретатель': 'artificer',
    'paladin': 'paladin',
    'fighter': 'fighter',
    'barbarian': 'barbarian',
    'monk': 'monk',
    'rogue': 'rogue',
    'ranger': 'ranger',
    'druid': 'druid',
    'cleric': 'cleric',
    'wizard': 'wizard',
    'sorcerer': 'sorcerer',
    'warlock': 'warlock',
    'bard': 'bard',
    'artificer': 'artificer',
  };

  static const Map<String, String> _subclassAliases = {
    'devotion': 'oath of devotion',
    'oath devotion': 'oath of devotion',
    'oath of devotion': 'oath of devotion',
    'клятва преданности': 'oath of devotion',
    'клятва древних': 'oath of the ancients',
    'oath of the ancients': 'oath of the ancients',
    'клятва мести': 'oath of vengeance',
    'oath of vengeance': 'oath of vengeance',
    'клятва покорения': 'oath of conquest',
    'oath of conquest': 'oath of conquest',
    'клятва славы': 'oath of glory',
    'oath of glory': 'oath of glory',
    'клятва искупления': 'oath of redemption',
    'oath of redemption': 'oath of redemption',
    'клятва смотрителей': 'oath of the watchers',
    'клятва стражей': 'oath of the watchers',
    'oath of the watchers': 'oath of the watchers',
    'life': 'life domain',
    'life domain': 'life domain',
    'домен жизни': 'life domain',
    'домен бури': 'tempest domain',
    'tempest domain': 'tempest domain',
    'домен войны': 'war domain',
    'war domain': 'war domain',
    'домен знаний': 'knowledge domain',
    'knowledge domain': 'knowledge domain',
    'домен света': 'light domain',
    'light domain': 'light domain',
    'домен обмана': 'trickery domain',
    'trickery domain': 'trickery domain',
    'домен природы': 'nature domain',
    'nature domain': 'nature domain',
    'champion': 'champion',
    'чемпион': 'champion',
    'battle master': 'battle master',
    'мастер боевых искусств': 'battle master',
    'eldritch knight': 'eldritch knight',
    'мистический рыцарь': 'eldritch knight',
    'circle of the moon': 'circle of the moon',
    'круг луны': 'circle of the moon',
    'circle of the land': 'circle of the land',
    'круг земли': 'circle of the land',
  };

  static Set<String> itemKeys(Item item) {
    final suffix = [
      item.type.name,
      if (item.weaponProperties != null) item.weaponProperties!.damageType.name,
      if (item.armorProperties != null) item.armorProperties!.armorType.name,
    ].join(':');
    return _localizedNameKeys(
      'item',
      [item.id, item.nameEn, item.nameRu],
      suffix,
    );
  }

  static Set<String> spellKeys(Spell spell) {
    return _localizedNameKeys(
      'spell',
      [spell.id, spell.nameEn, spell.nameRu],
      '${spell.level}:${_normalize(spell.school)}',
    );
  }

  static Set<String> raceKeys(RaceData race) {
    return _localizedNameKeys(
      'race',
      [race.id, ...race.name.values],
      '',
    );
  }

  static Set<String> backgroundKeys(BackgroundData background) {
    return _localizedNameKeys(
      'background',
      [background.id, ...background.name.values],
      '',
    );
  }

  static Set<String> featKeys(CharacterFeature feat) {
    return _localizedNameKeys(
      'feat',
      [feat.id, feat.nameEn, feat.nameRu],
      '',
    );
  }

  static Set<String> classKeys(ClassData classData) {
    final classId = classIdFromClassData(classData);
    return {
      'class:$classId',
      ..._localizedNameKeys('class', classData.name.values, ''),
    };
  }

  static Set<String> subclassKeys(
    ClassData classData,
    SubclassData subclass,
  ) {
    final classId = classIdFromClassData(classData);
    return _localizedNameKeys(
      'subclass:$classId',
      [subclass.id, ...subclass.name.values],
      '',
      canonicalize: canonicalSubclassName,
    );
  }

  static Set<String> featureKeys(CharacterFeature feature) {
    final classId = canonicalClassId(feature.associatedClass ?? '');
    final subclassId = canonicalSubclassName(feature.associatedSubclass ?? '');
    final prefix = [
      'feature',
      classId,
      subclassId,
      feature.minLevel,
    ].join(':');
    return _localizedNameKeys(
      prefix,
      [feature.id, feature.nameEn, feature.nameRu],
      '',
      canonicalize: _canonicalFeatureName,
    );
  }

  static String classIdFromClassData(ClassData classData) {
    for (final value in [classData.id, ...classData.name.values]) {
      final id = canonicalClassId(value);
      if (id.isNotEmpty && _classAliases.containsValue(id)) return id;
    }
    return _normalize(classData.name['en'] ?? classData.id)
        .replaceAll(' ', '_');
  }

  static String canonicalClassId(String value) {
    final normalized = _normalize(value)
        .replaceFirst(RegExp(r'^fc5 [^ ]+ class '), '')
        .replaceFirst(RegExp(r'^fc5 [^ ]+ [^ ]+ class '), '');
    return _classAliases[normalized] ?? normalized.replaceAll(' ', '_');
  }

  static String canonicalSubclassName(String value) {
    final normalized = _normalize(value)
        .replaceFirst(RegExp(r'^oath '), 'oath of ')
        .replaceFirst(RegExp(r'^circle '), 'circle of ');
    return _subclassAliases[normalized] ?? normalized;
  }

  static Set<String> _localizedNameKeys(
    String prefix,
    Iterable<String> names,
    String suffix, {
    String Function(String value)? canonicalize,
  }) {
    final result = <String>{};
    for (final rawName in names) {
      final normalized = _normalize(rawName);
      if (normalized.isEmpty) continue;
      final canonical = canonicalize?.call(normalized) ?? normalized;
      final fullSuffix = suffix.isEmpty ? '' : ':$suffix';
      result.add('$prefix:$canonical$fullSuffix');
    }
    return result;
  }

  static String _canonicalFeatureName(String value) {
    return _normalize(value)
        .replaceFirst(RegExp(r'\\s*\\([^)]*\\)$'), '')
        .trim();
  }

  static String _normalize(String value) {
    return FC5ImportedNameNormalizer.normalizedDisplayName(value)
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'[^a-zа-я0-9\\s]+'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }
}

class FC5CompendiumDeduplicationStats {
  int items = 0;
  int spells = 0;
  int races = 0;
  int classes = 0;
  int subclasses = 0;
  int backgrounds = 0;
  int feats = 0;
  int features = 0;

  int get total =>
      items +
      spells +
      races +
      classes +
      subclasses +
      backgrounds +
      feats +
      features;
}

class FC5CompendiumDeduplicationResult {
  const FC5CompendiumDeduplicationResult({
    required this.parseResult,
    required this.stats,
  });

  final FC5ParseResult parseResult;
  final FC5CompendiumDeduplicationStats stats;
}

class FC5CompendiumDeduplicationService {
  static FC5CompendiumDeduplicationResult dedupe(
    FC5ParseResult parseResult,
  ) {
    final registry = _ContentIdentityRegistry.fromLoadedContent();
    final stats = FC5CompendiumDeduplicationStats();

    final items = _dedupeEntities(
      parseResult.items,
      FC5ContentIdentityService.itemKeys,
      registry,
      onSkipped: () => stats.items += 1,
    );
    final spells = _dedupeEntities(
      parseResult.spells,
      FC5ContentIdentityService.spellKeys,
      registry,
      onSkipped: () => stats.spells += 1,
    );
    final races = _dedupeEntities(
      parseResult.races,
      FC5ContentIdentityService.raceKeys,
      registry,
      onSkipped: () => stats.races += 1,
    );
    final backgrounds = _dedupeEntities(
      parseResult.backgrounds,
      FC5ContentIdentityService.backgroundKeys,
      registry,
      onSkipped: () => stats.backgrounds += 1,
    );
    final feats = _dedupeEntities(
      parseResult.feats,
      FC5ContentIdentityService.featKeys,
      registry,
      onSkipped: () => stats.feats += 1,
    );

    final classes = <ClassData>[];
    for (final classData in parseResult.classes) {
      final filtered = _dedupeClass(classData, registry, stats);
      if (filtered == null) continue;
      classes.add(filtered);
    }

    final diagnostics = parseResult.diagnostics.copy();
    if (stats.total > 0) {
      diagnostics.info(
        'duplicates_skipped',
        'Skipped ${stats.total} duplicate imported entities.',
        context: '${stats.total}',
      );
    }

    return FC5CompendiumDeduplicationResult(
      parseResult: FC5ParseResult(
        items: items,
        spells: spells,
        races: races,
        classes: classes,
        backgrounds: backgrounds,
        feats: feats,
        diagnostics: diagnostics,
      ),
      stats: stats,
    );
  }

  static List<T> _dedupeEntities<T>(
    Iterable<T> entities,
    Set<String> Function(T entity) keysFor,
    _ContentIdentityRegistry registry, {
    required void Function() onSkipped,
  }) {
    final result = <T>[];
    for (final entity in entities) {
      final keys = keysFor(entity);
      if (registry.containsAny(keys)) {
        onSkipped();
        continue;
      }
      registry.addAll(keys);
      result.add(entity);
    }
    return result;
  }

  static ClassData? _dedupeClass(
    ClassData classData,
    _ContentIdentityRegistry registry,
    FC5CompendiumDeduplicationStats stats,
  ) {
    final classKeys = FC5ContentIdentityService.classKeys(classData);
    final classExists = registry.containsAny(classKeys);
    final skippedSubclassIds = <String>{};
    final subclasses = <SubclassData>[];

    for (final subclass in classData.subclasses) {
      final keys = FC5ContentIdentityService.subclassKeys(classData, subclass);
      if (registry.containsAny(keys)) {
        stats.subclasses += 1;
        skippedSubclassIds.add(
          FC5ContentIdentityService.canonicalSubclassName(
            subclass.name['en'] ?? subclass.id,
          ),
        );
        skippedSubclassIds.add(
          FC5ContentIdentityService.canonicalSubclassName(
            subclass.name['ru'] ?? subclass.id,
          ),
        );
        continue;
      }
      registry.addAll(keys);
      subclasses.add(subclass);
    }

    final features = <int, List<CharacterFeature>>{};
    for (final entry in classData.features.entries) {
      final kept = <CharacterFeature>[];
      for (final feature in entry.value) {
        final subclass = feature.associatedSubclass;
        if (subclass != null &&
            skippedSubclassIds.contains(
              FC5ContentIdentityService.canonicalSubclassName(subclass),
            )) {
          stats.features += 1;
          continue;
        }

        final keys = FC5ContentIdentityService.featureKeys(feature);
        if (registry.containsAny(keys) ||
            _matchesBuiltInFeature(classData, feature)) {
          stats.features += 1;
          continue;
        }
        registry.addAll(keys);
        kept.add(feature);
      }
      if (kept.isNotEmpty) {
        features[entry.key] = kept;
      }
    }

    if (!classExists) {
      registry.addAll(classKeys);
    }

    if (classExists && subclasses.isEmpty && features.isEmpty) {
      stats.classes += 1;
      return null;
    }

    return ClassData(
      id: classData.id,
      name: classData.name,
      description: classData.description,
      hitDie: classData.hitDie,
      primaryAbilities: classData.primaryAbilities,
      savingThrowProficiencies: classData.savingThrowProficiencies,
      armorProficiencies: classData.armorProficiencies,
      weaponProficiencies: classData.weaponProficiencies,
      skillProficiencies: classData.skillProficiencies,
      subclasses: subclasses,
      subclassLevel: classData.subclassLevel,
      spellcasting: classData.spellcasting,
      features: features,
      sourceId: classData.sourceId,
    );
  }

  static bool _matchesBuiltInFeature(
    ClassData classData,
    CharacterFeature feature,
  ) {
    final classId = FC5ContentIdentityService.classIdFromClassData(classData);
    final candidates = FeatureService.getFeaturesForLevel(
      classId: classId,
      level: feature.minLevel,
      subclassId: feature.associatedSubclass,
    );
    return candidates.any(
      (candidate) =>
          FeatureHydrationService.featureMatchesBuiltIn(feature, candidate) ||
          FC5ContentIdentityService.featureKeys(feature)
              .intersection(FC5ContentIdentityService.featureKeys(candidate))
              .isNotEmpty,
    );
  }
}

class _ContentIdentityRegistry {
  final Set<String> _keys = {};

  _ContentIdentityRegistry();

  factory _ContentIdentityRegistry.fromLoadedContent() {
    final registry = _ContentIdentityRegistry();

    for (final item in [
      ...ItemService.getAllItems(),
      ...StorageService.getAllItems(),
    ]) {
      registry.addAll(FC5ContentIdentityService.itemKeys(item));
    }
    for (final spell in [
      ...SpellService.getAllSpells(),
      ...StorageService.getAllSpells(),
    ]) {
      registry.addAll(FC5ContentIdentityService.spellKeys(spell));
    }
    for (final race in [
      ...CharacterDataService.getAllRaces(),
      ...StorageService.getAllRaces(),
    ]) {
      registry.addAll(FC5ContentIdentityService.raceKeys(race));
    }
    for (final background in [
      ...CharacterDataService.getAllBackgrounds(),
      ...StorageService.getAllBackgrounds(),
    ]) {
      registry.addAll(FC5ContentIdentityService.backgroundKeys(background));
    }
    for (final feat in [
      ...CharacterDataService.getAllFeats(),
      ...StorageService.getAllFeats(),
    ]) {
      registry.addAll(FC5ContentIdentityService.featKeys(feat));
    }
    for (final classData in [
      ...CharacterDataService.getAllClasses(),
      ...StorageService.getAllClasses(),
    ]) {
      registry.addAll(FC5ContentIdentityService.classKeys(classData));
      for (final subclass in classData.subclasses) {
        registry.addAll(
          FC5ContentIdentityService.subclassKeys(classData, subclass),
        );
      }
      for (final features in classData.features.values) {
        for (final feature in features) {
          registry.addAll(FC5ContentIdentityService.featureKeys(feature));
        }
      }
    }
    for (final feature in FeatureService.allFeatures) {
      registry.addAll(FC5ContentIdentityService.featureKeys(feature));
    }

    return registry;
  }

  bool containsAny(Set<String> keys) => keys.any(_keys.contains);

  void addAll(Iterable<String> keys) {
    _keys.addAll(keys);
  }
}
