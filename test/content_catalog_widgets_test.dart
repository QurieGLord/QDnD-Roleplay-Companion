import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/features/spell_almanac/spell_almanac_screen.dart';
import 'package:qd_and_d/features/character_level_up/widgets/class_advancement_picker.dart';
import 'package:qd_and_d/shared/widgets/spell_details_sheet.dart';
import 'spell_almanac_test.dart' as spells;
import 'multiclass_magic_flow_test.dart' as flow;
import 'multiclass_sheet_integration_test.dart' as widgets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-content-ui-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  setUp(() async {
    await Hive.box<Spell>('spells_library').clear();
    await Hive.box<ClassData>('classes_library').clear();
    await SpellService.reload();
    await CharacterDataService.reload();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets(
      'Almanac presents identical multi-book records as one row without deleting source records',
      (tester) async {
    await tester.runAsync(() async {
      await StorageService.saveSpells([
        for (final id in ['a', 'b', 'c'])
          spells.spell('audit-$id',
              en: 'Audit Wave', ru: 'Проверочная волна', source: id)
      ]);
      await SpellService.reload();
    });
    await tester.pumpWidget(widgets.app(const SpellAlmanacScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Audit Wave');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Audit Wave'),
        findsOneWidget);
    expect(SpellService.getAllSpells().where((s) => s.nameEn == 'Audit Wave'),
        hasLength(3));
    expect(find.text('3 sources · 1 version'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Different same-name spell variants require an explicit choice and show the chosen description',
      (tester) async {
    final a = spells.spell('audit-a',
            en: 'Audit Wave', ru: 'Проверочная волна', source: 'a')
          ..descriptionEn = 'Ordinary effect',
        b = spells.spell('audit-b',
            en: 'Audit Wave', ru: 'Проверочная волна', source: 'b')
          ..descriptionEn = 'Changed homebrew effect';
    await tester.runAsync(() async {
      await StorageService.saveSpells([a, b]);
      await SpellService.reload();
    });
    await tester.pumpWidget(widgets.app(const SpellAlmanacScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Audit Wave');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Audit Wave'));
    await tester.pumpAndSettle();
    expect(find.byType(SpellDetailsSheet), findsNothing);
    expect(find.text('Changed homebrew effect'), findsOneWidget);
    await tester.tap(find.text('Changed homebrew effect'));
    await tester.pumpAndSettle();
    expect(find.byType(SpellDetailsSheet), findsOneWidget);
    expect(find.text('Changed homebrew effect'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: class family appears once, explicit rules variants remain accessible at large text',
        (tester) async {
      tester.view.physicalSize = const Size(390, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = CharacterDataService.getClassById('sorcerer')!;
      await tester.runAsync(() async {
        await StorageService.saveClasses([
          for (final spec in [('a', 8), ('b', 10)])
            ClassData.fromJson({
              ...QdndBundleCodec.classToJson(base),
              'id': 'audit-${spec.$1}',
              'sourceId': spec.$1,
              'hitDie': spec.$2,
              'rulesMetadata': {
                'edition': '2014',
                'declaredFields': ['hitDie']
              }
            })
        ]);
        await CharacterDataService.reload();
      });
      final hero = flow.mixed({'fighter': 1});
      CharacterClassRules.capture(CharacterDataService.getClassById('fighter')!)
          .attachTo(hero.classes.single);
      await tester.pumpWidget(widgets.app(
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => chooseAdvancementClass(context, hero),
                  child: const Text('Open'))),
          locale: locale,
          scale: 1.5));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final title = locale == 'ru' ? 'Чародей' : 'Sorcerer';
      await tester.scrollUntilVisible(find.text(title), 350,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.textContaining('d8'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
