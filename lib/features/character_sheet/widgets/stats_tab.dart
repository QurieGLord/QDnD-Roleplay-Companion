import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../shared/widgets/dice_roller_modal.dart';

class StatsTab extends StatelessWidget {
  final Character character;

  const StatsTab({super.key, required this.character});

  String _getAbilityName(AppLocalizations l10n, String key) {
    switch (key.toLowerCase()) {
      case 'strength': return l10n.abilityStr;
      case 'dexterity': return l10n.abilityDex;
      case 'constitution': return l10n.abilityCon;
      case 'intelligence': return l10n.abilityInt;
      case 'wisdom': return l10n.abilityWis;
      case 'charisma': return l10n.abilityCha;
      default: return key;
    }
  }

  String _getSkillName(AppLocalizations l10n, String key) {
    switch (key.replaceAll(' ', '').toLowerCase()) {
      case 'athletics': return l10n.skillAthletics;
      case 'acrobatics': return l10n.skillAcrobatics;
      case 'sleightofhand': return l10n.skillSleightOfHand;
      case 'stealth': return l10n.skillStealth;
      case 'arcana': return l10n.skillArcana;
      case 'history': return l10n.skillHistory;
      case 'investigation': return l10n.skillInvestigation;
      case 'nature': return l10n.skillNature;
      case 'religion': return l10n.skillReligion;
      case 'animalhandling': return l10n.skillAnimalHandling;
      case 'insight': return l10n.skillInsight;
      case 'medicine': return l10n.skillMedicine;
      case 'perception': return l10n.skillPerception;
      case 'survival': return l10n.skillSurvival;
      case 'deception': return l10n.skillDeception;
      case 'intimidation': return l10n.skillIntimidation;
      case 'performance': return l10n.skillPerformance;
      case 'persuasion': return l10n.skillPersuasion;
      default: return key;
    }
  }

