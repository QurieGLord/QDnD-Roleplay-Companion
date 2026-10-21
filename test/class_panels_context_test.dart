import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/progression/character_class_context.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/progression/class_spellcasting_profile.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/fighter_combat_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/bard_inspiration_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/ki_tracker_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/warlock_magic_widget.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/rogue_tools_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/shared/class_panel_deck.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/fighter_tactics_surface.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'journal_service_test.dart' as fixtures;
import 'progression_widgets_test.dart' show app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-class-panels-');
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

  testWidgets('Pact slots and Arcanum display different recovery rules',
      (tester) async {
    final hero = fixtures.hero()
      ..characterClass = 'warlock'
      ..level = 11;
    hero.classes = [
      CharacterClass(id: 'warlock', name: 'Warlock', level: 11, isPrimary: true)
    ];
    hero.spellSlots = [0, 0, 0, 0, 2];
    hero.maxSpellSlots = [0, 0, 0, 0, 3];
    hero.features = [
      FeatureService.getFeatureById('mystic-arcanum-6th-level')!
          .copyForCharacter()
    ];
    final before = QdndBundleCodec.characterToJson(hero);
    await tester.pumpWidget(
        app(SingleChildScrollView(child: WarlockMagicWidget(character: hero))));
    await tester.pumpAndSettle();
    final pact = find.byKey(const ValueKey('warlock-pact-panel'));
    final arcanum = find.byKey(const ValueKey('warlock-arcanum-panel'));
    expect(find.descendant(of: pact, matching: find.text('Short Rest')),
        findsOneWidget);
    expect(find.descendant(of: pact, matching: find.text('Long Rest')),
        findsNothing);
    expect(find.descendant(of: arcanum, matching: find.text('Long Rest')),
        findsOneWidget);
    expect(find.descendant(of: arcanum, matching: find.text('Short Rest')),
        findsNothing);
    expect(QdndBundleCodec.characterToJson(hero), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Opening incomplete bard inspiration does not create a reserve or save',
      (tester) async {
    final hero = fixtures.hero();
    hero.classes = [
      CharacterClass(id: 'bard', name: 'Bard', level: 8, isPrimary: true)
    ];
    hero.characterClass = 'bard';
    final inspiration = CharacterFeature(
        id: 'table-inspiration',
        nameEn: 'Bardic Inspiration',
        nameRu: 'Бардовское вдохновение',
        descriptionEn: '',
        descriptionRu: '',
        type: FeatureType.resourcePool,
        minLevel: 1);
    hero.features = [inspiration];
    final before = QdndBundleCodec.characterToJson(hero);
    await tester.pumpWidget(app(SingleChildScrollView(
        child: BardInspirationWidget(
            character: hero, inspirationFeature: inspiration))));
    await tester.pumpAndSettle();
    expect(inspiration.resourcePool, isNull);
    expect(QdndBundleCodec.characterToJson(hero), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Giving inspiration spends once without rolling or changing health',
      (tester) async {
    final hero = fixtures.hero()
      ..characterClass = 'bard'
      ..level = 8;
    hero.classes = [
      CharacterClass(id: 'bard', name: 'Bard', level: 8, isPrimary: true)
    ];
    final inspiration = FeatureService.getFeatureById('bardic-inspiration-d8')!
        .copyForCharacter();
    inspiration.resourcePool!
      ..currentUses = 1
      ..maxUses = 4;
    hero.features = [inspiration];
    final hp = hero.currentHp;
    await tester.runAsync(() => StorageService.saveCharacter(hero));
    await tester.pumpWidget(app(SingleChildScrollView(
        child: BardInspirationWidget(
            character: hero, inspirationFeature: inspiration))));
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Inspire'));
      await tester.tap(find.widgetWithText(FilledButton, 'Inspire'));
      await GameplayActionsService.serializeCharacter(hero, () async {});
    });
    await tester.pumpAndSettle();
    expect(inspiration.resourcePool!.currentUses, 0);
    expect(hero.currentHp, hp);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A manual Ki maximum cannot change the martial arts die',
      (tester) async {
    final hero = fixtures.hero()
      ..characterClass = 'monk'
      ..level = 2;
    hero.classes = [
      CharacterClass(id: 'monk', name: 'Monk', level: 2, isPrimary: true)
    ];
    final ki = FeatureService.getFeatureById('ki')!.copyForCharacter();
    ki.resourcePool!
      ..currentUses = 6
      ..maxUses = 20;
    hero.features = [ki];
    final before = QdndBundleCodec.characterToJson(hero);
    await tester.pumpWidget(app(SingleChildScrollView(
        child: KiTrackerWidget(character: hero, kiFeature: ki))));
    await tester.pumpAndSettle();
    expect(find.text('1d4'), findsOneWidget);
    expect(find.text('1d10'), findsNothing);
    expect(QdndBundleCodec.characterToJson(hero), before);
    expect(tester.takeException(), isNull);
  });

  test(
      'Each class owns its level and subclass, absent classes cannot borrow the primary',
      () {
    const ids = [
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
    for (final id in ids) {
      final hero = fixtures.hero()
        ..characterClass = 'bard'
        ..subclass = 'lore'
        ..level = 11;
      final data = CharacterDataService.getClassById(id)!;
      hero.classes = [
        CharacterClass(
            id: 'other-source', name: 'Other', level: 9, isPrimary: true),
        CharacterClass(
            id: id,
            name: data.getName('en'),
            level: 2,
            subclass: data.subclasses.first.id)
      ];
      CharacterClassRules.capture(data).attachTo(hero.classes.last);
      final context = CharacterClassContext(hero, id);
      expect(context.level, 2, reason: id);
      expect(context.subclass, data.subclasses.first.id, reason: id);
      expect(context.subclassName('ru'),
          data.subclassLevel <= 2 ? data.subclasses.first.getName('ru') : null);
      hero.classes.last.level = data.subclassLevel;
      hero.level = 9 + data.subclassLevel;
      expect(context.subclassName('ru'), data.subclasses.first.getName('ru'));
      hero.classes.last.subclass = null;
      expect(context.subclass, isNull, reason: id);
      expect(CharacterClassContext(hero, 'absent').level, 0);
      expect(CharacterClassContext(hero, 'absent').subclass, isNull);
    }
  });
  test(
      'Personal class definitions remain authoritative and corrupt snapshots do not use live rules',
      () {
    final hero = fixtures.hero();
    CharacterClassRules.capture(CharacterDataService.getClassById('fighter')!)
        .attachTo(hero.classes.single);
    final context = CharacterClassContext(hero, 'fighter');
    expect(context.definition!.id, 'fighter');
    hero.classes.single.rulesSnapshot!['digest'] = 'damaged';
    expect(context.definition, isNull);
  });
  test(
      'Class spell profiles use different abilities and personal learning circles, independent of shared slots',
      () {
    final hero = fixtures.hero()..level = 10;
    hero.abilityScores.intelligence = 18;
    hero.abilityScores.wisdom = 14;
    hero.classes = [
      CharacterClass(id: 'wizard', name: 'Wizard', level: 1, isPrimary: true),
      CharacterClass(id: 'cleric', name: 'Cleric', level: 9)
    ];
    hero.maxSpellSlots = [4, 3, 3, 3, 2];
    final before = QdndBundleCodec.characterToJson(hero);
    final wizard = ClassSpellcastingProfile.resolve(hero, 'wizard')!;
    final cleric = ClassSpellcastingProfile.resolve(hero, 'cleric')!;
    expect(wizard.learningCircle, 1);
    expect(cleric.learningCircle, 5);
    expect(wizard.ability, 'intelligence');
    expect(cleric.ability, 'wisdom');
    expect(wizard.attackBonus, 8);
    expect(wizard.saveDC, 16);
    expect(cleric.attackBonus, 6);
    expect(cleric.saveDC, 14);
    expect(wizard.characterLevel, 10);
    expect(ClassSpellcastingProfile.resolve(hero, 'sorcerer'), isNull);
    expect(QdndBundleCodec.characterToJson(hero), before);
  });
  test(
      'Pact, ordinary and not-yet-acquired half casting remain distinct profiles',
      () {
    final hero = fixtures.hero()..level = 13;
    hero.classes = [
      CharacterClass(
          id: 'sorcerer', name: 'Sorcerer', level: 3, isPrimary: true),
      CharacterClass(id: 'warlock', name: 'Warlock', level: 9),
      CharacterClass(id: 'paladin', name: 'Paladin', level: 1)
    ];
    expect(
        ClassSpellcastingProfile.resolve(hero, 'sorcerer')!.learningCircle, 2);
    expect(
        ClassSpellcastingProfile.resolve(hero, 'warlock')!.learningCircle, 5);
    expect(ClassSpellcastingProfile.resolve(hero, 'warlock')!.isPact, true);
    expect(ClassSpellcastingProfile.resolve(hero, 'sorcerer')!.isPact, false);
    expect(
        ClassSpellcastingProfile.resolve(hero, 'paladin')!.learningCircle, 0);
  });
  test(
      'A personal source can change the casting ability; incomplete rules do not guess',
      () {
    final hero = fixtures.hero();
    hero.classes.single.id = 'wizard';
    hero.abilityScores.wisdom = 16;
    final data = QdndBundleCodec.classToJson(
        CharacterDataService.getClassById('wizard')!);
    data['spellcasting'] = {'ability': 'wisdom', 'type': 'full'};
    CharacterClassRules.capture(QdndBundleCodec.classFromJson(data))
        .attachTo(hero.classes.single);
    expect(ClassSpellcastingProfile.resolve(hero, 'wizard')!.ability, 'wisdom');
    expect(ClassSpellcastingProfile.resolve(hero, 'wizard')!.modifier, 3);
    data['spellcasting'] = {'ability': 'luck', 'type': 'full'};
    CharacterClassRules.capture(QdndBundleCodec.classFromJson(data))
        .attachTo(hero.classes.single);
    expect(() => ClassSpellcastingProfile.resolve(hero, 'wizard'),
        throwsFormatException);
    data['spellcasting'] = {'ability': 'wisdom', 'type': 'full'};
    data['rulesMetadata'] = {'edition': '2024'};
    CharacterClassRules.capture(QdndBundleCodec.classFromJson(data))
        .attachTo(hero.classes.single);
    expect(() => ClassSpellcastingProfile.resolve(hero, 'wizard'),
        throwsUnsupportedError);
  });
  testWidgets(
      'Switching class panels keeps local state and hides inactive actions',
      (tester) async {
    Widget deck() => app(const SingleChildScrollView(
            child: ClassPanelDeck(panels: [
          ClassPanelEntry(
              id: 'fighter',
              name: 'Fighter',
              level: 2,
              child: _PanelCounter(name: 'fighter')),
          ClassPanelEntry(
              id: 'rogue',
              name: 'Rogue',
              level: 5,
              child: _PanelCounter(name: 'rogue')),
        ])));
    await tester.pumpWidget(deck());
    await tester.tap(find.text('fighter: 0'));
    await tester.pumpAndSettle();
    expect(find.text('fighter: 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-rogue')));
    await tester.pumpAndSettle();
    expect(find.text('fighter: 1'), findsNothing);
    expect(find.text('rogue: 0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-fighter')));
    await tester.pumpAndSettle();
    expect(find.text('fighter: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'A library-owned class retains its panel in the inline class selector',
      (tester) async {
    final hero = fixtures.hero()
      ..level = 5
      ..characterClass = 'rogue';
    hero.classes = [
      CharacterClass(id: 'rogue', name: 'Rogue', level: 3, isPrimary: true),
      CharacterClass(id: 'library:fighter', name: 'Fighter', level: 2)
    ];
    final data = QdndBundleCodec.classToJson(
        CharacterDataService.getClassById('fighter')!);
    data['id'] = 'library:fighter';
    data['sourceId'] = 'book';
    CharacterClassRules.capture(QdndBundleCodec.classFromJson(data))
        .attachTo(hero.classes.last);
    hero.features = [
      for (final id in ['sneak-attack', 'second-wind', 'action-surge-1-use'])
        FeatureService.getFeatureById(id)!.copyForCharacter()
    ];
    final before = QdndBundleCodec.characterToJson(hero);
    await tester.pumpWidget(app(AbilitiesTab(character: hero)));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('class-panel-tab-fighter')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-fighter')));
    await tester.pumpAndSettle();
    expect(find.byType(FighterCombatWidget), findsOneWidget);
    expect(QdndBundleCodec.characterToJson(hero), before);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'The actual sheet exposes a secondary class panel without changing the hero',
      (tester) async {
    final hero = fixtures.hero()..level = 7;
    hero.classes = [
      CharacterClass(
          id: 'rogue',
          name: 'Rogue',
          level: 5,
          isPrimary: true,
          subclass: 'thief'),
      CharacterClass(id: 'fighter', name: 'Fighter', level: 2)
    ];
    hero.characterClass = 'rogue';
    hero.subclass = 'thief';
    hero.features = [
      for (final id in ['sneak-attack', 'second-wind', 'action-surge-1-use'])
        FeatureService.getFeatureById(id)!.copyForCharacter()
    ];
    final before = QdndBundleCodec.characterToJson(hero);
    await tester.pumpWidget(app(AbilitiesTab(character: hero)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RogueToolsWidget), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-fighter')));
    await tester.pumpAndSettle();
    expect(find.byType(FighterCombatWidget), findsOneWidget);
    expect(find.byType(RogueToolsWidget), findsNothing);
    final action = tester.widget<FighterTacticsSurface>(
        find.byKey(const ValueKey('fighter-action-second-wind')));
    expect(action.bonus, 2);
    expect(find.text('Thief'), findsNothing);
    expect(QdndBundleCodec.characterToJson(hero), before);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        'All three fighter gestures fit together at ordinary and large text in $locale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hero = fixtures.hero()..level = 20;
      hero.classes.single.level = 20;
      hero.features = [
        for (final id in [
          'second-wind',
          'action-surge-2-uses',
          'indomitable-3-uses'
        ])
          FeatureService.getFeatureById(id)!.copyForCharacter()
      ];
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(app(
            SingleChildScrollView(
                child: FighterCombatWidget(
                    character: hero,
                    secondWindFeature: hero.features[0],
                    actionSurgeFeature: hero.features[1],
                    indomitableFeature: hero.features[2])),
            locale: locale,
            scale: scale));
        await tester.pumpAndSettle();
        expect(find.byType(FighterTacticsSurface), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets(
        'Fighter panel keeps excess visible at narrow large text in $locale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hero = fixtures.hero();
      final feature =
          FeatureService.getFeatureById('second-wind')!.copyForCharacter();
      feature.resourcePool!
        ..currentUses = 6
        ..maxUses = 0;
      hero.features = [feature];
      await tester.pumpWidget(app(
          SingleChildScrollView(
              child: FighterCombatWidget(
                  character: hero, secondWindFeature: hero.features.single)),
          locale: locale,
          dark: locale == 'ru',
          scale: 1.5));
      await tester.pumpAndSettle();
      expect(find.text('6 / 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('Class ownership preserves choice options and rejects foreign owners',
      () {
    final hero = fixtures.hero();
    final context = CharacterClassContext(hero, 'fighter');
    final defense =
        FeatureService.getFeatureById('fighter-fighting-style-defense')!
            .copyForCharacter();
    expect(defense.associatedClass, 'Optional');
    expect(context.acceptsFeature(defense), isTrue);
    final foreign = FeatureService.getFeatureById('bardic-inspiration-d8')!
        .copyForCharacter();
    expect(context.acceptsFeature(foreign), isFalse);
  });

  testWidgets(
      'Joined fighter controls keep taps and holds on their own resource',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final taps = <FighterTactic>[];
    final edits = <FighterTactic>[];
    Widget control(FighterTactic tactic) => FighterTacticsSurface(
        key: ValueKey(tactic),
        tactic: tactic,
        joined: true,
        name: tactic.name,
        current: 1,
        maximum: 1,
        recovery: 'Short rest',
        onEdit: () => edits.add(tactic),
        onActivate: () => taps.add(tactic));
    await tester.pumpWidget(app(SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: FighterTacticsCluster(
                overlap: 30,
                primary: control(FighterTactic.secondWind),
                secondary: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(child: control(FighterTactic.actionSurge)),
                      const SizedBox(width: 6),
                      Expanded(child: control(FighterTactic.indomitable)),
                    ])))))));
    await tester.pumpAndSettle();
    for (final tactic in FighterTactic.values) {
      await tester.tap(find.byKey(ValueKey(tactic)));
      await tester.pumpAndSettle();
    }
    expect(taps, FighterTactic.values);
    await tester
        .longPress(find.byKey(const ValueKey(FighterTactic.actionSurge)));
    await tester.pumpAndSettle();
    expect(edits, [FighterTactic.actionSurge]);
    expect(taps, FighterTactic.values);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'The healing die spends once, shows its result and cannot restore an empty resource by tapping',
      (tester) async {
    final hero = fixtures.hero()
      ..level = 2
      ..currentHp = 1
      ..maxHp = 100;
    hero.classes.single.level = 2;
    hero.features = [
      FeatureService.getFeatureById('second-wind')!.copyForCharacter()
    ];
    hero.features.single.resourcePool!.currentUses = 1;
    await tester.runAsync(() => StorageService.saveCharacter(hero));
    await tester.pumpWidget(app(SingleChildScrollView(
        child: FighterCombatWidget(
            character: hero, secondWindFeature: hero.features.single))));
    final surface = find.byKey(const ValueKey('fighter-action-second-wind'));
    await tester.runAsync(() async {
      await tester.tap(surface);
      await GameplayActionsService.serializeCharacter(hero, () async {});
    });
    await tester.pumpAndSettle();
    expect(hero.features.single.resourcePool!.currentUses, 0);
    final panel = tester.widget<FighterTacticsSurface>(surface);
    expect(panel.lastRoll, inInclusiveRange(1, 10));
    expect(hero.currentHp, 1 + panel.lastRoll! + 2);
    expect(find.text('Use'), findsNothing);
    final hp = hero.currentHp;
    await tester.tap(surface);
    await tester.pumpAndSettle();
    expect(hero.currentHp, hp);
    expect(hero.features.single.resourcePool!.currentUses, 0);
    expect(tester.takeException(), isNull);
  });
}

class _PanelCounter extends StatefulWidget {
  const _PanelCounter({required this.name});
  final String name;
  @override
  State<_PanelCounter> createState() => _PanelCounterState();
}

class _PanelCounterState extends State<_PanelCounter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.name}: $count'));
}
