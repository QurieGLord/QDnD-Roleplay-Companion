import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/features/character_level_up/widgets/advancement_climb.dart';

void main() {
  Widget page({required VoidCallback onHold, required VoidCallback onTap}) =>
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            for (var i = 0; i < 12; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: AdvancementPick(
                  key: ValueKey('pick-$i'),
                  selected: false,
                  title: 'Option $i',
                  icon: 'star',
                  accent: Colors.teal,
                  onTap: onTap,
                  onInfo: onHold,
                ),
              ),
          ]),
        ),
      );

  // The outline is painted over the card only while it is lit.
  bool lit(WidgetTester tester, String key) => tester
      .widgetList<CustomPaint>(find.descendant(
          of: find.byKey(ValueKey(key)), matching: find.byType(CustomPaint)))
      .any((p) => p.foregroundPainter != null);

  testWidgets('a touch that scrolls never lights a card, and nothing stays lit',
      (tester) async {
    var held = 0, taps = 0;
    await tester.pumpWidget(page(onHold: () => held++, onTap: () => taps++));
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('pick-1'))));
    await tester.pump(const Duration(milliseconds: 60));
    await g.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(lit(tester, 'pick-1'), isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(lit(tester, 'pick-1'), isFalse);
    expect(held, 0);
    expect(taps, 0);
  });

  testWidgets('a quick tap selects without an outline', (tester) async {
    var held = 0, taps = 0;
    await tester.pumpWidget(page(onHold: () => held++, onTap: () => taps++));
    await tester.tap(find.byKey(const ValueKey('pick-2')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(held, 0);
    expect(lit(tester, 'pick-2'), isFalse);
  });

  testWidgets('a real hold lights the outline, opens and then puts it out',
      (tester) async {
    var held = 0, taps = 0;
    await tester.pumpWidget(page(onHold: () => held++, onTap: () => taps++));
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('pick-3'))));
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 16));
    expect(lit(tester, 'pick-3'), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(held, 1);
    await g.up();
    await tester.pumpAndSettle();
    expect(lit(tester, 'pick-3'), isFalse);
    expect(taps, 0);
  });
}
