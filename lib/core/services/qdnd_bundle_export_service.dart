import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/background_data.dart';
import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/compendium_source.dart';
import '../models/item.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'character_data_service.dart';
import 'feature_service.dart';
import 'qdnd_bundle_codec.dart';
import 'qdnd_bundle_schema.dart';
import 'spell_service.dart';
import 'storage_service.dart';

class QdndBundleExportService {
  static const String _appVersion = '0.13.0';

  static Future<QdndBundleExportResult> exportCharacter(
    Character character, {
    QdndBundleExportOptions options = const QdndBundleExportOptions(),
  }) async {
    final dependencies = _buildDependencies(character);
    final embedded = _buildEmbeddedContent(character, options);

    final files = <String, List<int>>{
      'character.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'exportPolicy': QdndBundleExportPolicy.snapshotOnly.name,
        'character': QdndBundleCodec.characterToJson(character),
      }),
      'content/items.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'items': embedded.items
            .map(
              (item) => {
                'exportPolicy': QdndBundleExportPolicy.userCreated.name,
                'data': QdndBundleCodec.itemToJson(
                  item,
                  policy: QdndBundleExportPolicy.userCreated,
                ),
              },
            )
            .toList(),
      }),
      'content/spells.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'spells': embedded.spells
            .map(
              (spell) => {
                'exportPolicy': QdndBundleExportPolicy.userCreated.name,
                'data': QdndBundleCodec.spellToJson(
                  spell,
                  policy: QdndBundleExportPolicy.userCreated,
                ),
              },
            )
            .toList(),
      }),
      'content/features.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'features': embedded.features
            .map(
              (feature) => {
                'exportPolicy': QdndBundleExportPolicy.userCreated.name,
                'data': QdndBundleCodec.featureToJson(
                  feature,
                  policy: QdndBundleExportPolicy.userCreated,
                ),
              },
            )
            .toList(),
      }),
      'content/races.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'races': embedded.races
            .map(
              (race) => {
                'exportPolicy': QdndBundleExportPolicy.userCreated.name,
                'data': QdndBundleCodec.raceToJson(
                  race,
                  policy: QdndBundleExportPolicy.userCreated,
                ),
              },
            )
            .toList(),
      }),
      'content/classes.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'classes': embedded.classes
            .map(
              (classData) => {
                'exportPolicy': QdndBundleExportPolicy.userCreated.name,
                'data': QdndBundleCodec.classToJson(
                  classData,
                  policy: QdndBundleExportPolicy.userCreated,
                ),
              },
            )
            .toList(),
      }),
      'content/backgrounds.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'backgrounds': embedded.backgrounds
            .map(
              (background) => {
                'exportPolicy': QdndBundleExportPolicy.userCreated.name,
                'data': QdndBundleCodec.backgroundToJson(
                  background,
                  policy: QdndBundleExportPolicy.userCreated,
                ),
              },
            )
            .toList(),
      }),
      'journal/notes.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'notes': character.journalNotes.map((note) => note.toJson()).toList(),
      }),
      'journal/quests.json': _jsonBytes({
        'schemaVersion': qdndBundleSchemaVersion,
        'quests': character.quests.map((quest) => quest.toJson()).toList(),
      }),
    };

    final checksums = files.map(
      (path, bytes) => MapEntry(path, QdndBundleHashes.bytesHash(bytes)),
    );
    final manifest = {
      'format': qdndBundleFormat,
      'schemaVersion': qdndBundleSchemaVersion,
      'app': {
        'name': 'QD&D',
        'version': _appVersion,
      },
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'exportMode': 'characterBundle',
      'character': {
        'id': character.id,
        'name': character.name,
        'level': character.level,
        'classes': character.classes.map((cls) => cls.toJson()).toList(),
      },
      'contentCounts': {
        'items': embedded.items.length,
        'spells': embedded.spells.length,
        'features': embedded.features.length,
        'races': embedded.races.length,
        'classes': embedded.classes.length,
        'backgrounds': embedded.backgrounds.length,
      },
      'dependencies':
          dependencies.map((dependency) => dependency.toJson()).toList(),
      'files': files.keys.toList(),
      'checksums': checksums,
    };

    files['manifest.json'] = _jsonBytes(manifest);

    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }

    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return QdndBundleExportResult(
      bytes: bytes,
      manifest: manifest,
      embeddedContentCount: embedded.count,
      dependencyCount: dependencies.length,
    );
  }

  static Future<QdndBundleExportResult> exportCharacterToFile(
    Character character,
    File outputFile, {
    QdndBundleExportOptions options = const QdndBundleExportOptions(),
  }) async {
    final result = await exportCharacter(character, options: options);
    await outputFile.writeAsBytes(result.bytes, flush: true);
    return result;
  }

  static List<BundleDependencyReference> _buildDependencies(
    Character character,
  ) {
    final builder = _DependencyBuilder();

    for (final spellId in {
      ...character.knownSpells,
      ...character.preparedSpells,
      if (character.concentratingOn != null) character.concentratingOn!,
    }) {
      final spell = _findSpell(spellId);
      if (spell?.sourceId != null) {
        builder.addSpell(spell!, requiredFor: const ['spells']);
      }
    }

    for (final item in character.inventory) {
      if (item.sourceId != null) {
        builder.addItem(item, requiredFor: const ['inventory']);
      }
    }

    for (final feature in character.features) {
      if (feature.sourceId != null) {
        builder.addFeature(feature, requiredFor: const ['features']);
      }
    }

    final race = _findRace(character.race);
    if (race?.sourceId != null) {
      builder.addRace(race!, requiredFor: const ['identity']);
    }

    final background = character.background == null
        ? null
        : _findBackground(character.background!);
    if (background?.sourceId != null) {
      builder.addBackground(background!, requiredFor: const ['background']);
    }

    for (final cls in character.classes) {
      final classData = _findClass(cls.id);
      if (classData?.sourceId != null) {
        builder.addClass(classData!, requiredFor: const ['progression']);
      }
    }

    return builder.references;
  }

  static _EmbeddedContent _buildEmbeddedContent(
    Character character,
    QdndBundleExportOptions options,
  ) {
    if (!options.includeUserCreatedContent) {
      return const _EmbeddedContent(
        items: [],
        spells: [],
        features: [],
        races: [],
        classes: [],
        backgrounds: [],
      );
    }

    final spells = <Spell>[];
    for (final spellId in {
      ...character.knownSpells,
      ...character.preparedSpells,
      if (character.concentratingOn != null) character.concentratingOn!,
    }) {
      final spell = _findSpell(spellId);
      if (spell != null && spell.sourceId == null) {
        spells.add(spell);
      }
    }

    final items = character.inventory
        .where((item) => item.sourceId == null)
        .map((item) => item)
        .toList();

    final features = character.features
        .where(
          (feature) =>
              feature.sourceId == null &&
              FeatureService.getFeatureById(feature.id) == null,
        )
        .toList();

    return _EmbeddedContent(
      items: _dedupe(items, (item) => item.id),
      spells: _dedupe(spells, (spell) => spell.id),
      features: _dedupe(features, (feature) => feature.id),
      races: const [],
      classes: const [],
      backgrounds: const [],
    );
  }

  static Spell? _findSpell(String id) {
    for (final spell in [
      ...SpellService.getAllSpells(),
      ...StorageService.getAllSpells(),
    ]) {
      if (spell.id == id) return spell;
    }
    return null;
  }

  static RaceData? _findRace(String idOrName) {
    final target = _normalize(idOrName);
    for (final race in CharacterDataService.getAllRaces()) {
      if (_normalize(race.id) == target ||
          _normalize(race.name['en'] ?? '') == target ||
          _normalize(race.name['ru'] ?? '') == target) {
        return race;
      }
    }
    return null;
  }

  static BackgroundData? _findBackground(String idOrName) {
    final target = _normalize(idOrName);
    for (final background in CharacterDataService.getAllBackgrounds()) {
      if (_normalize(background.id) == target ||
          _normalize(background.name['en'] ?? '') == target ||
          _normalize(background.name['ru'] ?? '') == target) {
        return background;
      }
    }
    return null;
  }

  static ClassData? _findClass(String idOrName) {
    final target = _normalize(idOrName);
    for (final classData in CharacterDataService.getAllClasses()) {
      if (_normalize(classData.id) == target ||
          _normalize(classData.name['en'] ?? '') == target ||
          _normalize(classData.name['ru'] ?? '') == target) {
        return classData;
      }
    }
    return null;
  }

  static List<T> _dedupe<T>(Iterable<T> values, String Function(T) keyOf) {
    final seen = <String>{};
    final result = <T>[];
    for (final value in values) {
      if (seen.add(keyOf(value))) {
        result.add(value);
      }
    }
    return result;
  }

  static String _normalize(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '');

  static List<int> _jsonBytes(Map<String, dynamic> json) {
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
  }
}

