import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/progression/advancement_history.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/shared/widgets/advancement_history_sheet.dart';
import 'package:qd_and_d/features/character_sheet/widgets/expandable_character_card.dart';
import 'package:qd_and_d/features/character_sheet/character_sheet_screen.dart';
import 'multiclass_magic_flow_test.dart' as flow;
import 'multiclass_sheet_integration_test.dart' as widgets;
import 'advancement_history_test.dart' as actions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-history-ui-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: preview is read-only, usable at large text, and confirmation performs one rollback',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = flow.mixed({'fighter': 1});
      await actions.advance(c, 'fighter');
      c.currentHp = 3;
      await tester.pumpWidget(widgets.app(
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => showAdvancementHistory(context, c),
                  child: const Text('Open'))),
          locale: locale,
          scale: 1.5));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final record = find.text(
          locale == 'ru' ? 'Уровень героя 1 → 2' : 'Character level 1 → 2');
      await tester.ensureVisible(record);
      await tester.pumpAndSettle();
      await tester.tap(record);
      await tester.pumpAndSettle();
      expect(c.level, 2);
      expect(find.text(locale == 'ru' ? 'После отката' : 'After reverting'),
          findsOneWidget);
      final confirm =
          find.text(locale == 'ru' ? 'Подтвердить откат' : 'Confirm rollback');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(confirm);
        await GameplayActionsService.serializeCharacter(
            c, () => Hive.box<Character>('characters').flush());
      });
      await tester.pumpAndSettle();
      expect(c.level, 1);
      expect(c.currentHp, 3);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Confirming rollback refreshes the whole sheet without leaving Overview',
      (tester) async {
    final c = flow.mixed({'fighter': 1})
      ..maxHp = 20
      ..currentHp = 11;
    await actions.advance(c, 'druid');
    await tester.pumpWidget(
        widgets.app(CharacterSheetScreen(character: c), locale: 'ru'));
    await tester.pumpAndSettle();
    // The rolling HP number is read through its accessible label.
    String healthText() => tester
        .widget<Semantics>(find
            .descendant(
                of: find.byKey(const ValueKey('sheet-health-edit')),
                matching: find.byWidgetPredicate(
                    (w) => w is Semantics && w.properties.label != null))
            .first)
        .properties
        .label!;
    expect(healthText(), '11 / ${c.maxHp}');
    await tester
        .longPress(find.byKey(const ValueKey('character-level-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Уровень героя 1 → 2'));
    await tester.pumpAndSettle();
    final confirm = find.text('Подтвердить откат');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(confirm);
      await GameplayActionsService.serializeCharacter(
          c, () => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(c.level, 1);
    expect(healthText(), '11 / 20');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Holding the level control squeezes it and opens history without advancing',
      (tester) async {
    final c = flow.mixed({'fighter': 1});
    await tester.pumpWidget(widgets.app(ExpandableCharacterCard(
        character: c, onDicePressed: () {})));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('character-level-control'));
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final transform = tester.widget<Transform>(
        find.descendant(of: target, matching: find.byType(Transform)).first);
    expect(transform.transform.storage[0], lessThan(1));
    expect(c.level, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Level-up history'), findsOneWidget);
    expect(c.level, 1);
    expect(AdvancementHistory.read(c), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