  String _getAbilityAbbr(AppLocalizations l10n, String key) {
    switch (key.toLowerCase()) {
      case 'strength': return l10n.abilityStrAbbr;
      case 'dexterity': return l10n.abilityDexAbbr;
      case 'constitution': return l10n.abilityConAbbr;
      case 'intelligence': return l10n.abilityIntAbbr;
      case 'wisdom': return l10n.abilityWisAbbr;
      case 'charisma': return l10n.abilityChaAbbr;
      default: return key.length >= 3 ? key.substring(0, 3).toUpperCase() : key.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Ability Scores Grid
        _buildSectionHeader(context, l10n.abilities.toUpperCase(), Icons.accessibility_new),
        const SizedBox(height: 12),
        _buildAbilityScoresGrid(context, l10n),
        const SizedBox(height: 24),

        // 2. Saving Throws
        _buildSectionHeader(context, l10n.savingThrows.toUpperCase(), Icons.shield),
        const SizedBox(height: 12),
        _buildSavingThrowsList(context, l10n),
        const SizedBox(height: 24),

        // 3. Skills
        _buildSectionHeader(context, l10n.skills.toUpperCase(), Icons.psychology),
        const SizedBox(height: 12),
        _buildSkillsList(context, l10n),
        
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: colorScheme.primary.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildAbilityScoresGrid(BuildContext context, AppLocalizations l10n) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        _buildAbilityCard(context, l10n.abilityStrAbbr, l10n.abilityStr, character.abilityScores.strength, character.abilityScores.strengthModifier, l10n),
        _buildAbilityCard(context, l10n.abilityDexAbbr, l10n.abilityDex, character.abilityScores.dexterity, character.abilityScores.dexterityModifier, l10n),
        _buildAbilityCard(context, l10n.abilityConAbbr, l10n.abilityCon, character.abilityScores.constitution, character.abilityScores.constitutionModifier, l10n),
        _buildAbilityCard(context, l10n.abilityIntAbbr, l10n.abilityInt, character.abilityScores.intelligence, character.abilityScores.intelligenceModifier, l10n),
        _buildAbilityCard(context, l10n.abilityWisAbbr, l10n.abilityWis, character.abilityScores.wisdom, character.abilityScores.wisdomModifier, l10n),
        _buildAbilityCard(context, l10n.abilityChaAbbr, l10n.abilityCha, character.abilityScores.charisma, character.abilityScores.charismaModifier, l10n),
      ],
    );
  }

  Widget _buildAbilityCard(BuildContext context, String abbr, String full, int score, int modifier, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDiceRoller(context, title: '$full ${l10n.check}', modifier: modifier),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(abbr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
            const SizedBox(height: 4),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  modifier >= 0 ? '+$modifier' : '$modifier',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('$score', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingThrowsList(BuildContext context, AppLocalizations l10n) {
    final saves = {
      'Strength': character.abilityScores.strengthModifier,
      'Dexterity': character.abilityScores.dexterityModifier,
      'Constitution': character.abilityScores.constitutionModifier,
      'Intelligence': character.abilityScores.intelligenceModifier,
      'Wisdom': character.abilityScores.wisdomModifier,
      'Charisma': character.abilityScores.charismaModifier,
    };

    return Column(
      children: saves.entries.map((entry) {
        final isProficient = character.savingThrowProficiencies.map((s) => s.toLowerCase()).contains(entry.key.toLowerCase());
        final totalMod = entry.value + (isProficient ? character.proficiencyBonus : 0);
        return _buildSkillRow(context, _getAbilityName(l10n, entry.key), totalMod, isProficient, l10n, isSave: true);
      }).toList(),
    );
  }

  Widget _buildSkillsList(BuildContext context, AppLocalizations l10n) {
    final skillsMap = {
      'Athletics': 'Strength',
      'Acrobatics': 'Dexterity',
      'Sleight of Hand': 'Dexterity',
      'Stealth': 'Dexterity',
      'Arcana': 'Intelligence',
      'History': 'Intelligence',
      'Investigation': 'Intelligence',
      'Nature': 'Intelligence',
      'Religion': 'Intelligence',
      'Animal Handling': 'Wisdom',
      'Insight': 'Wisdom',
      'Medicine': 'Wisdom',
      'Perception': 'Wisdom',
      'Survival': 'Wisdom',
      'Deception': 'Charisma',
      'Intimidation': 'Charisma',
      'Performance': 'Charisma',
      'Persuasion': 'Charisma',
    };

    return Column(
      children: skillsMap.entries.map((entry) {
        final skillKey = entry.key; // English key
        final ability = entry.value;
        
        // Get ability mod
        int mod = 0;
        switch(ability) {
          case 'Strength': mod = character.abilityScores.strengthModifier; break;
          case 'Dexterity': mod = character.abilityScores.dexterityModifier; break;
          case 'Constitution': mod = character.abilityScores.constitutionModifier; break;
          case 'Intelligence': mod = character.abilityScores.intelligenceModifier; break;
          case 'Wisdom': mod = character.abilityScores.wisdomModifier; break;
          case 'Charisma': mod = character.abilityScores.charismaModifier; break;
        }

        final isProficient = character.proficientSkills.map((s) => s.toLowerCase()).contains(skillKey.toLowerCase());
        final totalMod = mod + (isProficient ? character.proficiencyBonus : 0);

        return _buildSkillRow(
            context, 
            _getSkillName(l10n, skillKey), 
            totalMod, 
            isProficient, 
            l10n,
            abilityLabel: _getAbilityAbbr(l10n, ability)
        );
      }).toList(),
    );
  }

  Widget _buildSkillRow(BuildContext context, String name, int modifier, bool isProficient, AppLocalizations l10n, {bool isSave = false, String? abilityLabel}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => showDiceRoller(context, title: '$name ${isSave ? l10n.saveLabel : l10n.check}', modifier: modifier),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isProficient ? colorScheme.secondaryContainer.withOpacity(0.3) : null,
          borderRadius: BorderRadius.circular(8),
          border: isProficient ? Border.all(color: colorScheme.secondary.withOpacity(0.2)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 12, 
              height: 12,
              decoration: BoxDecoration(
                color: isProficient ? colorScheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isProficient ? colorScheme.primary : colorScheme.outline, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: isProficient ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                  if (abilityLabel != null)
                    Text(abilityLabel, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              modifier >= 0 ? '+$modifier' : '$modifier',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isProficient ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}