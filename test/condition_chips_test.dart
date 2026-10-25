import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/models/combat_state.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_sheet/widgets/overview_tab.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'gameplay_state_editor_test.dart' as fixtures;

Widget app(Character c,
        {Locale locale = const Locale('en'), double scale = 1}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: OverviewTab(character: c)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_condition_chips_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  setUp(() async => Hive.box<Character>('characters').clear());
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets(
      'combat condition is visible in overview and clears with one saved event',
      (tester) async {
    final c = fixtures.hero()..currentHp = 0;
    c.combatState.startCombat(10);
    c.addCondition(ConditionType.unconscious, persist: false);
    c.addCondition(ConditionType.poisoned, persist: false);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    final events = <BoxEvent>[];
    final sub =
        Hive.box<Character>('characters').watch(key: c.id).listen(events.add);
    // A seal opens the conditions sheet; its cell clears the mark.
    await tester.tap(find.byKey(const ValueKey('sheet-condition-unconscious')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('condition-pick-unconscious')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(const ValueKey('condition-pick-unconscious')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('condition-pick-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('condition-pick-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-condition-unconscious')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('sheet-condition-poisoned')), findsOneWidget);
    expect(c.currentHp, 0);
    expect(c.activeConditions, [ConditionType.poisoned]);
    expect(StorageService.getCharacter(c.id)!.activeConditions,
        [ConditionType.poisoned]);
    expect(c.combatState.combatLog.last.type, CombatLogType.conditionRemoved);
    expect(events, hasLength(1));
    await tester.runAsync(() => sub.cancel());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all RU conditions and exhaustion wrap at large text without losing labels',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = fixtures.hero()
      ..activeConditions = List.from(ConditionType.values)
      ..exhaustionLevel = 2;
    await tester.pumpWidget(app(c, locale: const Locale('ru'), scale: 2));
    await tester.pumpAndSettle();
    // Conditions sit below health and the quick numbers.
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sheet-condition-blinded')), 200,
        scrollable: find.byType(Scrollable).first);
    for (final condition in ConditionType.values) {
      expect(find.byKey(ValueKey('sheet-condition-${condition.name}')),
          findsOneWidget);
    }
    expect(find.byKey(const ValueKey('sheet-condition-exhaustion')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Last: failed clearing must restore both the mark and its combat log.
  testWidgets('failed chip removal retains condition and rolls back combat log',
      (tester) async {
    final c = fixtures.hero();
    c.combatState.startCombat(10);
    c.addCondition(ConditionType.poisoned, persist: false);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    final log = List.from(c.combatState.combatLog);
    await tester.tap(find.byKey(const ValueKey('sheet-condition-poisoned')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('condition-pick-poisoned')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Hive.box<Character>('characters').close());
    await tester.runAsync(() =>
        tester.tap(find.byKey(const ValueKey('condition-pick-poisoned'))));
    await tester.pumpAndSettle();
    expect(c.activeConditions, [ConditionType.poisoned]);
    expect(c.combatState.combatLog, log);
    expect(
        find.byKey(const ValueKey('sheet-condition-poisoned')), findsOneWidget);
    expect(find.textContaining('Could not save'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
