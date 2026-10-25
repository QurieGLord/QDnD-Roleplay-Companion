import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/features/character_sheet/tabs/journal_tab.dart';
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
    final search = find.byKey(const ValueKey('journal-search'));
    // The quest is the one in work; the note sits on the board.
    final quest = find.text('Угроза на северной дороге');
    final note = find.text('Письмо');
    await tester.enterText(search, 'дорога');
    await tester.pumpAndSettle();
    expect(quest, findsOneWidget);
    expect(note, findsNothing);
    await tester.enterText(search, 'пристань');
    await tester.pumpAndSettle();
    expect(quest, findsOneWidget);
    await tester.enterText(search, 'улика');
    await tester.pumpAndSettle();
    expect(quest, findsNothing);
    expect(note, findsOneWidget);
    await tester.enterText(search, 'Локация');
    await tester.pumpAndSettle();
    expect(note, findsOneWidget);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(quest, findsOneWidget);
    expect(note, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
