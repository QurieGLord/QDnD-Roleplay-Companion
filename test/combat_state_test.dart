import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/combat_state.dart';

void main() {
  group('CombatState death save tracking', () {
    test('death save roll is limited to once per combat round', () {
      final combatState = CombatState();

      combatState.startCombat(14);
      expect(combatState.canRollDeathSaveThisRound, isTrue);

      combatState.markDeathSaveRolledThisRound();
      expect(combatState.canRollDeathSaveThisRound, isFalse);

      combatState.currentRound++;
      expect(combatState.canRollDeathSaveThisRound, isTrue);
    });

    test('start and end combat reset death save round tracking', () {
      final combatState = CombatState(
        isInCombat: true,
        currentRound: 3,
        lastDeathSaveRound: 3,
      );

      combatState.endCombat();
      expect(combatState.lastDeathSaveRound, isNull);

      combatState.startCombat(12);
      expect(combatState.lastDeathSaveRound, isNull);
      expect(combatState.currentRound, 1);
    });
  });
}
