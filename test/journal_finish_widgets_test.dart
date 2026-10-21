import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/journal/journal_graph.dart';
import 'package:qd_and_d/core/journal/journal_service.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/features/character_sheet/tabs/journal_tab.dart';
import 'package:qd_and_d/features/journal/journal_entry_tile.dart';
import 'package:qd_and_d/features/journal/journal_atlas_page.dart';
import 'package:qd_and_d/features/journal/journal_story_carousel.dart';
import 'package:qd_and_d/features/journal/journal_reorder_section.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget page, {double scale = 1, bool reduced = false}) =>
    MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced),
            child: child!),
        home: page);
void mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-journal-finish-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  setUp(() async => Hive.box<Character>('characters').clear());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets(
      'Cards keep title, next objective and metadata readable at large text',
      (tester) async {
    mobile(tester);
    final quest = Quest(
        id: 'q',
        title: 'Find the missing keeper of the ancient wharf',
        description:
            'A long account of the disappearance and the clues that remain.',
        objectives: [
          QuestObjective(description: 'Read the letter', isCompleted: true),
          QuestObjective(description: 'Ask Elian at the northern gate')
        ]);
    final note = JournalNote(
        id: 'n',
        title: 'A long letter from Woodland Haven',
        content: 'Its sender mentioned the keeper.',
        tags: [
          "keeper-${List.filled(12, 'ancient').join('-')}",
          'letter',
          'haven',
          'Elian'
        ],
        isPinned: true);
    await tester.pumpWidget(app(
        Scaffold(
            body: ListView(children: [
          JournalEntryTile(
              entry: JournalEntry.quest(quest),
              onTap: () {},
              session: 6,
              connectionCount: 4),
          JournalEntryTile(
              entry: JournalEntry.note(note),
              onTap: () {},
              session: 2,
              connectionCount: 3),
        ])),
        scale: 1.6));
    await tester.pumpAndSettle();
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('Ask Elian at the northern gate'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('+1'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Carousel magnifies the center and atlas back exits after many selections',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    c.journalData = JournalGraph(entities: [
      JournalEntity(id: 'one', name: 'Elian'),
      JournalEntity(
          id: 'two', name: 'Woodland Haven', kind: JournalEntityKind.place),
      JournalEntity(
          id: 'three', name: 'Northern road', kind: JournalEntityKind.place)
    ]).toJson();
    await tester.pumpWidget(app(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => JournalAtlasPage(character: c))),
                child: const Text('Open atlas'))))));
    await tester.tap(find.text('Open atlas'));
    await tester.pumpAndSettle();
    final center = tester
        .widget<Transform>(find.byKey(const ValueKey('story-scale-one')))
        .transform
        .storage[0];
    final edge = tester
        .widget<Transform>(find.byKey(const ValueKey('story-scale-two')))
        .transform
        .storage[0];
    expect(center, greaterThan(edge));
    await tester.drag(find.byKey(const ValueKey('journal-story-carousel')),
        const Offset(-230, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('journal-story-carousel')),
        const Offset(-230, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('atlas-exit')));
    await tester.pumpAndSettle();
    expect(find.text('Open atlas'), findsOneWidget);
    expect(find.byType(JournalAtlasPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Carousel can coast beyond the next story and settle gently',
      (tester) async {
    mobile(tester);
    String selected = '0';
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) => JournalStoryCarousel(
                    entities: [
                      for (var i = 0; i < 9; i++)
                        JournalEntity(id: '$i', name: 'Story $i')
                    ],
                    selected: selected,
                    count: (_) => 1,
                    onSelected: (id) => refresh(() => selected = id))))));
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const ValueKey('journal-story-carousel')),
        const Offset(-200, 0), 2400);
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageView>(find.byKey(const ValueKey('journal-story-carousel')))
        .controller!;
    expect(controller.page!, greaterThan(1));
    expect(controller.page!, closeTo(controller.page!.roundToDouble(), .03));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Atlas height interpolates instead of jumping when a description grows',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    c.journalData = JournalGraph(entities: [
      JournalEntity(id: 'short', name: 'Elian'),
      JournalEntity(
          id: 'long',
          name: 'Aldren',
          description: List.filled(12, 'A longer story with clues.').join(' '))
    ]).toJson();
    await tester.pumpWidget(app(JournalAtlasPage(character: c)));
    await tester.pumpAndSettle();
    final start =
        tester.getSize(find.byKey(const ValueKey('atlas-content-size'))).height;
    tester
        .widget<JournalStoryCarousel>(find.byType(JournalStoryCarousel))
        .onSelected('long');
    await tester.pump();
    expect(
        tester.getSize(find.byKey(const ValueKey('atlas-content-size'))).height,
        closeTo(start, 1));
    await tester.pump(const Duration(milliseconds: 100));
    final middle =
        tester.getSize(find.byKey(const ValueKey('atlas-content-size'))).height;
    await tester.pumpAndSettle();
    final end =
        tester.getSize(find.byKey(const ValueKey('atlas-content-size'))).height;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Hold release opens note actions and quick unpin saves without altering content',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    c.journalNotes.add(JournalNote(
        id: 'n',
        title: 'Pinned letter',
        content: 'Keep this text',
        isPinned: true));
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pinned letter'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Pinned letter'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin'), findsOneWidget);
    Navigator.of(tester.element(find.text('Unpin'))).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Quick actions'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Unpin'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await GameplayActionsService.serializeCharacter(
          c, () async => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(c.journalNotes.single.isPinned, isFalse);
    expect(c.journalNotes.single.content, 'Keep this text');
    expect(tester.takeException(), isNull);
  });
  testWidgets('A held drag crosses the pin boundary and does not open a menu',
      (tester) async {
    mobile(tester);
    var moved = false;
    var menus = 0;
    double travel = 0;
    Offset? origin;
    var entries = [
      JournalEntry.note(JournalNote(id: 'a', title: 'Pinned', isPinned: true)),
      JournalEntry.note(JournalNote(id: 'b', title: 'Loose'))
    ];
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) => Listener(
                onPointerDown: (e) {
                  origin = e.position;
                  travel = 0;
                },
                onPointerMove: (e) {
                  travel = (e.position - origin!).distance;
                },
                child: CustomScrollView(slivers: [
                  SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: JournalReorderSection(
                          entries: entries,
                          notes: true,
                          travel: () => travel,
                          onMenu: (_) => menus++,
                          tile: (e) => JournalEntryTile(
                              entry: e, onTap: () {}, reorderManaged: true),
                          onReorder: (order, pinned) async {
                            moved = true;
                            refresh(() {
                              for (final e in entries) {
                                e.note!.isPinned = pinned!.contains(e.key);
                              }
                              entries.sort((a, b) => order
                                  .indexOf(a.key)
                                  .compareTo(order.indexOf(b.key)));
                            });
                          }))
                ]))))));
    await tester.pumpAndSettle();
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Loose')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture
        .moveTo(tester.getCenter(find.text('Pinned')) - const Offset(0, 45));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moved, isTrue);
    expect(
        entries.singleWhere((e) => e.note!.id == 'b').note!.isPinned, isTrue);
    final reverse =
        await tester.startGesture(tester.getCenter(find.text('Loose')));
    await tester.pump(const Duration(milliseconds: 600));
    await reverse.moveTo(const Offset(195, 720));
    await tester.pump(const Duration(milliseconds: 400));
    await reverse.up();
    await tester.pumpAndSettle();
    expect(
        entries.singleWhere((e) => e.note!.id == 'b').note!.isPinned, isFalse);
    expect(menus, 0);
    expect(tester.takeException(), isNull);
  });
}
