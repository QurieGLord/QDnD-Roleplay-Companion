import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/race_data.dart';
import '../models/class_data.dart';
import '../models/background_data.dart';
import '../models/character_feature.dart';
import 'storage_service.dart';

class CharacterDataService {
  static List<RaceData>? _races;
  static List<ClassData>? _classes;
  static List<BackgroundData>? _backgrounds;
  static List<CharacterFeature>? _feats;

  static Future<void> loadAllData() async {
    await Future.wait([
      loadRaces(),
      loadClasses(),
      loadBackgrounds(),
      loadFeats(),
    ]);
  }

  static Future<void> reload() async {
    _races = null;
    _classes = null;
    _backgrounds = null;
    _feats = null;
    await loadAllData();
  }

  static Future<void> loadRaces() async {
    if (_races != null) return;

    try {
      // Load asset races
      final humanJson = await rootBundle.loadString('assets/data/races/human.json');
      final dwarfJson = await rootBundle.loadString('assets/data/races/dwarf.json');
      final elfJson = await rootBundle.loadString('assets/data/races/elf.json');

      final assetRaces = [
        RaceData.fromJson(json.decode(humanJson)),
        RaceData.fromJson(json.decode(dwarfJson)),
        RaceData.fromJson(json.decode(elfJson)),
      ];

      // Load storage races
      final storageRaces = StorageService.getAllRaces();
      
      _races = [...assetRaces, ...storageRaces];
      print('✅ Loaded ${_races!.length} races (${assetRaces.length} assets + ${storageRaces.length} custom)');
    } catch (e) {
      print('❌ Failed to load races: $e');
      _races = [];
    }
  }

  static Future<void> loadClasses() async {
    if (_classes != null) return;

    try {
      // Load asset classes
      final paladinJson = await rootBundle.loadString('assets/data/classes/paladin.json');
      final wizardJson = await rootBundle.loadString('assets/data/classes/wizard.json');
      final clericJson = await rootBundle.loadString('assets/data/classes/cleric.json');
      final rogueJson = await rootBundle.loadString('assets/data/classes/rogue.json');

      final assetClasses = [
        ClassData.fromJson(json.decode(paladinJson)),
        ClassData.fromJson(json.decode(wizardJson)),
        ClassData.fromJson(json.decode(clericJson)),
        ClassData.fromJson(json.decode(rogueJson)),
      ];

      // Load storage classes
      final storageClasses = StorageService.getAllClasses();

      _classes = [...assetClasses, ...storageClasses];
      print('✅ Loaded ${_classes!.length} classes (${assetClasses.length} assets + ${storageClasses.length} custom)');
    } catch (e) {
      print('❌ Failed to load classes: $e');
      _classes = [];
    }
  }

  static Future<void> loadBackgrounds() async {
    if (_backgrounds != null) return;

    try {
      final acolyteJson = await rootBundle.loadString('assets/data/backgrounds/acolyte.json');
      final soldierJson = await rootBundle.loadString('assets/data/backgrounds/soldier.json');
      final folkHeroJson = await rootBundle.loadString('assets/data/backgrounds/folk_hero.json');

      final assetBackgrounds = [
        BackgroundData.fromJson(json.decode(acolyteJson)),
        BackgroundData.fromJson(json.decode(soldierJson)),
        BackgroundData.fromJson(json.decode(folkHeroJson)),
      ];

      final storageBackgrounds = StorageService.getAllBackgrounds();

      _backgrounds = [...assetBackgrounds, ...storageBackgrounds];
      print('✅ Loaded ${_backgrounds!.length} backgrounds (${assetBackgrounds.length} assets + ${storageBackgrounds.length} custom)');
    } catch (e) {
      print('❌ Failed to load backgrounds: $e');
      _backgrounds = [];
    }
  }

  static Future<void> loadFeats() async {
    if (_feats != null) return;

    try {
      // Load storage feats
      _feats = StorageService.getAllFeats();
      print('✅ Loaded ${_feats!.length} feats (custom)');
    } catch (e) {
      print('❌ Failed to load feats: $e');
      _feats = [];
    }
  }

  static List<RaceData> getAllRaces() => _races ?? [];
  static List<ClassData> getAllClasses() => _classes ?? [];
  static List<BackgroundData> getAllBackgrounds() => _backgrounds ?? [];
  static List<CharacterFeature> getAllFeats() => _feats ?? [];

  static String _normalizeId(String input) {
    final lower = input.toLowerCase().trim();
    // Simple mapping for common Russian names
    switch (lower) {
      // Classes
      case 'паладин': return 'paladin';
      case 'воин': return 'fighter';
      case 'варвар': return 'barbarian';
      case 'монах': return 'monk';
      case 'плут': return 'rogue';
      case 'следопыт': return 'ranger';
      case 'друид': return 'druid';
      case 'жрец': return 'cleric';
      case 'волшебник': return 'wizard';
      case 'чародей': return 'sorcerer';
      case 'колдун': return 'warlock';
      case 'бард': return 'bard';
      case 'изобретатель': return 'artificer';
      // Races
      case 'человек': return 'human';
      case 'эльф': return 'elf';
      case 'дварф': return 'dwarf';
      case 'гном': return 'gnome';
      case 'полурослик': return 'halfling';
      case 'драконорожденный': return 'dragonborn';
      case 'тифлинг': return 'tiefling';
      case 'полуорк': return 'half_orc';
      case 'полуэльф': return 'half_elf';
      // Backgrounds
      case 'прислужник': return 'acolyte';
      case 'солдат': return 'soldier';
      case 'народный герой': return 'folk_hero';
      default: return lower;
    }
  }

  static RaceData? getRaceById(String idOrName) {
    if (_races == null) return null;
    final targetId = _normalizeId(idOrName);
    return _races!.firstWhere(
      (r) => r.id == targetId || r.name.values.any((val) => val.toLowerCase() == targetId), 
      orElse: () => throw Exception('Race not found: $idOrName')
    );
  }

  static ClassData? getClassById(String idOrName) {
    if (_classes == null) return null;
    final targetId = _normalizeId(idOrName);
    return _classes!.firstWhere(
      (c) => c.id == targetId || c.name.values.any((val) => val.toLowerCase() == targetId), 
      orElse: () => throw Exception('Class not found: $idOrName')
    );
  }

  static BackgroundData? getBackgroundById(String idOrName) {
    if (_backgrounds == null) return null;
    final targetId = _normalizeId(idOrName);
    return _backgrounds!.firstWhere(
      (b) => b.id == targetId || b.name.values.any((val) => val.toLowerCase() == targetId), 
      orElse: () => throw Exception('Background not found: $idOrName')
    );
  }
}
