// ignore_for_file: avoid_print
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/character.dart';
import '../models/character_class.dart';
import '../models/ability_scores.dart';
import '../models/spell.dart';
import '../models/character_spell.dart';
import '../models/character_feature.dart';
import '../models/item.dart';
import '../models/combat_state.dart';
import '../models/death_saves.dart';
import '../models/condition.dart';
import '../models/journal_note.dart';
import '../models/quest.dart';
import '../models/compendium_source.dart';
import '../models/race_data.dart';
import '../models/class_data.dart';
import '../models/background_data.dart';
import 'catalog_install_journal.dart';
import 'catalog_mutation_queue.dart';

class StorageService {
  static const String _characterBoxName = 'characters';
  static const String _settingsBoxName = 'settings';
  static const String _itemsBoxName = 'items_library';
  static const String _spellsBoxName = 'spells_library';
  static const String _sourcesBoxName = 'compendium_sources';
  static const String _racesBoxName = 'races_library';
  static const String _classesBoxName = 'classes_library';
  static const String _backgroundsBoxName = 'backgrounds_library';
  static const String _featsBoxName = 'feats_library';
  static const String _fc5SourceFingerprintPrefix = 'fc5_source_fingerprint:';

  static late Box<Character> _characterBox;
  static late Box _settingsBox;
  static late Box<Item> _itemsBox;
  static late Box<Spell> _spellsBox;
  static late Box<CompendiumSource> _sourcesBox;
  static late Box<RaceData> _racesBox;
  static late Box<ClassData> _classesBox;
  static late Box<BackgroundData> _backgroundsBox;
  static late Box<CharacterFeature> _featsBox;

  static void _registerAdapter<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  static CatalogInstallJournal get _installJournal => CatalogInstallJournal(
      _settingsBox,
      {
        'items': _itemsBox,
        'spells': _spellsBox,
        'races': _racesBox,
        'classes': _classesBox,
        'backgrounds': _backgroundsBox,
        'feats': _featsBox,
        'settings': _settingsBox,
        'sources': _sourcesBox,
      },
      writeBatch: _writeCatalogBatch);
  static Future<void> _writeCatalogBatch(
          String name, Map<String, dynamic> values) =>
      switch (name) {
        'items' => _itemsBox.putAll(values.cast<String, Item>()),
        'spells' => _spellsBox.putAll(values.cast<String, Spell>()),
        'races' => _racesBox.putAll(values.cast<String, RaceData>()),
        'classes' => _classesBox.putAll(values.cast<String, ClassData>()),
        'backgrounds' =>
          _backgroundsBox.putAll(values.cast<String, BackgroundData>()),
        'feats' => _featsBox.putAll(values.cast<String, CharacterFeature>()),
        'sources' =>
          _sourcesBox.putAll(values.cast<String, CompendiumSource>()),
        'settings' => _settingsBox.putAll(values),
        _ => throw StateError('Unknown catalog box.'),
      };
  static bool _visibleSource(String? sourceId) {
    if (sourceId == null) return true;
    final pending = _settingsBox.get(CatalogInstallJournal.key);
    return pending is! Map ||
        pending['state'] == 'committed' ||
        pending['sourceId'] != sourceId;
  }

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    _registerAdapter(CharacterAdapter());
    _registerAdapter(CharacterClassAdapter());
    _registerAdapter(AbilityScoresAdapter());
    _registerAdapter(SpellAdapter());
    _registerAdapter(CharacterSpellAdapter());
    _registerAdapter(CharacterFeatureAdapter());
    _registerAdapter(ResourcePoolAdapter());
    _registerAdapter(FeatureTypeAdapter());
    _registerAdapter(RecoveryTypeAdapter());
    _registerAdapter(FeatureConsumptionAdapter());

    // Register Item adapters
    _registerAdapter(ItemAdapter());
    _registerAdapter(ItemTypeAdapter());
    _registerAdapter(ItemRarityAdapter());
    _registerAdapter(WeaponPropertiesAdapter());
    _registerAdapter(DamageTypeAdapter());
    _registerAdapter(ArmorPropertiesAdapter());
    _registerAdapter(ArmorTypeAdapter());

