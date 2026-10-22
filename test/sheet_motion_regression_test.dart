import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/features/character_sheet/character_sheet_screen.dart';
import 'package:qd_and_d/features/character_sheet/tabs/inventory_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/expandable_character_card.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/value_editor_dialog.dart';
import 'package:qd_and_d/features/journal/journal_appear.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget child, {bool reduced = false}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!),
    home: child);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-motion-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await ItemService.loadItems();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets(
      'Distant taps interpolate across pages and inventory has exactly one add button',
      (tester) async {
    final c = fixtures.hero();
    await tester.pumpWidget(app(CharacterSheetScreen(character: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final page =
        tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    expect(page, greaterThan(0));
    expect(page, lessThan(4));
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 4);
    await tester.tap(find.byKey(const ValueKey('sheet-tab-3')));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.widget<InventoryTab>(find.byType(InventoryTab)).showAddButton,
        isFalse);
    await tester.tap(find.byKey(const ValueKey('sheet-add-item')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.build), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('The folded island stays on top of the page it floats over',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(CharacterSheetScreen(character: fixtures.hero())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-1')));
    await tester.pumpAndSettle();
    final nested =
        tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    final outer = nested.outerController.position;
    expect(outer.pixels, closeTo(outer.maxScrollExtent, 1));
    // Scroll the page so its content sits right under the island.
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -300));
    await tester.pumpAndSettle();
    final home = tester.getCenter(find.byKey(const ValueKey('sheet-tab-0')));
    final hit = tester.hitTestOnBinding(home);
    expect(
        hit.path.any((e) =>
            e.target is RenderObject &&
            (e.target as RenderObject).debugCreator.toString().contains('sheet-tab-0')),
        isTrue);
    await tester.tapAt(home);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A half-unfolded hero card settles at an end, never between',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(CharacterSheetScreen(character: fixtures.hero())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-1')));
    await tester.pumpAndSettle();
    final outer = tester
        .state<NestedScrollViewState>(find.byType(NestedScrollView))
        .outerController
        .position;
    final fold = outer.maxScrollExtent;
    // A small pull folds back.
    final small = await tester.startGesture(const Offset(195, 500));
    await small.moveBy(const Offset(0, 30));
    await small.moveBy(const Offset(0, 20));
    await small.up();
    await tester.pumpAndSettle();
    expect(outer.pixels, closeTo(fold, 1));
    // A deliberate pull opens the card fully.
    final pull = await tester.startGesture(const Offset(195, 400));
    for (var i = 0; i < 10; i++) {
      await pull.moveBy(Offset(0, fold * .06));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pull.up();
    await tester.pumpAndSettle();
    expect(outer.pixels, closeTo(0, 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Rapid taps settle on the requested destination and swipe still works',
      (tester) async {
    await tester
        .pumpWidget(app(CharacterSheetScreen(character: fixtures.hero())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-4')));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 4);
    // Swipe across the lower part of the page, clear of the journal's search
    // field (a text field keeps horizontal drags for selection).
    final lower = tester.getBottomLeft(find.byType(PageView)) +
        const Offset(100, -60);
    await tester.dragFrom(lower, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 3);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Every incoming sheet tab resets nested and independent scroll positions',
      (tester) async {
    final c = fixtures.hero();
    c.journalNotes.addAll([
      for (var i = 0; i < 25; i++)
        JournalNote(
            id: 'note-$i', title: 'Entry $i', content: 'A remembered story.')
    ]);
    c.features.addAll([
      for (var i = 0; i < 24; i++)
        CharacterFeature(
            id: 'trait-${String.fromCharCode(65 + i)}',
            nameEn: 'Trait $i',
            nameRu: 'Черта $i',
            descriptionEn: 'A useful detail.',
            descriptionRu: 'Полезная деталь.',
            type: FeatureType.action,
            minLevel: 1)
    ]);
    await tester.pumpWidget(app(CharacterSheetScreen(character: c)));
    await tester.pumpAndSettle();
    final nested =
        tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    for (final pair in [(1, 4), (4, 3), (3, 0)]) {
      await tester.tap(find.byKey(ValueKey('sheet-tab-${pair.$1}')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(0, -850));
      await tester.pumpAndSettle();
      if (pair.$1 != 3) {
        expect(
            nested.innerController.positions
                .any((p) => p.pixels > p.minScrollExtent + 10),
            isTrue);
      }
      await tester.tap(find.byKey(ValueKey('sheet-tab-${pair.$2}')));
      await tester.pumpAndSettle();
      // Overview unfolds the hero card; other tabs fold it into the bar.
      final outer = nested.outerController.position;
      expect(outer.pixels,
          closeTo(pair.$2 == 0 ? 0 : outer.maxScrollExtent, 1));
      for (final position in nested.innerController.positions) {
        expect(position.pixels, closeTo(position.minScrollExtent, 1));
      }
    }
    await tester.tap(find.byKey(const ValueKey('sheet-tab-2')));
    await tester.pumpAndSettle();
    final magic = tester
        .widget<ListView>(find
            .descendant(
                of: find.byType(AbilitiesTab), matching: find.byType(ListView))
            .first)
        .controller!;
    await tester.drag(find.byType(PageView), const Offset(0, -850));
    await tester.pumpAndSettle();
    expect(magic.offset, greaterThan(10));
    await tester.tap(find.byKey(const ValueKey('sheet-tab-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-tab-2')));
    await tester.pumpAndSettle();
    expect(magic.offset, closeTo(0, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'The sheet handle dismisses with a slow pull and never saves a draft',
      (tester) async {
    var saved = 0;
    await tester.pumpWidget(app(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => showSheetValueEditor(context,
                    title: 'Health',
                    icon: Icons.favorite,
                    fields: const [SheetNumberField('hp', 'HP', 10)],
                    onSave: (_, __) async => saved++),
                child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sheet-value-hp')), '99');
    final gesture = await tester.startGesture(tester
        .getCenter(find.byKey(const ValueKey('sheet-value-drag-handle'))));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-value-editor')), findsNothing);
    expect(saved, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Indicator editors open unfocused and dismiss from the broad title',
      (tester) async {
    await tester.pumpWidget(app(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => showSheetValueEditor(context,
                    title: 'Health',
                    icon: Icons.favorite,
                    description: 'Current and maximum health.',
                    fields: const [SheetNumberField('hp', 'HP', 10)],
                    onSave: (_, __) async {}),
                child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    final input = tester.widget<EditableText>(find.byType(EditableText));
    expect(input.focusNode.hasFocus, isFalse);
    await tester.drag(find.text('Health'), const Offset(0, 85));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-value-editor')), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-value-hp')));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Pulling content at the top dismisses while ordinary upward scrolling does not',
      (tester) async {
    await tester.pumpWidget(app(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => showSheetValueEditor(context,
                    title: 'Health',
                    icon: Icons.favorite,
                    description: 'Pull from here to close.',
                    fields: const [SheetNumberField('hp', 'HP', 10)],
                    onSave: (_, __) async {}),
                child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.text('Pull from here to close.'), const Offset(0, 125));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-value-editor')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping the hero opens what is known about them',
      (tester) async {
    final c = fixtures.hero()
      ..personalityTraits = 'Keeps a journal'
      ..backstory = 'An old promise.';
    await tester.pumpWidget(app(Scaffold(
        body: ExpandableCharacterCard(character: c, onDicePressed: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Keeps a journal'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('character-about')));
    await tester.pumpAndSettle();
    expect(find.text('Keeps a journal'), findsOneWidget);
    expect(find.text('An old promise.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A hero without a story has no about sheet', (tester) async {
    final c = fixtures.hero()
      ..personalityTraits = null
      ..ideals = null
      ..bonds = null
      ..flaws = null
      ..backstory = null
      ..age = null;
    await tester.pumpWidget(app(
        Scaffold(
            body: ExpandableCharacterCard(character: c, onDicePressed: () {})),
        reduced: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('character-about')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Entry reveals when visible, then stays still when scrolled back',
      (tester) async {
    var seen = 0;
    var visited = false;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) =>
                ListView(controller: scroll, children: [
                  const SizedBox(height: 900),
                  JournalAppear(
                      seen: visited,
                      onSeen: () {
                        seen++;
                        refresh(() => visited = true);
                      },
                      child: const SizedBox(height: 120, child: Text('Entry'))),
                  const SizedBox(height: 900)
                ])))));
    await tester.pumpAndSettle();
    expect(seen, 0);
    scroll.jumpTo(700);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(seen, 1);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    scroll.jumpTo(700);
    await tester.pumpAndSettle();
    expect(seen, 1);
    expect(tester.takeException(), isNull);
  });
}
