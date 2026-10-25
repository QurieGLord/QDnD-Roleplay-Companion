import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/journal/journal_graph.dart';
import 'package:qd_and_d/core/journal/journal_service.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_sheet/tabs/journal_tab.dart';
import 'package:qd_and_d/features/journal/journal_entry_editor.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/features/journal/journal_atlas_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget page,
        {Locale locale = const Locale('en'),
        double scale = 1,
        double insets = 0,
        bool reduced = false}) =>
    MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: insets),
                disableAnimations: reduced),
            child: child!),
        home: page);
Future<void> launchEditor(
    WidgetTester tester, Character c, JournalEntry entry) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(app(Scaffold(
      body: Builder(
          builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          JournalEntryEditor(character: c, entry: entry))),
              child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('journal-save')));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await Hive.box<Character>('characters').flush();
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-journal-widgets-');
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
      'A new name confirmed in a real note links a later note automatically',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-write')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'At the wharf');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'We met Elian at the old wharf.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('suggest-new-Elian')));
    await tester.tap(find.byKey(const ValueKey('suggest-new-Elian')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-kind-person')));
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.journalNotes, hasLength(1));
    final elian = JournalService.graph(c).entities.single;
    expect(elian.name, 'Elian');
    await tester.tap(find.byKey(const ValueKey('journal-write')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'A letter');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'Elian remembered the letter.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('journal-on-${elian.id}')), findsOneWidget);
    await save(tester);
    final graph = JournalService.graph(c);
    final later = c.journalNotes.firstWhere((n) => n.title == 'A letter');
    expect(graph.forRecord('n:${later.id}').automatic, {elian.id});
    expect(graph.forRecord('n:${later.id}').session, graph.currentSession);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Cancelling a confirmed-name draft changes neither catalogue nor records',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-write')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'The old knight');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'We spoke with Aldren.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('suggest-new-Aldren')));
    await tester.tap(find.byKey(const ValueKey('suggest-new-Aldren')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-kind-person')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(c.journalNotes, isEmpty);
    expect(c.journalData, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Full editor retains tags, pin, category, session and quest objectives',
      (tester) async {
    final c = fixtures.hero();
    final note = JournalNote(
        id: 'n',
        title: 'Old letter',
        tags: ['clue'],
        category: NoteCategory.story,
        isPinned: true);
    c.journalNotes.add(note);
    c.journalData =
        JournalGraph(records: {'n:n': JournalRecordLinks(session: 2)}).toJson();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await launchEditor(tester, c, JournalEntry.note(note));
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'Renamed letter');
    await save(tester);
    expect(c.journalNotes.single.title, 'Renamed letter');
    expect(c.journalNotes.single.tags, ['clue']);
    expect(c.journalNotes.single.isPinned, isTrue);
    expect(c.journalNotes.single.category, NoteCategory.story);
    expect(JournalService.graph(c).forRecord('n:n').session, 2);
    final quest = Quest(id: 'q', title: 'Find Elian', objectives: [
      QuestObjective(description: 'First', isCompleted: true),
      QuestObjective(description: 'Second')
    ]);
    c.quests.add(quest);
    await launchEditor(tester, c, JournalEntry.quest(quest));
    await tester.ensureVisible(find.byTooltip('Remove step').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove step').first);
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.quests.single.objectives.single.description, 'Second');
    expect(c.quests.single.objectives.single.isCompleted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'The quest page checks a step once and backlinks survive record rename',
      (tester) async {
    final c = fixtures.hero();
    final quest = Quest(
        id: 'q',
        title: 'Find Elian',
        objectives: [QuestObjective(description: 'Ask the keeper')]);
    c.quests.add(quest);
    c.journalNotes.add(JournalNote(id: 'n', title: 'Letter'));
    c.journalData = JournalGraph(records: {
      'n:n': JournalRecordLinks(records: {'q:q'})
    }).toJson();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(
        app(JournalEntryPage(character: c, entryKey: 'q:q'), reduced: true));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('journal-step-0')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(c.quests.single.objectives.single.isCompleted, isTrue);
    await tester.scrollUntilVisible(find.text('Letter'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Links to this entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Typing on a phone keeps the toolbar above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    c.journalData =
        JournalGraph(entities: [JournalEntity(name: 'Elian')]).toJson();
    await tester.pumpWidget(app(JournalEntryEditor(character: c), insets: 300));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'A question');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'Nora asks Elian about the letter.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggest-new-Nora')), findsOneWidget);
    expect(tester.getBottomLeft(find.byKey(const ValueKey('journal-photo'))).dy,
        lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Known names come first, new ones after; tags keep keyboard ownership',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    c.journalData =
        JournalGraph(entities: [JournalEntity(id: 'elian', name: 'Elian')])
            .toJson();
    await tester.pumpWidget(app(JournalEntryEditor(character: c), insets: 300));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'At the wharf');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'Nora met Elian at the wharf.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
        tester.getCenter(find.byKey(const ValueKey('journal-on-elian'))).dy,
        lessThan(tester
            .getCenter(find.byKey(const ValueKey('suggest-new-Nora')))
            .dy));
    final body = tester
        .widget<TextField>(find.byKey(const ValueKey('journal-text')))
        .controller!;
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('journal-tags')), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-tags')));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('cl');
    await tester.pump(const Duration(milliseconds: 450));
    tester.testTextInput.enterText('clue');
    await tester.pumpAndSettle();
    final tags =
        tester.widget<TextField>(find.byKey(const ValueKey('journal-tags')));
    expect(tags.controller!.text, 'clue');
    expect(
        tester
            .state<EditableTextState>(find.descendant(
                of: find.byKey(const ValueKey('journal-tags')),
                matching: find.byType(EditableText)))
            .widget
            .focusNode
            .hasFocus,
        isTrue);
    expect(body.text, 'Nora met Elian at the wharf.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Selection toolbar can create a story from a phrase without rewriting text',
      (tester) async {
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-write')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'A meeting');
    final textField = find.byKey(const ValueKey('journal-text'));
    await tester.enterText(textField, 'Meet us at the Old Wharf.');
    final editable =
        find.descendant(of: textField, matching: find.byType(EditableText));
    final state = tester.state<EditableTextState>(editable);
    state.widget.controller.selection =
        const TextSelection(baseOffset: 15, extentOffset: 24);
    state.showToolbar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link to story'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a story from selection'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-kind-place')));
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.journalNotes.single.content, 'Meet us at the Old Wharf.');
    final wharf = JournalService.graph(c).entities.single;
    expect(wharf.name, 'Old Wharf');
    expect(
        JournalService.graph(c)
            .forRecord('n:${c.journalNotes.single.id}')
            .manual,
        {wharf.id});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Names in a note open their card; the note stays as it was',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    c.journalNotes.add(JournalNote(
        id: 'sign',
        title: 'A sign',
        content: 'Visit Old Wharf.',
        tags: ['clue'],
        isPinned: true));
    c.journalData =
        JournalGraph(entities: [JournalEntity(id: 'wharf', name: 'Old Wharf')])
            .toJson();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester
        .pumpWidget(app(JournalEntryPage(character: c, entryKey: 'n:sign')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journal-reader-content')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('journal-actor-wharf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-actor-wharf')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journal-entity-atlas')), findsOneWidget);
    expect(find.text('A sign'), findsWidgets);
    expect(c.journalNotes.single.content, 'Visit Old Wharf.');
    expect(c.journalNotes.single.tags, ['clue']);
    expect(c.journalNotes.single.isPinned, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Atlas and editor fit narrow screens, large text and both languages',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    c.journalNotes.add(
        JournalNote(id: 'n', title: 'Письмо', content: 'Элиан на пристани'));
    c.journalData = JournalGraph(entities: [
      JournalEntity(id: 'e', name: 'Элиан', description: 'Сын Альдрена')
    ], records: {
      'n:n': JournalRecordLinks(manual: {'e'})
    }).toJson();
    await tester.pumpWidget(app(JournalAtlasPage(character: c, selected: 'e'),
        locale: const Locale('ru'), scale: 1.6, reduced: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Письмо'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c)),
        locale: const Locale('ru'), scale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      await tester.pumpWidget(
          app(JournalEntryEditor(character: c), locale: locale, scale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
