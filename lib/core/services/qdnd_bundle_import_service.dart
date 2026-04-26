import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/background_data.dart';
import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/item.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'bundle_dependency_resolver.dart';
import 'bundle_id_mapper.dart';
import 'character_data_service.dart';
import 'feature_hydration_service.dart';
import 'feature_service.dart';
import 'item_service.dart';
import 'qdnd_bundle_codec.dart';
import 'qdnd_bundle_schema.dart';
import 'spell_service.dart';
import 'storage_service.dart';

class QdndBundleImportService {
  static const int _maxFileCount = 128;
  static const int _maxTotalUncompressedBytes = 25 * 1024 * 1024;
  static const int _maxSingleFileBytes = 10 * 1024 * 1024;

  static Future<QdndBundleImportPreview> previewFile(File file) async {
    return previewBytes(await file.readAsBytes());
  }

  static Future<QdndBundleImportPreview> previewBytes(List<int> bytes) async {
    final bundle = _decodeBundle(bytes);
    final resolution = BundleDependencyResolver.resolve(bundle.dependencies);
    return bundle.preview.copyWith(
      resolvedDependencyCount: resolution.resolved.length,
      missingDependencyCount: resolution.missing.length,
    );
  }

  static Future<QdndBundleImportResult> importFile(
    File file, {
    QdndBundleImportOptions options = const QdndBundleImportOptions(),
  }) async {
    return importBytes(await file.readAsBytes(), options: options);
  }

  static Future<QdndBundleImportResult> importBytes(
    List<int> bytes, {
    QdndBundleImportOptions options = const QdndBundleImportOptions(),
  }) async {
    final bundle = _decodeBundle(bytes);
    final diagnostics = QdndBundleDiagnostics();
    final mapper = BundleIdMapper();
    final dependencies = bundle.dependencies;
    final resolution = BundleDependencyResolver.resolve(dependencies);
    final preview = bundle.preview.copyWith(
      resolvedDependencyCount: resolution.resolved.length,
      missingDependencyCount: resolution.missing.length,
    );

    for (final resolved in resolution.resolved) {
      mapper.registerContentId(
        resolved.reference.contentType,
        resolved.reference.localId,
        resolved.resolvedId,
      );
    }

    final embedded = _parseEmbeddedContent(bundle.files, mapper);
    final placeholders = _buildPlaceholders(
      resolution.missing,
      mapper,
      diagnostics,
    );

    for (final missing in resolution.missing) {
      if (missing.contentType == 'spell') continue;
      diagnostics.warning(
        'missing_dependency',
        'Requires local library/source ${missing.sourceName ?? missing.sourceId ?? missing.canonicalName ?? missing.localId} for full ${missing.contentType} content.',
        context: missing.canonicalName ?? missing.localId,
      );
    }

    final characterJson = _jsonMap(bundle.files['character.json']);
    final character = QdndBundleCodec.characterFromJson(characterJson);
    final oldCharacterId = character.id;
    character.id = mapper.mapCharacterId(oldCharacterId);
    character.createdAt = DateTime.now();
    character.updatedAt = DateTime.now();

    _remapCharacterReferences(
      character,
      mapper,
      resolution.resolved,
    );

    final resourceStates = _captureResourceStates(character);
    FeatureService.addFeaturesToCharacter(character);
    final hydration = FeatureHydrationService.hydrateCharacter(character);
    character.features
      ..clear()
      ..addAll(hydration.features);
    _restoreResourceStates(character, resourceStates);
    _mergeHydrationDiagnostics(diagnostics, hydration);
    character.recalculateAC();

    if (embedded.items.isNotEmpty) {
      await StorageService.saveItems(embedded.items);
    }
    if (embedded.spells.isNotEmpty || placeholders.spells.isNotEmpty) {
      await StorageService.saveSpells([
        ...embedded.spells,
        ...placeholders.spells,
      ]);
    }
    if (embedded.features.isNotEmpty) {
      await StorageService.saveFeats(embedded.features);
    }
    if (embedded.races.isNotEmpty) {
      await StorageService.saveRaces(embedded.races);
    }
    if (embedded.classes.isNotEmpty) {
      await StorageService.saveClasses(embedded.classes);
    }
    if (embedded.backgrounds.isNotEmpty) {
      await StorageService.saveBackgrounds(embedded.backgrounds);
    }

    await StorageService.saveCharacter(character);
    await SpellService.reload();
    await ItemService.reload();
    await CharacterDataService.reload();

    return QdndBundleImportResult(
      character: character,
      preview: preview,
      diagnostics: diagnostics.entries,
      embeddedContentCount: embedded.count,
      resolvedDependencyCount: resolution.resolved.length,
      missingDependencyCount: resolution.missing.length,
    );
  }

