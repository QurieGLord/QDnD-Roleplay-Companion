import '../models/background_data.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/item.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'character_data_service.dart';
import 'feature_service.dart';
import 'item_service.dart';
import 'qdnd_bundle_codec.dart';
import 'qdnd_bundle_schema.dart';
import 'spell_service.dart';
import 'storage_service.dart';

class BundleResolvedDependency {
  final BundleDependencyReference reference;
  final String resolvedId;
  final Object entity;

  const BundleResolvedDependency({
    required this.reference,
    required this.resolvedId,
    required this.entity,
  });
}

class BundleDependencyResolution {
  final List<BundleResolvedDependency> resolved;
  final List<BundleDependencyReference> missing;

  const BundleDependencyResolution({
    required this.resolved,
    required this.missing,
  });
}

class BundleDependencyResolver {
  static BundleDependencyResolution resolve(
    Iterable<BundleDependencyReference> dependencies,
  ) {
    final resolved = <BundleResolvedDependency>[];
    final missing = <BundleDependencyReference>[];

    for (final dependency in dependencies) {
      final entity = _findEntity(dependency);
      if (entity == null) {
        missing.add(dependency);
        continue;
      }

      resolved.add(
        BundleResolvedDependency(
          reference: dependency,
          resolvedId: _entityId(entity),
          entity: entity,
        ),
      );
    }

    return BundleDependencyResolution(
      resolved: resolved,
      missing: missing,
    );
  }

  static Object? _findEntity(BundleDependencyReference dependency) {
    switch (dependency.contentType) {
      case 'spell':
        return _findSpell(dependency);
      case 'item':
        return _findItem(dependency);
      case 'feature':
        return _findFeature(dependency);
      case 'class':
        return _findClass(dependency);
      case 'race':
        return _findRace(dependency);
      case 'background':
        return _findBackground(dependency);
      default:
        return null;
    }
  }

  static Spell? _findSpell(BundleDependencyReference dependency) {
    return _findByIdentity<Spell>(
      _dedupeById(
          [...SpellService.getAllSpells(), ...StorageService.getAllSpells()]),
      dependency,
      idOf: (spell) => spell.id,
      nameOf: (spell) => spell.nameEn,
      sourceIdOf: (spell) => spell.sourceId,
      hashOf: (spell) => QdndBundleHashes.entityHash(spell.toJson()),
    );
  }

  static Item? _findItem(BundleDependencyReference dependency) {
    return _findByIdentity<Item>(
      _dedupeById(
          [...ItemService.getAllItems(), ...StorageService.getAllItems()]),
      dependency,
      idOf: (item) => item.id,
      nameOf: (item) => item.nameEn,
      sourceIdOf: (item) => item.sourceId,
      hashOf: (item) => QdndBundleHashes.entityHash(item.toJson()),
    );
  }

  static CharacterFeature? _findFeature(BundleDependencyReference dependency) {
    return _findByIdentity<CharacterFeature>(
      _dedupeById([
        ...FeatureService.allFeatures,
        ...CharacterDataService.getAllFeats(),
      ]),
      dependency,
      idOf: (feature) => feature.id,
      nameOf: (feature) => feature.nameEn,
      sourceIdOf: (feature) => feature.sourceId,
      hashOf: (feature) => QdndBundleHashes.entityHash(
        QdndBundleCodec.featureToJson(feature),
      ),
    );
  }

  static ClassData? _findClass(BundleDependencyReference dependency) {
    return _findByIdentity<ClassData>(
      CharacterDataService.getAllClasses(),
      dependency,
      idOf: (classData) => classData.id,
      nameOf: (classData) => classData.name['en'] ?? classData.id,
      sourceIdOf: (classData) => classData.sourceId,
      hashOf: (classData) => QdndBundleHashes.entityHash(
        QdndBundleCodec.classToJson(classData),
      ),
    );
  }

  static RaceData? _findRace(BundleDependencyReference dependency) {
    return _findByIdentity<RaceData>(
      CharacterDataService.getAllRaces(),
      dependency,
      idOf: (race) => race.id,
      nameOf: (race) => race.name['en'] ?? race.id,
      sourceIdOf: (race) => race.sourceId,
      hashOf: (race) => QdndBundleHashes.entityHash(
        QdndBundleCodec.raceToJson(race),
      ),
    );
  }

  static BackgroundData? _findBackground(BundleDependencyReference dependency) {
    return _findByIdentity<BackgroundData>(
      CharacterDataService.getAllBackgrounds(),
      dependency,
      idOf: (background) => background.id,
      nameOf: (background) => background.name['en'] ?? background.id,
      sourceIdOf: (background) => background.sourceId,
      hashOf: (background) => QdndBundleHashes.entityHash(
        QdndBundleCodec.backgroundToJson(background),
      ),
    );
  }

  static T? _findByIdentity<T>(
    Iterable<T> values,
    BundleDependencyReference dependency, {
    required String Function(T value) idOf,
    required String Function(T value) nameOf,
    required String? Function(T value) sourceIdOf,
    required String Function(T value) hashOf,
  }) {
    final list = values.toList();

    for (final value in list) {
      if (idOf(value) == dependency.localId &&
          sourceIdOf(value) == dependency.sourceId) {
        return value;
      }
    }

    for (final value in list) {
      if (idOf(value) == dependency.localId) {
        return value;
      }
    }

    if (dependency.contentHash != null) {
      for (final value in list) {
        if (hashOf(value) == dependency.contentHash) {
          return value;
        }
      }
    }

    final canonicalName = dependency.canonicalName;
    if (canonicalName != null && canonicalName.trim().isNotEmpty) {
      final targetName = _normalize(canonicalName);
      for (final value in list) {
        if (_normalize(nameOf(value)) == targetName) {
          return value;
        }
      }
    }

    return null;
  }

  static List<T> _dedupeById<T extends Object>(Iterable<T> values) {
    final seen = <String>{};
    final deduped = <T>[];
    for (final value in values) {
      final id = _entityId(value);
      if (seen.add(id)) {
        deduped.add(value);
      }
    }
    return deduped;
  }

  static String _entityId(Object entity) {
    if (entity is Spell) return entity.id;
    if (entity is Item) return entity.id;
    if (entity is CharacterFeature) return entity.id;
    if (entity is ClassData) return entity.id;
    if (entity is RaceData) return entity.id;
    if (entity is BackgroundData) return entity.id;
    return '';
  }

  static String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '');
  }
}
