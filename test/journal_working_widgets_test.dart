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
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/features/character_sheet/tabs/journal_tab.dart';
import 'package:qd_and_d/features/journal/journal_entry_editor.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/features/journal/journal_atlas_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget page,
        {Locale locale = const Locale('en'),
        double scale = 1,
        double insets = 0}) =>
    MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: insets)),
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
      'Confirm a new name inside a real note, then a later note links automatically',
      (tester) async {
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Add note'));
    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'Elian');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'We met Elian at the old wharf.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Elian'));
    await tester.tap(find.widgetWithText(ActionChip, 'Elian'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.journalNotes, hasLength(1));
    expect(JournalService.graph(c).entities.single.name, 'Elian');
    await tester.ensureVisible(find.byTooltip('Add note'));
    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'At the wharf');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'Elian remembered the letter.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Elian'), findsOneWidget);
    await save(tester);
    final graph = JournalService.graph(c);
    expect(graph.forRecord('n:${c.journalNotes.last.id}').automatic,
        {graph.entities.single.id});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Cancelling a confirmed-name draft changes neither catalogue nor records',
      (tester) async {
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Add note'));
    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('journal-title')), 'Aldren');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Aldren'));
    await tester.tap(find.widgetWithText(ActionChip, 'Aldren'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
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
    await tester.scrollUntilVisible(
        find.byTooltip('Remove objective').first, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byTooltip('Remove objective').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove objective').first);
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.quests.single.objectives.single.description, 'Second');
    expect(c.quests.single.objectives.single.isCompleted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Detail checks a subtask once and backlinks survive record rename',
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
    await tester
        .pumpWidget(app(JournalEntryPage(character: c, entryKey: 'q:q')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byType(Checkbox));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(c.quests.single.objectives.single.isCompleted, isTrue);
    await tester.scrollUntilVisible(find.text('Letter'), 160,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Links to this entry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Typing suggestions stay above the keyboard on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    c.journalData =
        JournalGraph(entities: [JournalEntity(name: 'Elian')]).toJson();
    await tester.pumpWidget(app(JournalEntryEditor(character: c), insets: 300));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('journal-title')), 'Nora');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'Nora asks Elian about the letter.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Stories in this entry'), findsOneWidget);
    expect(tester.getBottomLeft(find.widgetWithText(ActionChip, 'Nora')).dy,
        lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'New suggestions appear before known names; tags keep keyboard ownership',
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
    await tester.enterText(find.byKey(const ValueKey('journal-title')), 'Nora');
    await tester.enterText(find.byKey(const ValueKey('journal-text')),
        'Nora met Elian at the wharf.');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
        tester.getCenter(find.byKey(const ValueKey('suggest-new-Nora'))).dx,
        lessThan(tester
            .getCenter(find.byKey(const ValueKey('suggest-known-elian')))
            .dx));
    final bodyController = tester
        .widget<TextFormField>(find.byKey(const ValueKey('journal-text')))
        .controller!;
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('journal-tags')), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const ValueKey('journal-tags')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-tags')));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('cl');
    await tester.pump(const Duration(milliseconds: 450));
    tester.testTextInput.enterText('clue');
    await tester.pumpAndSettle();
    final tags =
        tester.widget<TextField>(find.byKey(const ValueKey('journal-tags')));
    expect(tags.focusNode!.hasFocus, isTrue);
    expect(tags.controller!.text, 'clue');
    expect(bodyController.text, 'Nora met Elian at the wharf.');
    expect(find.text('Stories in this entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Selection toolbar can create a story from a phrase without rewriting text',
      (tester) async {
    final c = fixtures.hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Scaffold(body: JournalTab(character: c))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Add note'));
    await tester.tap(find.byTooltip('Add note'));
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
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(c.journalNotes.single.content, 'Meet us at the Old Wharf.');
    expect(JournalService.graph(c).entities.single.name, 'Old Wharf');
    expect(
        JournalService.graph(c)
            .forRecord('n:${c.journalNotes.single.id}')
            .manual,
        isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selection while reading adds a link and preserves the note',
      (tester) async {
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
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    final editable = find.descendant(
        of: find.byType(SelectableText), matching: find.byType(EditableText));
    final state = tester.state<EditableTextState>(editable);
    state.widget.controller.selection =
        const TextSelection(baseOffset: 6, extentOffset: 15);
    state.showToolbar();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Link to story'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ListTile, 'Old Wharf'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await GameplayActionsService.serializeCharacter(c, () async {
        await Hive.box<Character>('characters').flush();
      });
    });
    await tester.pumpAndSettle();
    expect(JournalService.graph(c).forRecord('n:sign').manual, {'wharf'});
    expect(c.journalNotes.single.content, 'Visit Old Wharf.');
    expect(c.journalNotes.single.tags, ['clue']);
    expect(c.journalNotes.single.isPinned, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Atlas and editor fit narrow screens, large text and both languages',
      (tester) async {
    tester.view.physicalSize = const Size(360, 844);
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
    await tester.pumpWidget(app(JournalAtlasPage(character: c),
        locale: const Locale('ru'), scale: 1.6));
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
