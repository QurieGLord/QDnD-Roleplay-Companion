import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/progression/pact_slot_growth.dart';
import 'package:qd_and_d/core/progression/feature_evolution.dart';
import 'package:qd_and_d/core/progression/skill_check.dart';
import 'package:qd_and_d/core/models/spell_slots_table.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/progression/advancement_choice.dart';
import 'package:qd_and_d/core/progression/advancement_choice_catalog.dart';
import 'package:qd_and_d/core/progression/spell_progression.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const classes = [
    'barbarian',
    'bard',
    'cleric',
    'druid',
    'fighter',
    'monk',
    'paladin',
    'ranger',
    'rogue',
    'sorcerer',
    'warlock',
    'wizard'
  ];
  test(
      'Every installed class keeps its real level definitions and typed metadata',
      () async {
    await FeatureService.init();
    for (final id in classes) {
      final data = jsonDecode(
              await rootBundle.loadString('assets/data/classes/$id.json'))
          as Map<String, dynamic>;
      final parsed = ClassData.fromJson(data);
      expect(parsed.features.length, (data['features'] as Map).length,
          reason: id);
      for (final entry in parsed.features.entries) {
        for (final feature in entry.value) {
          expect(feature.minLevel, entry.key, reason: feature.id);
          expect(feature.nameEn, isNotEmpty);
          expect(feature.nameRu, isNotEmpty);
          expect(feature.associatedClass, id);
          final ref = FeatureService.getFeatureById(feature.id)!;
          expect(feature.associatedSubclass, ref.associatedSubclass,
              reason: feature.id);
          expect(feature.type, ref.type, reason: feature.id);
          expect(feature.isOptional, ref.isOptional, reason: feature.id);
        }
      }
    }
  });
  test(
      'Optional built-in variants cannot leak into automatic grants at their minimum level',
      () async {
    await FeatureService.init();
    for (final tuple in [
      ('warlock', 2, 'eldritch-invocation-'),
      ('sorcerer', 3, 'metamagic-'),
      ('warlock', 3, 'pact-of-')
    ]) {
      final grants = FeatureService.getFeaturesForLevel(
          classId: tuple.$1, level: tuple.$2);
      expect(
          grants
              .where((f) => f.id.startsWith(tuple.$3) && f.id != 'metamagic-1'),
          isEmpty);
    }
    expect(
        FeatureService.getFeaturesForLevel(classId: 'cleric', level: 17)
            .any((f) => f.id == 'supreme-healing'),
        isFalse);
    expect(
        FeatureService.getFeaturesForLevel(
                classId: 'cleric', level: 17, subclassId: 'Life')
            .any((f) => f.id == 'supreme-healing'),
        isTrue);
  });
  test('Class definitions cannot hide malformed levels or repeated row IDs',
      () async {
    final data = jsonDecode(
            await rootBundle.loadString('assets/data/classes/fighter.json'))
        as Map<String, dynamic>;
    data['features'] = {'21': []};
    expect(() => ClassData.fromJson(data), throwsFormatException);
    data['features'] = {
      '2': [
        {'id': 'a', 'minLevel': 3}
      ]
    };
    expect(() => ClassData.fromJson(data), throwsFormatException);
    data['features'] = {
      '2': [
        {'id': 'a'},
        {'id': 'a'}
      ]
    };
    expect(() => ClassData.fromJson(data), throwsFormatException);
    data['features'] = {
      '1': [
        {'id': 'same'}
      ],
      '2': [
        {'id': 'same'}
      ]
    };
    expect(ClassData.fromJson(data).features, hasLength(2));
  });
  test(
      'Expertise recognizes exact RU/EN training and cannot award untrained or repeated expertise',
      () {
    final c = fixtures.hero()
      ..proficientSkills = ['Внимательность', 'animal_handling']
      ..expertSkills = ['Уход за животными'];
    final choice = AdvancementChoice(
        id: 'expertise',
        kind: AdvancementChoiceKind.expertise,
        count: 1,
        options: const [
          AdvancementOption('perception'),
          AdvancementOption('animal-handling'),
          AdvancementOption('athletics')
        ]);
    expect(choice.isSatisfied(['perception'], c, 3), isTrue);
    expect(choice.isSatisfied(['animal-handling'], c, 3), isFalse);
    expect(choice.isSatisfied(['athletics'], c, 3), isFalse);
    expect(choice.isSatisfied(['perception', 'perception'], c, 3), isFalse);
    choice.applyTo(c, ['perception'], 3);
    expect(c.expertSkills, contains('perception'));
    expect(c.features, isEmpty);
  });
  test('Skill training updates training rather than creating a passive feature',
      () {
    final c = fixtures.hero();
    final choice = AdvancementChoice(
        id: 'skills',
        kind: AdvancementChoiceKind.skillProficiency,
        count: 1,
        options: const [AdvancementOption('athletics')]);
    choice.applyTo(c, ['athletics'], 1);
    expect(c.proficientSkills, ['athletics']);
    expect(c.features, isEmpty);
    expect(choice.isSatisfied(['athletics'], c, 1), isFalse);
  });
  test(
      'Choice prerequisites use the target class level and only confirmed features/spells',
      () {
    final c = fixtures.hero()..knownSpells = ['eldritch_blast'];
    final option = AdvancementOption('blast',
        minimumClassLevel: 5,
        requiredSpells: {'eldritch-blast'},
        feature: CharacterFeature(
            id: 'blast',
            nameEn: 'Blast',
            nameRu: 'Луч',
            descriptionEn: '',
            descriptionRu: '',
            type: FeatureType.passive,
            minLevel: 5));
    final choice = AdvancementChoice(
        id: 'invocation',
        kind: AdvancementChoiceKind.feature,
        count: 1,
        options: [option]);
    expect(choice.isSatisfied(['blast'], c, 4), isFalse);
    expect(choice.isSatisfied(['blast'], c, 5), isTrue);
    expect(choice.isSatisfied(['unknown'], c, 5), isFalse);
    const pact = AdvancementOption('blade',
        minimumClassLevel: 5, requiredFeatures: {'pact-of-the-blade'});
    expect(pact.available(c, 20), isFalse);
    c.features.add(CharacterFeature(
        id: 'pact_of_the_blade',
        nameEn: 'Blade',
        nameRu: 'Клинок',
        descriptionEn: '',
        descriptionRu: '',
        type: FeatureType.passive,
        minLevel: 3));
    expect(pact.available(c, 5), isTrue);
  });
  test(
      'Missing content remains incomplete and an absent feature cannot partially apply',
      () {
    final c = fixtures.hero();
    final empty = AdvancementChoice(
        id: 'missing',
        kind: AdvancementChoiceKind.feature,
        count: 2,
        options: const []);
    expect(empty.isSatisfied([], c, 2), isFalse);
    final missing = AdvancementChoice(
        id: 'missing',
        kind: AdvancementChoiceKind.feature,
        count: 1,
        options: const [AdvancementOption('x')]);
    expect(() => missing.applyTo(c, ['x'], 2), throwsStateError);
    expect(c.features, isEmpty);
  });
  test('A noncaster multiclass does not lower a single half-caster progression',
      () {
    final result = SpellProgression.calculate(const [
      ClassCasterLevel('fighter', 2, CasterProgression.none),
      ClassCasterLevel('paladin', 3, CasterProgression.half)
    ], edition: ProgressionEdition.srd2014);
    expect(result.sharedSlots, [3]);
    expect(result.learningCircles, {'fighter': 0, 'paladin': 1});
  });
  test('Shared higher circles cannot unlock higher class-specific spells', () {
    final result = SpellProgression.calculate(const [
      ClassCasterLevel('cleric', 3, CasterProgression.full),
      ClassCasterLevel('wizard', 2, CasterProgression.full)
    ], edition: ProgressionEdition.srd2014);
    expect(result.sharedSlots, [4, 3, 2]);
    expect(result.learningCircles, {'cleric': 2, 'wizard': 1});
  });
  test('Half-caster rounding is explicitly different between the two editions',
      () {
    const entries = [
      ClassCasterLevel('paladin', 3, CasterProgression.half),
      ClassCasterLevel('wizard', 2, CasterProgression.full)
    ];
    expect(
        SpellProgression.calculate(entries, edition: ProgressionEdition.srd2014)
            .sharedSlots,
        [4, 2]);
    expect(
        SpellProgression.calculate(entries, edition: ProgressionEdition.srd2024)
            .sharedSlots,
        [4, 3]);
    expect(
        SpellProgression.calculate(
                const [ClassCasterLevel('paladin', 1, CasterProgression.half)],
                edition: ProgressionEdition.srd2014)
            .sharedSlots,
        isEmpty);
    expect(
        SpellProgression.calculate(
                const [ClassCasterLevel('paladin', 1, CasterProgression.half)],
                edition: ProgressionEdition.srd2024)
            .sharedSlots,
        [2]);
  });
  test(
      'Pact is independent of full-caster slots and does not increase shared capacity',
      () {
    final result = SpellProgression.calculate(const [
      ClassCasterLevel('warlock', 5, CasterProgression.pact),
      ClassCasterLevel('wizard', 2, CasterProgression.full)
    ], edition: ProgressionEdition.srd2014);
    expect(result.sharedSlots, [3]);
    expect(result.pact!.circle, 3);
    expect(result.pact!.count, 2);
    expect(result.learningCircles, {'warlock': 3, 'wizard': 1});
  });
  test('Caster tables never decrease capacity over twenty single-class levels',
      () {
    for (final edition in ProgressionEdition.values) {
      for (final type in [
        CasterProgression.full,
        CasterProgression.half,
        CasterProgression.pact
      ]) {
        var previousCount = 0;
        var previousCircle = 0;
        for (var level = 1; level <= 20; level++) {
          final result = SpellProgression.calculate(
              [ClassCasterLevel('class', level, type)],
              edition: edition);
          final count = type == CasterProgression.pact
              ? result.pact!.count
              : result.sharedSlots.fold<int>(0, (sum, n) => sum + n);
          expect(count, greaterThanOrEqualTo(previousCount));
          expect(result.learningCircles['class'],
              greaterThanOrEqualTo(previousCircle));
          previousCount = count;
          previousCircle = result.learningCircles['class']!;
        }
      }
    }
  });
  test(
      'Every 2014 class level uses the SRD ASI schedule rather than the character total',
      () async {
    await FeatureService.init();
    for (final cls in classes) {
      final levels = {
        4,
        8,
        12,
        16,
        19,
        if (cls == 'fighter') ...[6, 14],
        if (cls == 'rogue') 10
      };
      for (var level = 1; level <= 20; level++) {
        final features =
            FeatureService.getFeaturesForLevel(classId: cls, level: level);
        expect(features.any((f) => f.id.contains('ability-score-improvement')),
            levels.contains(level),
            reason: '$cls $level');
      }
    }
  });
  test(
      'Warlock invocation choices follow all twenty table rows, including later choices without a new parent feature',
      () async {
    await FeatureService.init();
    final catalogue = AdvancementChoiceCatalog(FeatureService.allFeatures);
    const gains = {2: 2, 5: 1, 7: 1, 9: 1, 12: 1, 15: 1, 18: 1};
    for (var level = 1; level <= 20; level++) {
      final groups = catalogue.forLevel(
          classId: 'warlock',
          level: level,
          features: FeatureService.getFeaturesForLevel(
              classId: 'warlock', level: level));
      final invocation = groups.where((g) => g.id == 'eldritch-invocations');
      if (gains.containsKey(level)) {
        expect(invocation.single.count, gains[level]);
      } else {
        expect(invocation, isEmpty);
      }
    }
  });
  test('The complete full-caster table matches the SRD reference rows', () {
    const reference = [
      [2],
      [3],
      [4, 2],
      [4, 3],
      [4, 3, 2],
      [4, 3, 3],
      [4, 3, 3, 1],
      [4, 3, 3, 2],
      [4, 3, 3, 3, 1],
      [4, 3, 3, 3, 2],
      [4, 3, 3, 3, 2, 1],
      [4, 3, 3, 3, 2, 1],
      [4, 3, 3, 3, 2, 1, 1],
      [4, 3, 3, 3, 2, 1, 1],
      [4, 3, 3, 3, 2, 1, 1, 1],
      [4, 3, 3, 3, 2, 1, 1, 1],
      [4, 3, 3, 3, 2, 1, 1, 1, 1],
      [4, 3, 3, 3, 3, 1, 1, 1, 1],
      [4, 3, 3, 3, 3, 2, 1, 1, 1],
      [4, 3, 3, 3, 3, 2, 2, 1, 1]
    ];
    for (var level = 1; level <= 20; level++) {
      expect(SpellSlotsTable.getSlots(level, 'full'), reference[level - 1]);
    }
  });
  test(
      'A multiclass cannot acquire another class features through the overall level',
      () async {
    await FeatureService.init();
    final c = fixtures.hero()
      ..level = 11
      ..classes = [
        CharacterClass(
            id: 'fighter', name: 'Fighter', level: 1, isPrimary: true),
        CharacterClass(
            id: 'wizard',
            name: 'Wizard',
            level: 10,
            subclass: 'School of Evocation')
      ];
    final features = FeatureService.getFeaturesForCharacter(c);
    expect(features.any((f) => f.id == 'second-wind'), isTrue);
    expect(features.any((f) => f.id == 'extra-attack-1'), isFalse);
    expect(features.any((f) => f.id == 'empowered-evocation'), isTrue);
    expect(features.any((f) => f.id == 'spell-mastery'), isFalse);
    expect(
        FeatureService.tryCalculateMaxUses(c, 'level * 5', classId: 'fighter'),
        5);
    expect(
        FeatureService.tryCalculateMaxUses(c, 'class_level + character_level',
            classId: 'wizard'),
        21);
    expect(
        FeatureService.tryCalculateMaxUses(c, 'level * 5', classId: 'paladin'),
        isNull);
  });
  test(
      'Skill bonuses use total proficiency, exact aliases and Jack of All Trades only when granted',
      () {
    final c = fixtures.hero()
      ..level = 5
      ..proficientSkills = ['animal_handling']
      ..expertSkills = ['Внимательность'];
    expect(SkillCheck.trainingBonus(c, 'Animal Handling'), 3);
    expect(SkillCheck.trainingBonus(c, 'perception'), 6);
    expect(SkillCheck.trainingBonus(c, 'history'), 0);
    c.features.add(CharacterFeature(
        id: 'jack-of-all-trades',
        nameEn: 'Jack',
        nameRu: 'Мастер',
        descriptionEn: '',
        descriptionRu: '',
        type: FeatureType.passive,
        minLevel: 2));
    expect(SkillCheck.trainingBonus(c, 'history'), 1);
    expect(SkillCheck.trainingBonus(c, 'perception'), 6);
  });
  test(
      'Pact circle changes preserve the remainder, overfill and unrelated explicit slots',
      () {
    final current = [6, 0, 1];
    final maximum = [4, 0, 2];
    final moved = PactSlotGrowth.move(
        current: current,
        maximum: maximum,
        oldCircle: 1,
        newCircle: 2,
        oldNorm: 2,
        newNorm: 2);
    expect(moved.current, [0, 6, 1]);
    expect(moved.maximum, [0, 4, 2]);
    expect(current, [6, 0, 1]);
    expect(maximum, [4, 0, 2]);
    final grown = PactSlotGrowth.move(
        current: [0, 1],
        maximum: [0, 2],
        oldCircle: 2,
        newCircle: 2,
        oldNorm: 2,
        newNorm: 3);
    expect(grown.current, [0, 2]);
    expect(grown.maximum, [0, 3]);
  });
  test(
      'Resource upgrades replace one family while distinct Arcanum circles remain independent',
      () async {
    await FeatureService.init();
    final old = FeatureService.getFeatureById('bardic-inspiration-d6')!
        .copyForCharacter();
    old.resourcePool!.currentUses = 0;
    final owned = [old];
    FeatureEvolution.acquire(
        owned, FeatureService.getFeatureById('bardic-inspiration-d8')!);
    expect(owned, hasLength(1));
    expect(owned.single.id, 'bardic-inspiration-d8');
    expect(old.resourcePool!.currentUses, 0);
    expect(
        FeatureEvolution.key(
            FeatureService.getFeatureById('mystic-arcanum-6th-level')!),
        isNot(FeatureEvolution.key(
            FeatureService.getFeatureById('mystic-arcanum-7th-level')!)));
  });
  test('Recognized imported upgrades retain explicitly changed recovery rules',
      () async {
    await FeatureService.init();
    final old = FeatureService.getFeatureById('bardic-inspiration-d6')!
        .copyForCharacter()
      ..sourceId = 'my-import';
    old.resourcePool!.recoveryType = RecoveryType.manual;
    final owned = [old];
    FeatureEvolution.acquire(
        owned, FeatureService.getFeatureById('bardic-inspiration-d8')!,
        referenceFor: FeatureService.getFeatureById);
    expect(owned.single.id, 'bardic-inspiration-d8');
    expect(owned.single.resourcePool!.recoveryType, RecoveryType.manual);
    expect(old.resourcePool!.recoveryType, RecoveryType.manual);
  });
  test(
      'Unresolved or invalid spell progressions never guess a successful table',
      () {
    expect(
        () => SpellProgression.calculate(const [
              ClassCasterLevel('wizard', 20, CasterProgression.full),
              ClassCasterLevel('fighter', 1, CasterProgression.none)
            ], edition: ProgressionEdition.srd2014),
        throwsArgumentError);
    expect(
        () => SpellProgression.calculate(const [
              ClassCasterLevel('warlock', 1, CasterProgression.pact),
              ClassCasterLevel('warlock', 1, CasterProgression.pact)
            ], edition: ProgressionEdition.srd2014),
        throwsArgumentError);
    expect(
        () => SpellProgression.calculate(
            const [ClassCasterLevel('eldritch', 5, CasterProgression.third)],
            edition: ProgressionEdition.srd2024),
        throwsUnsupportedError);
  });
}
