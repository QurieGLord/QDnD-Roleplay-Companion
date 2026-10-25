import 'dart:math' as math;

import '../magic/magic_slots.dart';
import '../models/character.dart';
import '../models/combat_state.dart';
import '../models/combat_turn.dart';
import 'gameplay_actions_service.dart';

/// The combat screen's own actions (G01): each is one write through the
/// shared action path, with rollback on failure.
abstract final class CombatActionsService {
  static CombatLogEntry _entry(Character c, String text,
          {CombatLogType type = CombatLogType.other, int? amount}) =>
      CombatLogEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 20)}',
          timestamp: DateTime.now(),
          type: type,
          amount: amount,
          description: text,
          round: c.combatState.currentRound);

  /// Adds a line to the combat journal inside an action.
  static void note(Character c, String text,
          {CombatLogType type = CombatLogType.other, int? amount}) =>
      c.combatState.addLogEntry(_entry(c, text, type: type, amount: amount));

  /// The fight begins at the rolled initiative; effects the hero already
  /// carries (rage, Sacred Weapon, concentration) join the round tape.
  static Future<void> start(Character c, int initiative,
          {required String text, List<CombatEffect> effects = const []}) =>
      GameplayActionsService.combat(c, () {
        c.combatState.startCombat(initiative);
        final turn = CombatTurn(c.combatState);
        for (final e in effects) {
          turn.addEffect(e);
        }
        note(c, text, type: CombatLogType.roundStart, amount: initiative);
      });

  static Future<void> end(Character c) =>
      GameplayActionsService.combat(c, () => c.combatState.endCombat());

  /// A new round: a fresh turn, one round off every effect; an effect whose
  /// time ran out ends the flag it mirrors. Returns the ended effects.
  static Future<List<CombatEffect>> nextRound(Character c,
          {required String roundText,
          required String Function(CombatEffect) endedText}) =>
      GameplayActionsService.combat(c, () {
        final state = c.combatState;
        state.currentRound++;
        final ended = CombatTurn(state).advance();
        for (final e in ended) {
          _endFlag(c, e);
          note(c, endedText(e));
        }
        note(c, roundText,
            type: CombatLogType.roundStart, amount: state.currentRound);
        return ended;
      });

  static void _endFlag(Character c, CombatEffect e) {
    if (e.key == 'rage') c.endRage();
    if (e.key == 'sacred') c.isSacredWeaponActive = false;
    if (e.concentration) {
      c.concentratingOn = null;
      CombatTurn(c.combatState).check = null;
    }
  }

  /// Ends an effect before its time.
  static Future<void> endEffect(Character c, String key, String text) =>
      GameplayActionsService.combat(c, () {
        final turn = CombatTurn(c.combatState);
        final e = turn.effect(key);
        if (e == null) return;
        turn.removeEffect(key);
        _endFlag(c, e);
        note(c, text);
      });

  static Future<void> toggleToken(Character c, TurnCost cost) =>
      GameplayActionsService.combat(c, () {
        final turn = CombatTurn(c.combatState);
        turn.setUsed(cost, !turn.used(cost));
      });

  /// Movement in one write: feet moved, and the Dash that spent the action.
  static Future<void> move(Character c,
          {required int moved, required bool dash, String? dashText}) =>
      GameplayActionsService.combat(c, () {
        final turn = CombatTurn(c.combatState);
        if (dash && !turn.dash) {
          turn.setUsed(TurnCost.action, true);
          if (dashText != null) note(c, dashText);
        }
        turn.dash = dash;
        turn.moved = moved;
      });

  /// The concentration save: d20 + the Constitution save against the DC.
  /// A failure ends the concentration and its effect.
  static Future<bool> concentrationSave(Character c, int roll,
          {required String Function(int total, int dc, bool kept) text}) =>
      GameplayActionsService.combat(c, () {
        final turn = CombatTurn(c.combatState);
        final dc = turn.check ?? 10;
        final total = roll + c.constitutionSavingThrowBonus;
        final kept = roll == 20 || (roll != 1 && total >= dc);
        turn.check = null;
        if (!kept) {
          c.concentratingOn = null;
          turn.removeConcentration();
        }
        note(c, text(total, dc, kept),
            type: CombatLogType.concentrationCheck, amount: total);
        return kept;
      });

  static Future<void> endConcentration(Character c, String text) =>
      GameplayActionsService.combat(c, () {
        c.concentratingOn = null;
        final turn = CombatTurn(c.combatState);
        turn.removeConcentration();
        turn.check = null;
        note(c, text);
      });
}

/// Inside a combat write: one shared slot of [circle] is spent.
void spendSharedSlotInWrite(Character c, int circle) {
  final state = MagicSlots.read(c);
  final slots = List<int>.of(state.current);
  if (circle < 1 || circle > slots.length || slots[circle - 1] < 1) {
    throw StateError('No slot of circle $circle remains.');
  }
  slots[circle - 1]--;
  MagicSlots.allocation(
          current: slots, maximum: state.maximum, pact: state.pact)
      .applyTo(c);
}

/// Mirrors the hero's own flags on the round tape: rage, Sacred Weapon and
/// concentration appear while they last and leave when they end.
void syncCombatEffects(Character c,
    {required String rage,
    required String sacred,
    required String Function(String spellId) concentration,
    required int Function(String spellId) concentrationRounds}) {
  final turn = CombatTurn(c.combatState);
  if (c.isRaging && turn.effect('rage') == null) {
    turn.addEffect(CombatEffect(
        key: 'rage', name: rage, icon: 'axe', accent: 0, left: 10, max: 10));
  } else if (!c.isRaging && turn.effect('rage') != null) {
    turn.removeEffect('rage');
  }
  if (c.isSacredWeaponActive && turn.effect('sacred') == null) {
    turn.addEffect(CombatEffect(
        key: 'sacred',
        name: sacred,
        icon: 'sword',
        accent: 2,
        left: 10,
        max: 10));
  } else if (!c.isSacredWeaponActive && turn.effect('sacred') != null) {
    turn.removeEffect('sacred');
  }
  final spell = c.concentratingOn;
  final current = turn.effects.where((e) => e.concentration).firstOrNull;
  if (spell == null) {
    if (current != null) turn.removeConcentration();
  } else if (current?.key != 'conc:$spell') {
    final rounds = concentrationRounds(spell);
    turn.addEffect(CombatEffect(
        key: 'conc:$spell',
        name: concentration(spell),
        icon: 'timer',
        accent: 5,
        left: rounds,
        max: rounds,
        concentration: true));
  }
}
