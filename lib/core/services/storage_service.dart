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

class StorageService {
  static const String _characterBoxName = 'characters';
  static const String _settingsBoxName = 'settings';
  static const String _itemsBoxName = 'items_library';
  static const String _spellsBoxName = 'spells_library';
  static const String _sourcesBoxName = 'compendium_sources';

  static late Box<Character> _characterBox;
  static late Box _settingsBox;
  static late Box<Item> _itemsBox;
  static late Box<Spell> _spellsBox;
  static late Box<CompendiumSource> _sourcesBox;

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

  // Library Management (Items & Spells)
  static Future<void> saveItems(List<Item> items) async {
    final Map<String, Item> itemsMap = {
      for (var item in items) item.id: item
    };
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
      print('🗑️ StorageService: Deleted ${itemsToDelete.length} items for source $sourceId');
    }

    // 3. Delete associated spells
    final spellsToDelete = _spellsBox.values
        .where((spell) => spell.sourceId == sourceId)
        .map((spell) => spell.id)
        .toList();
    
    if (spellsToDelete.isNotEmpty) {
      await _spellsBox.deleteAll(spellsToDelete);
      print('🗑️ StorageService: Deleted ${spellsToDelete.length} spells for source $sourceId');
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
