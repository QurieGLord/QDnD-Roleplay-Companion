import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/race_data.dart';
import '../models/class_data.dart';
import '../models/background_data.dart';

class CharacterDataService {
  static List<RaceData>? _races;
  static List<ClassData>? _classes;
  static List<BackgroundData>? _backgrounds;

  static Future<void> loadAllData() async {
    await Future.wait([
      loadRaces(),
      loadClasses(),
      loadBackgrounds(),
    ]);
  }

  static Future<void> loadRaces() async {
    if (_races != null) return;

    try {
      // Load all race files
      final humanJson = await rootBundle.loadString('assets/data/races/human.json');
      final dwarfJson = await rootBundle.loadString('assets/data/races/dwarf.json');
      final elfJson = await rootBundle.loadString('assets/data/races/elf.json');

      _races = [
        RaceData.fromJson(json.decode(humanJson)),
        RaceData.fromJson(json.decode(dwarfJson)),
        RaceData.fromJson(json.decode(elfJson)),
      ];
      print('✅ Loaded ${_races!.length} races');
    } catch (e) {
      print('❌ Failed to load races: $e');
      _races = [];
    }
  }

  static Future<void> loadClasses() async {
    if (_classes != null) return;

    try {
      final paladinJson = await rootBundle.loadString('assets/data/classes/paladin.json');
      final wizardJson = await rootBundle.loadString('assets/data/classes/wizard.json');
      final clericJson = await rootBundle.loadString('assets/data/classes/cleric.json');
      final rogueJson = await rootBundle.loadString('assets/data/classes/rogue.json');

      _classes = [
        ClassData.fromJson(json.decode(paladinJson)),
        ClassData.fromJson(json.decode(wizardJson)),
        ClassData.fromJson(json.decode(clericJson)),
        ClassData.fromJson(json.decode(rogueJson)),
      ];
      print('✅ Loaded ${_classes!.length} classes');
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

      _backgrounds = [
        BackgroundData.fromJson(json.decode(acolyteJson)),
        BackgroundData.fromJson(json.decode(soldierJson)),
        BackgroundData.fromJson(json.decode(folkHeroJson)),
      ];
      print('✅ Loaded ${_backgrounds!.length} backgrounds');
    } catch (e) {
      print('❌ Failed to load backgrounds: $e');
      _backgrounds = [];
    }
  }

  static List<RaceData> getAllRaces() => _races ?? [];
  static List<ClassData> getAllClasses() => _classes ?? [];
  static List<BackgroundData> getAllBackgrounds() => _backgrounds ?? [];

  static RaceData? getRaceById(String id) {
    return _races?.firstWhere((r) => r.id == id, orElse: () => throw Exception('Race not found: $id'));
  }

  static ClassData? getClassById(String id) {
    return _classes?.firstWhere((c) => c.id == id, orElse: () => throw Exception('Class not found: $id'));
  }

  static BackgroundData? getBackgroundById(String id) {
    return _backgrounds?.firstWhere((b) => b.id == id, orElse: () => throw Exception('Background not found: $id'));
  }
}
