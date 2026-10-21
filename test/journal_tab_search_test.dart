import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/features/character_sheet/tabs/journal_tab.dart';
import 'package:qd_and_d/features/journal/widgets/adventurer_quote_card.dart';
import 'package:qd_and_d/features/journal/journal_entry_tile.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void main() {
  testWidgets(
      'Real journal searches objectives, tags and categories and clears its field',
      (tester) async {
    final character = Character(
        id: 'journal-search',
        name: 'Reader',
        race: 'human',
        characterClass: 'fighter',
        level: 1,
        maxHp: 10,
        currentHp: 10,
        spellSlots: [],
        maxSpellSlots: [],
        abilityScores: AbilityScores(
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10));
    character.quests.add(Quest(
        id: 'road',
        title: 'Угроза на северной дороге',
        objectives: [
          QuestObjective(description: 'Осмотреть старую пристань')
        ]));
    character.journalNotes.add(JournalNote(
        id: 'letter',
        title: 'Письмо',
        tags: ['улики'],
        category: NoteCategory.location));
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: JournalTab(character: character))));
    await tester.pumpAndSettle();
    final quote = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(AdventurerQuoteCard), matching: find.byType(Text)))
        .map((e) => e.data)
        .toList();
    await tester.enterText(find.byType(TextField), 'дорога');
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.quest != null),
        findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.note != null),
        findsNothing);
    await tester.enterText(find.byType(TextField), 'пристань');
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.quest != null),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'улика');
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.quest != null),
        findsNothing);
    await tester.scrollUntilVisible(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.note != null),
        160,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.note != null),
        findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TextField), -160,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'Локация');
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.note != null),
        findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(
        find.byWidgetPredicate(
            (w) => w is JournalEntryTile && w.entry.quest != null),
        findsOneWidget);
    expect(
        tester
            .widgetList<Text>(find.descendant(
                of: find.byType(AdventurerQuoteCard),
                matching: find.byType(Text)))
            .map((e) => e.data)
            .toList(),
        quote);
    expect(tester.takeException(), isNull);
  });
}