class _EmbeddedContent {
  final List<Item> items;
  final List<Spell> spells;
  final List<CharacterFeature> features;
  final List<RaceData> races;
  final List<ClassData> classes;
  final List<BackgroundData> backgrounds;

  const _EmbeddedContent({
    required this.items,
    required this.spells,
    required this.features,
    required this.races,
    required this.classes,
    required this.backgrounds,
  });

  int get count =>
      items.length +
      spells.length +
      features.length +
      races.length +
      classes.length +
      backgrounds.length;
}

class _DependencyBuilder {
  final Map<String, BundleDependencyReference> _references = {};
  final Map<String, CompendiumSource> _sources = {
    for (final source in StorageService.getAllSources()) source.id: source,
  };

  List<BundleDependencyReference> get references => _references.values.toList();

  void addSpell(Spell spell, {required List<String> requiredFor}) {
    _add(
      BundleDependencyReference(
        contentType: 'spell',
        localId: spell.id,
        canonicalName: spell.nameEn,
        sourceId: spell.sourceId,
        sourceName: _sources[spell.sourceId]?.name,
        sourceKind: 'externalLibrary',
        contentHash: QdndBundleHashes.entityHash(spell.toJson()),
        ruleset: '5e-2014',
        requiredFor: requiredFor,
      ),
    );
  }

