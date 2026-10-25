import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';

/// A companion sheet closes with a swipe down: on its floating handle, and
/// by pulling its content down from the top.
void main() {
  Future<void> open(WidgetTester tester, {int rows = 40}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showCompanionSheet<void>(context,
                builder: (_) => Column(children: [
                      for (var i = 0; i < rows; i++)
                        SizedBox(height: 48, child: Text('row $i')),
                    ])),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
  }

  testWidgets('a swipe on the handle closes a long sheet', (tester) async {
    await open(tester);
    await tester.flingFrom(
        tester.getCenter(find.byType(SheetGrab)), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });

  testWidgets('pulling the content down from its top closes the sheet',
      (tester) async {
    await open(tester);
    await tester.drag(find.text('row 3'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });

  testWidgets('a short sheet closes with a swipe on its content',
      (tester) async {
    await open(tester, rows: 3);
    await tester.flingFrom(
        tester.getCenter(find.text('row 1')), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });

  testWidgets('scrolling down the content does not close it', (tester) async {
    await open(tester);
    await tester.drag(find.text('row 5'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(SheetGrab), findsOneWidget);
  });
}
