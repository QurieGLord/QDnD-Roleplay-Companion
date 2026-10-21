import '../models/character_feature.dart';

/// Upgrade identity must not be confused with learning a second independent
/// resource. Separate Arcanum circles deliberately remain separate features.
class FeatureEvolution {
  static String key(CharacterFeature feature) {
    var id = feature.id;
    for (final pattern in [
      r'^bardic-inspiration-d\d+$',
      r'^action-surge-\d+-uses?$',
      r'^indomitable-\d+-uses?$',
      r'^channel-divinity-\d+-rest$',
      r'^song-of-rest-d\d+$',
      r'^brutal-critical-\d+-(die|dice)$',
      r'^extra-attack-\d+$',
      r'^destroy-undead-cr-.*$',
      r'^unarmored-movement-\d+$'
    ]) {
      if (RegExp(pattern).hasMatch(id)) {
        id = id.replaceFirst(RegExp(r'-(d\d+|\d+.*|cr-.*)$'), '');
        break;
      }
    }
    return '${feature.associatedClass?.toLowerCase() ?? ''}:$id';
  }

  static void acquire(List<CharacterFeature> owned, CharacterFeature definition,
      {CharacterFeature? Function(String)? referenceFor}) {
    final existing = owned.where((f) => key(f) == key(definition)).toList();
    if (existing.any((f) => f.minLevel >= definition.minLevel)) return;
    for (final feature in existing) {
      if (feature.sourceId != definition.sourceId && feature.sourceId != null) {
        final reference = referenceFor?.call(feature.id);
        if (reference == null ||
            feature.nameEn != reference.nameEn ||
            feature.associatedClass?.toLowerCase() !=
                reference.associatedClass?.toLowerCase()) {
          throw StateError(
              'The upgraded feature has an unresolved source identity.');
        }
      }
    }
    final next = definition.copyForCharacter();
    final before = existing.firstOrNull;
    final oldReference = before == null ? null : referenceFor?.call(before.id);
    if (before?.resourcePool != null &&
        next.resourcePool != null &&
        oldReference?.resourcePool != null &&
        before!.resourcePool!.recoveryType !=
            oldReference!.resourcePool!.recoveryType) {
      next.resourcePool!.recoveryType = before.resourcePool!.recoveryType;
    }
    owned.removeWhere((f) => key(f) == key(definition));
    owned.add(next);
  }
}
