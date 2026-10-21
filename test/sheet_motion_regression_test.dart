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
    await tester.drag(find.byType(PageView), const Offset(600, 0));
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
      expect(nested.outerController.offset, closeTo(0, 1));
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

  testWidgets(
      'Character details grow along one reveal and honor reduced motion',
      (tester) async {
    final c = fixtures.hero()
      ..personalityTraits = 'Keeps a journal'
      ..backstory = 'An old promise.';
    var expanded = false;
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) => ExpandableCharacterCard(
                character: c,
                isExpanded: expanded,
                onDicePressed: () {},
                onDetailsToggled: (v) => refresh(() => expanded = v))))));
    await tester.pumpAndSettle();
    final initial = tester.getSize(find.byType(ExpandableCharacterCard)).height;
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getSize(find.byType(ExpandableCharacterCard)).height;
    expect(middle, greaterThan(initial));
    await tester.pumpAndSettle();
    final full = tester.getSize(find.byType(ExpandableCharacterCard)).height;
    expect(full, greaterThan(middle));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byType(ExpandableCharacterCard)).height, initial);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Reduced motion reveals details immediately and leaves no entrance tween',
      (tester) async {
    final c = fixtures.hero()..personalityTraits = 'Keeps a journal';
    var expanded = false;
    await tester.pumpWidget(app(
        Scaffold(
            body: StatefulBuilder(
                builder: (context, refresh) => ExpandableCharacterCard(
                    character: c,
                    isExpanded: expanded,
                    onDicePressed: () {},
                    onDetailsToggled: (v) => refresh(() => expanded = v)))),
        reduced: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(
        tester
            .widget<SizeTransition>(
                find.byKey(const ValueKey('character-details-reveal')))
            .sizeFactor
            .value,
        1);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(
        tester
            .widget<SizeTransition>(
                find.byKey(const ValueKey('character-details-reveal')))
            .sizeFactor
            .value,
        0);
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
