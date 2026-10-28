import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../services/character_data_service.dart';
import '../services/item_service.dart';
import '../services/spell_service.dart';
import '../services/storage_service.dart';
import 'content_catalog.dart';

/// C01 · persistent identities of catalogue entities (see
/// docs/CONTENT_MODEL_C01_C04_2026-10-29.md).
///
/// The read index ([ContentCatalog]) regroups records by name on every
/// build, so its family keys are transient. This registry gives each family
/// a lasting ID and each exact definition a lasting variant ID, and records
/// every change (a new family, a merge when a book bridges two names, a split
/// when the bridge goes away) in a journal.
///
/// It is an overlay: stores, source records, their old IDs and heroes are
/// never rewritten here. A variant that loses its last book stays registered,
/// so a reference to it still resolves to its family.
class ContentIdentityRegistry {
  ContentIdentityRegistry._(this._families, this._variants, this._journal);

  factory ContentIdentityRegistry.empty() =>
      ContentIdentityRegistry._({}, {}, []);

  /// Version of the stored shape; a newer one is kept untouched, not read.
  static const version = 1;
  static const _journalLimit = 400;

  final Map<String, _Family> _families;
  final Map<String, _Variant> _variants;
  final List<Map<String, dynamic>> _journal;

  /// Variant IDs follow the exact definition (edition + full definition
  /// signature), so the same book yields the same ID on every device.
  static String variantIdOf(ContentRecord record) =>
      'v1:${record.kind.name}:${record.variantKey.substring(0, 24)}';

  /// The family a stored family ID stands for now (merges are followed).
  String? resolveFamily(String familyId) {
    var id = familyId;
    for (var hops = 0; hops < 32; hops++) {
      final f = _families[id];
      if (f == null) return null;
      if (f.mergedInto == null) return id;
      id = f.mergedInto!;
    }
    return null;
  }

  String? familyOfVariant(String variantId) {
    final v = _variants[variantId];
    return v == null ? null : resolveFamily(v.familyId);
  }

  /// The family of a source record, by its kind, source and record ID.
  String? familyOfRecord(ContentKind kind, String? sourceId, String id) {
    final key = jsonEncode([kind.name, sourceId, id]);
    for (final v in _variants.values) {
      if (v.records.contains(key)) return resolveFamily(v.familyId);
    }
    return null;
  }

  String? variantOfRecord(ContentKind kind, String? sourceId, String id) {
    final key = jsonEncode([kind.name, sourceId, id]);
    for (final entry in _variants.entries) {
      if (entry.value.records.contains(key)) return entry.key;
    }
    return null;
  }

  Set<String> variantsOfFamily(String familyId) {
    final family = resolveFamily(familyId);
    return {
      for (final e in _variants.entries)
        if (resolveFamily(e.value.familyId) == family) e.key
    };
  }

  List<Map<String, dynamic>> get journal => List.unmodifiable(_journal);
  int get liveFamilies =>
      _families.values.where((f) => f.mergedInto == null).length;
  int get variantCount => _variants.length;
  int liveFamiliesOf(ContentKind kind) => _families.values
      .where((f) => f.kind == kind.name && f.mergedInto == null)
      .length;

  /// Brings the registry in line with a freshly built catalogue of one kind.
  /// Returns true when anything changed.
  bool reconcile(ContentKind kind, List<ContentFamily> computed,
      {DateTime? now, String Function()? newId}) {
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    final mint = newId ?? () => const Uuid().v4().replaceAll('-', '').substring(0, 16);
    var changed = false;
    // The first sight of a kind is one 'seed' entry, not a create per family,
    // so a whole library arriving at once does not flush the journal.
    final seeding = !_families.values.any((f) => f.kind == kind.name);
    var seeded = 0;
    void log(String op, Map<String, dynamic> data) {
      _journal.add({'at': at, 'op': op, 'kind': kind.name, ...data});
      changed = true;
    }

    // Claims of existing families on each computed family, by shared variants.
    final claims = <int, Map<String, int>>{};
    for (var i = 0; i < computed.length; i++) {
      final family = computed[i];
      final counts = <String, int>{};
      for (final variant in family.variants) {
        final known = _variants[variantIdOf(variant.records.first)];
        if (known == null) continue;
        final owner = resolveFamily(known.familyId);
        if (owner != null) counts[owner] = (counts[owner] ?? 0) + 1;
      }
      claims[i] = counts;
    }
    // A split: one stored family now spread over several computed ones. The
    // computed family that holds most of it keeps the ID; the others get new
    // IDs and the journal remembers where they came from.
    final keeper = <String, int>{};
    for (final entry in claims.entries) {
      for (final owner in entry.value.entries) {
        final best = keeper[owner.key];
        if (best == null ||
            owner.value > (claims[best]![owner.key] ?? 0) ||
            owner.value == (claims[best]![owner.key] ?? 0) &&
                entry.key < best) {
          keeper[owner.key] = entry.key;
        }
      }
    }
    for (var i = 0; i < computed.length; i++) {
      final family = computed[i];
      final owners = [
        for (final o in claims[i]!.keys)
          if (keeper[o] == i) o
      ]..sort();
      String id;
      if (owners.isEmpty) {
        id = 'f1:${kind.name}:${mint()}';
        _families[id] = _Family(kind.name, {}, null, at);
        final from = claims[i]!.keys.toList()..sort();
        if (seeding) {
          seeded++;
          changed = true;
        } else {
          log(from.isEmpty ? 'create' : 'split',
              {'family': id, if (from.isNotEmpty) 'from': from});
        }
      } else {
        // A merge: two stored families joined by a bridging name. The oldest
        // survives, so references made first keep their direct ID.
        owners.sort((a, b) => _families[a]!.createdAt.compareTo(_families[b]!.createdAt));
        id = owners.first;
        for (final other in owners.skip(1)) {
          _families[other]!.mergedInto = id;
          log('merge', {'family': other, 'into': id});
        }
      }
      final f = _families[id]!;
      final aliases = family.aliases;
      if (!f.aliases.containsAll(aliases)) {
        f.aliases.addAll(aliases);
        changed = true;
      }
      for (final variant in family.variants) {
        final vid = variantIdOf(variant.records.first);
        final keys = variant.records.map((r) => r.recordKey).toSet();
        final known = _variants[vid];
        if (known == null) {
          _variants[vid] = _Variant(id, keys);
          if (owners.isNotEmpty) log('variant', {'variant': vid, 'family': id});
        } else {
          if (resolveFamily(known.familyId) != id) {
            log('move', {'variant': vid, 'from': known.familyId, 'to': id});
            known.familyId = id;
          }
          if (!known.records.containsAll(keys)) {
            known.records.addAll(keys);
            changed = true;
          }
        }
      }
    }
    if (seeded > 0) log('seed', {'families': seeded});
    if (_journal.length > _journalLimit) {
      _journal.removeRange(0, _journal.length - _journalLimit);
    }
    return changed;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'families': {
          for (final e in _families.entries) e.key: e.value.toJson()
        },
        'variants': {
          for (final e in _variants.entries) e.key: e.value.toJson()
        },
        'journal': _journal,
      };

