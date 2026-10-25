import '../../core/models/ability_scores.dart';
import '../../core/models/character.dart';
import '../../core/services/storage_service.dart';
import 'journal_campaign.dart';

/// Explicit opt-in for the separate Cycle package only; never replaces a hero.
Future<void> seedJournalCycle() async {
  const id = 'cycle-journal-working-20261008';
  if (StorageService.getCharacter(id) != null) return;
  final c = Character(
      id: id,
      name: 'Cycle · Журнал',
      race: 'human',
      characterClass: 'fighter',
      level: 3,
      maxHp: 24,
      currentHp: 24,
      spellSlots: [],
      maxSpellSlots: [],
      abilityScores: AbilityScores(
          strength: 14,
          dexterity: 14,
          constitution: 14,
          intelligence: 12,
          wisdom: 12,
          charisma: 12));
  writeJournalCampaign(c, prefix: 'cycle-', story: 'paladin');
  await StorageService.saveCharacter(c);
  if (StorageService.getSetting('locale_code') == null) {
    await StorageService.saveSetting('locale_code', 'ru');
  }
}
