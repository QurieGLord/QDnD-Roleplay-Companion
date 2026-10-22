import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/progression/character_class_context.dart';
import 'package:qd_and_d/core/progression/character_training.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/spellcasting_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/magic/spell_use.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/features/character_sheet/widgets/spell_slots_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/rogue_tools_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/cleric_magic_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/druid_magic_widget.dart';
import 'package:qd_and_d/features/character_list/widgets/hero_deck.dart';
import 'multiclass_magic_flow_test.dart' as flow;
import 'multiclass_sheet_integration_test.dart' as widgets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-acquisition-');
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
      'All twelve class levels govern acquisition at every boundary despite a total level of twenty',
      () {
    const ids = [
      'barbarian',
      'bard',
      'cleric',
      'druid',
      'fighter',
      'monk',
      'paladin',
      'ranger',
      'rogue',
      'sorcerer',
      'warlock',
      'wizard'
    ];
    var cases = 0;
    for (final id in ids) {
      final features = FeatureService.allFeatures.where((f) =>
          FeatureService.classKey(f.associatedClass ?? '') == id &&
          f.associatedSubclass == null &&
          !f.isOptional);
      for (var own = 1; own <= 20; own++) {
        final c = flow.mixed({
          id: own,
          if (own < 20) (id == 'fighter' ? 'wizard' : 'fighter'): 20 - own
        });
        for (final f in features) {
          expect(
              CharacterClassContext(c, id).canUseFeature(f), f.minLevel <= own,
              reason: '$id $own: ${f.id}');
          cases++;
        }
      }
    }
    expect(cases, greaterThan(3000));
  });
  testWidgets(
      'Druid one does not expose a stale Wild Shape action, Druid two does',
      (tester) async {
    final c = flow.mixed({'fighter': 18, 'druid': 1});
    final stale = FeatureService.getFeatureById('wild-shape-action')!
        .copyForCharacter()
      ..minLevel = 1;
    c.features = [stale];
    expect(CharacterClassContext(c, 'druid').canUseFeature(stale), false);
    await tester.pumpWidget(widgets.app(SingleChildScrollView(
        child: DruidMagicWidget(character: c, onStateChanged: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Wild Shape'), findsNothing);
    expect(find.text('Transform'), findsNothing);
    c.classes.last.level = 2;
    c.level = 20;
    await tester.pumpWidget(widgets.app(SingleChildScrollView(
        child: DruidMagicWidget(character: c, onStateChanged: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Wild Shape'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('Extra Attack and prepared spell allowance use their own class levels',
      () {
    final c = flow.mixed({'wizard': 1, 'fighter': 19});
    c.features = [
      FeatureService.getFeatureById('extra-attack-3')!.copyForCharacter()
    ];
    expect(CharacterTraining.attacks(c), 1);
    expect(SpellcastingService.getMaxPreparedSpells(c), 5);
    final cap = flow.mixed({'fighter': 20})..features = c.features;
    expect(CharacterTraining.attacks(cap), 4);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: lobby shows each class and its own level at large text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = flow.mixed({'fighter': 3, 'druid': 1});
      await tester.pumpWidget(widgets.app(
          HeroDeck(characters: [c], onOpen: (_, __) {}, onHold: (_) {}),
          scale: 1.5,
          locale: locale));
      await tester.pumpAndSettle();
      final classes =
          locale == 'ru' ? ['Воин 3', 'Друид 1'] : ['Fighter 3', 'Druid 1'];
      for (final text in classes) {
        expect(find.text(text), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('A stale ninth-circle Arcanum cannot bypass its own class level', () {
    final c = flow.mixed({'warlock': 11, 'fighter': 9}),
        spell = flow.spell(circle: 9);
    final feature = FeatureService.getFeatureById('mystic-arcanum-9th-level')!
        .copyForCharacter();
    feature.resourcePool!.currentUses = 1;
    c.features = [feature];
    final b = SpellbookState.read(c.spellbookData)
      ..bindArcanum('class:warlock', 9, spell.id);
    c.spellbookData = b.toJson();
    c.knownSpells = [spell.id];
    flow.slots(c, circle: 5, pact: 3);
    expect(
        SpellUse.options(c, spell)
            .any((o) => o.method == SpellUseMethod.arcanum),
        false);
    c.classes.first.level = 17;
    c.classes.last.level = 3;
    expect(
        SpellUse.options(c, spell)
            .any((o) => o.method == SpellUseMethod.arcanum),
        true);
  });
  testWidgets(
      'Future Arcanum, rogue defenses and cleric channels do not appear from stale records',
      (tester) async {
    final warlock = flow.mixed({'warlock': 1, 'fighter': 19});
    warlock.features = [
      FeatureService.getFeatureById('mystic-arcanum-9th-level')!
          .copyForCharacter()
    ];
    await tester.pumpWidget(widgets.app(SingleChildScrollView(
        child: SpellSlotsWidget(character: warlock, onChanged: () {}))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('arcanum-counter-9')), findsNothing);
    final rogue = flow.mixed({'rogue': 1, 'fighter': 19});
    rogue.features = [
      for (final id in ['sneak-attack', 'uncanny-dodge', 'rogue-evasion'])
        FeatureService.getFeatureById(id)!.copyForCharacter()
    ];
    await tester.pumpWidget(widgets
        .app(SingleChildScrollView(child: RogueToolsWidget(character: rogue))));
    await tester.pumpAndSettle();
    expect(find.text('Uncanny Dodge'), findsNothing);
    expect(find.text('Evasion'), findsNothing);
    final cleric = flow.mixed({'cleric': 1, 'fighter': 19})
      ..channelDivinityCharges = 6;
    cleric.features = [
      FeatureService.getFeatureById('channel-divinity-2-rest')!
          .copyForCharacter()
    ];
    await tester.pumpWidget(widgets.app(SingleChildScrollView(
        child: ClericMagicWidget(character: cleric, onStateChanged: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Channel Divinity'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
      'Missing form charges initialize from the owning class; explicit table values remain authoritative',
      () {
    for (final levels in [
      {'fighter': 19, 'druid': 1},
      {'fighter': 18, 'druid': 2},
      {'fighter': 20}
    ]) {
      final original = flow.mixed(levels),
          json = QdndBundleCodec.characterToJson(original)
            ..remove('wildShapeCharges');
      final loaded = QdndBundleCodec.characterFromJson(json);
      expect(loaded.wildShapeCharges, (levels['druid'] ?? 0) >= 2 ? 2 : 0);
      json['wildShapeCharges'] = 6;
      expect(QdndBundleCodec.characterFromJson(json).wildShapeCharges, 6);
    }
  });
}
