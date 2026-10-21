import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/ui/companion_surface.dart';
import 'package:qd_and_d/features/character_level_up/steps/features_step.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/magic_slots.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/progression/character_training.dart';
import 'package:qd_and_d/core/services/hit_dice_rest_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/sorcery_actions_service.dart';
import 'package:qd_and_d/core/services/magic_resource_actions_service.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'package:qd_and_d/features/character_level_up/steps/hp_increase_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/class_magic_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/summary_step.dart';
import 'package:qd_and_d/shared/widgets/spell_cast_sheet.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'multiclass_magic_flow_test.dart' as flow;

Widget app(Widget child, {double scale = 1, String locale = 'en'}) =>
    MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(body: child));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-multi-sheet-');
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
      'Short rest spends dice from the selected class and heals only actual missing HP',
      () async {
    final c = flow.mixed({'fighter': 3, 'wizard': 2})
      ..hitDice = [2, 1]
      ..maxHitDice = 5
      ..currentHp = 8
      ..maxHp = 10;
    final healed =
        await HitDiceRestService.shortRest(c, [const HitDieRoll('wizard', 6)]);
    expect(healed, 2);
    expect(c.currentHp, 10);
    expect(c.hitDice, [2, 0]);
  });
  test('Failed rest rolls back dice, HP and rest resources in one transaction',
      () async {
    final c = flow.mixed({'wizard': 3, 'warlock': 3})
      ..hitDice = [1, 1]
      ..currentHp = 3
      ..maxHp = 20;
    flow.slots(c, pact: 0);
    final before = jsonEncode(c.toJson());
    await expectLater(
        HitDiceRestService.shortRest(c, [const HitDieRoll('wizard', 4)],
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test('Overfilled dice in one class do not block recovery of the other class',
      () {
    final c = flow.mixed({'fighter': 3, 'wizard': 2})
      ..hitDice = [6, 0]
      ..maxHitDice = 5;
    c.longRest();
    expect(c.hitDice, [6, 2]);
  });
  test(
      'Shared-slot recovery never changes Pact slots or exceeds the class budget',
      () async {
    final c = flow.mixed({'wizard': 3, 'warlock': 3});
    flow.slots(c, shared: 0, pact: 1, maxShared: 4);
    await MagicResourceActionsService.recover(c, {1: 2}, classId: 'wizard');
    expect(c.spellSlots, [2]);
    expect(MagicSlots.read(c).pact!.current, 1);
    await expectLater(
        MagicResourceActionsService.recover(c, {1: 1}, classId: 'wizard'),
        throwsStateError);
  });
  test(
      'Sorcery conversion can consume Pact and created slots expire without erasing unrelated extras',
      () async {
    final c = flow.mixed({'sorcerer': 3, 'warlock': 3});
    flow.slots(c, shared: 6, pact: 2, maxShared: 4);
    await SorceryActionsService.setCurrent(c, 10);
    await SorceryActionsService.convert(c, 1, creating: true);
    expect(c.spellSlots, [7]);
    await SorceryActionsService.convert(c, 2,
        creating: false, payment: MagicPool.pact);
    expect(MagicSlots.read(c).pact!.current, 1);
    expect(c.spellSlots, [7]);
    c.longRest();
    expect(c.spellSlots, [6]);
  });
  test(
      'Entry training does not grant a second starting package or add extra attacks together',
      () {
    final c = flow.mixed({'wizard': 3, 'fighter': 2});
    c.classes.last.entryProficiencies = ['armor:light', 'weapon:martial'];
    expect(CharacterTraining.tokens(c), contains('weapon:martial'));
    expect(CharacterTraining.tokens(c), isNot(contains('armor:heavy')));
  });
  testWidgets(
      'The class picker connects a new wizard to the real advancement and owned spellbook',
      (tester) async {
    final c = flow.mixed({'fighter': 3})
      ..hitDice = [2]
      ..maxHitDice = 3;
    c.abilityScores = c.abilityScores.copyWith(strength: 14, intelligence: 16);
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => LevelUpScreen(character: c))),
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advancement-choose-class')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Wizard'), 300,
        scrollable: find
            .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Wizard'));
    await tester.pumpAndSettle();
    tester.widget<HpIncreaseStep>(find.byType(HpIncreaseStep)).onAverage();
    await tester.pumpAndSettle();
    if (find.byType(FeaturesStep).evaluate().isNotEmpty) {
      tester.widget<FeaturesStep>(find.byType(FeaturesStep)).onNext();
      await tester.pumpAndSettle();
    }
    final magic = tester.widget<ClassMagicStep>(find.byType(ClassMagicStep));
    final selections = <String, List<String>>{};
    for (final choice in magic.plan.choices) {
      selections[choice.key] =
          choice.options.take(choice.count).map((s) => s.id).toList();
    }
    magic.onChanged(selections);
    await tester.pumpAndSettle();
    tester.widget<ClassMagicStep>(find.byType(ClassMagicStep)).onNext();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      tester.widget<SummaryStep>(find.byType(SummaryStep)).onConfirm();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    expect(c.level, 4);
    expect(c.classes.map((c) => c.id), ['fighter', 'wizard']);
    expect(c.classes.last.level, 1);
    expect(c.hitDice, [2, 1]);
    expect(SpellbookState.read(c.spellbookData).ids('class:wizard', 'known'),
        hasLength(9));
    expect(c.spellSlots.first, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Prepared combat spell does not default to a ten-minute ritual',
      (tester) async {
    final c = flow.mixed({'wizard': 3, 'warlock': 3}),
        spell = flow.spell(ritual: true);
    flow.slots(c);
    flow.learn(c, spell, 'class:wizard', prepared: true);
    await tester
        .pumpWidget(app(SpellCastSheet(hero: c, spell: spell), locale: 'ru'));
    await tester.pumpAndSettle();
    final ritual = find.ancestor(
        of: find.text('Ритуал'), matching: find.byType(CompanionSurface));
    expect(tester.widget<CompanionSurface>(ritual).raised, isFalse);
    expect(find.text('Наложить заклинание'), findsOneWidget);
    await tester.tap(find.text('Ритуал'));
    await tester.pumpAndSettle();
    expect(tester.widget<CompanionSurface>(ritual).raised, isTrue);
    expect(find.text('Провести ритуал'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['ru', 'en']) {
    testWidgets(
        'Casting restriction requires a fresh explicit table exception in $locale',
        (tester) async {
      final c = flow.mixed({'wizard': 3}), spell = flow.spell();
      flow.learn(c, spell, 'class:wizard', prepared: true);
      c.isRaging = true;
      c.spellSlots = [2];
      c.maxSpellSlots = [2];
      final baseline = QdndBundleCodec.characterToJson(c);
      await tester.pumpWidget(app(SpellCastSheet(hero: c, spell: spell),
          locale: locale, scale: 1.7));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('spell-cast-confirm')))
              .onPressed,
          isNull);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('spell-cast-confirm')))
              .onPressed,
          isNotNull);
      expect(QdndBundleCodec.characterToJson(c), baseline);
      expect(tester.takeException(), isNull);
    });
  }
  for (final locale in ['ru', 'en']) {
    testWidgets(
        'Cast choices show independent shared and Pact payments without overflow in $locale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = flow.mixed({'wizard': 3, 'warlock': 3}), s = flow.spell();
      flow.slots(c);
      flow.learn(c, s, 'class:wizard', prepared: true);
      flow.learn(c, s, 'class:warlock');
      await tester.pumpWidget(
          app(SpellCastSheet(hero: c, spell: s), scale: 1.7, locale: locale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
