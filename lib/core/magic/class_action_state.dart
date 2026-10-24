import 'dart:convert';
import '../models/character.dart';
import 'magic_slots.dart';

/// Versioned class action cooldowns, retained by the existing native magic
/// payload. Successful Intervention has a player-managed seven-day cooldown;
/// a failed attempt resets on a long rest, not on reopening its panel.
class ClassActionState {
  static Map<String, dynamic> _read(Character hero) {
    final raw = hero.magicData['classActions'];
    if (raw == null) return {'version': 1};
    if (raw is! Map ||
        raw['version'] != 1 ||
        (raw.containsKey('interventionAttempted') &&
            raw['interventionAttempted'] is! bool)) {
      throw const FormatException('Unsupported class action state.');
    }
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
  }

  static bool interventionAttempted(Character hero) =>
      _read(hero)['interventionAttempted'] == true;
  static void setInterventionAttempted(Character hero, bool value) {
    final state = _read(hero);
    // Preserve a legacy Pact-only reserve before adding a typed payload.
    MagicSlots.read(hero).applyTo(hero);
    hero.magicData = {
      ...hero.magicData,
      'classActions': {...state, 'interventionAttempted': value}
    };
  }

  static Object? companionData(Character hero) => _read(hero)['companion'];
  static void setCompanion(Character hero, Map<String, dynamic> companion) {
    final state = _read(hero);
    MagicSlots.read(hero).applyTo(hero);
    hero.magicData = {
      ...hero.magicData,
      'classActions': {...state, 'companion': companion}
    };
  }

  /// The beast of the current Wild Shape beyond its name and hit points:
  /// armour, speed, attacks and challenge, as the player recorded them.
  static Map<String, dynamic>? beast(Character hero) {
    final raw = _read(hero)['beast'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static void setBeast(Character hero, Map<String, dynamic>? beast) {
    final state = _read(hero);
    MagicSlots.read(hero).applyTo(hero);
    hero.magicData = {
      ...hero.magicData,
      'classActions': {...state, 'beast': beast}
    };
  }

  /// Forms the player shaped by hand, newest first, for one-tap reuse.
  static List<Map<String, dynamic>> forms(Character hero) {
    final raw = _read(hero)['forms'];
    if (raw is! List) return const [];
    return [for (final f in raw) if (f is Map) Map<String, dynamic>.from(f)];
  }

  static void setForms(Character hero, List<Map<String, dynamic>> forms) {
    final state = _read(hero);
    MagicSlots.read(hero).applyTo(hero);
    hero.magicData = {
      ...hero.magicData,
      'classActions': {...state, 'forms': forms}
    };
  }

  static void longRest(Character hero) {
    if (hero.magicData['classActions'] != null) {
      setInterventionAttempted(hero, false);
    }
  }
}
