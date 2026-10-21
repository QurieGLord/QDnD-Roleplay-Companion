import '../magic/spellbook_state.dart';
import '../models/character.dart';
import '../services/spell_eligibility_service.dart';
import '../services/spell_service.dart';
import 'class_spellcasting_profile.dart';

/// Preserve the existing single-caster interpretation in a detached draft.
/// Unknown, off-list and already mixed legacy records require a player choice.
class LegacySpellAllocation {
  static Map<String, String> unambiguous(Character before) {
    if (before.classes.length != 1) return {};
    final entry = before.classes.single;
    try {
      final profile = ClassSpellcastingProfile.resolve(before, entry.id);
      if (profile == null || profile.preparation == null) return {};
      final book = SpellbookState.read(before.spellbookData);
      return {
        for (final id in {
          ...book.unassignedKnown(before),
          ...book.unassignedPrepared(before)
        })
          if (SpellService.getSpellById(id) != null &&
              SpellEligibilityService.classAccess(
                      before, SpellService.getSpellById(id)!)
                  .any((a) =>
                      a.classId == entry.id &&
                      a.state == SpellAccessState.available))
            id: 'class:${entry.id}'
      };
    } catch (_) {
      return {};
    }
  }
}
