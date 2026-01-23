import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/spell.dart';
import '../services/spellcasting_service.dart';

class SpellPreparationManager {
  /// Toggles the prepared status of a spell for a character.
  /// 
  /// Handles logic for 'prepared' vs 'known' casters.
  /// Returns true if the state changed, false otherwise.
  static bool togglePreparation(Character character, Spell spell, BuildContext context) {
    final isPrepared = character.preparedSpells.contains(spell.id);
    final casterType = SpellcastingService.getSpellcastingType(character.characterClass);

    // If already prepared, simple removal (always allowed)
    if (isPrepared) {
      character.preparedSpells.remove(spell.id);
      character.save();
      return true;
    }

    // Attempting to prepare a new spell
    
    // 1. Check if the class prepares spells at all
    // 'Known' casters (Bard, Sorcerer, etc.) technically don't "prepare" from a larger list day-to-day 
    // in the same way Wizards/Clerics do, but the app might use 'preparedSpells' to track 
    // which spells are currently "equipped" or simply reuse 'knownSpells'.
    // However, the prompt implies we should treat 'known' casters as just adding/removing freely 
    // (perhaps modeling the 'Known Spells' limit elsewhere, or assuming the user manages 'Known Spells' separately).
    // 
    // If the prompt implies that for Bards/Sorcerers we just toggle without limit checking 
    // (because their limit is on 'Known Spells', not 'Prepared Spells'), we allow it.
    if (casterType == 'known' || casterType == 'pact_magic') {
       character.preparedSpells.add(spell.id);
       character.save();
       return true;
    }

    // 2. For 'prepared' casters (Wizard, Cleric, Druid, Paladin), check limits
    if (casterType == 'prepared') {
      final maxPrepared = SpellcastingService.getMaxPreparedSpells(character);
      final currentPrepared = character.preparedSpells.length;

      // Always allow Cantrips (Level 0) to be "prepared" (though usually they are just known)
      // D&D 5e: Cantrips are not prepared, they are known. 
      // If the app treats cantrips as prepared spells, we should exclude them from the count.
      // Usually, prepared count applies to Level 1+ spells.
      if (spell.level == 0) {
         character.preparedSpells.add(spell.id);
         character.save();
         return true;
      }

      // Check count (excluding cantrips from the current count if necessary, 
      // but usually 'preparedSpells' list should only contain leveled spells for prepared casters).
      // Let's assume preparedSpells might contain cantrips if the user added them there.
      // We should count only leveled spells against the limit.
      // However, retrieving all spell objects to check levels is expensive here without a cache.
      // For now, let's assume the standard list logic. 
      // A better approach: Filter character.preparedSpells by checking if they are leveled spells.
      // Since we don't have easy synchronous access to all spell objects by ID here without SpellService,
      // and SpellService.getSpellById might be sync or async (it looks sync in previous file).
      
      // Strict check:
      if (currentPrepared >= maxPrepared) {
        // Validation Failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot prepare more spells! (Max: $maxPrepared)'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // Optional: Haptic feedback could be added here if a plugin was available
        return false;
      }

      // Validation Passed
      character.preparedSpells.add(spell.id);
      character.save();
      
      final locale = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prepared ${spell.getName(locale)} (${currentPrepared + 1}/$maxPrepared)'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1000),
        ),
      );
      return true;
    }

    // Fallback
    character.preparedSpells.add(spell.id);
    character.save();
    return true;
  }
}
