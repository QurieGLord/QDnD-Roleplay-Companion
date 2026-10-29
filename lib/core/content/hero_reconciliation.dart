import '../magic/spellbook_state.dart';
import '../models/character.dart';
import '../models/class_data.dart';
import '../models/spell.dart';
import '../services/character_data_service.dart';
import '../services/fc5_content_identity_service.dart';
import '../services/spell_service.dart';
import '../services/storage_service.dart';
import 'content_catalog.dart';
import 'content_reference_repair.dart';
import 'shelf_choices.dart';

/// One entry of an imported hero that the libraries know in several
/// differing versions: what the file said, the versions, and the one taken.
class HeroAmbiguity {
  HeroAmbiguity.spell(this.original, this.family, this.chosen)
      : kind = ContentKind.spell,
        classIndex = null;
  HeroAmbiguity.characterClass(
      this.original, this.family, this.chosen, int this.classIndex)
      : kind = ContentKind.characterClass;

  final ContentKind kind;

  /// The name as the hero's file wrote it.
  final String original;
  final ContentFamily family;

  /// The hero's class entry this ambiguity is about (classes only).
  final int? classIndex;

  /// The record the hero refers to now.
  ContentRecord chosen;

  /// The versions, each by its lead record.
  List<ContentRecord> get versions =>
      [for (final v in family.variants) leadRecord(v.records)];
}

/// C03 · settles an FC5 hero against the libraries (see
/// docs/CONTENT_MODEL_C01_C04_2026-10-29.md). The file names spells and
/// classes; a name the libraries know in one version takes it quietly, one
/// with several differing versions takes the lead (as the shelf setting
/// picks it, never the first book loaded) and is listed for the player.
/// The original name stays in the reference's provenance.
abstract final class HeroReconciliation {
  static List<HeroAmbiguity> settle(Character hero,
      {required Map<String, List<String>> spellNames,
      ContentCatalog<Spell>? spells,
      ContentCatalog<ClassData>? classes}) {
    final found = <HeroAmbiguity>[];
    final spellIndex = spells ??
        ContentCatalog(SpellService.getAllSpells().map(ContentRecords.spell));
    final mapping = <String, String>{};
    final provenance = <String, Map<String, dynamic>>{};
    final seen = <String>{};
    for (final entry in spellNames.entries) {
      for (final name in entry.value) {
        final alias = ContentRecord.normalize(name);
        final matches = spellIndex.records
            .where((r) => r.aliases.contains(alias))
            .toList();
        if (matches.isEmpty) continue;
        final family = spellIndex.familyOf(matches.first)!;
        final variants = matches.map((r) => r.variantKey).toSet();
        final lead = leadRecord(matches);
        mapping[entry.key] = lead.id;
        provenance[lead.id] = _provenance(lead, [
          ...?provenance[lead.id]?['originalNames'] as List?,
          name,
        ]);
        if (variants.length > 1 && seen.add(lead.id)) {
          found.add(HeroAmbiguity.spell(name, family, lead));
        }
      }
    }
    if (mapping.isNotEmpty) {
      ContentReferenceRepair.remapSpells(
          hero, {for (final e in mapping.entries) if (e.key != e.value) e.key: e.value});
      _writeProvenance(hero, provenance);
    }

    final classIndex = classes ??
        ContentCatalog(CharacterDataService.getAllClasses()
            .map(ContentRecords.characterClass));
    for (final (i, entry) in hero.classes.indexed) {
      final alias = ContentRecord.normalize(
          FC5ContentIdentityService.canonicalClassId(entry.name));
      final family = classIndex.families
          .where((f) => f.aliases.contains(alias))
          .firstOrNull;
      if (family == null) continue;
      final lead = leadRecord(family.records, usable: (c) => c.rulesPlayable);
      entry.id = lead.id;
      if (family.variants.length > 1) {
        found.add(HeroAmbiguity.characterClass(entry.name, family, lead, i));
      }
    }
    return found;
  }

  /// Points the hero at another version of an ambiguous entry.
  static void choose(Character hero, HeroAmbiguity ambiguity,
      ContentRecord record) {
    final before = ambiguity.chosen;
    if (before.id == record.id && before.sourceId == record.sourceId) return;
    if (ambiguity.kind == ContentKind.characterClass) {
      hero.classes[ambiguity.classIndex!].id = record.id;
    } else {
      ContentReferenceRepair.remapSpells(hero, {before.id: record.id});
      final book = SpellbookState.read(hero.spellbookData).toJson();
      final refs =
          Map<String, dynamic>.from(book['contentReferences'] as Map? ?? {});
      final old = Map<String, dynamic>.from(refs.remove(before.id) as Map? ?? {});
      refs[record.id] = _provenance(
          record, old['originalNames'] as List? ?? [ambiguity.original]);
      hero.spellbookData = book..['contentReferences'] = refs;
    }
    ambiguity.chosen = record;
  }

  /// Saves the player's choices; on failure the hero keeps the leads.
  static Future<void> apply(Character hero, List<(HeroAmbiguity, ContentRecord)> choices,
      {Future<void> Function(Character)? write}) async {
    for (final (a, record) in choices) {
      choose(hero, a, record);
    }
    await (write ?? StorageService.saveCharacter)(hero);
  }

  static Map<String, dynamic> _provenance(ContentRecord record, List names) {
    final spell = record.entity as Spell;
    return {
      'version': 1,
      'variantKey': record.variantKey,
      'nameEn': spell.nameEn,
      'nameRu': spell.nameRu,
      'origin': 'fc5',
      'originalNames': {...names.cast<String>()}.toList(),
    };
  }

  static void _writeProvenance(
      Character hero, Map<String, Map<String, dynamic>> provenance) {
    // References live in the spellbook data, as restored spells' do; an
    // empty book reads as the same empty book with them added.
    final book = SpellbookState.read(hero.spellbookData).toJson();
    final refs =
        Map<String, dynamic>.from(book['contentReferences'] as Map? ?? {})
          ..addAll(provenance);
    hero.spellbookData = book..['contentReferences'] = refs;
  }
}
