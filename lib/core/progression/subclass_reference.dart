import '../models/character_class.dart';
import '../models/class_data.dart';
import '../models/character_feature.dart';
import '../services/fc5_content_identity_service.dart';
import '../services/feature_service.dart';
import 'progression_catalog_stamp.dart';

/// Presentation lookup only. It never changes a hero's rules or resources.
class SubclassReference {
  SubclassReference._(this.owned, this.candidates, this.selected,
      {required this.selectionMissing, required this.features});
  final SubclassData? owned;
  final List<SubclassReferenceCandidate> candidates;
  final SubclassData? selected;
  final bool selectionMissing;
  final List<CharacterFeature> features;
  bool get ambiguous => selected == null && candidates.length > 1;
  bool get requiresChoice => selected == null && candidates.isNotEmpty;

  static SubclassReference resolve({
    required CharacterClass entry,
    required String subclass,
    required ClassData? definition,
    required Iterable<ClassData> catalog,
  }) {
    bool matches(SubclassData data) => [data.id, ...data.name.values]
        .where((v) => v.trim().isNotEmpty)
        .any((name) =>
            FC5ContentIdentityService.canonicalSubclassName(name) ==
                FC5ContentIdentityService.canonicalSubclassName(subclass) ||
            FeatureService.matchesSubclass(name, subclass));
    final owned = definition?.subclasses.where(matches).firstOrNull;
    final family = definition == null
        ? FC5ContentIdentityService.canonicalClassId(entry.name)
        : FC5ContentIdentityService.classIdFromClassData(definition);
    final edition = definition?.rulesEdition ?? 'unknown';
    final referenceEdition = edition == 'unknown' ? '2014' : edition;
    final unique = <String, SubclassReferenceCandidate>{};
    for (final data in catalog) {
      if (FC5ContentIdentityService.classIdFromClassData(data) != family) {
        continue;
      }
      // A named foreign edition is never borrowed as 2014 reference material.
      if (data.rulesEdition != 'unknown' &&
          data.rulesEdition != referenceEdition) {
        continue;
      }
      for (final sub in data.subclasses.where(matches)) {
        final features = data.features.values
            .expand((v) => v)
            .where((f) =>
                f.associatedSubclass != null &&
                [sub.id, ...sub.name.values].any((name) =>
                    FeatureService.matchesSubclass(f.associatedSubclass, name)))
            .toList()
          ..sort((a, b) {
            final level = a.minLevel.compareTo(b.minLevel);
            return level != 0
                ? level
                : '${a.nameEn}|${a.nameRu}|${a.descriptionEn}|${a.descriptionRu}'
                    .compareTo(
                        '${b.nameEn}|${b.nameRu}|${b.descriptionEn}|${b.descriptionRu}');
          });
        if (!hasDescription(sub) && features.isEmpty) continue;
        final signature = ProgressionCatalogStamp.fingerprint({
          'family': family,
          'name': sub.name,
          'description': sub.description,
          'features': [
            for (final f in features)
              {
                'level': f.minLevel,
                'nameEn': f.nameEn,
                'nameRu': f.nameRu,
                'textEn': f.descriptionEn,
                'textRu': f.descriptionRu,
              }
          ],
        });
        unique.putIfAbsent(signature,
            () => SubclassReferenceCandidate(data, sub, signature, features));
        if (data.sourceId != null && data.sourceId == definition?.sourceId) {
          unique[signature] =
              SubclassReferenceCandidate(data, sub, signature, features);
        }
      }
    }
    final candidates = unique.values.toList()
      ..sort((a, b) => a.signature.compareTo(b.signature));
    final selection = entry.referenceData;
    final automaticCandidates = definition?.sourceId == null
        ? candidates
        : candidates
            .where((c) => c.owner.sourceId == definition!.sourceId)
            .toList();
    final unsupportedSelection =
        selection.isNotEmpty && selection['version'] != 1;
    final chosen = selection['version'] == 1 &&
            selection['subclass'] ==
                FC5ContentIdentityService.canonicalSubclassName(subclass)
        ? selection['signature'] is String
            ? selection['signature'] as String
            : null
        : null;
    final selected = unsupportedSelection
        ? null
        : chosen == null
            ? hasDescription(owned) && entry.rulesSnapshot != null
                ? owned
                : automaticCandidates.length == 1
                    ? automaticCandidates.single.subclass
                    : candidates.isEmpty
                        ? owned
                        : null
            : candidates
                .where((c) => c.signature == chosen)
                .firstOrNull
                ?.subclass;
    final selectedCandidate =
        candidates.where((c) => identical(c.subclass, selected)).firstOrNull;
    final features = selectedCandidate?.features ??
        (selected == owned
            ? definition?.features.values
                .expand((v) => v)
                .where((f) =>
                    f.associatedSubclass != null &&
                    FeatureService.matchesSubclass(
                        f.associatedSubclass, subclass))
                .toList()
            : null) ??
        <CharacterFeature>[];
    return SubclassReference._(owned, List.unmodifiable(candidates), selected,
        features: List.unmodifiable(features),
        selectionMissing:
            unsupportedSelection || chosen != null && selected == null);
  }

  static bool hasDescription(SubclassData? data) =>
      data != null &&
      data.description.values.any((text) =>
          text.trim().isNotEmpty &&
          !RegExp(r'^(Subclass of |Подкласс )', caseSensitive: false)
              .hasMatch(text.trim()));

  String name(String locale, String fallback) =>
      (selected ?? owned)?.name[locale]?.trim().isNotEmpty == true
          ? (selected ?? owned)!.name[locale]!
          : (selected ?? owned)
                  ?.name
                  .values
                  .where((s) => s.trim().isNotEmpty)
                  .firstOrNull ??
              fallback;

  String description(String locale) {
    final data =
        selected ?? (selectionMissing || requiresChoice ? null : owned);
    if (!hasDescription(data)) return '';
    final local = data!.description[locale];
    if (local != null && local.trim().isNotEmpty) return local;
    return data.description.values
            .where((s) => s.trim().isNotEmpty)
            .firstOrNull ??
        '';
  }
}

class SubclassReferenceCandidate {
  const SubclassReferenceCandidate(
      this.owner, this.subclass, this.signature, this.features);
  final ClassData owner;
  final SubclassData subclass;
  final String signature;
  final List<CharacterFeature> features;
  Map<String, dynamic> selection(String subclassKey) => {
        'version': 1,
        'subclass':
            FC5ContentIdentityService.canonicalSubclassName(subclassKey),
        'signature': signature,
      };
}
