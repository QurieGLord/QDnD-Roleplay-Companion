import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/features/character_edit/character_edit_screen.dart';
import 'package:qd_and_d/features/character_list/hero_transfer.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

Character _hero() => Character(
      id: 'w5-hero',
      name: 'Rowan',
      race: 'Human',
      characterClass: 'Paladin',
      level: 6,
      maxHp: 52,
      currentHp: 52,
      abilityScores: AbilityScores(
          strength: 16,
          dexterity: 10,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 15),
      spellSlots: List.filled(9, 0),
      maxSpellSlots: List.filled(9, 0),
      armorClass: 18,
      speed: 30,
      initiative: 0,
      classes: [
        CharacterClass(
            id: 'paladin', name: 'Paladin', level: 6, isPrimary: true)
      ],
    );

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: home,
    );

void main() {
  testWidgets('transfer sheet switches formats in place', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final hero = _hero();
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
          builder: (context) => TextButton(
              onPressed: () => showHeroTransfer(context, hero),
              child: const Text('open'))),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Full copy'), findsOneWidget);
    expect(find.text('Sheet as XML'), findsOneWidget);
    expect(find.text('Save .qdnd'), findsOneWidget);
    expect(find.text('Pack your own content'), findsOneWidget);

    await tester.tap(find.text('Sheet as XML'));
    await tester.pumpAndSettle();
    expect(find.text('Save .xml'), findsOneWidget);
    // The own-content switch folds away with the full copy.
    final row = tester.getSize(find
        .ancestor(
            of: find.text('Pack your own content'),
            matching: find.byType(ClipRect))
        .first);
    expect(row.height, 0);
  });

  testWidgets('hero card wakes Save on the first change', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(CharacterEditScreen(character: _hero())));
    await tester.pumpAndSettle();

    expect(find.text('Rowan'), findsWidgets);
    expect(find.text('1 of 12 told'), findsOneWidget);

    await tester.tap(find.text('Speaks little, but always to the point'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 12 told'), findsOneWidget);
  });
}
