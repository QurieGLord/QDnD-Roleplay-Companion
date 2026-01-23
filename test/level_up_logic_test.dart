import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/models/spell_slots_table.dart';

void main() {
  group('SpellSlotsTable Tests', () {
    test('Paladin (Half-Caster) Progression', () {
      // Paladin Level 1: No slots
      expect(SpellSlotsTable.getSlots(1, 'half'), isEmpty);

      // Paladin Level 2: 2 slots (1st level)
      // Equivalent to Full Caster Level 1
      expect(SpellSlotsTable.getSlots(2, 'half'), [2]);

      // Paladin Level 3: 3 slots
      // Equivalent to Full Caster Level 2 ([3])
      expect(SpellSlotsTable.getSlots(3, 'half'), [3]);

      // Paladin Level 5: 4 slots (1st), 2 slots (2nd)
      // Equivalent to Full Caster Level 3 ([4, 2])
      expect(SpellSlotsTable.getSlots(5, 'half'), [4, 2]);
    });

    test('Wizard (Full-Caster) Progression', () {
      // Wizard Level 1: 2 slots
      expect(SpellSlotsTable.getSlots(1, 'full'), [2]);

      // Wizard Level 3: 4 slots (1st), 2 slots (2nd)
      expect(SpellSlotsTable.getSlots(3, 'full'), [4, 2]);
    });
  });
}
