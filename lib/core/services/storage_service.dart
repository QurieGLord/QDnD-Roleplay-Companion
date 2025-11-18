import 'package:hive_flutter/hive_flutter.dart';
import '../models/character.dart';
import '../models/ability_scores.dart';
import '../models/spell.dart';
import '../models/character_spell.dart';
import '../models/character_feature.dart';

class StorageService {
  static const String _characterBoxName = 'characters';
  static const String _settingsBoxName = 'settings';

  static late Box<Character> _characterBox;
  static late Box _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(CharacterAdapter());
    Hive.registerAdapter(AbilityScoresAdapter());
    Hive.registerAdapter(SpellAdapter());
    Hive.registerAdapter(CharacterSpellAdapter());
    Hive.registerAdapter(CharacterFeatureAdapter());
    Hive.registerAdapter(ResourcePoolAdapter());
    Hive.registerAdapter(FeatureTypeAdapter());
    Hive.registerAdapter(RecoveryTypeAdapter());

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
