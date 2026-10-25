import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/features/character_sheet/widgets/overview_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/spell_slots_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/gameplay_state_editor.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/life_band.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'gameplay_state_editor_test.dart' as fixtures;

Finder field(String id) => find.byKey(ValueKey('sheet-value-$id'));
Widget app(Widget child,
        {Locale locale = const Locale('en'), double scale = 1}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: child),
    );
Future<void> save(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('sheet-value-save')));
    await Hive.box<Character>('characters').flush();
  });
  await tester.pumpAndSettle();
}

Future<void> applyPad(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('hp-keypad-apply')));
    await Hive.box<Character>('characters').flush();
  });
  await tester.pumpAndSettle();
}

void mobile(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_session_widgets_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await SpellService.loadSpells();
  });
  setUp(() async {
    await Hive.box<Character>('characters').clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets(
      'HP opens only its own fields, saves an excess and discards cancelled drafts',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero()..armorClass = 19;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(OverviewTab(character: c)));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    expect(find.byType(GameplayStateEditor), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.enterText(field('current'), '31');
    await save(tester);
    expect(c.currentHp, 31);
    expect(c.armorClass, 19);
    expect(StorageService.getCharacter(c.id)!.currentHp, 31);
    await tester.longPress(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    await tester.enterText(field('current'), '99');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.currentHp, 31);
    expect(tester.takeException(), isNull);
  });

  testWidgets('health actions use temporary HP and reject zero damage',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero()..temporaryHp = 7;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(OverviewTab(character: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    // Nothing typed yet: the pad cannot apply zero.
    await tester.tap(find.byKey(const ValueKey('hp-key-0')));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('hp-keypad-apply')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('hp-key-1')));
    await tester.tap(find.byKey(const ValueKey('hp-key-0')));
    await tester.pump();
    expect(find.text('Take 10 damage'), findsOneWidget);
    await applyPad(tester);
    expect(c.currentHp, 14);
    expect(c.temporaryHp, 0);
    await tester.tap(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hp-mode-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hp-key-5')));
    await applyPad(tester);
    expect(c.currentHp, 19);
    // The pad remembers the last amount for this hero.
    await tester.tap(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    expect(find.text('same as last · 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hp-mode-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('same as last · 5'));
    await applyPad(tester);
    expect(c.temporaryHp, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC opens its own manual/automatic choice', (tester) async {
    mobile(tester);
    final c = fixtures.hero()..armorClass = 19;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(OverviewTab(character: c)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('19'));
    await tester.longPress(find.text('19'));
    await tester.pumpAndSettle();
    // The breakdown comes first; the calculation stays visible.
    expect(find.byKey(const ValueKey('ac-breakdown-total')), findsOneWidget);
    expect(find.text('Pinned by hand: 19. From gear: ${c.calculatedArmorClass}.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ac-breakdown-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-auto-value')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-auto-value')));
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.usesAutomaticArmorClass, isTrue);
    expect(c.armorClass, c.calculatedArmorClass);
  });

  testWidgets('slot card tap spends and hold edits without also consuming',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(SingleChildScrollView(
        child: SpellSlotsWidget(character: c, onChanged: () {}))));
    await tester.pumpAndSettle();
    final scope = find.byKey(const ValueKey('slot-counter-1'));
    await tester.runAsync(() async {
      await tester.tap(scope);
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    expect(c.spellSlots, [5]);
    await tester.longPress(scope);
    await tester.pumpAndSettle();
    expect(c.spellSlots, [5]);
    await tester.enterText(field('value'), '7');
    await save(tester);
    expect(c.spellSlots, [7]);
    expect(c.maxSpellSlots, [4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'generic resource edits from actual AbilitiesTab retain library content',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(AbilitiesTab(character: c)));
    await tester.pumpAndSettle();
    final counter = find.byKey(const ValueKey('counter-edit-Library reserve'));
    await tester.scrollUntilVisible(counter, 200,
        scrollable: find
            .descendant(
                of: find.byType(AbilitiesTab),
                matching: find.byType(Scrollable))
            .first);
    await tester.longPress(counter);
    await tester.pumpAndSettle();
    expect(c.features.single.resourcePool!.currentUses, 6);
    await tester.enterText(field('value'), '9');
    await save(tester);
    expect(c.features.single.resourcePool!.currentUses, 9);
    expect(c.features.single.descriptionEn, 'Installed library text');
    expect(c.features.single.sourceId, 'test-source');
    expect(tester.takeException(), isNull);
  });

  testWidgets('small RU overview and counters support large text',
      (tester) async {
    mobile(tester, width: 320);
    final c = fixtures.hero()
      ..currentHp = 31
      ..temporaryHp = 7;
    await tester.pumpWidget(
        app(OverviewTab(character: c), locale: const Locale('ru'), scale: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LifeSection), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(
        SingleChildScrollView(
            child: SpellSlotsWidget(character: c, onChanged: () {})),
        locale: const Locale('ru'),
        scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('active form exposes its own HP without replacing character HP',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero()
      ..isWildShaped = true
      ..beastName = 'Wolf'
      ..beastCurrentHp = 4
      ..beastMaxHp = 8;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(
        app(SingleChildScrollView(child: LifeSection(character: c))));
    await tester.pumpAndSettle();
    expect(find.text('WOLF'), findsOneWidget);
    expect(find.text('Character HP: 17 / 20'), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextFormField>(field('current')).controller!.text, '4');
    await tester.enterText(field('current'), '10');
    await save(tester);
    expect(c.beastCurrentHp, 10);
    expect(c.currentHp, 17);
    expect(c.isWildShaped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('damage shows the concentration check without clearing its mark',
      (tester) async {
    mobile(tester);
    // Enough HP to stay up: falling to 0 would end the concentration.
    final c = fixtures.hero()
      ..concentratingOn = 'focus'
      ..maxHp = 40
      ..currentHp = 40;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(
        app(SingleChildScrollView(child: LifeSection(character: c))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hp-key-3')));
    await tester.tap(find.byKey(const ValueKey('hp-key-0')));
    await applyPad(tester);
    expect(c.concentratingOn, 'focus');
    expect(find.text('Concentration: Constitution save DC 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Last: intentionally make the backing store unavailable.
  testWidgets(
      'failed contextual save keeps dialog open and previous values intact',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(OverviewTab(character: c)));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('life-number')));
    await tester.pumpAndSettle();
    await tester.enterText(field('current'), '31');
    await tester.runAsync(() => Hive.box<Character>('characters').close());
    await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('sheet-value-save'))));
    await tester.pumpAndSettle();
    expect(c.currentHp, 17);
    expect(find.byKey(const ValueKey('sheet-value-editor')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('sheet-value-save-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
