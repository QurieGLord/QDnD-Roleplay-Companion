import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_sheet/widgets/overview_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/rest_sheet.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'gameplay_state_editor_test.dart' as fixtures;

Widget app(Character c, bool short,
        {Locale locale = const Locale('en'), double scale = 1}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showRestSheet(context, c, short: short),
                  child: const Text('Open')))),
    );

Future<void> open(WidgetTester tester, Character c, bool short,
    {Locale locale = const Locale('en'), double scale = 1}) async {
  await tester.pumpWidget(app(c, short, locale: locale, scale: scale));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Finishes the rest the way the sheet asks: a tap on the short rest's
/// button, or holding the long rest's until dawn.
Future<void> confirm(WidgetTester tester) async {
  final short = find.byKey(const ValueKey('rest-short-go'));
  if (short.evaluate().isNotEmpty) {
    await tester.ensureVisible(short);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(short);
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    return;
  }
  final hold = find.byKey(const ValueKey('rest-long-hold'));
  await tester.ensureVisible(hold);
  await tester.pumpAndSettle();
  // The screen reader's tap: the write runs on the real clock.
  await tester.runAsync(() async {
    tester.widget<Semantics>(hold).properties.onTap!();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await Hive.box<Character>('characters').flush();
  });
  await tester.pumpAndSettle();
}

/// Closes the sheet without resting, by tapping the dimmed page above it.
Future<void> dismiss(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_rest_sheet_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
  });
  setUp(() async => Hive.box<Character>('characters').clear());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('preview and cancel do not restore or persist a depleted pool',
      (tester) async {
    final c = fixtures.hero();
    c.features.single.resourcePool!.currentUses = 0;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    final before = c.toJson(), timestamp = c.updatedAt;
    await open(tester, c, true);
    expect(find.text('0 / 4 → 4 / 4', findRichText: true), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(c.toJson(), before);
    expect(c.updatedAt, timestamp);
    await dismiss(tester);
    expect(c.features.single.resourcePool!.currentUses, 0);
    expect(
        StorageService.getCharacter(c.id)!
            .features
            .single
            .resourcePool!
            .currentUses,
        0);
  });

  testWidgets('preview with depleted hit dice never writes the cloned hero',
      (tester) async {
    final c = fixtures.hero()..hitDice = [0];
    c.features.single.resourcePool!.currentUses = 0;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    final before = c.toJson();
    await open(tester, c, false);
    await tester.runAsync(() => Hive.box<Character>('characters').flush());
    expect(c.hitDice, [0]);
    expect(StorageService.getCharacter(c.id)!.toJson(), before);
    await dismiss(tester);
    expect(StorageService.getCharacter(c.id)!.toJson(), before);
  });

  testWidgets('short rest restores eligible pools and Pact slots, preserves HP',
      (tester) async {
    final c = fixtures.hero()
      ..characterClass = 'warlock'
      ..level = 20
      ..classes = [CharacterClass(id: 'warlock', name: 'Warlock', level: 20)]
      ..spellSlots = [0, 0, 0, 0, 1]
      ..maxSpellSlots = [0, 0, 0, 0, 4];
    c.features.single.resourcePool!.currentUses = 0;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c, true);
    expect(
        find.byKey(const ValueKey('sheet-rest-change-slot-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-rest-change-hp')), findsNothing);
    await confirm(tester);
    expect(c.spellSlots[4], 4);
    expect(c.features.single.resourcePool!.currentUses, 4);
    expect(c.currentHp, 17);
    expect(StorageService.getCharacter(c.id)!.spellSlots[4], 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long rest preview and commit retain excess and active marks',
      (tester) async {
    final c = fixtures.hero()
      ..currentHp = 31
      ..spellSlots = [6, 1]
      ..maxSpellSlots = [4, 3]
      ..temporaryHp = 7
      ..activeConditions = [ConditionType.poisoned]
      ..exhaustionLevel = 2
      ..concentratingOn = 'focus'
      ..isWildShaped = true
      ..beastCurrentHp = 4
      ..beastMaxHp = 8;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c, false);
    expect(find.byKey(const ValueKey('sheet-rest-change-hp')), findsNothing);
    expect(
        find.byKey(const ValueKey('sheet-rest-change-slot-1')), findsNothing);
    expect(find.text('1 / 3 → 3 / 3', findRichText: true), findsOneWidget);
    await confirm(tester);
    expect(c.currentHp, 31);
    expect(c.spellSlots, [6, 3]);
    expect(c.features.single.resourcePool!.currentUses, 6);
    expect(c.temporaryHp, 7);
    expect(c.activeConditions, [ConditionType.poisoned]);
    expect(c.exhaustionLevel, 2);
    expect(c.concentratingOn, 'focus');
    expect(c.isWildShaped, isTrue);
    expect(c.beastCurrentHp, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'RU large text scrolls a dense preview and keeps actions reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = fixtures.hero()
      ..spellSlots = List.filled(9, 0)
      ..maxSpellSlots = List.filled(9, 4);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c, false, locale: const Locale('ru'), scale: 2);
    await confirm(tester);
    expect(c.spellSlots, List.filled(9, 4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(body: OverviewTab(character: c))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sheet-rest-short')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-rest-short')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rest-short-go')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest with depleted hit dice persists the complete event once',
      (tester) async {
    final c = fixtures.hero()
      ..hitDice = [0]
      ..spellSlots = [1];
    c.features.single.resourcePool!.currentUses = 0;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c, false);
    final events = <BoxEvent>[];
    final sub =
        Hive.box<Character>('characters').watch(key: c.id).listen(events.add);
    await confirm(tester);
    expect(c.currentHp, 20);
    expect(c.spellSlots, [4]);
    expect(c.hitDice, [1]);
    expect(c.features.single.resourcePool!.currentUses, 4);
    expect(events, hasLength(1));
    await tester.runAsync(() => sub.cancel());
  });

  // Last: this deliberately closes the store to exercise the entire rest event.
  testWidgets('a failed rest retains the preview and rolls back all resources',
      (tester) async {
    final c = fixtures.hero()..spellSlots = [1];
    c.features.single.resourcePool!.currentUses = 0;
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await open(tester, c, false);
    await tester.runAsync(() => Hive.box<Character>('characters').close());
    final hold = find.byKey(const ValueKey('rest-long-hold'));
    await tester.ensureVisible(hold);
    await tester.runAsync(() async {
      tester.widget<Semantics>(hold).properties.onTap!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(c.currentHp, 17);
    expect(c.spellSlots, [1]);
    expect(c.features.single.resourcePool!.currentUses, 0);
    // The night stays open to try again.
    expect(hold, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
