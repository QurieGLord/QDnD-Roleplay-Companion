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
import 'package:qd_and_d/features/journal/journal_atlas_page.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/features/journal/journal_pin_board.dart';
import 'package:qd_and_d/features/journal/journal_session_tape.dart';
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
void mobile(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

JournalCardData card(String id, String title, {String text = 'A few words.'}) =>
    JournalCardData(
        key: 'n:$id', title: title, text: text, category: NoteCategory.general);

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

  testWidgets('The journal stays readable at large text', (tester) async {
    mobile(tester, height: 2400);
    final c = fixtures.hero();
    c.quests.add(Quest(
        id: 'q',
        title: 'Find the missing keeper of the ancient wharf',
        description: 'A long account of the disappearance.',
        objectives: [
          QuestObjective(description: 'Read the letter', isCompleted: true),
          QuestObjective(description: 'Ask Elian at the northern gate')
        ]));
    c.journalNotes.addAll([
      JournalNote(
          id: 'n',
          title: 'A long letter from Woodland Haven',
          content: 'Its sender mentioned the keeper.',
          isPinned: true),
      JournalNote(id: 'm', title: 'Supplies', content: 'Rope and torches.'),
    ]);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(
        app(Scaffold(body: JournalTab(character: c)), scale: 1.6));
    await tester.pumpAndSettle();
    expect(find.text('NEXT STEP'), findsOneWidget);
    expect(find.text('Ask Elian at the northern gate'), findsOneWidget);
    expect(find.text('Supplies'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A held card pins on the shelf and unpins back onto the board',
      (tester) async {
    mobile(tester);
    var pinned = [card('a', 'Kept')];
    var loose = [card('b', 'Loose'), card('c', 'Other')];
    final commits = <bool?>[];
    var opened = 0;
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      JournalPinBoard(
                          pinned: pinned,
                          loose: loose,
                          onOpen: (_) => opened++,
                          onCommit: (shelf, board, pin) {
                            commits.add(pin);
                            final all = {for (final d in [...pinned, ...loose]) d.key: d};
                            refresh(() {
                              pinned = [for (final k in shelf) all[k]!];
                              loose = [for (final k in board) all[k]!];
                            });
                          }),
                    ])))));
    await tester.pumpAndSettle();
    final lift = await tester.startGesture(tester.getCenter(find.text('Loose')));
    await tester.pump(const Duration(milliseconds: 600));
    await lift.moveTo(tester.getCenter(find.text('Kept')) + const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 100));
    await lift.moveTo(tester.getCenter(find.text('Kept')));
    await tester.pump(const Duration(milliseconds: 100));
    await lift.up();
    await tester.pumpAndSettle();
    expect(commits.last, isTrue);
    expect(pinned.map((d) => d.title), ['Loose', 'Kept']);
    final back = await tester.startGesture(tester.getCenter(find.text('Loose')));
    await tester.pump(const Duration(milliseconds: 600));
    await back.moveTo(tester.getCenter(find.text('Other')) + const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 100));
    await back.moveTo(tester.getCenter(find.text('Other')));
    await tester.pump(const Duration(milliseconds: 100));
    await back.up();
    await tester.pumpAndSettle();
    expect(commits.last, isFalse);
    expect(loose.map((d) => d.title), contains('Loose'));
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A held card rearranges the board and never opens the note',
      (tester) async {
    mobile(tester);
    var loose = [card('a', 'First'), card('b', 'Second'), card('c', 'Third')];
    List<String>? order;
    var opened = 0;
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      JournalPinBoard(
                          pinned: const [],
                          loose: loose,
                          onOpen: (_) => opened++,
                          onCommit: (shelf, board, pin) {
                            order = board;
                            final all = {for (final d in loose) d.key: d};
                            refresh(() => loose = [for (final k in board) all[k]!]);
                          }),
                    ])))));
    await tester.pumpAndSettle();
    final from = tester.getCenter(find.text('Third')),
        to = tester.getCenter(find.text('First'));
    final hold = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 1; i <= 6; i++) {
      await hold.moveTo(Offset.lerp(from, to, i / 6)!);
      await tester.pump(const Duration(milliseconds: 160));
    }
    await hold.up();
    await tester.pumpAndSettle();
    expect(order, isNotNull);
    expect(order!.first, 'n:c');
    expect(opened, 0);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The session tape opens a session and takes an empty one back',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    c.journalNotes.add(JournalNote(id: 'n', title: 'At the tavern'));
    c.journalData = (JournalGraph(sessions: 2)..forRecord('n:n').session = 2).toJson();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    expect(find.text('SESSION 2 IN PLAY'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('journal-session-add')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(JournalService.graph(c).currentSession, 3);
    expect(find.text('SESSION 3 IN PLAY'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await JournalService.dropSession(c), isTrue);
      expect(await JournalService.dropSession(c), isFalse);
    });
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    expect(JournalService.graph(c).currentSession, 2);
    await tester.tap(find.byKey(const ValueKey('journal-session-2')));
    await tester.pumpAndSettle();
    expect(find.text('SESSION 2'), findsOneWidget);
    expect(find.text('At the tavern'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('journal-session-1')));
    await tester.pumpAndSettle();
    expect(find.text('At the tavern'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Holding the empty latest session takes it back', (tester) async {
    mobile(tester);
    var dropped = 0, added = 0;
    int? picked;
    await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
            builder: (context, refresh) => JournalSessionTape(
                current: 3,
                countIn: (n) => n == 2 ? 1 : 0,
                picked: picked,
                onPick: (n) => refresh(() => picked = n),
                onAdd: () => added++,
                onDrop: () => dropped++)))));
    await tester.pumpAndSettle();
    final hold = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey('journal-session-3'))));
    await tester.pump(const Duration(milliseconds: 700));
    await hold.up();
    await tester.pumpAndSettle();
    expect(dropped, 1);
    expect(picked, isNull);
    // A session with records has no hold; a tap filters by it.
    final busy = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey('journal-session-2'))));
    await tester.pump(const Duration(milliseconds: 700));
    await busy.up();
    await tester.pumpAndSettle();
    expect(dropped, 1);
    expect(picked, 2);
    await tester.tap(find.byKey(const ValueKey('journal-session-add')));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The Atlas exits after many selections', (tester) async {
    mobile(tester, height: 1400);
    final c = fixtures.hero();
    c.journalData = JournalGraph(entities: [
      JournalEntity(id: 'one', name: 'Elian'),
      JournalEntity(id: 'two', name: 'Woodland Haven', kind: JournalEntityKind.place),
      JournalEntity(id: 'three', name: 'Northern road', kind: JournalEntityKind.place)
    ]).toJson();
    await tester.pumpWidget(app(
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => JournalAtlasPage(character: c))),
                    child: const Text('Open atlas')))),
        reduced: true));
    await tester.tap(find.text('Open atlas'));
    await tester.pumpAndSettle();
    for (final id in ['one', 'two', 'three', 'one']) {
      await tester.tap(find.byKey(ValueKey('journal-star-$id')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('atlas-entity-$id')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('atlas-exit')));
    await tester.pumpAndSettle();
    expect(find.text('Open atlas'), findsOneWidget);
    expect(find.byType(JournalAtlasPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A finger on the sky scrolls the page; on a star it drags the star',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    c.journalNotes.add(JournalNote(id: 'n', title: 'A meeting', content: 'Elian met Mira.'));
    c.journalData = JournalGraph(entities: [
      JournalEntity(id: 'one', name: 'Elian'),
      JournalEntity(id: 'two', name: 'Mira'),
    ]).toJson();
    await tester.pumpWidget(
        app(JournalAtlasPage(character: c, selected: 'one'), reduced: true));
    await tester.pumpAndSettle();
    final page = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final sky = tester.getRect(find.byKey(const ValueKey('journal-constellation')));
    await tester.dragFrom(sky.topLeft + const Offset(12, 60), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(page.pixels, greaterThan(50));
    page.jumpTo(0);
    await tester.pumpAndSettle();
    final star = tester.getCenter(find.byKey(const ValueKey('journal-star-two')));
    await tester.dragFrom(star - const Offset(0, 10), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(page.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pinning from the note page saves without altering content',
      (tester) async {
    mobile(tester);
    final c = fixtures.hero();
    c.journalNotes.add(JournalNote(
        id: 'n', title: 'Pinned letter', content: 'Keep this text', isPinned: true));
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(JournalEntryPage(character: c, entryKey: 'n:n')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-more')));
    await tester.pumpAndSettle();
    // The write starts once the sheet has closed; real file work is let
    // through between frames.
    await tester.tap(find.text('Unpin'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    }
    await tester.runAsync(() => GameplayActionsService.serializeCharacter(
        c, () async => Hive.box<Character>('characters').flush()));
    await tester.pumpAndSettle();
    expect(c.journalNotes.single.isPinned, isFalse);
    expect(c.journalNotes.single.content, 'Keep this text');
    expect(tester.takeException(), isNull);
  });
}
