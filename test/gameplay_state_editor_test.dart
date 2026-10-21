import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_sheet/widgets/gameplay_state_editor.dart';
import 'package:qd_and_d/features/character_sheet/widgets/overview_tab.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

Character hero() => Character(
      id: 'editor-hero',
      name: 'Editor hero',
      race: 'human',
      characterClass: 'fighter',
      level: 3,
      maxHp: 20,
      currentHp: 17,
      spellSlots: [6],
      maxSpellSlots: [4],
      abilityScores: AbilityScores(
        strength: 16,
        dexterity: 14,
        constitution: 14,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      ),
      features: [
        CharacterFeature(
          id: 'library-reserve',
          nameEn: 'Library reserve',
          nameRu: 'Библиотечный ресурс',
          descriptionEn: 'Installed library text',
          descriptionRu: 'Текст установленной библиотеки',
          sourceId: 'test-source',
          minLevel: 1,
          type: FeatureType.resourcePool,
          resourcePool: ResourcePool(
            currentUses: 6,
            maxUses: 4,
            recoveryType: RecoveryType.shortRest,
          ),
        ),
      ],
    );

Widget app(Character c, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showGameplayStateEditor(context, c),
            child: const Text('Open'),
          ),
        ),
      ),
    );

Future<void> open(
  WidgetTester tester,
  Character c, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(app(c, locale: locale));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder field(String id) => find.byKey(ValueKey('game-state-$id'));

Future<void> expand(WidgetTester tester, String title) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester
      .tap(find.widgetWithText(Tab, title == 'Spell slots' ? 'Magic' : title));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('qdnd_editor_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    await StorageService.init();
    await FeatureService.init();
    await SpellService.loadSpells();
  });
  setUp(() async {
    await Hive.box<Character>('characters').clear();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  testWidgets(
    'cancel discards numeric drafts and leaves persisted state intact',
    (tester) async {
      final c = hero();
      await tester.runAsync(() => StorageService.saveCharacter(c));
      await open(tester, c);
      await tester.enterText(field('hp'), '31');
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(c.currentHp, 17);
      expect(StorageService.getCharacter(c.id)!.currentHp, 17);
    },
  );

  testWidgets('manual HP and pinned AC save without stripping library state', (
    tester,
  ) async {
    final c = hero()..armorClass = 19;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c);
    await tester.enterText(field('hp'), '31');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('game-state-save')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (Hive.box<Character>('characters').isOpen) {
        await Hive.box<Character>('characters').flush();
      }
    });
    await tester.pumpAndSettle();
    expect(c.currentHp, 31);
    expect(c.maxHp, 20);
    expect(c.armorClass, 19);
    expect(c.armorClassOverride, 19);
    expect(c.features.single.descriptionEn, 'Installed library text');
    expect(c.features.single.sourceId, 'test-source');
  });

  testWidgets(
    'a slot remainder above normal is directly editable and persisted',
    (tester) async {
      final c = hero();
      await tester.runAsync(() => StorageService.saveCharacter(c));
      await open(tester, c);
      await expand(tester, 'Spell slots');
      await tester.scrollUntilVisible(
        field('slot-1'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.enterText(field('slot-1'), '9');
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('game-state-save')));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (Hive.box<Character>('characters').isOpen) {
          await Hive.box<Character>('characters').flush();
        }
      });
      await tester.pumpAndSettle();
      expect(c.spellSlots.first, 9);
      expect(c.maxSpellSlots.first, 4);
      await tester.runAsync(() async {
        c.useSpellSlot(1);
        await c.save();
      });
      expect(c.spellSlots.first, 8);
      c.longRest();
      expect(c.spellSlots.first, 8);
    },
  );

  testWidgets(
    'an invalid draft on another tab cannot be saved',
    (tester) async {
      final c = hero();
      await tester.runAsync(() => StorageService.saveCharacter(c));
      await open(tester, c);
      await expand(tester, 'Spell slots');
      await tester.scrollUntilVisible(
        field('slot-1'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.enterText(field('slot-1'), '-1');
      await tester.pumpAndSettle();
      await expand(tester, 'Basics');
      await tester.pumpAndSettle();
      expect(field('slot-1'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('game-state-save')));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (Hive.box<Character>('characters').isOpen) {
          await Hive.box<Character>('characters').flush();
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(GameplayStateEditor), findsOneWidget);
      expect(c.spellSlots.first, 6);
    },
  );

  testWidgets('an automatic AC choice explicitly clears the previous pin', (
    tester,
  ) async {
    final c = hero()..armorClass = 19;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('game-state-manual-armor')),
      180,
      scrollable: find
          .byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down)
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-state-manual-armor')));

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('game-state-save')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (Hive.box<Character>('characters').isOpen) {
        await Hive.box<Character>('characters').flush();
      }
    });
    await tester.pumpAndSettle();
    expect(c.armorClassOverride, isNull);
    expect(c.usesAutomaticArmorClass, true);
    expect(c.armorClass, 12);
  });

  testWidgets(
    'RU editor uses localised labels and keeps six of four unchanged',
    (tester) async {
      final c = hero();
      await tester.runAsync(() => StorageService.saveCharacter(c));
      await open(tester, c, locale: const Locale('ru'));
      expect(find.text('Редактировать персонажа'), findsOneWidget);
      expect(find.text('Текущие ОЗ'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('game-state-save')));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (Hive.box<Character>('characters').isOpen) {
          await Hive.box<Character>('characters').flush();
        }
      });
      await tester.pumpAndSettle();
      expect(c.spellSlots, [6]);
      expect(c.features.single.resourcePool!.currentUses, 6);
    },
  );

  testWidgets(
    'active overview accepts over-normal HP with a zero reference maximum',
    (tester) async {
      final c = hero()
        ..currentHp = 6
        ..maxHp = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OverviewTab(character: c)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.currentHp, 6);
    },
  );

  for (final value in [null, '0', '6']) {
    testWidgets(
        'CD edit $value preserves intent and synchronizes only explicit edits',
        (tester) async {
      final c = Character(
          spellSlots: [],
          maxSpellSlots: [],
          id: 'cd-editor',
          name: 'Cleric',
          race: 'human',
          characterClass: 'cleric',
          level: 2,
          maxHp: 20,
          currentHp: 17,
          abilityScores: hero().abilityScores);
      FeatureService.addFeaturesToCharacter(c);
      c.channelDivinityCharges = 0;
      expect(c.channelDivinityResource!.resourcePool!.currentUses, 1);
      await tester.runAsync(() => StorageService.saveCharacter(c));
      await open(tester, c);
      await tester.enterText(field('hp'), '18');
      if (value != null) {
        await expand(tester, 'Resources');
        expect(find.byType(GameplayStateEditor), findsOneWidget);
        expect(field('channel-divinity'), findsOneWidget);
        await tester.ensureVisible(field('channel-divinity'));
        // Clear and re-enter: sending the identical editing state is not an edit.
        await tester.enterText(field('channel-divinity'), '');
        await tester.enterText(field('channel-divinity'), value);
      }
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('game-state-save')));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Hive.box<Character>('characters').flush();
      });
      await tester.pumpAndSettle();
      expect(c.currentHp, 18);
      expect(c.channelDivinityCharges, value == null ? 0 : int.parse(value));
      expect(c.channelDivinityResource!.resourcePool!.currentUses,
          value == null ? 1 : int.parse(value));
    });
  }

  testWidgets('visiting resources does not grant missing arcanum uses',
      (tester) async {
    final c = hero()
      ..characterClass = 'warlock'
      ..level = 20
      ..classes = [CharacterClass(id: 'warlock', name: 'Warlock', level: 20)]
      ..features = [];
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c);
    await expand(tester, 'Resources');
    await tester.scrollUntilVisible(field('arcanum-6'), 180,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    expect(field('arcanum-6'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('game-state-save')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    expect(c.features, isEmpty);
    expect(StorageService.getCharacter(c.id)!.features, isEmpty);
  });

  testWidgets(
      'explicit arcanum correction saves excess without granting others',
      (tester) async {
    final c = hero()
      ..characterClass = 'warlock'
      ..level = 20
      ..classes = [CharacterClass(id: 'warlock', name: 'Warlock', level: 20)]
      ..features = [];
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c);
    await expand(tester, 'Resources');
    await tester.scrollUntilVisible(field('arcanum-6'), 180,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.enterText(field('arcanum-6'), '2');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('game-state-save')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    final f = c.features.single;
    expect(f.id, 'mystic-arcanum-6th-level');
    expect(f.resourcePool!.currentUses, 2);
    expect(f.resourcePool!.maxUses, 1);
    expect(f.resourcePool!.recoveryType, RecoveryType.longRest);
    expect(
        StorageService.getCharacter(c.id)!
            .features
            .single
            .resourcePool!
            .currentUses,
        2);
    expect(FeatureService.getFeatureById(f.id)!.resourcePool?.currentUses,
        isNot(2));
  });
  testWidgets(
      'RU editor keeps all tabs and Save usable with large text and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final c = hero();
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showGameplayStateEditor(context, c),
                  child: const Text('Open')))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    for (final tab in ['resources', 'conditions', 'core', 'magic']) {
      await tester.tap(find.byKey(ValueKey('editor-tab-$tab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(field('slot-9'), 220,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.enterText(field('slot-9'), '6');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('game-state-save'));
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(544));
    await tester.runAsync(() async {
      await tester.tap(save);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    expect(c.spellSlots[8], 6);
    expect(c.maxSpellSlots[8], 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'other usage marks remain editable without moving during a manual correction',
      (tester) async {
    final c = hero()
      ..characterClass = 'wizard'
      ..classes = [CharacterClass(id: 'wizard', name: 'Wizard', level: 3)]
      ..features = [];
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c);
    await expand(tester, 'Resources');
    final other =
        find.byKey(const PageStorageKey('editor-other-resource-marks'));
    await tester.scrollUntilVisible(other, 160,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(
        find.descendant(of: other, matching: find.text('Other usage marks')));
    await tester.pumpAndSettle();
    final natural = find.byKey(const ValueKey('game-state-natural-used'));
    await tester.scrollUntilVisible(natural, 160,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(natural);
    await tester.pumpAndSettle();
    expect(find.descendant(of: other, matching: natural), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('game-state-save')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    expect(c.naturalRecoveryUsed, isTrue);
    expect(c.arcaneRecoveryUsed, isFalse);
    expect(StorageService.getCharacter(c.id)!.naturalRecoveryUsed, isTrue);
  });

  // Keep this last: it deliberately closes the backing box to exercise failure.
  testWidgets(
    'failed persistence restores original in-memory state and keeps the editor open',
    (tester) async {
      final c = hero()..armorClass = 19;
      await tester.runAsync(() => StorageService.saveCharacter(c));
      await open(tester, c);
      await tester.enterText(field('hp'), '31');
      await tester.runAsync(() => Hive.box<Character>('characters').close());
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('game-state-save'))),
      );
      await tester.pumpAndSettle();
      expect(c.currentHp, 17);
      expect(c.armorClass, 19);
      expect(c.features.single.descriptionEn, 'Installed library text');
      expect(find.byType(GameplayStateEditor), findsOneWidget);
      expect(
          find.textContaining(
              'Could not save. Your previous values were kept.'),
          findsWidgets);
    },
  );
}
