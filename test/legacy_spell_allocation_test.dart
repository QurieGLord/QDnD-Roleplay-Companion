import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/progression/legacy_spell_allocation.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'package:qd_and_d/features/character_level_up/steps/hp_increase_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/legacy_spell_sources_step.dart';
import 'multiclass_magic_flow_test.dart' as flow;
import 'multiclass_sheet_integration_test.dart' as widgets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-legacy-origin-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'A single legacy caster retains its existing on-list spell interpretation without a write',
      () {
    final c = flow.mixed({'bard': 1})
      ..knownSpells = ['mage-hand', 'healing-word'];
    final before = jsonEncode(c.toJson());
    expect(LegacySpellAllocation.unambiguous(c),
        {'mage-hand': 'class:bard', 'healing-word': 'class:bard'});
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Off-list, missing and genuinely mixed records do not acquire a guessed class',
      () {
    final single = flow.mixed({'bard': 1})
      ..knownSpells = ['mage-hand', 'shield', 'missing-book'];
    expect(
        LegacySpellAllocation.unambiguous(single), {'mage-hand': 'class:bard'});
    final mixed = flow.mixed({'bard': 1, 'sorcerer': 1})
      ..knownSpells = ['mage-hand'];
    expect(LegacySpellAllocation.unambiguous(mixed), isEmpty);
  });
  testWidgets(
      'Adding a new class to an unambiguous bard opens HP directly and cancellation preserves the original',
      (tester) async {
    final c = flow.mixed({'bard': 1})
      ..knownSpells = ['mage-hand', 'healing-word'];
    final before = jsonEncode(c.toJson());
    await tester.pumpWidget(widgets.app(LevelUpScreen(
        character: c,
        newClass: CharacterDataService.getClassById('sorcerer')!)));
    await tester.pumpAndSettle();
    expect(find.byType(LegacySpellSourcesStep), findsNothing);
    expect(find.byType(HpIncreaseStep), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(jsonEncode(c.toJson()), before);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: ambiguous origins explain the choice and remain usable at large text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = flow.mixed({'bard': 1, 'sorcerer': 1});
      var selected = <String, String>{};
      await tester.pumpWidget(widgets.app(
          StatefulBuilder(
              builder: (context, setState) => LegacySpellSourcesStep(
                  before: c,
                  preview: c,
                  ids: const ['mage-hand'],
                  selected: selected,
                  onChanged: (v) => setState(() => selected = v),
                  onNext: () {})),
          locale: locale,
          scale: 1.7));
      expect(
          find.text(locale == 'ru'
              ? 'Откуда эти заклинания?'
              : 'Where did these spells come from?'),
          findsOneWidget);
      final choice = find.text(
          locale == 'ru' ? 'Дар или правило стола' : 'Gift or table ruling');
      await tester.scrollUntilVisible(choice, 220);
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(selected, {'mage-hand': 'manual'});
      expect(tester.takeException(), isNull);
    });
  }
}