  static _DecodedBundle _decodeBundle(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.length > _maxFileCount) {
      throw const QdndBundleException(
        'too_many_files',
        'QDND bundle contains too many files.',
      );
    }

    final files = <String, Uint8List>{};
    var totalSize = 0;
    for (final entry in archive) {
      if (entry.isDirectory) continue;
      _validatePath(entry.name);
      if (entry.size > _maxSingleFileBytes) {
        throw QdndBundleException(
          'file_too_large',
          'Bundle file ${entry.name} is too large.',
        );
      }
      totalSize += entry.size;
      if (totalSize > _maxTotalUncompressedBytes) {
        throw const QdndBundleException(
          'bundle_too_large',
          'QDND bundle is too large.',
        );
      }
      if (files.containsKey(entry.name)) {
        throw QdndBundleException(
          'duplicate_path',
          'Bundle contains duplicate path ${entry.name}.',
        );
      }
      files[entry.name] = Uint8List.fromList(entry.readBytes() ?? const []);
    }

    final manifestBytes = files['manifest.json'];
    if (manifestBytes == null) {
      throw const QdndBundleException(
        'missing_manifest',
        'QDND bundle is missing manifest.json.',
      );
    }

    final manifest = _jsonMap(manifestBytes);
    if (manifest['format'] != qdndBundleFormat) {
      throw const QdndBundleException(
        'invalid_format',
        'File is not a QDND bundle.',
      );
    }

    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion != qdndBundleSchemaVersion) {
      throw const QdndBundleException(
        'unsupported_schema',
        'This QDND bundle schema version is not supported.',
      );
    }

    _validateChecksums(manifest, files);

    if (!files.containsKey('character.json')) {
      throw const QdndBundleException(
        'missing_character',
        'QDND bundle is missing character.json.',
      );
    }

    final dependencies = (manifest['dependencies'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => BundleDependencyReference.fromJson(
              Map<String, dynamic>.from(entry),
            ))
        .toList();

    final contentCounts = manifest['contentCounts'] is Map
        ? Map<String, dynamic>.from(manifest['contentCounts'] as Map)
        : const <String, dynamic>{};
    final characterSummary = manifest['character'] is Map
        ? Map<String, dynamic>.from(manifest['character'] as Map)
        : const <String, dynamic>{};
    final classes = (characterSummary['classes'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => entry['name']?.toString() ?? entry['id']?.toString())
        .whereType<String>()
        .toList();

    return _DecodedBundle(
      manifest: manifest,
      files: files,
      dependencies: dependencies,
      preview: QdndBundleImportPreview(
        characterName: characterSummary['name'] as String? ?? 'Unknown',
        level: characterSummary['level'] as int? ?? 1,
        classes: classes,
        embeddedContentCount: contentCounts.values.fold<int>(
          0,
          (sum, value) => sum + (value is int ? value : 0),
        ),
        dependencyCount: dependencies.length,
        dependencies: dependencies,
      ),
    );
  }

  static void _validatePath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.startsWith(r'\') ||
        path.contains(r'\') ||
        path.contains(':') ||
        path.split('/').any((segment) => segment == '..' || segment.isEmpty)) {
      throw QdndBundleException(
        'unsafe_path',
        'Unsafe path in QDND bundle: $path',
      );
    }
  }

  static void _validateChecksums(
    Map<String, dynamic> manifest,
    Map<String, Uint8List> files,
  ) {
    final checksums = manifest['checksums'];
    if (checksums is! Map) return;

    for (final entry in checksums.entries) {
      final path = entry.key.toString();
      if (path == 'manifest.json') continue;
      final bytes = files[path];
      if (bytes == null) {
        throw QdndBundleException(
          'checksum_missing_file',
          'Manifest references missing file $path.',
        );
      }
      final expected = entry.value.toString();
      final actual = QdndBundleHashes.bytesHash(bytes);
      if (actual != expected) {
        throw QdndBundleException(
          'checksum_mismatch',
          'Checksum mismatch for $path.',
        );
      }
    }
  }

  static _ImportedEmbeddedContent _parseEmbeddedContent(
    Map<String, Uint8List> files,
    BundleIdMapper mapper,
  ) {
    final items = <Item>[];
    final spells = <Spell>[];
    final features = <CharacterFeature>[];
    final races = <RaceData>[];
    final classes = <ClassData>[];
    final backgrounds = <BackgroundData>[];

    for (final wrapper in _jsonList(files['content/items.json'], 'items')) {
      final item = Item.fromJson(_wrappedData(wrapper));
      final oldId = item.id;
      item.id = mapper.createContentId('item', oldId);
      items.add(item);
    }

    for (final wrapper in _jsonList(files['content/spells.json'], 'spells')) {
      final spell = Spell.fromJson(_wrappedData(wrapper));
      final oldId = spell.id;
      spell.id = mapper.createContentId('spell', oldId);
      spells.add(spell);
    }

    for (final wrapper
        in _jsonList(files['content/features.json'], 'features')) {
      final feature = CharacterFeature.fromJson(_wrappedData(wrapper));
      final oldId = feature.id;
      feature.id = mapper.createContentId('feature', oldId);
      features.add(feature);
    }

    for (final wrapper in _jsonList(files['content/races.json'], 'races')) {
      final race = QdndBundleCodec.raceFromJson(_wrappedData(wrapper));
      final oldId = race.id;
      final newId = mapper.createContentId('race', oldId);
      races.add(
        RaceData(
          id: newId,
          name: race.name,
          description: race.description,
          speed: race.speed,
          abilityScoreIncreases: race.abilityScoreIncreases,
          languages: race.languages,
          proficiencies: race.proficiencies,
          traits: race.traits,
          subraces: race.subraces,
          size: race.size,
          sourceId: race.sourceId,
        ),
      );
    }

    for (final wrapper in _jsonList(files['content/classes.json'], 'classes')) {
      final classData = QdndBundleCodec.classFromJson(_wrappedData(wrapper));
      final oldId = classData.id;
      final newId = mapper.createContentId('class', oldId);
      classes.add(
        ClassData(
          id: newId,
          name: classData.name,
          description: classData.description,
          hitDie: classData.hitDie,
          primaryAbilities: classData.primaryAbilities,
          savingThrowProficiencies: classData.savingThrowProficiencies,
          armorProficiencies: classData.armorProficiencies,
          weaponProficiencies: classData.weaponProficiencies,
          skillProficiencies: classData.skillProficiencies,
          subclasses: classData.subclasses,
          subclassLevel: classData.subclassLevel,
          spellcasting: classData.spellcasting,
          features: classData.features,
          sourceId: classData.sourceId,
        ),
      );
    }

    for (final wrapper
        in _jsonList(files['content/backgrounds.json'], 'backgrounds')) {
      final background = QdndBundleCodec.backgroundFromJson(
        _wrappedData(wrapper),
      );
      final oldId = background.id;
      final newId = mapper.createContentId('background', oldId);
      backgrounds.add(
        BackgroundData(
          id: newId,
          name: background.name,
          description: background.description,
          skillProficiencies: background.skillProficiencies,
          toolProficiencies: background.toolProficiencies,
          languages: background.languages,
          feature: background.feature,
          equipment: background.equipment,
          sourceId: background.sourceId,
        ),
      );
    }

    return _ImportedEmbeddedContent(
      items: items,
      spells: spells,
      features: features,
      races: races,
      classes: classes,
      backgrounds: backgrounds,
    );
  }

  static _PlaceholderContent _buildPlaceholders(
    List<BundleDependencyReference> missing,
    BundleIdMapper mapper,
    QdndBundleDiagnostics diagnostics,
  ) {
    final spells = <Spell>[];
    for (final dependency in missing) {
      if (dependency.contentType != 'spell') continue;
      final placeholderId = mapper.createContentId('spell', dependency.localId);
      final sourceName =
          dependency.sourceName ?? dependency.sourceId ?? 'external library';
      spells.add(
        Spell(
          id: placeholderId,
          nameEn: dependency.canonicalName ?? dependency.localId,
          nameRu: dependency.canonicalName ?? dependency.localId,
          level: 0,
          school: 'Unknown',
          castingTime: '-',
          range: '-',
          duration: '-',
          concentration: false,
          ritual: false,
          components: const [],
          descriptionEn: 'Requires local content library: $sourceName.',
          descriptionRu: 'Requires local content library: $sourceName.',
          availableToClasses: const [],
        ),
      );
      diagnostics.warning(
        'missing_dependency',
        'Requires local library/source $sourceName for full spell content.',
        context: dependency.canonicalName ?? dependency.localId,
      );
    }
    return _PlaceholderContent(spells: spells);
  }

  static void _remapCharacterReferences(
    Character character,
    BundleIdMapper mapper,
    List<BundleResolvedDependency> resolved,
  ) {
    final resolvedByKey = {
      for (final dependency in resolved) dependency.reference.key: dependency,
    };

    character.knownSpells = character.knownSpells
        .map((id) => mapper.mapContentId('spell', id))
        .toList();
    character.preparedSpells = character.preparedSpells
        .map((id) => mapper.mapContentId('spell', id))
        .toList();
    if (character.concentratingOn != null) {
      character.concentratingOn = mapper.mapContentId(
        'spell',
        character.concentratingOn!,
      );
    }

    character.inventory = character.inventory.map((item) {
      final resolvedItem = resolvedByKey['item:${item.id}']?.entity;
      if (resolvedItem is Item) {
        return _mergeItemState(resolvedItem, item);
      }
      item.id = mapper.mapContentId('item', item.id);
      return item;
    }).toList();

    character.features = character.features.map((feature) {
      final resolvedFeature = resolvedByKey['feature:${feature.id}']?.entity;
      if (resolvedFeature is CharacterFeature) {
        return _mergeFeatureState(resolvedFeature, feature);
      }
      feature.id = mapper.mapContentId('feature', feature.id);
      if (feature.usageCostId != null) {
        feature.usageCostId = mapper.mapContentId(
          'feature',
          feature.usageCostId!,
        );
      }
      if (feature.consumption != null) {
        feature.consumption = FeatureConsumption(
          resourceId: mapper.mapContentId(
            'feature',
            feature.consumption!.resourceId,
          ),
          amount: feature.consumption!.amount,
        );
      }
      feature.options = feature.options
          ?.map((id) => mapper.mapContentId('feature', id))
          .toList();
      return feature;
    }).toList();

    character.race = mapper.mapContentId('race', character.race);
    if (character.background != null) {
      character.background = mapper.mapContentId(
        'background',
        character.background!,
      );
    }
    for (final cls in character.classes) {
      cls.id = mapper.mapContentId('class', cls.id);
    }
  }

  static Item _mergeItemState(Item template, Item state) {
    return Item(
      id: template.id,
      nameEn: template.nameEn,
      nameRu: template.nameRu,
      descriptionEn: template.descriptionEn,
      descriptionRu: template.descriptionRu,
      type: template.type,
      rarity: template.rarity,
      quantity: state.quantity,
      weight: template.weight,
      valueInCopper: template.valueInCopper,
      isEquipped: state.isEquipped,
      isAttuned: state.isAttuned,
      weaponProperties: template.weaponProperties,
      armorProperties: template.armorProperties,
      isMagical: template.isMagical,
      iconName: template.iconName,
      customImagePath: state.customImagePath ?? template.customImagePath,
      sourceId: template.sourceId,
    );
  }

  static CharacterFeature _mergeFeatureState(
    CharacterFeature template,
    CharacterFeature state,
  ) {
    return CharacterFeature(
      id: template.id,
      nameEn: template.nameEn,
      nameRu: template.nameRu,
      descriptionEn: template.descriptionEn,
      descriptionRu: template.descriptionRu,
      type: template.type,
      resourcePool: state.resourcePool ?? template.resourcePool,
      minLevel: template.minLevel,
      associatedClass: template.associatedClass ?? state.associatedClass,
      associatedSubclass:
          template.associatedSubclass ?? state.associatedSubclass,
      requiresRest: template.requiresRest,
      actionEconomy: template.actionEconomy,
      iconName: template.iconName,
      consumption: template.consumption ?? state.consumption,
      sourceId: template.sourceId,
      usageCostId: template.usageCostId ?? state.usageCostId,
      usageInputMode: template.usageInputMode ?? state.usageInputMode,
      options: template.options ?? state.options,
    );
  }

  static Map<String, int> _captureResourceStates(Character character) {
    final states = <String, int>{};
    for (final feature in character.features) {
      if (feature.resourcePool == null) continue;
      states[_resourceKey(feature)] = feature.resourcePool!.currentUses;
    }
    return states;
  }

  static void _restoreResourceStates(
    Character character,
    Map<String, int> states,
  ) {
    for (final feature in character.features) {
      if (feature.resourcePool == null) continue;
      final current = states[_resourceKey(feature)];
      if (current == null) continue;
      feature.resourcePool!.currentUses = current.clamp(
        0,
        feature.resourcePool!.maxUses,
      );
    }
  }

  static String _resourceKey(CharacterFeature feature) {
    final explicit = feature.usageCostId;
    if (explicit != null) return _normalizeId(explicit);

    final id = _normalizeId(feature.id);
    for (final resourceId in _knownResourceIds) {
      if (id == resourceId || id.startsWith('$resourceId-')) {
        return resourceId;
      }
    }

    final name = _normalizeId(feature.nameEn);
    return _resourceNameAliases[name] ?? id;
  }

  static String _normalizeId(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[\s_]+'), '-');
  }

  static void _mergeHydrationDiagnostics(
    QdndBundleDiagnostics diagnostics,
    FeatureHydrationResult hydration,
  ) {
    for (final entry in hydration.diagnostics) {
      switch (entry.severity) {
        case FeatureHydrationDiagnosticSeverity.info:
          diagnostics.info(entry.code, entry.message, context: entry.context);
          break;
        case FeatureHydrationDiagnosticSeverity.warning:
          diagnostics.warning(
            entry.code,
            entry.message,
            context: entry.context,
          );
          break;
      }
    }
  }

  static Map<String, dynamic> _jsonMap(Uint8List? bytes) {
    if (bytes == null) return {};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  static List<Map<String, dynamic>> _jsonList(Uint8List? bytes, String key) {
    final map = _jsonMap(bytes);
    final list = map[key];
    if (list is! List) return [];
    return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static Map<String, dynamic> _wrappedData(Map<String, dynamic> wrapper) {
    final data = wrapper['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return wrapper;
  }

  static const List<String> _knownResourceIds = [
    'channel-divinity',
    'ki',
    'rage',
    'bardic-inspiration',
    'wild-shape',
    'lay-on-hands',
    'divine-sense',
    'action-surge',
    'second-wind',
    'sneak-attack',
    'sorcery-points',
    'arcane-recovery',
    'natural-recovery',
  ];

  static const Map<String, String> _resourceNameAliases = {
    'channel-divinity': 'channel-divinity',
    'ki': 'ki',
    'rage': 'rage',
    'bardic-inspiration': 'bardic-inspiration',
    'wild-shape': 'wild-shape',
    'lay-on-hands': 'lay-on-hands',
    'divine-sense': 'divine-sense',
    'action-surge': 'action-surge',
    'second-wind': 'second-wind',
    'sneak-attack': 'sneak-attack',
    'sorcery-points': 'sorcery-points',
    'font-of-magic': 'sorcery-points',
    'arcane-recovery': 'arcane-recovery',
    'natural-recovery': 'natural-recovery',
  };
}

class _DecodedBundle {
  final Map<String, dynamic> manifest;
  final Map<String, Uint8List> files;
  final List<BundleDependencyReference> dependencies;
  final QdndBundleImportPreview preview;

  const _DecodedBundle({
    required this.manifest,
    required this.files,
    required this.dependencies,
    required this.preview,
  });
}

class _ImportedEmbeddedContent {
  final List<Item> items;
  final List<Spell> spells;
  final List<CharacterFeature> features;
  final List<RaceData> races;
  final List<ClassData> classes;
  final List<BackgroundData> backgrounds;

  const _ImportedEmbeddedContent({
    this.items = const [],
    this.spells = const [],
    this.features = const [],
    this.races = const [],
    this.classes = const [],
    this.backgrounds = const [],
  });

  int get count =>
      items.length +
      spells.length +
      features.length +
      races.length +
      classes.length +
      backgrounds.length;
}

class _PlaceholderContent {
  final List<Spell> spells;

  const _PlaceholderContent({this.spells = const []});
}
