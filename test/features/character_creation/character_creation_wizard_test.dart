import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/features/character_creation/character_creation_state.dart';
import 'package:qd_and_d/features/character_creation/character_creation_wizard.dart';
import 'package:qd_and_d/features/character_creation/prologue.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder next() => find.descendant(
      of: find.byKey(const ValueKey('prologue-island')),
      matching: find.byKey(const ValueKey('advancement-island-next')));

  testWidgets('the name chapter waits for a name, then goes on to the people',
      (tester) async {
    await tester.pumpWidget(_wrapWizard());
    await tester.pumpAndSettle();
    expect(find.text('What is the hero called?'), findsOneWidget);
    expect(find.text('Name the hero'), findsOneWidget);
    await tester.tap(next());
    await tester.pumpAndSettle();
    expect(find.text('What is the hero called?'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('prologue-name')), 'Lyra');
    await tester.pumpAndSettle();
    final state =
        tester.element(find.byType(Prologue)).read<CharacterCreationState>();
    expect(state.name, 'Lyra');
    // The hero card takes the name and its first letter at once.
    expect(find.text('Lyra'), findsWidgets);
    await tester.tap(next());
    await tester.pumpAndSettle();
    expect(find.text('Where do they come from?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('a class skill over the limit replaces the earliest one', () {
    final state = CharacterCreationState()
      ..selectedClass = _cls(choose: 2, from: ['a', 'b', 'c']);
    state.pickSkill('a');
    state.pickSkill('b');
    state.pickSkill('c');
    expect(state.selectedSkills, ['b', 'c']);
    state.pickSkill('b');
    expect(state.selectedSkills, ['c']);
  });

  test('values placed from the tray and bought points both complete abilities',
      () {
    final state = CharacterCreationState();
    expect(state.abilitiesComplete, isFalse);
    for (final (i, key) in CharacterCreationState.abilityKeys.indexed) {
      state.assignScore(key, CharacterCreationState.standardArray[i]);
    }
    expect(state.abilitiesComplete, isTrue);
    expect(state.abilityScores['strength'], 15);
    state.assignScore('strength', null);
    expect(state.abilitiesComplete, isFalse);

    state.setAllocationMethod('point_buy');
    expect(state.pointBuyLeft, 27);
    expect(state.abilitiesComplete, isTrue);
    state.setPointBuy('strength', 15);
    expect(state.pointBuyLeft, 18);
    expect(state.abilityScores['strength'], 15);

    state.setAllocationMethod('roll');
    expect(state.scorePool, isEmpty);
    state.setRolledScores([12, 13, 14, 15, 16, 17]);
    expect(state.scorePool, [12, 13, 14, 15, 16, 17]);
    expect(state.abilitiesComplete, isFalse);
  });
}

ClassData _cls({required int choose, required List<String> from}) =>
    ClassData.fromJson({
      'id': 'tester',
      'name': {'en': 'Tester', 'ru': 'Тестер'},
      'description': {'en': '', 'ru': ''},
      'hitDie': 8,
      'primaryAbilities': ['strength'],
      'savingThrowProficiencies': ['strength'],
      'armorProficiencies': <String, dynamic>{},
      'weaponProficiencies': <String, dynamic>{},
      'skillProficiencies': {'choose': choose, 'from': from},
      'subclasses': [],
      'subclassLevel': 3,
      'features': <String, dynamic>{},
    });

Widget _wrapWizard() {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      );
    },
    home: const CharacterCreationWizard(),
  );
}
