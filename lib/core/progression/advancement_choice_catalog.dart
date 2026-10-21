import '../models/character_feature.dart';
import 'advancement_choice.dart';

class AdvancementChoiceCatalog {
  AdvancementChoiceCatalog(Iterable<CharacterFeature> definitions)
      : _definitions = {for (final f in definitions) f.id: f};
  final Map<String, CharacterFeature> _definitions;
  static const skillIds = [
    'acrobatics',
    'animal-handling',
    'arcana',
    'athletics',
    'deception',
    'history',
    'insight',
    'intimidation',
    'investigation',
    'medicine',
    'nature',
    'perception',
    'performance',
    'persuasion',
    'religion',
    'sleight-of-hand',
    'stealth',
    'survival'
  ];
  static const _invocations = [
    0,
    2,
    2,
    2,
    3,
    3,
    4,
    4,
    5,
    5,
    5,
    6,
    6,
    6,
    7,
    7,
    7,
    8,
    8,
    8
  ];
  static const legacyChoices = {
    'pact-boon',
    'hunters-prey',
    'defensive-tactics',
    'multiattack',
    'superior-hunters-defense'
  };

  List<AdvancementChoice> forLevel(
      {required String classId,
      required int level,
      required Iterable<CharacterFeature> features}) {
    if (level < 1 || level > 20) throw ArgumentError.value(level, 'level');
    final choices = <String, AdvancementChoice>{};
    for (final feature in features) {
      if (feature.id == 'bonus-proficiencies' && classId == 'bard') {
        choices[feature.id] = AdvancementChoice(
            id: feature.id,
            kind: AdvancementChoiceKind.skillProficiency,
            count: 3,
            options: [for (final skill in skillIds) AdvancementOption(skill)]);
      } else if (feature.options?.isNotEmpty == true &&
          !legacyChoices.contains(feature.id) &&
          feature.id != 'eldritch-invocations') {
        final count = feature.id == 'metamagic-1' ? 2 : 1;
        choices[feature.id] = _featureChoice(feature, count);
      }
    }
    // Additional invocation choices are events in the class table, even when
    // the descriptive parent feature was originally acquired at level two.
    if (classId == 'warlock') {
      final before = level == 1 ? 0 : _invocations[level - 2];
      final gain = _invocations[level - 1] - before;
      if (gain > 0) {
        final parent = _definitions['eldritch-invocations'];
        choices['eldritch-invocations'] = parent == null
            ? AdvancementChoice(
                id: 'eldritch-invocations',
                kind: AdvancementChoiceKind.feature,
                count: gain,
                options: const [])
            : _featureChoice(parent, gain);
      }
    }
    return choices.values.toList();
  }

  AdvancementChoice _featureChoice(CharacterFeature parent, int count) =>
      AdvancementChoice(
          id: parent.id,
          kind: AdvancementChoiceKind.feature,
          count: count,
          options: [
            for (final id in parent.options ?? <String>[])
              AdvancementOption(id,
                  feature: _definitions[id],
                  minimumClassLevel: _definitions[id]?.minLevel ?? 0,
                  requiredFeatures: switch (id) {
                    'eldritch-invocation-book-of-ancient-secrets' => {
                        'pact-of-the-tome'
                      },
                    'eldritch-invocation-voice-of-the-chain-master' ||
                    'eldritch-invocation-chains-of-carceri' =>
                      {'pact-of-the-chain'},
                    'eldritch-invocation-thirsting-blade' ||
                    'eldritch-invocation-lifedrinker' =>
                      {'pact-of-the-blade'},
                    _ => <String>{},
                  },
                  requiredSpells: switch (id) {
                    'eldritch-invocation-agonizing-blast' ||
                    'eldritch-invocation-eldritch-spear' ||
                    'eldritch-invocation-repelling-blast' =>
                      {'eldritch-blast'},
                    _ => <String>{},
                  })
          ]);
}