    // Register Compendium adapters
    _registerAdapter(CompendiumSourceAdapter());
    _registerAdapter(RaceDataAdapter());
    _registerAdapter(SubraceDataAdapter());
    _registerAdapter(ClassDataAdapter());
    _registerAdapter(SubclassDataAdapter());
    _registerAdapter(ArmorProficienciesAdapter());
    _registerAdapter(WeaponProficienciesAdapter());
    _registerAdapter(SkillProficienciesAdapter());
    _registerAdapter(SpellcastingInfoAdapter());
    _registerAdapter(BackgroundDataAdapter());
    _registerAdapter(BackgroundFeatureAdapter());

    // Register Combat adapters
    _registerAdapter(CombatStateAdapter());
    _registerAdapter(CombatLogEntryAdapter());
    _registerAdapter(CombatLogTypeAdapter());
    _registerAdapter(DeathSavesAdapter());
    _registerAdapter(ConditionTypeAdapter());

    // Register Journal adapters
    _registerAdapter(JournalNoteAdapter());
    _registerAdapter(NoteCategoryAdapter());
    _registerAdapter(QuestAdapter());
    _registerAdapter(QuestObjectiveAdapter());
    _registerAdapter(QuestStatusAdapter());

    // Open boxes
    _characterBox = await Hive.openBox<Character>(_characterBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _itemsBox = await Hive.openBox<Item>(_itemsBoxName);
    _spellsBox = await Hive.openBox<Spell>(_spellsBoxName);
    _sourcesBox = await Hive.openBox<CompendiumSource>(_sourcesBoxName);
    _racesBox = await Hive.openBox<RaceData>(_racesBoxName);
    _classesBox = await Hive.openBox<ClassData>(_classesBoxName);
    _backgroundsBox = await Hive.openBox<BackgroundData>(_backgroundsBoxName);
    _featsBox = await Hive.openBox<CharacterFeature>(_featsBoxName);
    await _installJournal.recover();
  }

  // Character CRUD operations
  static Future<void> saveCharacter(Character character) async {
    character.updatedAt = DateTime.now();
    await _characterBox.put(character.id, character);
  }

  static Character? getCharacter(String id) {
    return _characterBox.get(id);
  }

  static List<Character> getAllCharacters() {
    return _characterBox.values.toList();
  }

  static Future<void> deleteCharacter(String id) async {
    await _characterBox.delete(id);
  }

  static Stream<BoxEvent> watchCharacters() {
    return _characterBox.watch();
  }

  // Library Management (Items, Spells, Races, Classes, Backgrounds, Feats)
  static Future<void> saveItems(List<Item> items) async {
    final Map<String, Item> itemsMap = {for (var item in items) item.id: item};
    await _itemsBox.putAll(itemsMap);
  }

  static List<Item> getAllItems() {
    return _itemsBox.values
        .where((item) => _visibleSource(item.sourceId))
        .toList();
  }

  static Future<void> saveSpells(List<Spell> spells) async {
    final Map<String, Spell> spellsMap = {
      for (var spell in spells) spell.id: spell
    };
    await _spellsBox.putAll(spellsMap);
  }

  static List<Spell> getAllSpells() {
    return _spellsBox.values
        .where((spell) => _visibleSource(spell.sourceId))
        .toList();
  }

  static Future<void> saveRaces(List<RaceData> races) async {
    final Map<String, RaceData> racesMap = {
      for (var race in races) race.id: race
    };
    await _racesBox.putAll(racesMap);
  }

  static List<RaceData> getAllRaces() {
    return _racesBox.values
        .where((race) => _visibleSource(race.sourceId))
        .toList();
  }

  static Future<void> saveClasses(List<ClassData> classes) async {
    final Map<String, ClassData> classesMap = {
      for (var charClass in classes) charClass.id: charClass
    };
    await _classesBox.putAll(classesMap);
  }

  static List<ClassData> getAllClasses() {
    return _classesBox.values.where((c) => _visibleSource(c.sourceId)).toList();
  }

