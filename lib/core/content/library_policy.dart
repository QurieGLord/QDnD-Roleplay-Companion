import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// Which side keeps an entry that both the built-in book and the player's
/// own libraries define (matched by English name within one kind).
enum LibraryOverlap {
  /// The built-in, hand-checked entry stays; the player's books add only
  /// what the built-in one lacks.
  base,

  /// The player's entry stays and replaces the built-in one.
  mine,
}

/// The built-in SRD 2014 book on the shelf and how it meets the player's
/// libraries. Only what the shelf lists is affected — pickers and browsers.
/// Lookups by ID (a hero's spells, items, race) keep resolving everything,
/// so turning the book off or preferring other entries never breaks a hero.
abstract final class LibraryPolicy {
  static const _srdKey = 'library_srd_2014_enabled';
  static const _overlapKey = 'library_overlap';

  /// Bumps on every change; the content services rebuild their lists.
  static final revision = ValueNotifier<int>(0);

  static dynamic _read(String key, dynamic fallback) {
    try {
      return StorageService.getSetting(key, defaultValue: fallback);
    } catch (_) {
      return fallback;
    }
  }

  static bool get srdEnabled => _read(_srdKey, true) != false;

  static LibraryOverlap get overlap =>
      _read(_overlapKey, 'base') == 'mine' ? LibraryOverlap.mine : LibraryOverlap.base;

  static Future<void> setSrdEnabled(bool value) async {
    await StorageService.saveSetting(_srdKey, value);
    revision.value++;
  }

  static Future<void> setOverlap(LibraryOverlap value) async {
    await StorageService.saveSetting(_overlapKey, value.name);
    revision.value++;
  }

  /// A name reduced to letters and digits, for matching across books.
  static String key(String name) => name
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

  /// What the shelf lists of one kind: the built-in entries and the
  /// player's, with overlaps settled by [overlap].
  static List<T> listed<T>(
      List<T> builtIn, List<T> mine, String Function(T) name) {
    if (!srdEnabled) return mine;
    if (mine.isEmpty) return builtIn;
    if (overlap == LibraryOverlap.base) {
      final taken = {for (final e in builtIn) key(name(e))};
      return [...builtIn, ...mine.where((e) => !taken.contains(key(name(e))))];
    }
    final taken = {for (final e in mine) key(name(e))};
    return [...builtIn.where((e) => !taken.contains(key(name(e)))), ...mine];
  }

  /// How many of the player's entries the built-in book already covers.
  static int overlapping<T>(
      List<T> builtIn, List<T> mine, String Function(T) name) {
    final taken = {for (final e in builtIn) key(name(e))};
    return mine.where((e) => taken.contains(key(name(e)))).length;
  }
}
