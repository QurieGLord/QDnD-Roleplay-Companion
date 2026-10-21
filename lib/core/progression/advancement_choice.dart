import '../models/character.dart';
import '../models/character_feature.dart';
import 'proficiency_identity.dart';

/// Meaning is independent from the feature's action economy (passive/action).
enum AdvancementChoiceKind { feature, skillProficiency, expertise, subclass }

class AdvancementOption {
  const AdvancementOption(this.id,
      {this.feature,
      this.requiredFeatures = const {},
      this.requiredSpells = const {},
      this.minimumClassLevel = 0});
  final String id;
  final CharacterFeature? feature;
  final Set<String> requiredFeatures;
  final Set<String> requiredSpells;
  final int minimumClassLevel;

  bool available(Character character, int classLevel) =>
      classLevel >= minimumClassLevel &&
      requiredFeatures.every(character.hasFeatureId) &&
      requiredSpells.every((id) => character.knownSpells
          .any((known) => normalize(known) == normalize(id)));

  static String normalize(String id) =>
      id.toLowerCase().trim().replaceAll('_', '-');
}

class AdvancementChoice {
  AdvancementChoice(
      {required this.id,
      required this.kind,
      required this.count,
      required Iterable<AdvancementOption> options})
      : options = List.unmodifiable(options) {
    if (count < 1 ||
        this.options.map((o) => o.id).toSet().length != this.options.length) {
      throw ArgumentError('Invalid advancement choice.');
    }
  }
  final String id;
  final AdvancementChoiceKind kind;
  final int count;
  final List<AdvancementOption> options;

  /// Missing content must remain visible as an incomplete choice, never become
  /// an automatic success or shrink the rules' required count to fit a list.
  bool isSatisfied(
      Iterable<String> selected, Character character, int classLevel) {
    final values = selected.toList();
    if (values.length != count ||
        values
                .map((value) =>
                    kind == AdvancementChoiceKind.skillProficiency ||
                            kind == AdvancementChoiceKind.expertise
                        ? ProficiencyIdentity.normalize(value)
                        : value)
                .toSet()
                .length !=
            values.length) {
      return false;
    }
    for (final value in values) {
      final matches = options.where((option) => option.id == value);
      if (matches.length != 1 ||
          !matches.single.available(character, classLevel)) {
        return false;
      }
      if (kind == AdvancementChoiceKind.skillProficiency &&
          _contains(character.proficientSkills, value)) {
        return false;
      }
      if (kind == AdvancementChoiceKind.expertise &&
          (!_contains(character.proficientSkills, value) ||
              _contains(character.expertSkills, value))) {
        return false;
      }
      if (kind == AdvancementChoiceKind.feature &&
          (matches.single.feature == null || character.hasFeatureId(value))) {
        return false;
      }
    }
    return true;
  }

  static bool _contains(Iterable<String> values, String target) =>
      ProficiencyIdentity.contains(values, target);

  void applyTo(Character draft, Iterable<String> selected, int classLevel) {
    final values = selected.toList();
    if (!isSatisfied(values, draft, classLevel)) {
      throw StateError('Incomplete or unavailable choice: $id');
    }
    switch (kind) {
      case AdvancementChoiceKind.skillProficiency:
        draft.proficientSkills = [...draft.proficientSkills, ...values];
      case AdvancementChoiceKind.expertise:
        draft.expertSkills = [...draft.expertSkills, ...values];
      case AdvancementChoiceKind.feature:
        final copies = [
          for (final id in values)
            options.singleWhere((o) => o.id == id).feature?.copyForCharacter()
        ];
        if (copies.any((f) => f == null)) {
          throw StateError('Missing feature definition: $id');
        }
        draft.features = [
          ...draft.features,
          ...copies.cast<CharacterFeature>()
        ];
      case AdvancementChoiceKind.subclass:
        throw StateError(
            'Subclass choice is applied to a specific class by the progression flow.');
    }
  }
}