  /// Reads a stored registry. Unknown versions are refused rather than
  /// guessed at; the caller keeps the stored value as it is.
  static ContentIdentityRegistry? fromJson(Object? raw) {
    if (raw is! Map) return ContentIdentityRegistry.empty();
    if (raw['version'] != version) return null;
    final families = <String, _Family>{
      for (final e in (raw['families'] as Map? ?? {}).entries)
        e.key as String: _Family.fromJson(e.value as Map)
    };
    final variants = <String, _Variant>{
      for (final e in (raw['variants'] as Map? ?? {}).entries)
        e.key as String: _Variant.fromJson(e.value as Map)
    };
    final journal = [
      for (final j in raw['journal'] as List? ?? const [])
        Map<String, dynamic>.from(j as Map)
    ];
    return ContentIdentityRegistry._(families, variants, journal);
  }
}

class _Family {
  _Family(this.kind, this.aliases, this.mergedInto, this.createdAt);
  final String kind;
  final Set<String> aliases;
  String? mergedInto;
  final String createdAt;
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'aliases': aliases.toList()..sort(),
        if (mergedInto != null) 'mergedInto': mergedInto,
        'createdAt': createdAt,
      };
  static _Family fromJson(Map m) => _Family(
      m['kind'] as String,
      {...(m['aliases'] as List? ?? const []).cast<String>()},
      m['mergedInto'] as String?,
      m['createdAt'] as String? ?? '');
}

class _Variant {
  _Variant(this.familyId, this.records);
  String familyId;

  /// Source records that carry this exact definition, ever seen.
  final Set<String> records;
  Map<String, dynamic> toJson() =>
      {'family': familyId, 'records': records.toList()..sort()};
  static _Variant fromJson(Map m) => _Variant(m['family'] as String,
      {...(m['records'] as List? ?? const []).cast<String>()});
}

/// Keeps the stored registry in step with the libraries: run after the
/// catalogues load and after a book is installed or removed.
abstract final class ContentIdentityService {
  static const storageKey = 'content_identity';
  static ContentIdentityRegistry? _current;
  static Future<void> _queue = Future.value();

  /// The registry as last reconciled (empty until the first refresh).
  static ContentIdentityRegistry get current =>
      _current ?? ContentIdentityRegistry.empty();

  /// Refreshes run one after another, so a launch refresh and a library
  /// change never write the stored registry over each other.
  static Future<void> refresh() => _queue = _queue.then((_) async {
        // An overlay: a failure here never stands in the way of the
        // libraries or the heroes; the next refresh tries again.
        try {
          await _refresh();
        } catch (_) {}
      });

  static Future<void> _refresh() async {
    final stored = StorageService.getSetting(storageKey);
    final decoded = stored is String ? jsonDecode(stored) : stored;
    final registry = ContentIdentityRegistry.fromJson(decoded);
    // A registry written by a newer app is left as it is.
    if (registry == null) return;
    var changed = stored == null;
    final catalogs = <ContentKind, List<ContentFamily>>{
      ContentKind.spell:
          ContentCatalog(SpellService.getAllSpells().map(ContentRecords.spell)).families,
      ContentKind.characterClass: ContentCatalog(CharacterDataService.getAllClasses()
              .map(ContentRecords.characterClass))
          .families,
      ContentKind.item:
          ContentCatalog(ItemService.getAllItems().map(ContentRecords.item)).families,
      ContentKind.race: ContentCatalog(
              CharacterDataService.getAllRaces().map(ContentRecords.race))
          .families,
      ContentKind.background: ContentCatalog(CharacterDataService
              .getAllBackgrounds()
              .map(ContentRecords.background))
          .families,
      ContentKind.feat: ContentCatalog(
              CharacterDataService.getAllFeats().map(ContentRecords.feat))
          .families,
    };
    for (final e in catalogs.entries) {
      changed = registry.reconcile(e.key, e.value) || changed;
    }
    _current = registry;
    if (changed) {
      await StorageService.saveSetting(storageKey, jsonEncode(registry.toJson()));
    }
  }
}
