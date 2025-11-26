import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../shared/widgets/dice_roller_modal.dart';

class StatsTab extends StatelessWidget {
  final Character character;

  const StatsTab({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Ability Scores Grid
        _buildSectionHeader(context, 'ABILITIES', Icons.accessibility_new),
        const SizedBox(height: 12),
        _buildAbilityScoresGrid(context),
        const SizedBox(height: 24),

        // 2. Saving Throws
        _buildSectionHeader(context, 'SAVING THROWS', Icons.shield),
        const SizedBox(height: 12),
        _buildSavingThrowsList(context),
        const SizedBox(height: 24),

        // 3. Skills
        _buildSectionHeader(context, 'SKILLS', Icons.psychology),
        const SizedBox(height: 12),
        _buildSkillsList(context),
        
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

  Widget _buildAbilityScoresGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        _buildAbilityCard(context, 'STR', 'Strength', character.abilityScores.strength, character.abilityScores.strengthModifier),
        _buildAbilityCard(context, 'DEX', 'Dexterity', character.abilityScores.dexterity, character.abilityScores.dexterityModifier),
        _buildAbilityCard(context, 'CON', 'Constitution', character.abilityScores.constitution, character.abilityScores.constitutionModifier),
        _buildAbilityCard(context, 'INT', 'Intelligence', character.abilityScores.intelligence, character.abilityScores.intelligenceModifier),
        _buildAbilityCard(context, 'WIS', 'Wisdom', character.abilityScores.wisdom, character.abilityScores.wisdomModifier),
        _buildAbilityCard(context, 'CHA', 'Charisma', character.abilityScores.charisma, character.abilityScores.charismaModifier),
      ],
    );
  }

  Widget _buildAbilityCard(BuildContext context, String abbr, String full, int score, int modifier) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDiceRoller(context, title: '$full Check', modifier: modifier),
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

  Widget _buildSavingThrowsList(BuildContext context) {
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
        return _buildSkillRow(context, entry.key, totalMod, isProficient, isSave: true);
      }).toList(),
    );
  }

  Widget _buildSkillsList(BuildContext context) {
    // Standard 5e Skills mapped to abilities
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
        final skillName = entry.key;
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

        final isProficient = character.proficientSkills.map((s) => s.toLowerCase()).contains(skillName.toLowerCase());
        final totalMod = mod + (isProficient ? character.proficiencyBonus : 0);

        return _buildSkillRow(context, skillName, totalMod, isProficient, abilityLabel: ability.substring(0, 3).toUpperCase());
      }).toList(),
    );
  }

  Widget _buildSkillRow(BuildContext context, String name, int modifier, bool isProficient, {bool isSave = false, String? abilityLabel}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => showDiceRoller(context, title: '$name ${isSave ? "Save" : "Check"}', modifier: modifier),
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