  static Future<void> saveBackgrounds(List<BackgroundData> backgrounds) async {
    final Map<String, BackgroundData> bgMap = {
      for (var bg in backgrounds) bg.id: bg
    };
    await _backgroundsBox.putAll(bgMap);
  }

  static List<BackgroundData> getAllBackgrounds() {
    return _backgroundsBox.values
        .where((b) => _visibleSource(b.sourceId))
        .toList();
  }

  static Future<void> saveFeats(List<CharacterFeature> feats) async {
    final Map<String, CharacterFeature> featsMap = {
      for (var feat in feats) feat.id: feat
    };
    await _featsBox.putAll(featsMap);
  }

  static List<CharacterFeature> getAllFeats() {
    return _featsBox.values.where((f) => _visibleSource(f.sourceId)).toList();
  }

  // Compendium Source Management
  static Future<void> saveSource(CompendiumSource source) async {
    await _sourcesBox.put(source.id, source);
  }

  static List<CompendiumSource> getAllSources() {
    return _sourcesBox.values
        .where((source) => _visibleSource(source.id))
        .toList();
  }

  static Stream<BoxEvent> watchSources() {
    return _sourcesBox.watch();
  }

  static ValueListenable<Box<CompendiumSource>> getSourcesListenable() {
    return _sourcesBox.listenable();
  }

  static Future<void> installSource(
          {required CompendiumSource source,
          required String fingerprint,
          List<Item> items = const [],
          List<Spell> spells = const [],
          List<RaceData> races = const [],
          List<ClassData> classes = const [],
          List<BackgroundData> backgrounds = const [],
          List<CharacterFeature> feats = const [],
          Future<void> Function(String)? afterWrite}) =>
      CatalogMutationQueue.run(() async {
        await _installJournal.recover();
        final previousSource = getSourceIdForFingerprint(fingerprint);
        if (previousSource != null && _sourcesBox.containsKey(previousSource)) {
          throw StateError('This source content is already installed.');
        }
        void validate<T>(
            List<T> values, String Function(T) id, String? Function(T) owner) {
          final ids = <String>{};
          for (final value in values) {
            if (owner(value) != source.id ||
                id(value).trim().isEmpty ||
                !ids.add(id(value))) {
              throw ArgumentError(
                  'Every source definition needs a unique ID and matching source ownership.');
            }
          }
        }

        validate(items, (v) => v.id, (v) => v.sourceId);
        validate(spells, (v) => v.id, (v) => v.sourceId);
        validate(races, (v) => v.id, (v) => v.sourceId);
        validate(classes, (v) => v.id, (v) => v.sourceId);
        validate(backgrounds, (v) => v.id, (v) => v.sourceId);
        validate(feats, (v) => v.id, (v) => v.sourceId);
        if (_sourcesBox.containsKey(source.id)) {
          throw StateError('An existing source needs an explicit update.');
        }
        final writes = <String, Map<String, dynamic>>{
          if (items.isNotEmpty)
            'items': {for (final item in items) item.id: item},
          if (spells.isNotEmpty)
            'spells': {for (final spell in spells) spell.id: spell},
          if (races.isNotEmpty)
            'races': {for (final race in races) race.id: race},
          if (classes.isNotEmpty) 'classes': {for (final c in classes) c.id: c},
          if (backgrounds.isNotEmpty)
            'backgrounds': {for (final b in backgrounds) b.id: b},
          if (feats.isNotEmpty) 'feats': {for (final f in feats) f.id: f},
          'settings': {'$_fc5SourceFingerprintPrefix$fingerprint': source.id},
          'sources': {source.id: source},
        };
        final boxes = _installJournal.boxes;
        for (final write in writes.entries
            .where((e) => e.key != 'settings' && e.key != 'sources')) {
          if (write.value.keys.any(boxes[write.key]!.containsKey)) {
            throw StateError(
                'Source entity ID collides with installed content. An explicit update is required.');
          }
        }
        await _installJournal.install(source.id, writes,
            afterWrite: afterWrite);
      });

