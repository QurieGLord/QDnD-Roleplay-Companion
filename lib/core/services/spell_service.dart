import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/spell.dart';

class SpellService {
  static List<Spell>? _allSpells;

  static Future<void> loadSpells() async {
    if (_allSpells != null) return;

    try {
      final jsonString = await rootBundle.loadString('assets/data/spells/paladin_spells.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _allSpells = jsonList.map((json) => Spell.fromJson(json)).toList();
      print('✅ Loaded ${_allSpells!.length} spells');
    } catch (e) {
      print('❌ Failed to load spells: $e');
      _allSpells = [];
    }
  }

  static List<Spell> getAllSpells() {
    return _allSpells ?? [];
  }

  static Spell? getSpellById(String id) {
    try {
      return _allSpells?.firstWhere((spell) => spell.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<Spell> getSpellsForClass(String className) {
    return _allSpells?.where((spell) {
      return spell.availableToClasses.any((c) => c.toLowerCase() == className.toLowerCase());
    }).toList() ?? [];
  }

  static List<Spell> getSpellsByLevel(int level) {
    return _allSpells?.where((spell) => spell.level == level).toList() ?? [];
  }

  static List<Spell> searchSpells(String query) {
    final lowerQuery = query.toLowerCase();
    return _allSpells?.where((spell) {
      return spell.nameEn.toLowerCase().contains(lowerQuery) ||
          spell.nameRu.toLowerCase().contains(lowerQuery);
    }).toList() ?? [];
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
        return spell.availableToClasses.any((c) => c.toLowerCase() == className.toLowerCase());
      }).toList();
    }

    if (level != null) {
      filtered = filtered.where((spell) => spell.level == level).toList();
    }

    if (school != null) {
      filtered = filtered.where((spell) => spell.school == school).toList();
    }

    if (concentration != null) {
      filtered = filtered.where((spell) => spell.concentration == concentration).toList();
    }

    if (ritual != null) {
      filtered = filtered.where((spell) => spell.ritual == ritual).toList();
    }

    return filtered;
  }
}
