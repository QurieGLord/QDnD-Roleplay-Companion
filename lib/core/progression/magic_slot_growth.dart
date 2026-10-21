import 'character_class_rules.dart';
import 'class_spellcasting_profile.dart';
import 'dart:math' as math;
import '../magic/magic_slots.dart';
import '../models/character.dart';
import 'multiclass_rules.dart';
import 'resource_growth.dart';

class MagicSlotGrowth {
  static void advance(Character before, Character after) {
    final state = MagicSlots.read(before),
        previous = MulticlassRules.spellCapacity(before, definitions: {
          for (final entry in after.classes)
            entry.id: CharacterClassRules.resolve(entry).data
        }),
        next = MulticlassRules.spellCapacity(after);
    int at(List<int> v, int i) => i < v.length ? v[i] : 0;
    var gainedLength = 0;
    for (var i = 0; i < next.sharedSlots.length; i++) {
      if (at(next.sharedSlots, i) > at(previous.sharedSlots, i)) {
        gainedLength = i + 1;
      }
    }
    final length = [state.current.length, state.maximum.length, gainedLength]
        .reduce((a, b) => a > b ? a : b);
    final maxima = <int>[
      for (var i = 0; i < length; i++)
        at(state.maximum, i) +
            math
                .max(0, at(next.sharedSlots, i) - at(previous.sharedSlots, i))
                .toInt()
    ];
    final remaining = [
      for (var i = 0; i < length; i++)
        ResourceGrowth.remaining(
            current: at(state.current, i),
            oldMaximum: at(state.maximum, i),
            newMaximum: maxima[i])
    ];
    PactSlots? pact = state.pact;
    if (next.pact != null) {
      final owner = after.classes.firstWhere(
          (c) => ClassSpellcastingProfile.resolve(after, c.id)?.isPact == true);
      final increment =
          math.max(0, next.pact!.count - (previous.pact?.count ?? 0));
      pact = PactSlots(
          owner: owner.id,
          circle: next.pact!.circle,
          current: (state.pact?.current ?? 0) + increment,
          maximum: (state.pact?.maximum ?? 0) + increment);
    }
    MagicSlots.allocation(current: remaining, maximum: maxima, pact: pact)
        .applyTo(after);
  }
}
