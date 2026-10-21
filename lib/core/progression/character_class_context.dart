import '../models/character.dart';
import '../models/character_class.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../services/feature_service.dart';
import '../services/character_data_service.dart';
import '../services/fc5_content_identity_service.dart';
import 'character_class_rules.dart';
import 'subclass_reference.dart';

/// Read-only ownership for class panels. Never substitutes the primary class
/// or the character's total level for an absent secondary class.
class CharacterClassContext {
  const CharacterClassContext(this.character, this.classId);
  final Character character;
  final String classId;

  CharacterClass? get entry {
    final exact = character.classes
        .where((c) => FeatureService.classKey(c.id) == classId)
        .toList();
    if (exact.length == 1) return exact.single;
    if (exact.isNotEmpty) return null;
    final family = character.classes
        .where((c) =>
            FC5ContentIdentityService.canonicalClassId(c.name) == classId)
        .toList();
    return family.length == 1 ? family.single : null;
  }

  int get level => entry?.level ?? 0;

  /// Explicit foreign owners never leak into this panel. Legacy features
  /// without an owner remain readable instead of being reassigned on view.
  bool acceptsFeature(CharacterFeature feature) {
    final owned = entry;
    if (owned == null) return false;
    final owner = feature.associatedClass;
    // Built-in choice options use Optional as a catalog category, not
    // as a foreign class. Their concrete identity is filtered by the panel.
    return owner == null ||
        FeatureService.classKey(owner) == 'optional' ||
        owner == owned.id ||
        FeatureService.classKey(owner) == classId ||
        FeatureService.classKey(owner) == FeatureService.classKey(owned.name);
  }

  /// Catalog presence is not acquisition. UI and actions share own-level gates.
  bool canUseFeature(CharacterFeature feature) {
    final reference = feature.sourceId == null
        ? FeatureService.getFeatureById(feature.id)
        : null;
    final minimum = reference != null &&
            reference.sourceId == null &&
            reference.minLevel > feature.minLevel
        ? reference.minLevel
        : feature.minLevel;
    if (feature.associatedSubclass != null) {
      final data = definition;
      if (data != null &&
          data.declares('subclassLevel') &&
          level < data.subclassLevel) {
        return false;
      }
    }
    return entry != null &&
        acceptsFeature(feature) &&
        minimum <= level &&
        FeatureService.matchesSubclass(feature.associatedSubclass, subclass);
  }

  bool get hasAcquiredSubclass {
    if (subclass == null) return false;
    final data = definition;
    return data == null ||
        !data.declares('subclassLevel') ||
        level >= data.subclassLevel;
  }

  String? get subclass {
    final owned = entry;
    if (owned == null) return null;
    return owned.subclass ?? (owned.isPrimary ? character.subclass : null);
  }

  ClassData? get definition {
    final owned = entry;
    if (owned == null) return null;
    if (owned.rulesSnapshot == null) {
      return CharacterDataService.getClassById(owned.id);
    }
    try {
      return CharacterClassRules.resolve(owned).data;
    } on FormatException {
      // A damaged personal source is not replaced with unrelated live rules.
      return null;
    } on StateError {
      return null;
    }
  }

  String name(String locale) =>
      definition?.getName(locale) ?? entry?.name ?? classId;

  SubclassReference? get subclassReference {
    final value = subclass;
    final owned = entry;
    if (value == null || owned == null) return null;
    // A damaged snapshot is never replaced by live book data, even for display.
    final data = definition;
    if (owned.rulesSnapshot != null && data == null) return null;
    return SubclassReference.resolve(
        entry: owned,
        subclass: value,
        definition: data,
        catalog: CharacterDataService.getAllClassReferences());
  }

  SubclassData? get subclassDefinition =>
      subclassReference?.selected ?? subclassReference?.owned;

  String? subclassName(String locale) => hasAcquiredSubclass
      ? (subclassReference?.name(locale, subclass ?? '') ?? subclass)
      : null;
}
