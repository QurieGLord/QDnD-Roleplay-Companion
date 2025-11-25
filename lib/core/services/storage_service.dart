import 'package:hive_flutter/hive_flutter.dart';
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

class StorageService {
  static const String _characterBoxName = 'characters';
  static const String _settingsBoxName = 'settings';

  static late Box<Character> _characterBox;
  static late Box _settingsBox;

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
