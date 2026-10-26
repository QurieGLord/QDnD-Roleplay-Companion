// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/spell.dart';
import '../content/library_policy.dart';
import 'storage_service.dart';

class SpellService {
  static int _catalogRevision = 0;
  static int get catalogRevision => _catalogRevision;
  static List<Spell>? _allSpells;
  static Set<String> _builtInIds = {};

  static Future<void> loadSpells() async {
    if (_allSpells != null) return;

    _allSpells = [];

    // 1. Load Standard Assets
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/spells/srd_spells.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final assetSpells = jsonList.map((json) => Spell.fromJson(json)).toList();
      _allSpells!.addAll(assetSpells);
      _builtInIds = {for (final s in assetSpells) s.id};
      print('✅ Loaded ${assetSpells.length} spells from assets');
    } catch (e) {
      print('❌ Failed to load asset spells: $e');
    }

    // 2. Load Custom Spells from Storage
    try {
      final storedSpells = StorageService.getAllSpells();
      if (storedSpells.isNotEmpty) {
        _allSpells!.addAll(storedSpells);
        print('✅ Loaded ${storedSpells.length} spells from storage');
      }
    } catch (e) {
      print('❌ Failed to load stored spells: $e');
    }

    print('✨ Total spells loaded: ${_allSpells!.length}');
  }

  static Future<void> reload() async {
    _catalogRevision++;
    print('🔄 SpellService: Reloading spells...');
    _allSpells = null;
    await loadSpells();
  }

  static List<Spell> getAllSpells() {
    return _allSpells ?? [];
  }

  /// The built-in SRD 2014 spells.
  static List<Spell> builtInSpells() =>
      getAllSpells().where((s) => _builtInIds.contains(s.id)).toList();

  /// Spells from the player's libraries.
  static List<Spell> librarySpells() =>
      getAllSpells().where((s) => !_builtInIds.contains(s.id)).toList();

  static String _name(Spell s) => s.nameEn.isEmpty ? s.nameRu : s.nameEn;

  /// What the shelf offers for choosing: the built-in book (unless turned
  /// off) and the player's libraries, overlaps settled by [LibraryPolicy].
  /// Lookups by ID still see every spell.
  static List<Spell> shelfSpells() =>
      LibraryPolicy.listed(builtInSpells(), librarySpells(), _name);

  static Spell? getSpellById(String id) {
    try {
      return _allSpells?.firstWhere((spell) => spell.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<Spell> getSpellsForClass(String className) {
    return shelfSpells().where((spell) {
          return spell.availableToClasses
              .any((c) => c.toLowerCase() == className.toLowerCase());
        }).toList();
  }

  static List<Spell> getSpellsByLevel(int level) {
    return _allSpells?.where((spell) => spell.level == level).toList() ?? [];
  }

  static List<Spell> searchSpells(String query) {
    final lowerQuery = query.toLowerCase();
    return shelfSpells().where((spell) {
          return spell.nameEn.toLowerCase().contains(lowerQuery) ||
              spell.nameRu.toLowerCase().contains(lowerQuery);
        }).toList();
  }

  static List<Spell> filterSpells({
    String? className,
    int? level,
    String? school,
    bool? concentration,
    bool? ritual,
  }) {
    var filtered = _allSpells ?? [];

    if (className != null) {
      filtered = filtered.where((spell) {
        return spell.availableToClasses
            .any((c) => c.toLowerCase() == className.toLowerCase());
      }).toList();
    }

    if (level != null) {
      filtered = filtered.where((spell) => spell.level == level).toList();
    }

    if (school != null) {
      filtered = filtered.where((spell) => spell.school == school).toList();
    }

    if (concentration != null) {
      filtered = filtered
          .where((spell) => spell.concentration == concentration)
          .toList();
    }

    if (ritual != null) {
      filtered = filtered.where((spell) => spell.ritual == ritual).toList();
    }

    return filtered;
  }
}