  static Future<void> deleteSource(String sourceId) =>
      CatalogMutationQueue.run(() async {
        await _installJournal.recover();
        await _deleteSource(sourceId);
      });
  static Future<void> _deleteSource(String sourceId) async {
    await deleteSourceFingerprintsForSource(sourceId);

    // 1. Delete source record
    await _sourcesBox.delete(sourceId);

    // 2. Delete associated items
    final itemsToDelete = _itemsBox.values
        .where((item) => item.sourceId == sourceId)
        .map((item) => item.id)
        .toList();

    if (itemsToDelete.isNotEmpty) {
      await _itemsBox.deleteAll(itemsToDelete);
      print(
          '🗑️ StorageService: Deleted ${itemsToDelete.length} items for source $sourceId');
    }

    // 3. Delete associated spells
    final spellsToDelete = _spellsBox.values
        .where((spell) => spell.sourceId == sourceId)
        .map((spell) => spell.id)
        .toList();

    if (spellsToDelete.isNotEmpty) {
      await _spellsBox.deleteAll(spellsToDelete);
      print(
          '🗑️ StorageService: Deleted ${spellsToDelete.length} spells for source $sourceId');
    }

    // 4. Delete associated races
    final racesToDelete = _racesBox.values
        .where((race) => race.sourceId == sourceId)
        .map((race) => race.id)
        .toList();

    if (racesToDelete.isNotEmpty) {
      await _racesBox.deleteAll(racesToDelete);
      print(
          '🗑️ StorageService: Deleted ${racesToDelete.length} races for source $sourceId');
    }

    // 5. Delete associated classes
    final classesToDelete = _classesBox.values
        .where((cls) => cls.sourceId == sourceId)
        .map((cls) => cls.id)
        .toList();

    if (classesToDelete.isNotEmpty) {
      await _classesBox.deleteAll(classesToDelete);
      print(
          '🗑️ StorageService: Deleted ${classesToDelete.length} classes for source $sourceId');
    }

    // 6. Delete associated backgrounds
    final backgroundsToDelete = _backgroundsBox.values
        .where((bg) => bg.sourceId == sourceId)
        .map((bg) => bg.id)
        .toList();

    if (backgroundsToDelete.isNotEmpty) {
      await _backgroundsBox.deleteAll(backgroundsToDelete);
      print(
          '🗑️ StorageService: Deleted ${backgroundsToDelete.length} backgrounds for source $sourceId');
    }

    // 7. Delete associated feats
    final featsToDelete = _featsBox.values
        .where((feat) => feat.sourceId == sourceId)
        .map((feat) => feat.id)
        .toList();

    if (featsToDelete.isNotEmpty) {
      await _featsBox.deleteAll(featsToDelete);
      print(
          '🗑️ StorageService: Deleted ${featsToDelete.length} feats for source $sourceId');
    }
  }

  static Future<void> deleteSources(Iterable<String> sourceIds) async {
    for (final sourceId in sourceIds) {
      await deleteSource(sourceId);
    }
  }

  // Settings
  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  static String? getSourceIdForFingerprint(String fingerprint) {
    return _settingsBox.get(
      '$_fc5SourceFingerprintPrefix$fingerprint',
    ) as String?;
  }

  static Future<void> saveSourceFingerprint(
    String fingerprint,
    String sourceId,
  ) async {
    await _settingsBox.put(
      '$_fc5SourceFingerprintPrefix$fingerprint',
      sourceId,
    );
  }

  static Future<void> deleteSourceFingerprint(String fingerprint) async {
    await _settingsBox.delete('$_fc5SourceFingerprintPrefix$fingerprint');
  }

  static Future<void> deleteSourceFingerprintsForSource(String sourceId) async {
    final keys = _settingsBox.keys
        .where((key) =>
            key is String &&
            key.startsWith(_fc5SourceFingerprintPrefix) &&
            _settingsBox.get(key) == sourceId)
        .toList();
    if (keys.isNotEmpty) {
      await _settingsBox.deleteAll(keys);
    }
  }

  // Clear all data (for testing)
  static Future<void> clearAll() async {
    await _characterBox.clear();
    await _settingsBox.clear();
  }
}
