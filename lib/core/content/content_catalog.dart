import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/spell.dart';
import '../models/class_data.dart';
import '../models/item.dart';
import '../models/race_data.dart';
import '../models/background_data.dart';
import '../models/character_feature.dart';
import '../services/catalog_definition_signature.dart';
import '../services/fc5_content_identity_service.dart';
import '../services/qdnd_bundle_codec.dart';

/// Common read model above the existing stores. Family membership groups a
/// catalogue, but never authorizes changing a character reference or mechanics.
/// This index's family keys are transient; persistent entity IDs belong to the
/// later, explicit reference migration, not a hash of a translated title.
enum ContentKind { spell, characterClass, item, race, background, feat }

class ContentRecord<T> {
  ContentRecord(
      {required this.kind,
      required this.id,
      required this.sourceId,
      required this.entity,
      required Iterable<String> names,
      required Map<String, dynamic> definition,
      this.edition = 'unknown',
      Iterable<String>? familyAliases})
      : aliases = Set.unmodifiable(
            (familyAliases ?? names).map(normalize).where((n) => n.isNotEmpty)),
        definitionSignature = sha256
            .convert(utf8.encode(CatalogDefinitionSignature.of(definition)))
            .toString();
  final ContentKind kind;
  final String id;
  final String? sourceId;
  final T entity;
  final String edition;
  final Set<String> aliases;
  final String definitionSignature;
  String get recordKey => jsonEncode([kind.name, sourceId, id]);

  /// Exact definition equality includes localized text and explicit edition.
  /// A different translation is a candidate variant until semantic proof exists.
  String get variantKey => sha256
      .convert(
          utf8.encode(jsonEncode([kind.name, edition, definitionSignature])))
      .toString();
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class ContentVariant<T> {
  ContentVariant(Iterable<ContentRecord<T>> records)
      : records = List.unmodifiable(records);
  final List<ContentRecord<T>> records;
  String get key => records.first.variantKey;
  Set<String?> get sources => records.map((r) => r.sourceId).toSet();
}

class ContentFamily<T> {
  ContentFamily(Iterable<ContentRecord<T>> records)
      : records = List.unmodifiable(records);
  final List<ContentRecord<T>> records;
  Set<String> get aliases => records.expand((r) => r.aliases).toSet();
  List<ContentVariant<T>> get variants {
    final groups = <String, List<ContentRecord<T>>>{};
    for (final record in records) {
      groups.putIfAbsent(record.variantKey, () => []).add(record);
    }
    return groups.values.map(ContentVariant<T>.new).toList();
  }

  Set<String?> get sources => records.map((r) => r.sourceId).toSet();
}

class ContentCatalog<T> {
  ContentCatalog(Iterable<ContentRecord<T>> input) {
    records = List.unmodifiable(input);
    if (records.map((r) => r.recordKey).toSet().length != records.length) {
      throw ArgumentError('Duplicate source record identity');
    }
    final parent = List<int>.generate(records.length, (i) => i);
    int root(int n) {
      while (parent[n] != n) {
        parent[n] = parent[parent[n]];
        n = parent[n];
      }
      return n;
    }

    final byAlias = <String, int>{};
    for (var i = 0; i < records.length; i++) {
      for (final alias in records[i].aliases) {
        final key = '${records[i].kind.name}:$alias';
        final previous = byAlias[key];
        if (previous != null) {
          parent[root(i)] = root(previous);
        } else {
          byAlias[key] = i;
        }
      }
    }
    final grouped = <int, List<ContentRecord<T>>>{};
    for (var i = 0; i < records.length; i++) {
      grouped.putIfAbsent(root(i), () => []).add(records[i]);
    }
    families = List.unmodifiable(grouped.values.map(ContentFamily<T>.new));
    for (final family in families) {
      for (final record in family.records) {
        _byRecord[record.recordKey] = family;
      }
    }
  }
  late final List<ContentRecord<T>> records;
  late final List<ContentFamily<T>> families;
  final _byRecord = <String, ContentFamily<T>>{};
  ContentFamily<T>? familyOf(ContentRecord<T> record) =>
      _byRecord[record.recordKey];
  List<ContentRecord<T>> candidates(String original, {ContentKind? kind}) {
    final exact = records
        .where((r) => r.id == original && (kind == null || r.kind == kind))
        .toList();
    if (exact.isNotEmpty) return exact;
    final alias = ContentRecord.normalize(original);
    return records
        .where((r) =>
            (kind == null || r.kind == kind) && r.aliases.contains(alias))
        .toList();
  }

  /// A shared title only yields candidates. Callers cannot silently choose the
  /// first book when different definitions or editions match that title.
  ContentVariant<T>? unambiguousDefinition(String original,
      {ContentKind? kind}) {
    final matches = candidates(original, kind: kind);
    if (matches.isEmpty) return null;
    if (matches.map((r) => r.variantKey).toSet().length != 1) return null;
    return ContentVariant<T>(matches);
  }
}

class ContentRecords {
  static ContentRecord<Spell> spell(Spell s) => ContentRecord(
      kind: ContentKind.spell,
      id: s.id,
      sourceId: s.sourceId,
      entity: s,
      names: [s.nameEn, s.nameRu],
      definition: s.toJson());
  static ContentRecord<ClassData> characterClass(ClassData c) => ContentRecord(
      kind: ContentKind.characterClass,
      id: c.id,
      sourceId: c.sourceId,
      entity: c,
      names: c.name.values,
      familyAliases: [FC5ContentIdentityService.classIdFromClassData(c)],
      edition: c.rulesEdition,
      definition: QdndBundleCodec.classToJson(c));
  static ContentRecord<Item> item(Item i) {
    final data = i.toJson()
      ..remove('instanceId')
      ..remove('quantity')
      ..remove('isEquipped')
      ..remove('isAttuned')
      ..remove('familyId')
      ..remove('variantId');
    return ContentRecord(
        kind: ContentKind.item,
        id: i.id,
        sourceId: i.sourceId,
        entity: i,
        names: [i.nameEn, i.nameRu],
        definition: data);
  }

  static ContentRecord<RaceData> race(RaceData r) => ContentRecord(
      kind: ContentKind.race,
      id: r.id,
      sourceId: r.sourceId,
      entity: r,
      names: r.name.values,
      definition: QdndBundleCodec.raceToJson(r));
  static ContentRecord<BackgroundData> background(BackgroundData b) =>
      ContentRecord(
          kind: ContentKind.background,
          id: b.id,
          sourceId: b.sourceId,
          entity: b,
          names: b.name.values,
          definition: QdndBundleCodec.backgroundToJson(b));
  static ContentRecord<CharacterFeature> feat(CharacterFeature f) =>
      ContentRecord(
          kind: ContentKind.feat,
          id: f.id,
          sourceId: f.sourceId,
          entity: f,
          names: [f.nameEn, f.nameRu],
          definition: f.toJson());
}
