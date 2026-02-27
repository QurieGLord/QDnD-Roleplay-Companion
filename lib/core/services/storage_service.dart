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

  static late Box<Character> _characterBox;
  static late Box _settingsBox;
  static late Box<Item> _itemsBox;
  static late Box<Spell> _spellsBox;
  static late Box<CompendiumSource> _sourcesBox;
  static late Box<RaceData> _racesBox;
  static late Box<ClassData> _classesBox;
  static late Box<BackgroundData> _backgroundsBox;
  static late Box<CharacterFeature> _featsBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(CharacterAdapter());
    Hive.registerAdapter(CharacterClassAdapter());
    Hive.registerAdapter(AbilityScoresAdapter());
    Hive.registerAdapter(SpellAdapter());
    Hive.registerAdapter(CharacterSpellAdapter());
    Hive.registerAdapter(CharacterFeatureAdapter());
    Hive.registerAdapter(ResourcePoolAdapter());
    Hive.registerAdapter(FeatureTypeAdapter());
    Hive.registerAdapter(RecoveryTypeAdapter());
    Hive.registerAdapter(FeatureConsumptionAdapter());

    // Register Item adapters
    Hive.registerAdapter(ItemAdapter());
    Hive.registerAdapter(ItemTypeAdapter());
    Hive.registerAdapter(ItemRarityAdapter());
    Hive.registerAdapter(WeaponPropertiesAdapter());
    Hive.registerAdapter(DamageTypeAdapter());
    Hive.registerAdapter(ArmorPropertiesAdapter());
    Hive.registerAdapter(ArmorTypeAdapter());

    // Register Compendium adapters
    Hive.registerAdapter(CompendiumSourceAdapter());
    Hive.registerAdapter(RaceDataAdapter());
    Hive.registerAdapter(SubraceDataAdapter());
    Hive.registerAdapter(ClassDataAdapter());
    Hive.registerAdapter(SubclassDataAdapter());
    Hive.registerAdapter(ArmorProficienciesAdapter());
    Hive.registerAdapter(WeaponProficienciesAdapter());
    Hive.registerAdapter(SkillProficienciesAdapter());
    Hive.registerAdapter(SpellcastingInfoAdapter());
    Hive.registerAdapter(BackgroundDataAdapter());
    Hive.registerAdapter(BackgroundFeatureAdapter());

    // Register Combat adapters
    Hive.registerAdapter(CombatStateAdapter());
    Hive.registerAdapter(CombatLogEntryAdapter());
    Hive.registerAdapter(CombatLogTypeAdapter());
    Hive.registerAdapter(DeathSavesAdapter());
    Hive.registerAdapter(ConditionTypeAdapter());

    // Register Journal adapters
    Hive.registerAdapter(JournalNoteAdapter());
    Hive.registerAdapter(NoteCategoryAdapter());
    Hive.registerAdapter(QuestAdapter());
    Hive.registerAdapter(QuestObjectiveAdapter());
    Hive.registerAdapter(QuestStatusAdapter());

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
    return _itemsBox.values.toList();
  }

  static Future<void> saveSpells(List<Spell> spells) async {
    final Map<String, Spell> spellsMap = {
      for (var spell in spells) spell.id: spell
    };
    await _spellsBox.putAll(spellsMap);
  }

  static List<Spell> getAllSpells() {
    return _spellsBox.values.toList();
  }

  static Future<void> saveRaces(List<RaceData> races) async {
    final Map<String, RaceData> racesMap = {
      for (var race in races) race.id: race
    };
    await _racesBox.putAll(racesMap);
  }

  static List<RaceData> getAllRaces() {
    return _racesBox.values.toList();
  }

  static Future<void> saveClasses(List<ClassData> classes) async {
    final Map<String, ClassData> classesMap = {
      for (var charClass in classes) charClass.id: charClass
    };
    await _classesBox.putAll(classesMap);
  }

  static List<ClassData> getAllClasses() {
    return _classesBox.values.toList();
  }

  static Future<void> saveBackgrounds(List<BackgroundData> backgrounds) async {
    final Map<String, BackgroundData> bgMap = {
      for (var bg in backgrounds) bg.id: bg
    };
    await _backgroundsBox.putAll(bgMap);
  }

  static List<BackgroundData> getAllBackgrounds() {
    return _backgroundsBox.values.toList();
  }

  static Future<void> saveFeats(List<CharacterFeature> feats) async {
    final Map<String, CharacterFeature> featsMap = {
      for (var feat in feats) feat.id: feat
    };
    await _featsBox.putAll(featsMap);
  }

  static List<CharacterFeature> getAllFeats() {
    return _featsBox.values.toList();
  }

  // Compendium Source Management
  static Future<void> saveSource(CompendiumSource source) async {
    await _sourcesBox.put(source.id, source);
  }

  static List<CompendiumSource> getAllSources() {
    return _sourcesBox.values.toList();
  }

  static Stream<BoxEvent> watchSources() {
    return _sourcesBox.watch();
  }

  static ValueListenable<Box<CompendiumSource>> getSourcesListenable() {
    return _sourcesBox.listenable();
  }

  static Future<void> deleteSource(String sourceId) async {
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

  // Settings
  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  // Clear all data (for testing)
  static Future<void> clearAll() async {
    await _characterBox.clear();
    await _settingsBox.clear();
  }
}
