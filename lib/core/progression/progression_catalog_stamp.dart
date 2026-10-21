import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/character_data_service.dart';
import '../services/feature_service.dart';
import '../services/qdnd_bundle_codec.dart';
import '../services/spell_service.dart';

/// Describes the definitions actually available to this development session.
/// Reloading a source must not mix newly loaded choices into an older preview.
class ProgressionCatalogStamp {
  ProgressionCatalogStamp._(this.digest, this.revisions);
  final String digest;
  final (int, int, int) revisions;
  static (int, int, int) get _revisions => (
        CharacterDataService.catalogRevision,
        FeatureService.catalogRevision,
        SpellService.catalogRevision
      );
  factory ProgressionCatalogStamp.capture() => ProgressionCatalogStamp._(
      fingerprint({
        'classes': _records(CharacterDataService.getAllClasses()
            .map(QdndBundleCodec.classToJson)),
        'features': _records(FeatureService.allFeatures.map((f) => f.toJson())),
        'spells': _records(SpellService.getAllSpells().map((s) => s.toJson())),
        'feats':
            _records(CharacterDataService.getAllFeats().map((f) => f.toJson())),
        'races': _records(
            CharacterDataService.getAllRaces().map(QdndBundleCodec.raceToJson)),
        'backgrounds': _records(CharacterDataService.getAllBackgrounds()
            .map(QdndBundleCodec.backgroundToJson)),
      }),
      _revisions);
  // Fast check for rendering; expensive content verification happens at commit.
  bool isCurrent() => revisions == _revisions;
  bool verifyContent() =>
      isCurrent() && digest == ProgressionCatalogStamp.capture().digest;

  static List<String> _records(Iterable<Map<String, dynamic>> values) =>
      values.map((v) => jsonEncode(_canonical(v))).toList()..sort();
  static String fingerprint(Map<String, dynamic> value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();
  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}
