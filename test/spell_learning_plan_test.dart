import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/class_spell_grants.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/progression/spell_learning_plan.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'multiclass_magic_flow_test.dart' as flow;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-learning-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'First wizard class grants six book choices and three cantrips at its own circle',
      () {
    final before = flow.mixed({'fighter': 4});
    final after =
        LevelUpDraft.begin(before, classId: 'wizard', newClassName: 'Wizard')
            .preview;
    final plan = SpellLearningPlan.forAdvance(before, after, 'wizard');
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.normal)
            .count,
        6);
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.cantrip)
            .count,
        3);
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.normal)
            .options
            .every((s) => s.level == 1),
        true);
  });
  test(
      'The same spell already known by the other class can be learned by the new wizard',
      () {
    final before = flow.mixed({'cleric': 4});
    final s = SpellService.getSpellsForClass('wizard')
        .firstWhere((s) => s.level == 1);
    flow.learn(before, s, 'class:cleric', prepared: true);
    final after =
        LevelUpDraft.begin(before, classId: 'wizard', newClassName: 'Wizard')
            .preview;
    expect(
        SpellLearningPlan.forAdvance(before, after, 'wizard')
            .choices
            .first
            .options
            .map((s) => s.id),
        contains(s.id));
  });
  test(
      'Bard secrets at ten replace the ordinary known-count increase and allow other lists',
      () {
    final before = flow.mixed({'bard': 9}),
        after = LevelUpDraft.begin(flow.mixed({'bard': 9}), classId: 'bard')
            .preview;
    final plan = SpellLearningPlan.forAdvance(before, after, 'bard');
    expect(
        plan.choices.where((c) => c.kind == SpellLearningKind.normal), isEmpty);
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.secret)
            .count,
        2);
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.secret)
            .options
            .any((s) =>
                !s.availableToClasses.any((c) => c.toLowerCase() == 'bard')),
        true);
  });
  test('Lore six gives two secrets in addition to its normal spell choice', () {
    final before = flow.mixed({'bard': 5});
    before.classes.single.subclass = 'lore';
    final after = LevelUpDraft.begin(before, classId: 'bard').preview;
    final plan = SpellLearningPlan.forAdvance(before, after, 'bard');
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.normal)
            .count,
        1);
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.secret)
            .count,
        2);
  });
  test(
      'Warlock eleven learns a normal spell separately from its circle-six Arcanum',
      () {
    final before = flow.mixed({'warlock': 10}),
        after =
            LevelUpDraft.begin(flow.mixed({'warlock': 10}), classId: 'warlock')
                .preview;
    final plan = SpellLearningPlan.forAdvance(before, after, 'warlock');
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.normal)
            .options
            .every((s) => s.level <= 5),
        true);
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.arcanum)
            .options
            .every((s) => s.level == 6),
        true);
  });
  test(
      'Land subclass gives its own bonus cantrip and guaranteed forest spells without spending preparation',
      () {
    final before = flow.mixed({'druid': 1}),
        after = LevelUpDraft.begin(flow.mixed({'druid': 1}), classId: 'druid')
            .preview;
    after.classes.single.subclass = 'land';
    final plan = SpellLearningPlan.forAdvance(before, after, 'druid');
    expect(
        plan.choices
            .singleWhere((c) => c.kind == SpellLearningKind.cantrip)
            .count,
        1);
  });
  test('All declared SRD subclass grants resolve to real catalog spells', () {
    for (final pair in [
      ('cleric', 'life'),
      ('paladin', 'devotion'),
      ('warlock', 'fiend')
    ]) {
      final hero = flow.mixed({pair.$1: 20});
      hero.classes.single.subclass = pair.$2;
      for (final id in ClassSpellGrants.ids(hero, pair.$1,
          expanded: pair.$1 == 'warlock')) {
        expect(ClassSpellGrants.spell(id), isNotNull, reason: id);
      }
    }
  });
  test(
      'Life domain spells are always prepared and belong only to cleric even beside a wizard',
      () {
    final hero = flow.mixed({'wizard': 3, 'cleric': 3});
    hero.classes.last.subclass = 'life';
    ClassSpellGrants.apply(hero, 'cleric');
    final book = SpellbookState.read(hero.spellbookData),
        bless = ClassSpellGrants.spell('bless')!;
    expect(book.ids('class:cleric', 'alwaysPrepared'), contains(bless.id));
    expect(book.ids('class:wizard', 'known'), isEmpty);
  });
  test(
      'A missing selection cannot silently shrink learning to fit a small library',
      () {
    final before = flow.mixed({'wizard': 2}),
        after = LevelUpDraft.begin(flow.mixed({'wizard': 2}), classId: 'wizard')
            .preview;
    final plan = SpellLearningPlan.forAdvance(before, after, 'wizard');
    expect(() => plan.validate({}), throwsStateError);
  });
  test(
      'Learning and replacement preserve the same spell owned by another class',
      () {
    final hero = flow.mixed({'bard': 3, 'wizard': 2});
    final old =
        SpellService.getSpellsForClass('bard').firstWhere((s) => s.level == 1);
    flow.learn(hero, old, 'class:bard');
    flow.learn(hero, old, 'class:wizard', prepared: true);
    final after = LevelUpDraft.begin(hero, classId: 'bard').preview;
    final plan = SpellLearningPlan.forAdvance(hero, after, 'bard');
    final selected = <String, List<String>>{};
    final used = <String>{old.id};
    for (final choice in plan.choices) {
      final ids = choice.options
          .where((s) => !used.contains(s.id))
          .take(choice.count)
          .map((s) => s.id)
          .toList();
      selected[choice.key] = ids;
      used.addAll(ids);
    }
    final replacement =
        plan.replacementOptions.firstWhere((s) => !used.contains(s.id));
    plan.apply(after, selected, replaceOld: old.id, replaceNew: replacement.id);
    final book = SpellbookState.read(after.spellbookData);
    expect(book.ids('class:bard', 'known'), isNot(contains(old.id)));
    expect(book.ids('class:wizard', 'known'), contains(old.id));
    expect(after.knownSpells, contains(old.id));
    expect(after.preparedSpells, contains(old.id));
  });
  test(
      'Pact of the Tome adds three cantrips from any class and uses its own source',
      () {
    final before = flow.mixed({'warlock': 2, 'wizard': 1});
    final after = LevelUpDraft.begin(before, classId: 'warlock').preview;
    after.features.add(
        FeatureService.getFeatureById('pact-of-the-tome')!.copyForCharacter());
    final plan = SpellLearningPlan.forAdvance(before, after, 'warlock');
    final tome =
        plan.choices.singleWhere((c) => c.kind == SpellLearningKind.tome);
    expect(tome.count, 3);
    expect(tome.options.any((s) => !s.availableToClasses.contains('Warlock')),
        isTrue);
    final choices = <String, List<String>>{};
    final used = <String>{};
    for (final choice in plan.choices) {
      choices[choice.key] = choice.options
          .where((s) => !used.contains(s.id))
          .take(choice.count)
          .map((s) => s.id)
          .toList();
      used.addAll(choices[choice.key]!);
    }
    plan.apply(after, choices);
    final book = SpellbookState.read(after.spellbookData);
    expect(book.ids('class:warlock', 'known'), containsAll(choices['tome']!));
    expect(book.ids('class:wizard', 'known'), isEmpty);
  });
  for (final classId in ['fighter', 'rogue']) {
    test(
        '$classId separates unrestricted learning and preserves it on replacement and transfer',
        () {
      final before = flow.mixed({classId: 2});
      final after = LevelUpDraft.begin(before, classId: classId).preview;
      after.classes.single.subclass =
          classId == 'fighter' ? 'eldritch knight' : 'arcane trickster';
      final plan = SpellLearningPlan.forAdvance(before, after, classId);
      expect(
          plan.choices
              .singleWhere((c) => c.kind == SpellLearningKind.normal)
              .count,
          2);
      expect(
          plan.choices
              .singleWhere((c) => c.kind == SpellLearningKind.unrestricted)
              .count,
          1);
      final selections = <String, List<String>>{};
      final used = <String>{};
      for (final choice in plan.choices) {
        selections[choice.key] = choice.options
            .where((s) => !used.contains(s.id))
            .take(choice.count)
            .map((s) => s.id)
            .toList();
        used.addAll(selections[choice.key]!);
      }
      plan.apply(after, selections);
      final unrestricted = selections['unrestricted']!.single;
      expect(
          SpellbookState.read(after.spellbookData)
              .ids('class:$classId', 'unrestricted'),
          {unrestricted});
      final next = LevelUpDraft.begin(after, classId: classId).preview;
      final advance = SpellLearningPlan.forAdvance(after, next, classId);
      expect(advance.replaceable.map((s) => s.id), contains(unrestricted));
      expect(
          advance.replacementsFor(unrestricted).any((s) =>
              !advance.replacementSchools.contains(s.school.toLowerCase())),
          isTrue);
      final restricted = selections['normal']!.first;
      expect(
          advance.replacementsFor(restricted).every((s) =>
              advance.replacementSchools.contains(s.school.toLowerCase())),
          isTrue);
      final book = SpellbookState.read(after.spellbookData);
      final remapped = SpellbookState.read(
          book.remap(spell: (id) => 'mapped-$id', classId: (id) => 'new-$id'));
      expect(remapped.ids('class:new-$classId', 'unrestricted'),
          {'mapped-$unrestricted'});
    });
  }
}
