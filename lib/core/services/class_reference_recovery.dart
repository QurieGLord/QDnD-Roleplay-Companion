import '../models/class_data.dart';
import '../models/character_feature.dart';
import '../progression/subclass_reference.dart';
import 'fc5_content_identity_service.dart';
import 'feature_service.dart';

/// Restores presentation from records retained by historical imports that did
/// not preserve XML. Never writes a library, feature, snapshot or character.
class ClassReferenceRecovery {
  static ClassData fromStoredFeatures(ClassData stored) {
    bool matches(String name, SubclassData sub) =>
        name.trim().isNotEmpty &&
        [sub.id, ...sub.name.values].where((v) => v.trim().isNotEmpty).any(
            (value) =>
                FC5ContentIdentityService.canonicalSubclassName(name) ==
                    FC5ContentIdentityService.canonicalSubclassName(value) ||
                FeatureService.matchesSubclass(name, value));
    final subclasses = <SubclassData>[];
    var changed = false;
    for (final sub in stored.subclasses) {
      final candidates = <CharacterFeature>[];
      for (final f in stored.features.values.expand((v) => v)) {
        if (f.associatedSubclass != null &&
            !matches(f.associatedSubclass!, sub)) {
          continue;
        }
        if ([f.nameEn, f.nameRu].any(
            (name) => matches(name.split(RegExp(r'[:：]')).last.trim(), sub))) {
          if (f.descriptionEn.trim().isNotEmpty ||
              f.descriptionRu.trim().isNotEmpty) {
            candidates.add(f);
          }
        }
      }
      if (candidates.isEmpty) {
        subclasses.add(sub);
        continue;
      }
      final earliest =
          candidates.map((f) => f.minLevel).reduce((a, b) => a < b ? a : b);
      final roots = candidates.where((f) => f.minLevel == earliest).toList();
      // Different texts at the same declaration point require source repair;
      // choosing the longest/first would hide an actual ambiguity.
      if (roots
              .map((f) => '${f.descriptionEn.trim()}|${f.descriptionRu.trim()}')
              .toSet()
              .length !=
          1) {
        subclasses.add(sub);
        continue;
      }
      final intro = roots.first;
      final names = Map<String, String>.of(sub.name);
      for (final name in [intro.nameRu, intro.nameEn]) {
        final tail = name.split(RegExp(r'[:：]')).last.trim();
        if (RegExp('[А-Яа-яЁё]').hasMatch(tail) &&
            (matches(tail, sub) ||
                name == intro.nameRu &&
                    intro.nameRu != intro.nameEn &&
                    intro.nameRu.contains(':')) &&
            !(RegExp('[А-Яа-яЁё]').hasMatch(names['ru'] ?? ''))) {
          names['ru'] = tail;
        }
      }
      final description = SubclassReference.hasDescription(sub)
          ? sub.description
          : {
              'en': intro.descriptionEn.trim().isNotEmpty
                  ? intro.descriptionEn
                  : intro.descriptionRu,
              'ru': intro.descriptionRu.trim().isNotEmpty
                  ? intro.descriptionRu
                  : intro.descriptionEn,
            };
      changed = true;
      subclasses
          .add(SubclassData(id: sub.id, name: names, description: description));
    }
    if (!changed) return stored;
    return ClassData(
        id: stored.id,
        name: stored.name,
        description: stored.description,
        hitDie: stored.hitDie,
        primaryAbilities: stored.primaryAbilities,
        savingThrowProficiencies: stored.savingThrowProficiencies,
        armorProficiencies: stored.armorProficiencies,
        weaponProficiencies: stored.weaponProficiencies,
        skillProficiencies: stored.skillProficiencies,
        subclasses: subclasses,
        subclassLevel: stored.subclassLevel,
        spellcasting: stored.spellcasting,
        features: stored.features,
        sourceId: stored.sourceId,
        rulesMetadata: stored.rulesMetadata,
        sourceDefinition: stored.sourceDefinition);
  }
}
