import 'package:qd_and_d/features/character_level_up/steps/class_magic_step.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart' show RollingNumber;
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'package:qd_and_d/features/character_level_up/steps/hp_increase_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/features_step.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/cleric_magic_widget.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

Character hero(String cls, int level) => Character(
      spellSlots: [],
      maxSpellSlots: [],
      id: 'cd-$cls-$level',
      name: 'CD hero',
      race: 'human',
      characterClass: cls,
      level: level,
      maxHp: 20,
      currentHp: 20,
      subclass: cls == 'cleric' ? 'Life Domain' : null,
      abilityScores: AbilityScores(
          strength: 14,
          dexterity: 12,
          constitution: 14,
          intelligence: 10,
          wisdom: 16,
          charisma: 16),
    );
Widget app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('qdnd_cd_cycle_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
    await StorageService.init();
    await CharacterDataService.loadAllData();
    await FeatureService.init();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  for (final cls in ['cleric', 'paladin']) {
    test('$cls acquisition, spend, manual excess and rest share a resource',
        () async {
      final c = hero(cls, cls == 'cleric' ? 2 : 3);
      FeatureService.addFeaturesToCharacter(c);
      expect(c.channelDivinityCharges, 1);
      expect(c.channelDivinityResources, isNotEmpty);
      expect(
          c.channelDivinityResources
              .every((f) => f.resourcePool!.currentUses == 1),
          isTrue);
      expect(
          c.consumeChannelDivinity(
              source: c.channelDivinityResource!.resourcePool),
          isTrue);
      expect(c.channelDivinityCharges, 0);
      expect(c.channelDivinityResource!.resourcePool!.currentUses, 0);
      c.setChannelDivinityCharges(6);
      c.shortRest();
      expect(c.channelDivinityCharges, 6);
      c.consumeChannelDivinity();
      await StorageService.saveCharacter(c);
      expect(StorageService.getCharacter(c.id)!.channelDivinityCharges, 5);
      expect(c.channelDivinityResource!.resourcePool!.currentUses, 5);
    });
  }

  test(
      'spent upgrade does not grant uses; custom recovery controls both counters',
      () {
    final c = hero('cleric', 6);
    c.features.add(FeatureService.getFeatureById('channel-divinity-1-rest')!
        .copyForCharacter());
    c.setChannelDivinityCharges(0);
    FeatureService.addFeaturesToCharacter(c);
    expect(c.channelDivinityCharges, 0);
    expect(
        c.channelDivinityResources
            .every((f) => f.resourcePool!.currentUses == 0),
        isTrue);
    for (final f in c.channelDivinityResources) {
      f.resourcePool!.recoveryType = RecoveryType.longRest;
    }
    c.shortRest();
    expect(c.channelDivinityCharges, 0);
    c.longRest();
    expect(c.channelDivinityCharges, 2);
    c.setChannelDivinityCharges(6);
    for (final f in c.channelDivinityResources) {
      f.resourcePool!.recoveryType = RecoveryType.manual;
    }
    c.longRest();
    expect(c.channelDivinityCharges, 6);
  });

  test('save preserves legacy mismatch; explicit rest preserves hidden excess',
      () async {
    final c = hero('cleric', 2);
    FeatureService.addFeaturesToCharacter(c);
    c.channelDivinityCharges = 0;
    c.channelDivinityResource!.resourcePool!.currentUses = 6;
    await StorageService.saveCharacter(c);
    expect(c.channelDivinityCharges, 0);
    expect(c.channelDivinityResource!.resourcePool!.currentUses, 6);
    c.shortRest();
    expect(c.channelDivinityCharges, 6);
    expect(c.channelDivinityResource!.resourcePool!.currentUses, 6);
  });

  testWidgets(
      'Cleric panel keeps a zero-capacity manual reserve visible and spendable',
      (tester) async {
    final c = hero('cleric', 6);
    FeatureService.addFeaturesToCharacter(c);
    c.channelDivinityResource!.resourcePool!.maxUses = 0;
    c.setChannelDivinityCharges(6);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(SingleChildScrollView(
        child: ClericMagicWidget(character: c, onStateChanged: () {}))));
    await tester.pumpAndSettle();
    // The sun carries the reserve: six charges remain over a zero capacity.
    final use = find.byKey(const ValueKey('cleric-sun'));
    expect(
        tester
            .widget<RollingNumber>(
                find.descendant(of: use, matching: find.byType(RollingNumber)))
            .value,
        6);
    await tester.ensureVisible(use);
    await tester.runAsync(() async {
      await tester.tap(use);
      await GameplayActionsService.serializeCharacter(c, () async {});
    });
    await tester.pumpAndSettle();
    expect(c.channelDivinityCharges, 5);
    expect(c.channelDivinityResource!.resourcePool!.maxUses, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'An acquired domain option uses the shared channel without healing the actor',
      (tester) async {
    final c = hero('cleric', 6)..currentHp = 7;
    FeatureService.addFeaturesToCharacter(c);
    expect(c.features.any((f) => f.id == 'channel-divinity-preserve-life'),
        isTrue);
    c.setChannelDivinityCharges(1);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(SingleChildScrollView(
        child: ClericMagicWidget(character: c, onStateChanged: () {}))));
    await tester.pumpAndSettle();
    // Preserve Life is the way on the right; the sun spends the channel and
    // opens the distribution, never healing the cleric by itself.
    await tester.tap(find.byKey(const ValueKey('cleric-way-1')));
    await tester.pumpAndSettle();
    final use = find.byKey(const ValueKey('cleric-sun'));
    await tester.ensureVisible(use);
    await tester.runAsync(() async {
      await tester.tap(use);
      await tester.tap(use);
      await GameplayActionsService.serializeCharacter(c, () async {});
    });
    await tester.pumpAndSettle();
    expect(c.channelDivinityCharges, 0);
    expect(c.currentHp, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real cleric level-up grants a usable channel and Turn Undead spends it',
      (tester) async {
    final c = hero('cleric', 1);
    FeatureService.addFeaturesToCharacter(c);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => LevelUpScreen(character: c))),
            child: const Text('Open level up')))));
    await tester.tap(find.text('Open level up'));
    await tester.pumpAndSettle();
    // Exercise the actual callbacks wired by the level-up screen.
    tester.widget<HpIncreaseStep>(find.byType(HpIncreaseStep)).onAverage();
    await tester.pumpAndSettle();
    tester
        .widget<FeaturesStep>(
            find.byKey(const ValueKey(FeaturesStepContent.features)))
        .onNext();
    await tester.pumpAndSettle();
    tester
        .widget<ClassMagicStep>(
            find.byKey(const ValueKey(FeaturesStepContent.magic)))
        .onNext();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Confirm level-up'));
      await GameplayActionsService.serializeCharacter(
          c, () => Hive.box<Character>('characters').flush());
    });
    await tester.pumpAndSettle();
    expect(c.level, 2);
    expect(c.channelDivinityCharges, 1);
    expect(c.channelDivinityResource!.resourcePool!.currentUses, 1);
    await tester.pumpWidget(app(SingleChildScrollView(
        child: ClericMagicWidget(character: c, onStateChanged: () {}))));
    await tester.pumpAndSettle();
    final use = find.byKey(const ValueKey('cleric-sun'));
    await tester.scrollUntilVisible(use, 200);
    await tester.runAsync(() => tester.tap(use));
    await tester.pumpAndSettle();
    expect(c.channelDivinityCharges, 0);
    expect(c.channelDivinityResource!.resourcePool!.currentUses, 0);
    expect(tester.takeException(), isNull);
  });
}
