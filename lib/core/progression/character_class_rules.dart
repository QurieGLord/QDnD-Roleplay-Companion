import 'dart:convert';
import '../models/character_class.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../services/character_data_service.dart';
import '../services/feature_service.dart';
import '../services/qdnd_bundle_codec.dart';
import '../services/qdnd_bundle_schema.dart';
import 'progression_catalog_stamp.dart';

/// A character-owned rule definition. Reading never installs, migrates, or saves.
class CharacterClassRules {
  CharacterClassRules._(this.data, this.definitions, this.snapshot);
  final ClassData data;
  final List<CharacterFeature> definitions;
  final Map<String, dynamic> snapshot;
  CharacterFeature? feature(String id) =>
      definitions.where((f) => f.id == id).firstOrNull;
  List<CharacterFeature> atLevel(int level, String? subclass) => definitions
      .where((f) =>
          !f.isOptional &&
          !f.id.startsWith('primal-path-improvement-') &&
          f.minLevel == level &&
          FeatureService.matchesSubclass(f.associatedSubclass, subclass))
      .toList();

  factory CharacterClassRules.capture(ClassData data) {
    final byId = <String, CharacterFeature>{};
    final byVersion = <String, CharacterFeature>{};
    void add(CharacterFeature f) {
      byId[f.id] = f;
      byVersion['${f.id}:${f.minLevel}:${f.associatedSubclass ?? ''}'] = f;
    }

    // Imported standalone classes cannot inherit a built-in class by name.
    if (data.sourceId == null && data.rulesMetadata['origin'] == 'bundled') {
      for (final f in FeatureService.allFeatures) {
        if (f.associatedClass != null &&
            FeatureService.classKey(f.associatedClass!) == data.id) {
          add(f);
        }
      }
    }
    for (final f in data.features.values.expand((v) => v)) {
      add(f);
    }
    final pending = byVersion.values.toList();
    for (var i = 0; i < pending.length; i++) {
      for (final id in pending[i].options ?? <String>[]) {
        if (byId.containsKey(id)) continue;
        final option = FeatureService.getFeatureById(id);
        if (option != null) {
          add(option);
          pending.add(option);
        }
      }
    }
    final payload = <String, dynamic>{
      'version': 1,
      'definition': QdndBundleCodec.classToJson(data),
      'features': byVersion.values.map((f) => f.toJson()).toList(),
    };
    return CharacterClassRules.fromSnapshot(
        {...payload, 'digest': ProgressionCatalogStamp.fingerprint(payload)});
  }

  factory CharacterClassRules.fromSnapshot(Map<String, dynamic> value) {
    // Deep isolation also normalizes Hive's nested Map<dynamic, dynamic>.
    final snapshot =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
    final payload = Map<String, dynamic>.from(snapshot)..remove('digest');
    if (snapshot['version'] != 1 ||
        snapshot['definition'] is! Map ||
        snapshot['features'] is! List ||
        snapshot['digest'] != ProgressionCatalogStamp.fingerprint(payload)) {
      throw const FormatException('The saved class rules are invalid.');
    }
    return CharacterClassRules._(
      QdndBundleCodec.classFromJson(
          Map<String, dynamic>.from(snapshot['definition'] as Map)),
      (snapshot['features'] as List)
          .map((f) =>
              CharacterFeature.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
      snapshot,
    );
  }

  factory CharacterClassRules.resolve(CharacterClass entry) {
    if (entry.rulesSnapshot != null) {
      return CharacterClassRules.fromSnapshot(entry.rulesSnapshot!);
    }
    final data = CharacterDataService.getClassById(entry.id);
    if (data == null) throw StateError('Missing class definition.');
    return CharacterClassRules.capture(data);
  }

  /// Changes declared metadata only; never recaptures features from a live book.
  CharacterClassRules withMetadata(Map<String, dynamic> metadata) {
    final payload =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot)) as Map)
          ..remove('digest');
    final definition = Map<String, dynamic>.from(payload['definition'] as Map);
    definition['rulesMetadata'] = metadata;
    payload['definition'] = definition;
    return CharacterClassRules.fromSnapshot(
        {...payload, 'digest': ProgressionCatalogStamp.fingerprint(payload)});
  }

  /// Personal mechanics survive transfer; reference-only source descriptions
  /// retain the bundle's established policy and require the local source text.
  Map<String, dynamic> forExport() {
    Map<String, dynamic> featureJson(CharacterFeature f) =>
        QdndBundleCodec.featureToJson(f,
            policy: f.sourceId == null
                ? QdndBundleExportPolicy.snapshotOnly
                : QdndBundleExportPolicy.referenceOnly);
    final definition = QdndBundleCodec.classToJson(data,
        policy: data.sourceId == null
            ? QdndBundleExportPolicy.snapshotOnly
            : QdndBundleExportPolicy.referenceOnly);
    definition.remove('sourceDefinition');
    definition['features'] = data.features.map((level, features) =>
        MapEntry('$level', features.map(featureJson).toList()));
    final payload = <String, dynamic>{
      'version': 1,
      'originDigest': snapshot['originDigest'] ?? snapshot['digest'],
      'definition': definition,
      'features': definitions.map(featureJson).toList()
    };
    return {...payload, 'digest': ProgressionCatalogStamp.fingerprint(payload)};
  }

  void attachTo(CharacterClass entry) {
    entry.rulesSnapshot =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot)) as Map);
  }
}
