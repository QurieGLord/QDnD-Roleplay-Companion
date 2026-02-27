// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:qd_and_d/main.dart';

void main() {
  testWidgets('QD&D app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QDnDApp());

    // Verify that splash screen shows QD&D title
    expect(find.text('QD&D'), findsOneWidget);
    expect(find.text('Your Roleplay Companion'), findsOneWidget);
  });
}
