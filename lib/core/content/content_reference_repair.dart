import 'dart:convert';
import '../magic/spellbook_state.dart';
import '../models/character.dart';
import '../models/spell.dart';
import '../progression/advancement_history.dart';
import '../services/gameplay_actions_service.dart';
import '../services/spell_service.dart';
import '../services/storage_service.dart';
import 'content_catalog.dart';

/// Safe first migration: missing spell references only. Exact live IDs retain
/// their chosen definition; different same-name variants require a player choice.
/// No resource, class rules, equipment, history event or session entry is replayed.
class ContentReferenceRepair {
  static String? retainedName(Character hero, String id, String locale) {
    final references = hero.spellbookData['contentReferences'];
    final record = references is Map ? references[id] : null;
    if (record is Map) {
      final value = record[locale == 'ru' ? 'nameRu' : 'nameEn'];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    if (id.startsWith('fc5_') ||
        id.length > 80 ||
        RegExp(r'^[0-9a-f-]{32,}$').hasMatch(id)) {
      return null;
    }
    final text = id.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (!RegExp(r'[a-zA-Zа-яА-ЯёЁ]').hasMatch(text)) return null;
    return text[0].toUpperCase() + text.substring(1);
  }

  static Set<String> spellIds(Character c) {
    final book = SpellbookState.read(c.spellbookData);
    return {
      ...c.knownSpells,
      ...c.preparedSpells,
      ...c.spellMasterySpells,
      ...c.signatureSpells,
      ...c.signatureSpellsUsed.keys,
      if (c.concentratingOn != null) c.concentratingOn!,
      ...book.allKnown,
      ...book.all('unrestricted'),
      for (final source in book.sources)
        ...((c.spellbookData['sources'] as Map?)?[source]?['arcanum'] as Map? ??
                {})
            .values
            .cast<String>()
    };
  }

  static Map<String, String> _mapping(
      Character hero, ContentCatalog<Spell> index) {
    final ids = spellIds(hero);
    for (final view in AdvancementHistory.historicalViews(hero)) {
      ids.addAll(spellIds(view));
    }
    final references = hero.spellbookData['contentReferences'] as Map? ?? {};
    final result = <String, String>{};
    for (final id in ids) {
      if (index.records.any((r) => r.id == id)) continue;
      final metadata = references[id] as Map?;
      if (metadata != null && metadata['version'] != 1) continue;
      ContentVariant<Spell>? exact;
      if (metadata?['version'] == 1 && metadata?['variantKey'] is String) {
        final matches = index.records
            .where((r) => r.variantKey == metadata!['variantKey'])
            .toList();
        if (matches.isNotEmpty) exact = ContentVariant(matches);
      } else {
        exact = index.unambiguousDefinition(id, kind: ContentKind.spell);
      }
      if (exact == null) continue;
      final matches = exact.records.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      result[id] = matches.first.id;
    }
    return result;
  }

  /// Points every spell list of [c] from one ID to another.
  static void remapSpells(Character c, Map<String, String> mapping) =>
      _remap(c, mapping);

  static void _remap(Character c, Map<String, String> mapping) {
    String map(String id) => mapping[id] ?? id;
    c.knownSpells = c.knownSpells.map(map).toSet().toList();
    c.preparedSpells = c.preparedSpells.map(map).toSet().toList();
    c.spellMasterySpells = c.spellMasterySpells.map(map).toSet().toList();
    c.signatureSpells = c.signatureSpells.map(map).toSet().toList();
    final used = <String, bool>{};
    for (final e in c.signatureSpellsUsed.entries) {
      used[map(e.key)] = (used[map(e.key)] ?? false) || e.value;
    }
    c.signatureSpellsUsed = used;
    if (c.concentratingOn != null) c.concentratingOn = map(c.concentratingOn!);
    if (c.spellbookData.isNotEmpty) {
      c.spellbookData = SpellbookState.read(c.spellbookData)
          .remap(spell: map, classId: (id) => id);
    }
  }

  static Future<int> repair(Character hero,
          {ContentCatalog<Spell>? catalog,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        final index = catalog ??
                ContentCatalog(
                    SpellService.getAllSpells().map(ContentRecords.spell)),
            mapping = _mapping(hero, index);
        if (mapping.isEmpty) return 0;
        // Clones contain ordinary values only; no mutable spellbook state is shared.
        final before = _SpellReferenceSnapshot(hero), time = hero.updatedAt;
        final history = {
          ...hero.advancementData,
          ...AdvancementHistory.remap(hero, (view) => _remap(view, mapping)),
        };
        try {
          _remap(hero, mapping);
          hero.advancementData = history;
          final book = SpellbookState.read(hero.spellbookData).toJson(),
              refs = Map<String, dynamic>.from(
                  book['contentReferences'] as Map? ?? {});
          for (final e in mapping.entries) {
            final record = index.records.firstWhere((r) => r.id == e.value),
                old =
                    Map<String, dynamic>.from(refs.remove(e.key) as Map? ?? {}),
                current =
                    Map<String, dynamic>.from(refs[e.value] as Map? ?? {});
            refs[e.value] = {
              'version': 1,
              'variantKey': record.variantKey,
              'nameEn': record.entity.nameEn,
              'nameRu': record.entity.nameRu,
              'originalIds': {
                ...?current['originalIds'] as List?,
                ...?old['originalIds'] as List?,
                e.key
              }.toList()
            };
          }
          book['contentReferences'] = refs;
          hero.spellbookData = book;
          await (write ?? StorageService.saveCharacter)(hero);
          return mapping.length;
        } catch (_) {
          before.restore(hero);
          hero.updatedAt = time;
          rethrow;
        }
      });
  static Future<({int repaired, int deferred})> repairStoredCharacters() async {
    final index =
        ContentCatalog(SpellService.getAllSpells().map(ContentRecords.spell));
    var repaired = 0, deferred = 0;
    for (final hero in StorageService.getAllCharacters()) {
      try {
        repaired += await repair(hero, catalog: index);
      } catch (_) {
        deferred++;
      }
    }
    return (repaired: repaired, deferred: deferred);
  }
}

class _SpellReferenceSnapshot {
  _SpellReferenceSnapshot(Character c)
      : known = List.of(c.knownSpells),
        prepared = List.of(c.preparedSpells),
        mastery = List.of(c.spellMasterySpells),
        signature = List.of(c.signatureSpells),
        used = Map.of(c.signatureSpellsUsed),
        concentration = c.concentratingOn,
        book = _clone(c.spellbookData),
        history = _clone(c.advancementData);
  final List<String> known, prepared, mastery, signature;
  final Map<String, bool> used;
  final String? concentration;
  final Map<String, dynamic> book, history;
  static Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  void restore(Character c) {
    c.knownSpells = known;
    c.preparedSpells = prepared;
    c.spellMasterySpells = mastery;
    c.signatureSpells = signature;
    c.signatureSpellsUsed = used;
    c.concentratingOn = concentration;
    c.spellbookData = book;
    c.advancementData = history;
  }
}
