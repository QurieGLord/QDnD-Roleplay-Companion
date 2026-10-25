import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/combat_state.dart';
import 'package:qd_and_d/core/models/combat_turn.dart';
import 'package:qd_and_d/core/services/combat_actions_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/combat/combat_tracker_screen.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'gameplay_state_editor_test.dart' as fixtures;

/// Wave 3 combat (G01): the turn, the round tape's effects, damage by the
/// table's rules and undo — each one write through the shared action path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_combat_actions_');
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

  Future<Character> fighting() async {
    final c = fixtures.hero()
      ..maxHp = 40
      ..currentHp = 30;
    c.combatState.startCombat(14);
    await StorageService.saveCharacter(c);
    return c;
  }

  test('a new round refreshes the turn and runs effects down', () {
    final state = CombatState()..startCombat(12);
    final turn = CombatTurn(state)
      ..setUsed(TurnCost.action, true)
      ..moved = 20
      ..dash = true
      ..attacks = 2
      ..addEffect(const CombatEffect(
          key: 'rage', name: 'Rage', icon: 'axe', accent: 0, left: 1, max: 10))
      ..addEffect(const CombatEffect(
          key: 'bless',
          name: 'Bless',
          icon: 'timer',
          accent: 5,
          left: 5,
          max: 10,
          concentration: true));
    final ended = turn.advance();
    expect(ended.map((e) => e.key), ['rage']);
    expect(turn.used(TurnCost.action), isFalse);
    expect(turn.moved, 0);
    expect(turn.dash, isFalse);
    expect(turn.attacks, 0);
    expect(turn.effects.single.left, 4);
    // A new concentration replaces the old one.
    turn.addEffect(const CombatEffect(
        key: 'haste',
        name: 'Haste',
        icon: 'timer',
        accent: 5,
        left: 10,
        max: 10,
        concentration: true));
    expect(turn.effects.map((e) => e.key), ['haste']);
  });

  test('an ending rage effect ends the rage, in one write', () async {
    final c = await fighting();
    c.isRaging = true;
    CombatTurn(c.combatState).addEffect(const CombatEffect(
        key: 'rage', name: 'Rage', icon: 'axe', accent: 0, left: 1, max: 10));
    await StorageService.saveCharacter(c);
    final events = <BoxEvent>[];
    final sub =
        Hive.box<Character>('characters').watch(key: c.id).listen(events.add);
    final ended = await CombatActionsService.nextRound(c,
        roundText: 'Round 2', endedText: (e) => '${e.name}: over');
    await Hive.box<Character>('characters').flush();
    await Future<void>.delayed(Duration.zero);
    expect(ended.single.key, 'rage');
    expect(c.isRaging, isFalse);
    expect(c.combatState.currentRound, 2);
    expect(CombatTurn(c.combatState).effects, isEmpty);
    expect(c.combatState.combatLog.map((e) => e.description),
        containsAll(['Rage: over', 'Round 2']));
    expect(events, hasLength(1));
    await sub.cancel();
  });

  test(
      'damage: Uncanny Dodge halves once, the check is asked, 0 HP ends concentration',
      () async {
    final c = await fighting();
    c.concentratingOn = 'bless';
    CombatTurn(c.combatState).halveNext = true;
    expect(await GameplayActionsService.takeHit(c, 10), 5);
    expect(c.currentHp, 25);
    expect(CombatTurn(c.combatState).halveNext, isFalse);
    expect(CombatTurn(c.combatState).check, 10);
    expect(await GameplayActionsService.takeHit(c, 30), 30);
    expect(c.currentHp, 0);
    expect(c.concentratingOn, isNull);
    // Damage at 0 HP is a failed death save.
    await GameplayActionsService.takeHit(c, 3);
    expect(c.deathSaves.failures, 1);
  });

  test('the concentration save keeps or drops the spell and its ribbon',
      () async {
    final c = await fighting();
    c.concentratingOn = 'bless';
    final turn = CombatTurn(c.combatState)
      ..check = 15
      ..addEffect(const CombatEffect(
          key: 'conc:bless',
          name: 'Bless',
          icon: 'timer',
          accent: 5,
          left: 10,
          max: 10,
          concentration: true));
    expect(turn.check, 15);
    final kept = await CombatActionsService.concentrationSave(c, 2,
        text: (total, dc, kept) => '$total vs $dc');
    expect(kept, isFalse);
    expect(c.concentratingOn, isNull);
    expect(CombatTurn(c.combatState).effects, isEmpty);
    expect(CombatTurn(c.combatState).check, isNull);
  });

  test('a Dash spends the action with the movement, and undo puts it all back',
      () async {
    final c = await fighting();
    final before = CombatSnapshot(c);
    await CombatActionsService.move(c, moved: 45, dash: true, dashText: 'Dash');
    final turn = CombatTurn(c.combatState);
    expect(turn.moved, 45);
    expect(turn.dash, isTrue);
    expect(turn.used(TurnCost.action), isTrue);
    await GameplayActionsService.takeHit(c, 8);
    await GameplayActionsService.restoreCombat(c, before);
    expect(c.currentHp, 30);
    expect(CombatTurn(c.combatState).moved, 0);
    expect(CombatTurn(c.combatState).used(TurnCost.action), isFalse);
    expect(StorageService.getCharacter(c.id)!.currentHp, 30);
  });

  test('the round tape mirrors rage, Sacred Weapon and concentration',
      () async {
    final c = await fighting();
    c
      ..isRaging = true
      ..isSacredWeaponActive = true
      ..concentratingOn = 'bless';
    void sync() => syncCombatEffects(c,
        rage: 'Rage',
        sacred: 'Sacred',
        concentration: (id) => id,
        concentrationRounds: (_) => 10);
    sync();
    expect(CombatTurn(c.combatState).effects.map((e) => e.key).toSet(),
        {'rage', 'sacred', 'conc:bless'});
    c
      ..isRaging = false
      ..concentratingOn = null;
    sync();
    expect(CombatTurn(c.combatState).effects.map((e) => e.key), ['sacred']);
  });

  test('a failed combat write rolls everything back', () async {
    final c = await fighting();
    CombatTurn(c.combatState).moved = 10;
    await StorageService.saveCharacter(c);
    await expectLater(
        GameplayActionsService.combat(c, () {
          c.currentHp = 1;
          CombatTurn(c.combatState).moved = 30;
          throw StateError('boom');
        }),
        throwsStateError);
    expect(c.currentHp, 30);
    expect(CombatTurn(c.combatState).moved, 10);
  });

  testWidgets('the combat page turns the round and undoes it', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = fixtures.hero()
      ..maxHp = 40
      ..currentHp = 30;
    c.combatState.startCombat(14);
    await tester.runAsync(() => StorageService.saveCharacter(c));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CombatTrackerScreen(character: c),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Бой · раунд 1'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('tape-next')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    expect(c.combatState.currentRound, 2);
    expect(find.text('Бой · раунд 2'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('combat-undo')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await Hive.box<Character>('characters').flush();
    });
    await tester.pumpAndSettle();
    expect(c.combatState.currentRound, 1);
    expect(tester.takeException(), isNull);
  });
}
