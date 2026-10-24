import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/magic_slots.dart';
import 'package:qd_and_d/core/magic/companion_state.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/cleric_magic_widget.dart';
import 'package:qd_and_d/shared/widgets/feature_slot_sheet.dart';
import 'package:qd_and_d/shared/widgets/companion_editor.dart';
import 'multiclass_magic_flow_test.dart' as flow;
import 'multiclass_sheet_integration_test.dart' as widgets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-class-ui-');
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
        '$locale: intervention own-level and cooldown remain readable at large text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = flow.mixed({'cleric': 10, 'fighter': 10});
      c.features.add(FeatureService.getFeatureById('divine-intervention')!
          .copyForCharacter());
      c.divineInterventionUsed = true;
      await tester.pumpWidget(widgets.app(
          SingleChildScrollView(
              child: ClericMagicWidget(character: c, onStateChanged: () {})),
          locale: locale,
          scale: 1.7));
      await tester.scrollUntilVisible(find.text('10%'), 200);
      await tester.pumpAndSettle();
      expect(
          find.text(locale == 'ru' ? 'через 7 дней' : 'in 7 days'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Companion editor opens without focus and saves an independent overfilled reserve',
      (tester) async {
    final c = flow.mixed({'ranger': 3, 'druid': 2});
    c.isWildShaped = true;
    c.beastCurrentHp = 34;
    c.beastMaxHp = 34;
    await tester.pumpWidget(widgets.app(Builder(
        builder: (context) => TextButton(
            onPressed: () => showCompanionEditor(context, c),
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.autofocus, false);
    }
    await tester.enterText(fields.at(0), 'Wolf');
    await tester.enterText(fields.at(1), '6');
    await tester.enterText(fields.at(2), '4');
    final save = find.text('Save companion');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(save);
      await GameplayActionsService.serializeCharacter(
          c, () => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(CompanionState.read(c)!.current, 6);
    expect(c.beastCurrentHp, 34);
    expect(c.isWildShaped, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Awareness shows both pools, Pact requires an explicit ruling and reading spends nothing',
      (tester) async {
    final c = flow.mixed({'ranger': 3, 'warlock': 3}),
        feature = FeatureService.getFeatureById('primeval-awareness')!
            .copyForCharacter();
    c.features.add(feature);
    flow.slots(c, shared: 6, pact: 2, circle: 2);
    await tester.pumpWidget(widgets.app(Builder(
        builder: (context) => TextButton(
            onPressed: () => showPrimevalAwarenessSheet(context, c, feature),
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pact Magic'));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, 'Sense presence');
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
    expect(MagicSlots.read(c).pact!.current, 2);
    expect(c.spellSlots, [6]);
    expect(tester.takeException(), isNull);
  });
}