  void addItem(Item item, {required List<String> requiredFor}) {
    _add(
      BundleDependencyReference(
        contentType: 'item',
        localId: item.id,
        canonicalName: item.nameEn,
        sourceId: item.sourceId,
        sourceName: _sources[item.sourceId]?.name,
        sourceKind: 'externalLibrary',
        contentHash: QdndBundleHashes.entityHash(item.toJson()),
        ruleset: '5e-2014',
        requiredFor: requiredFor,
      ),
    );
  }

  void addFeature(
    CharacterFeature feature, {
    required List<String> requiredFor,
  }) {
    _add(
      BundleDependencyReference(
        contentType: 'feature',
        localId: feature.id,
        canonicalName: feature.nameEn,
        sourceId: feature.sourceId,
        sourceName: _sources[feature.sourceId]?.name,
        sourceKind: 'externalLibrary',
        contentHash: QdndBundleHashes.entityHash(
          QdndBundleCodec.featureToJson(feature),
        ),
        ruleset: '5e-2014',
        requiredFor: requiredFor,
      ),
    );
  }

  void addRace(RaceData race, {required List<String> requiredFor}) {
    _add(
      BundleDependencyReference(
        contentType: 'race',
        localId: race.id,
        canonicalName: race.name['en'],
        sourceId: race.sourceId,
        sourceName: _sources[race.sourceId]?.name,
        sourceKind: 'externalLibrary',
        contentHash: QdndBundleHashes.entityHash(
          QdndBundleCodec.raceToJson(race),
        ),
        ruleset: '5e-2014',
        requiredFor: requiredFor,
      ),
    );
  }

  void addClass(ClassData classData, {required List<String> requiredFor}) {
    _add(
      BundleDependencyReference(
        contentType: 'class',
        localId: classData.id,
        canonicalName: classData.name['en'],
        sourceId: classData.sourceId,
        sourceName: _sources[classData.sourceId]?.name,
        sourceKind: 'externalLibrary',
        contentHash: QdndBundleHashes.entityHash(
          QdndBundleCodec.classToJson(classData),
        ),
        ruleset: '5e-2014',
        requiredFor: requiredFor,
      ),
    );
  }

  void addBackground(
    BackgroundData background, {
    required List<String> requiredFor,
  }) {
    _add(
      BundleDependencyReference(
        contentType: 'background',
        localId: background.id,
        canonicalName: background.name['en'],
        sourceId: background.sourceId,
        sourceName: _sources[background.sourceId]?.name,
        sourceKind: 'externalLibrary',
        contentHash: QdndBundleHashes.entityHash(
          QdndBundleCodec.backgroundToJson(background),
        ),
        ruleset: '5e-2014',
        requiredFor: requiredFor,
      ),
    );
  }

  void _add(BundleDependencyReference reference) {
    final existing = _references[reference.key];
    if (existing == null) {
      _references[reference.key] = reference;
      return;
    }

    _references[reference.key] = BundleDependencyReference(
      contentType: existing.contentType,
      localId: existing.localId,
      canonicalName: existing.canonicalName,
      sourceId: existing.sourceId,
      sourceName: existing.sourceName,
      sourceKind: existing.sourceKind,
      contentHash: existing.contentHash,
      ruleset: existing.ruleset,
      requiredFor: {
        ...existing.requiredFor,
        ...reference.requiredFor,
      }.toList(),
      fallbackBehavior: existing.fallbackBehavior,
      exportPolicy: existing.exportPolicy,
    );
  }
}
