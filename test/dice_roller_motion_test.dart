import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/dice_roller_modal.dart';

/// Always rolls the highest face.
class _TopFace implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  double nextDouble() => .5;
  @override
  bool nextBool() => true;
}

Widget _host({required bool reduced, Random? random, int modifier = 5}) =>
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(412, 915), disableAnimations: reduced),
        child: Scaffold(
            body: SingleChildScrollView(
                child: DiceRollerModal(
                    title: 'Атака', initialModifier: modifier, random: random))),
      ),
    );

int? _shownTotal(WidgetTester tester) {
  final total = find.byKey(const ValueKey('dice-total'));
  return total.evaluate().isEmpty
      ? null
      : tester.widget<RollingNumber>(total).value;
}

void main() {
  testWidgets('a throw lands, rolls the total in and leaves no pending timers',
      (tester) async {
    await tester.pumpWidget(_host(reduced: false));
    await tester.tap(find.byKey(const ValueKey('dice-roll')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Бросок...'), findsOneWidget);
    await tester.pumpAndSettle();
    final total = _shownTotal(tester);
    expect(total, isNotNull);
    expect(total, inInclusiveRange(1 + 5, 20 + 5));
  });

  testWidgets('a natural 20 is named and keeps its total', (tester) async {
    await tester.pumpWidget(_host(reduced: false, random: _TopFace()));
    await tester.tap(find.byKey(const ValueKey('dice-roll')));
    await tester.pumpAndSettle();
    expect(_shownTotal(tester), 25);
    expect(find.text('Критический успех'), findsOneWidget);
  });

  testWidgets('reduced motion shows the result at once', (tester) async {
    await tester.pumpWidget(_host(reduced: true, random: _TopFace()));
    await tester.tap(find.byKey(const ValueKey('dice-roll')));
    await tester.pump();
    expect(_shownTotal(tester), 25);
    expect(find.text('Бросок...'), findsNothing);
  });
}

