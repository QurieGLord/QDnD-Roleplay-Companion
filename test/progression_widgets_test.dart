import 'package:qd_and_d/features/character_level_up/steps/class_magic_step.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/progression/advancement_choice_catalog.dart';
import 'package:qd_and_d/core/progression/advancement_choice.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/features/character_level_up/widgets/class_rules_review.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/sorcerer_magic_widget.dart';
import 'package:qd_and_d/features/character_level_up/steps/features_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/hp_increase_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/asi_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/summary_step.dart';
import 'package:qd_and_d/features/character_level_up/widgets/advancement_choice_card.dart';
import 'package:qd_and_d/features/character_level_up/widgets/advancement_layout.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget child,
        {String locale = 'en', bool dark = false, double scale = 1}) =>
    MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: dark ? Brightness.dark : Brightness.light)),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(body: child));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-progression-widgets-');
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
  testWidgets(
      'A real level-up routes an incomplete saved class through clarification without saving it on entry',
      (tester) async {
    final data = (await FC5Parser.parseCompendium(
            '<compendium><class><name>Unfinished Knight</name></class></compendium>',
            sourceId: 'partial'))
        .classes
        .single;
    final c = fixtures.hero()..level = 2;
    c.classes.single.level = 2;
    c.classes.single.id = data.id;
    c.classes.single.name = data.getName('en');
    c.characterClass = data.id;
    CharacterClassRules.capture(data).attachTo(c.classes.single);
    final before = QdndBundleCodec.characterToJson(c);
    await tester.pumpWidget(app(LevelUpScreen(character: c)));
    await tester.pumpAndSettle();
    expect(find.byType(ClassRulesReview), findsOneWidget);
    await tester.tap(find.text('d10'));
    await tester.ensureVisible(find.text('No spellcasting'));
    await tester.tap(find.text('No spellcasting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('class-rules-apply')));
    await tester.pumpAndSettle();
    expect(find.byType(HpIncreaseStep), findsOneWidget);
    expect(
        tester.widget<HpIncreaseStep>(find.byType(HpIncreaseStep)).hitDie, 10);
    expect(QdndBundleCodec.characterToJson(c), before);
    tester.widget<HpIncreaseStep>(find.byType(HpIncreaseStep)).onAverage();
    await tester.pumpAndSettle();
    expect(find.byType(FeaturesStep), findsNothing);
    await tester.runAsync(() async {
      tester.widget<SummaryStep>(find.byType(SummaryStep)).onConfirm();
      await GameplayActionsService.serializeCharacter(
          c, () => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(c.level, 3);
    expect(c.currentHp, 10);
    expect(c.maxHp, 16);
    expect(CharacterClassRules.resolve(c.classes.single).data.rulesEdition,
        '2014');
    expect(
        CharacterClassRules.resolve(
                StorageService.getCharacter(c.id)!.classes.single)
            .data
            .hitDie,
        10);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'An explicitly unsupported edition cannot silently use the 2014 advancement tables',
      (tester) async {
    final c = fixtures.hero();
    final json = QdndBundleCodec.classToJson(
        CharacterDataService.getClassById('fighter')!);
    json['rulesMetadata'] = {'edition': '2024'};
    CharacterClassRules.capture(QdndBundleCodec.classFromJson(json))
        .attachTo(c.classes.single);
    final before = QdndBundleCodec.characterToJson(c);
    await tester.pumpWidget(app(LevelUpScreen(character: c)));
    await tester.pumpAndSettle();
    expect(find.byType(HpIncreaseStep), findsNothing);
    expect(find.byType(ClassRulesReview), findsNothing);
    expect(find.textContaining('This rules edition is not yet supported'),
        findsOneWidget);
    expect(QdndBundleCodec.characterToJson(c), before);
  });
  testWidgets(
      'A level with only ASI goes directly to ability choices without a duplicate class-feature page',
      (tester) async {
    final c = fixtures.hero()..level = 3;
    c.classes.single.level = 3;
    c.classes.single.subclass = 'champion';
    await tester.pumpWidget(app(LevelUpScreen(character: c)));
    await tester.pumpAndSettle();
    tester.widget<HpIncreaseStep>(find.byType(HpIncreaseStep)).onAverage();
    await tester.pumpAndSettle();
    expect(find.byType(AsiStep), findsOneWidget);
    expect(
        tester.widget<AdvancementRoute>(find.byType(AdvancementRoute)).labels,
        ['HP', 'Abilities', 'Review']);
    expect(find.byType(FeaturesStep), findsNothing);
    expect(c.level, 3);
    await tester.tap(find.byKey(const ValueKey('asi-ability-strength')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('asi-ability-strength')));
    await tester.pumpAndSettle();
    tester.widget<AsiStep>(find.byType(AsiStep)).onNext();
    await tester.pumpAndSettle();
    expect(find.byType(SummaryStep), findsOneWidget);
    await tester.runAsync(() async {
      tester.widget<SummaryStep>(find.byType(SummaryStep)).onConfirm();
      await GameplayActionsService.serializeCharacter(
          c, () => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(c.level, 4);
    expect(c.abilityScores.strength, 12);
    expect(c.knownSpells, isEmpty);
    expect(c.spellSlots, isEmpty);
    expect(c.currentHp, 10);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        'Summary stays readable on a narrow screen in $locale and uses actual HP/proficiency',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = fixtures.hero()
        ..currentHp = 18
        ..maxHp = 30;
      final next = QdndBundleCodec.cloneCharacter(c)
        ..level = 2
        ..maxHp = 36;
      next.classes.single.level = 2;
      await tester.pumpWidget(app(
          SummaryStep(
              character: c,
              nextLevel: 2,
              hpIncrease: 6,
              newFeatures: const [],
              previewBuilder: () => next,
              onConfirm: () {}),
          locale: locale,
          dark: locale == 'ru',
          scale: 1.3));
      await tester.pumpAndSettle();
      expect(find.text('18/36'), findsOneWidget);
      final prof =
          find.byKey(const ValueKey('progression-summary-proficiency'));
      expect(
          find.descendant(of: prof, matching: find.text('+2')), findsOneWidget);
      expect(c.maxHp, 30);
      expect(tester.takeException(), isNull);
    });
  }
  for (final locale in ['ru', 'en']) {
    testWidgets(
        'Review includes newly gained training and expertise in $locale',
        (tester) async {
      final before = fixtures.hero()..proficientSkills = ['arcana'];
      final next = QdndBundleCodec.cloneCharacter(before)
        ..level = 2
        ..proficientSkills = ['arcana', 'history']
        ..expertSkills = ['arcana'];
      next.classes.single.level = 2;
      await tester.pumpWidget(app(
          SummaryStep(
              character: before,
              nextLevel: 2,
              hpIncrease: 0,
              newFeatures: const [],
              onConfirm: () {},
              previewBuilder: () => next),
          locale: locale));
      final history = find.text(locale == 'ru' ? 'История' : 'History');
      final list = find
          .descendant(
              of: find.byType(SummaryStep), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(history, 160, scrollable: list);
      expect(history, findsOneWidget);
      expect(find.text(locale == 'ru' ? 'Компетентность' : 'Expertise'),
          findsOneWidget);
      expect(before.expertSkills, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Full metamagic choices replace the earliest selection and can still be deselected',
      (tester) async {
    final c = fixtures.hero();
    final choice = AdvancementChoiceCatalog(FeatureService.allFeatures)
        .forLevel(
            classId: 'sorcerer',
            level: 3,
            features: [FeatureService.getFeatureById('metamagic-1')!]).single;
    var picks = <String>{};
    await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
            child: AdvancementChoiceCard(
                choice: choice,
                character: c,
                classLevel: 3,
                title: 'Metamagic',
                selected: picks,
                labelFor: (option) => option.feature!.nameEn,
                onChanged: (values) => setState(() => picks = values))))));
    final first = choice.options[0].id;
    final second = choice.options[1].id;
    final third = choice.options[2].id;
    await tester.tap(find.byKey(ValueKey('advancement-option-$first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('advancement-option-$second')));
    await tester.pumpAndSettle();
    expect(picks, {first, second});
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('advancement-option-$third')));
    await tester.pumpAndSettle();
    expect(picks.toList(), [second, third]);
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('advancement-option-$first')));
    await tester.pumpAndSettle();
    expect(picks.toList(), [third, first]);
    await tester.tap(find.byKey(ValueKey('advancement-option-$first')));
    await tester.pumpAndSettle();
    expect(picks, {third});
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'A one-place skill choice switches immediately but keeps learned and ineligible options blocked',
      (tester) async {
    final hero = fixtures.hero()..proficientSkills = ['athletics'];
    final choice = AdvancementChoice(
        id: 'training',
        kind: AdvancementChoiceKind.skillProficiency,
        count: 1,
        options: const [
          AdvancementOption('arcana'),
          AdvancementOption('history'),
          AdvancementOption('athletics'),
          AdvancementOption('religion', minimumClassLevel: 8),
        ]);
    var picks = <String>{};
    await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
            child: AdvancementChoiceCard(
                choice: choice,
                character: hero,
                classLevel: 3,
                title: 'Training',
                selected: picks,
                labelFor: (o) => o.id,
                onChanged: (v) => setState(() => picks = v))))));
    for (final id in ['arcana', 'history', 'athletics', 'religion']) {
      final tile = find.byKey(ValueKey('advancement-option-$id'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(picks, id == 'arcana' ? {'arcana'} : {'history'});
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Spell replacement works while the old choices are hidden by search',
      (tester) async {
    final hero = fixtures.hero();
    var spells = <String>[];
    await tester.pumpWidget(app(FeaturesStep(
        content: FeaturesStepContent.magic,
        character: hero,
        newFeatures: const [],
        newSpellSlots: const [3],
        oldSpellSlots: const [2],
        onNext: () {},
        classData: CharacterDataService.getClassById('wizard')!,
        nextLevel: 2,
        spellsToLearnCount: 2,
        onOptionSelected: (_, __) {},
        onExpertiseChanged: (_) {},
        onOptionalFeaturesChanged: (_) {},
        onSpellsSelected: (v) => spells = v,
        onMasterySpellsSelected: (_) {},
        onSignatureSpellsSelected: (_) {})));
    await tester.pumpAndSettle();
    const ids = ['magic-missile', 'shield', 'sleep'];
    for (final id in ids) {
      final search = find.byKey(const ValueKey('advancement-spell-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, SpellService.getSpellById(id)!.nameEn);
      await tester.pumpAndSettle();
      final tile = find.byKey(ValueKey('advancement-spell-$id'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    expect(spells, ['shield', 'sleep']);
    await tester.tap(find.byKey(const ValueKey('advancement-spell-sleep')));
    await tester.pumpAndSettle();
    expect(spells, ['shield']);
    expect(hero.knownSpells, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Expertise swaps the earliest choice without clearing the group',
      (tester) async {
    final hero = fixtures.hero()
      ..proficientSkills = ['acrobatics', 'stealth', 'perception'];
    var skills = <String>{};
    await tester.pumpWidget(app(FeaturesStep(
        content: FeaturesStepContent.features,
        character: hero,
        newFeatures: const [],
        newSpellSlots: const [],
        oldSpellSlots: const [],
        onNext: () {},
        classData: CharacterDataService.getClassById('rogue')!,
        nextLevel: 6,
        spellsToLearnCount: 0,
        onOptionSelected: (_, __) {},
        onExpertiseChanged: (v) => skills = Set.of(v),
        onOptionalFeaturesChanged: (_) {},
        onSpellsSelected: (_) {},
        onMasterySpellsSelected: (_) {},
        onSignatureSpellsSelected: (_) {})));
    await tester.pumpAndSettle();
    for (final id in ['acrobatics', 'stealth', 'perception']) {
      final chip = find.byKey(ValueKey('advancement-expertise-$id'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(skills.toList(), ['stealth', 'perception']);
    expect(hero.expertSkills, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Choice cards adapt to narrow large text and detail reading never changes the selection',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = fixtures.hero();
    final choice = AdvancementChoiceCatalog(FeatureService.allFeatures)
        .forLevel(
            classId: 'sorcerer',
            level: 3,
            features: [FeatureService.getFeatureById('metamagic-1')!]).single;
    var picks = <String>{};
    await tester.pumpWidget(app(
        StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
                child: AdvancementChoiceCard(
                    choice: choice,
                    character: c,
                    classLevel: 3,
                    title: 'Метамагия',
                    selected: picks,
                    labelFor: (o) => o.feature!.nameRu,
                    onChanged: (v) => setState(() => picks = v)))),
        locale: 'ru',
        dark: true,
        scale: 1.4));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Подробнее').first);
    await tester.pumpAndSettle();
    expect(picks, isEmpty);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
        find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(choice.options.first.feature!.descriptionRu)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Reading an older sorcerer without a pool cannot create or refill state',
      (tester) async {
    final c = fixtures.hero()
      ..characterClass = 'sorcerer'
      ..level = 2;
    c.classes = [
      CharacterClass(
          id: 'sorcerer', name: 'Sorcerer', level: 2, isPrimary: true)
    ];
    final before = QdndBundleCodec.characterToJson(c);
    await tester.pumpWidget(app(SingleChildScrollView(
        child: SorcererMagicWidget(
            character: c, metamagic: const [], ancestryFeatures: const []))));
    await tester.pumpAndSettle();
    expect(QdndBundleCodec.characterToJson(c), before);
    expect(c.features, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Closing the HP step cancels the delayed roll instead of advancing a disposed wizard',
      (tester) async {
    var rolls = 0;
    await tester.pumpWidget(app(HpIncreaseStep(
        hitDie: 6, conMod: 1, onAverage: () {}, onRoll: (_) => rolls++)));
    await tester.tap(find.byKey(const ValueKey('hp-method-roll')));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pump(const Duration(seconds: 2));
    expect(rolls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Real sorcerer development applies selected metamagic once, preserves damaged HP and grants only slot growth',
      (tester) async {
    final c = fixtures.hero()
      ..characterClass = 'sorcerer'
      ..level = 2
      ..subclass = 'Draconic'
      ..currentHp = 18
      ..maxHp = 30
      ..spellSlots = [1]
      ..maxSpellSlots = [3]
      ..hitDice = [1]
      ..maxHitDice = 2;
    c.classes = [
      CharacterClass(
          id: 'sorcerer',
          name: 'Sorcerer',
          level: 2,
          subclass: 'Draconic',
          isPrimary: true)
    ];
    c.knownSpells = ['magic-missile', 'shield', 'burning-hands'];
    FeatureService.addFeaturesToCharacter(c);
    c.features
        .singleWhere((f) => f.id == 'font-of-magic')
        .resourcePool!
        .currentUses = 0;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => LevelUpScreen(character: c))),
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.widget<HpIncreaseStep>(find.byType(HpIncreaseStep)).onAverage();
    await tester.pumpAndSettle();
    final card = tester.widget<AdvancementChoiceCard>(
        find.byKey(const ValueKey('progression-choice-metamagic-1')));
    card.onChanged({'metamagic-careful-spell', 'metamagic-distant-spell'});
    await tester.pumpAndSettle();
    final spell = SpellService.getSpellsForClass('sorcerer').firstWhere(
        (s) => s.level > 0 && s.level <= 2 && !c.knownSpells.contains(s.id));
    tester
        .widget<FeaturesStep>(
            find.byKey(const ValueKey(FeaturesStepContent.features)))
        .onNext();
    await tester.pumpAndSettle();
    final magicStep = find.byKey(const ValueKey(FeaturesStepContent.magic));
    final chooseMagic = tester.widget<ClassMagicStep>(magicStep);
    chooseMagic.onChanged({
      'normal': [spell.id]
    });
    await tester.pumpAndSettle();
    tester.widget<ClassMagicStep>(magicStep).onNext();
    await tester.pumpAndSettle();
    expect(
        find.text('18/35'), findsOneWidget); // CON 0 + average 4 + Draconic 1.
    final summaryScroll = find
        .descendant(
            of: find.byType(SummaryStep), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
        find.byKey(ValueKey('progression-learned-${spell.id}')), 160,
        scrollable: summaryScroll);
    expect(find.text(spell.nameEn), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('progression-resource-font-of-magic')), 160,
        scrollable: summaryScroll);
    expect(
        find.descendant(
            of: find
                .byKey(const ValueKey('progression-resource-font-of-magic')),
            matching: find.text('1/3')),
        findsOneWidget);
    await tester.drag(summaryScroll, const Offset(0, 1800));
    await tester.pumpAndSettle();
    final before = QdndBundleCodec.characterToJson(c);
    await tester.tap(find.byKey(const ValueKey('advancement-route-1')));
    await tester.pumpAndSettle();
    final retained = tester.widget<AdvancementChoiceCard>(
        find.byKey(const ValueKey('progression-choice-metamagic-1')));
    expect(retained.selected,
        {'metamagic-careful-spell', 'metamagic-distant-spell'});
    tester
        .widget<FeaturesStep>(
            find.byKey(const ValueKey(FeaturesStepContent.features)))
        .onNext();
    await tester.pumpAndSettle();
    final activeMagic = find.byKey(const ValueKey(FeaturesStepContent.magic));
    expect(
        tester
            .widget<AdvancementFooter>(find.descendant(
                of: activeMagic, matching: find.byType(AdvancementFooter)))
            .onPressed,
        isNotNull);
    tester.widget<ClassMagicStep>(activeMagic).onNext();
    await tester.pumpAndSettle();
    expect(find.text('18/35'), findsOneWidget);
    expect(QdndBundleCodec.characterToJson(c), before);
    await tester.runAsync(() async {
      await tester.tap(find.text('Confirm level-up'));
      await GameplayActionsService.serializeCharacter(
          c, () => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(c.level, 3);
    expect(c.currentHp, 18);
    expect(c.maxHp, 35);
    expect(c.spellSlots, [2, 2]);
    expect(c.hitDice, [2]);
    expect(
        c.features
            .singleWhere((f) => f.id == 'font-of-magic')
            .resourcePool!
            .currentUses,
        1);
    expect(
        c.features
            .singleWhere((f) => f.id == 'font-of-magic')
            .resourcePool!
            .maxUses,
        3);
    expect(
        c.features
            .where(
                (f) => f.id.startsWith('metamagic-') && f.id != 'metamagic-1')
            .map((f) => f.id)
            .toSet(),
        {'metamagic-careful-spell', 'metamagic-distant-spell'});
    expect(tester.takeException(), isNull);
  });
}
