import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/expressive_hold_surface.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/resource_counter.dart';
import 'package:qd_and_d/features/character_sheet/widgets/spell_slots_widget.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'gameplay_state_editor_test.dart' as fixtures;

Widget app(Widget child, {bool reduced = false}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!),
      home: Scaffold(body: child),
    );
void main() {
  testWidgets(
      'hold squeezes and confirms once, cancellation never edits or spends',
      (tester) async {
    var edits = 0, spends = 0;
    final haptics = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(app(Center(
        child: ExpressiveHoldSurface(
      key: const Key('hold'),
      onHold: () => edits++,
      onTap: () => spends++,
      child: const SizedBox(width: 160, height: 56),
    ))));
    final target = find.byKey(const Key('hold'));
    var gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final transform = tester.widget<Transform>(
        find.descendant(of: target, matching: find.byType(Transform)));
    expect(transform.transform.storage[0], lessThan(1));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(edits, 0);
    expect(spends, 0);
    expect(haptics, isEmpty);
    await tester.longPress(target);
    await tester.pumpAndSettle();
    expect(edits, 1);
    expect(spends, 0);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(spends, 1);
    expect(edits, 1);
  });

  testWidgets('reduced motion keeps scale still while hold remains available',
      (tester) async {
    var edits = 0;
    await tester.pumpWidget(app(
        Center(
            child: ExpressiveHoldSurface(
                onHold: () => edits++,
                child: const SizedBox(width: 160, height: 56))),
        reduced: true));
    final target = find.byType(ExpressiveHoldSurface);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
        tester
            .widget<Transform>(
                find.descendant(of: target, matching: find.byType(Transform)))
            .transform
            .storage[0],
        1);
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(edits, 1);
  });

  for (final count in [1, 2, 3, 4, 7, 9]) {
    testWidgets(
        '$count compact slot cards center every row and have no calculator controls',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = fixtures.hero()
        ..spellSlots = List.filled(count, 4)
        ..maxSpellSlots = List.filled(count, 4);
      await tester.pumpWidget(app(Padding(
          padding: const EdgeInsets.all(32),
          child: SpellSlotsWidget(character: c, onChanged: () {}))));
      await tester.pumpAndSettle();
      final rows = <double, List<Rect>>{};
      for (var level = 1; level <= count; level++) {
        final rect =
            tester.getRect(find.byKey(ValueKey('slot-counter-$level')));
        rows.putIfAbsent(rect.top, () => []).add(rect);
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      for (final row in rows.values) {
        expect((row.first.left + row.last.right) / 2, closeTo(195, 1));
      }
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text('C1'), findsNothing);
      expect(find.byType(SheetResourceCounter), findsNWidgets(count));
      expect(tester.takeException(), isNull);
    });
  }
}
