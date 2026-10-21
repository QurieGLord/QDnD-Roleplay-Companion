import '../models/character.dart';
import '../models/spell.dart';
import 'class_spell_grants.dart';

/// Only explicit supported spell identities gain automatic session tracking.
/// A matching title in a homebrew book is not a mechanical declaration.
class SpellSessionEffects {
  static bool huntersMark(Spell spell) =>
      spell.sourceId == null &&
      spell.id == ClassSpellGrants.spell('hunters-mark')?.id;
  static bool concentratingOnMark(Character c) =>
      c.concentratingOn != null &&
      c.concentratingOn == ClassSpellGrants.spell('hunters-mark')?.id;
  static void applyConcentration(Character c, Spell spell) {
    if (!spell.concentration) return;
    c.concentratingOn = spell.id;
    c.isHuntersMarkActive = huntersMark(spell);
    c.huntersMarkTarget = null;
  }

  static void endConcentration(Character c) {
    c.concentratingOn = null;
    c.isHuntersMarkActive = false;
    c.huntersMarkTarget = null;
  }
}
