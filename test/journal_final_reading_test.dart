import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/features/journal/journal_pin_board.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget child, {double scale = 1}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: child);
void main() {
  testWidgets(
      'A swipe never squeezes a journal card but a deliberate hold does',
      (tester) async {
    await tester.pumpWidget(app(Scaffold(
        body: ListView(children: [
      JournalPinBoard(
          pinned: const [],
          loose: const [
            JournalCardData(
                key: 'n:n', title: 'Letter', text: '', category: NoteCategory.general)
          ],
          onOpen: (_) {},
          onCommit: (_, __, ___) {}),
      const SizedBox(height: 900)
    ]))));
    await tester.pumpAndSettle();
    double scale() => tester
        .widget<AnimatedScale>(find.ancestor(
            of: find.text('Letter'), matching: find.byType(AnimatedScale)))
        .scale;
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Letter')));
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(), 1);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(), 1);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 140));
    await tester.pumpAndSettle();
    final hold =
        await tester.startGesture(tester.getCenter(find.text('Letter')));
    await tester.pump(const Duration(milliseconds: 380));
    await tester.pump(const Duration(milliseconds: 80));
    expect(scale(), lessThan(1));
    await hold.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Reader has distinct description, objective and status blocks',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero();
    c.quests.add(Quest(
        id: 'q',
        title: 'Find the keeper',
        description: 'An old letter mentions the northern wharf.',
        objectives: [
          QuestObjective(description: 'Read the letter', isCompleted: true),
          QuestObjective(description: 'Ask the keeper')
        ]));
    await tester.pumpWidget(
        app(JournalEntryPage(character: c, entryKey: 'q:q'), scale: 1.6));
    await tester.pumpAndSettle();
    for (final key in [
      'journal-reader-content',
      'journal-reader-objectives',
      'journal-step-1',
      'journal-reader-status'
    ]) {
      await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 160,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
