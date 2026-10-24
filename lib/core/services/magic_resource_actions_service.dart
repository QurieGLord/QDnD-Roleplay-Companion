import 'dart:convert';
import '../magic/magic_slots.dart';
import '../magic/spell_session_effects.dart';
import '../models/character.dart';
import '../models/combat_state.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';

class MagicResourceActionsService {
  static Future<T> change<T>(Character hero, T Function() action,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        final current = List<int>.of(hero.spellSlots),
            maximum = List<int>.of(hero.maxSpellSlots);
        final magic = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(hero.magicData)) as Map);
        final arcane = hero.arcaneRecoveryUsed,
            natural = hero.naturalRecoveryUsed;
        final combat = CombatState.fromJson(hero.combatState.toJson()),
            timestamp = hero.updatedAt;
        try {
          final result = action();
          await (write ?? StorageService.saveCharacter)(hero);
          return result;
        } catch (_) {
          hero.spellSlots = current;
          hero.maxSpellSlots = maximum;
          hero.magicData = magic;
          hero.arcaneRecoveryUsed = arcane;
          hero.naturalRecoveryUsed = natural;
          hero.combatState = combat;
          hero.updatedAt = timestamp;
          rethrow;
        }
      });
  /// Ends concentration and anything it held (Hunter's Mark) as one save.
  static Future<void> endConcentration(Character hero,
      {Future<void> Function(Character)? write}) async {
    final before =
        (hero.concentratingOn, hero.isHuntersMarkActive, hero.huntersMarkTarget);
    try {
      await change(hero, () => SpellSessionEffects.endConcentration(hero),
          write: write);
    } catch (_) {
      hero.concentratingOn = before.$1;
      hero.isHuntersMarkActive = before.$2;
      hero.huntersMarkTarget = before.$3;
      rethrow;
    }
  }

  static Future<void> spendSlot(Character hero, MagicPool pool, int circle,
          {Future<void> Function(Character)? write}) =>
      change(hero, () {
        MagicSlots.spendOn(hero, pool, circle);
      }, write: write);
  static Future<void> recover(Character hero, Map<int, int> amounts,
          {required String classId, Future<void> Function(Character)? write}) =>
      change(hero, () {
        if (!{'wizard', 'druid'}.contains(classId) ||
            hero.classLevel(classId) < (classId == 'wizard' ? 1 : 2)) {
          throw StateError('Unavailable recovery feature.');
        }
        if (classId == 'wizard'
            ? hero.arcaneRecoveryUsed
            : hero.naturalRecoveryUsed) {
          throw StateError('Recovery already used.');
        }
        if (classId == 'druid' && !hero.hasFeatureId('natural-recovery')) {
          throw StateError('Natural Recovery not acquired.');
        }
        if (amounts.isEmpty ||
            amounts.entries.any((e) => e.key < 1 || e.key > 5 || e.value < 0) ||
            amounts.entries
                    .fold<int>(0, (total, e) => total + e.key * e.value) >
                (hero.classLevel(classId) + 1) ~/ 2) {
          throw StateError('Invalid recovery budget.');
        }
        final state = MagicSlots.read(hero),
            next = List<int>.of(MagicSlots.read(hero).current);
        for (final entry in amounts.entries) {
          if (entry.key > state.maximum.length ||
              entry.key > next.length ||
              next[entry.key - 1] + entry.value > state.maximum[entry.key - 1]) {
            throw StateError('No missing shared slots.');
          }
          next[entry.key - 1] += entry.value;
        }
        MagicSlots.allocation(
                current: next, maximum: state.maximum, pact: state.pact)
            .applyTo(hero);
        if (classId == 'wizard') {
          hero.arcaneRecoveryUsed = true;
        } else {
          hero.naturalRecoveryUsed = true;
        }
      }, write: write);
}
