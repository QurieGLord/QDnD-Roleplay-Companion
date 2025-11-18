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
        // Ability Scores Section
        Card(
          elevation: 4,
          shadowColor: colorScheme.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ABILITY SCORES',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to roll ability check',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Ability Scores Grid
                GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
          children: [
            _AbilityScoreCard(
              name: 'STR',
              score: character.abilityScores.strength,
              modifier: character.abilityScores.strengthModifier,
              onTap: () => showDiceRoller(
                context,
                title: 'Strength Check',
                modifier: character.abilityScores.strengthModifier,
              ),
            ),
            _AbilityScoreCard(
              name: 'DEX',
              score: character.abilityScores.dexterity,
              modifier: character.abilityScores.dexterityModifier,
              onTap: () => showDiceRoller(
                context,
                title: 'Dexterity Check',
                modifier: character.abilityScores.dexterityModifier,
              ),
            ),
            _AbilityScoreCard(
              name: 'CON',
              score: character.abilityScores.constitution,
              modifier: character.abilityScores.constitutionModifier,
              onTap: () => showDiceRoller(
                context,
                title: 'Constitution Check',
                modifier: character.abilityScores.constitutionModifier,
              ),
            ),
            _AbilityScoreCard(
              name: 'INT',
              score: character.abilityScores.intelligence,
              modifier: character.abilityScores.intelligenceModifier,
              onTap: () => showDiceRoller(
                context,
                title: 'Intelligence Check',
                modifier: character.abilityScores.intelligenceModifier,
              ),
            ),
            _AbilityScoreCard(
              name: 'WIS',
              score: character.abilityScores.wisdom,
              modifier: character.abilityScores.wisdomModifier,
              onTap: () => showDiceRoller(
                context,
                title: 'Wisdom Check',
                modifier: character.abilityScores.wisdomModifier,
              ),
            ),
            _AbilityScoreCard(
              name: 'CHA',
              score: character.abilityScores.charisma,
              modifier: character.abilityScores.charismaModifier,
              onTap: () => showDiceRoller(
                context,
                title: 'Charisma Check',
                modifier: character.abilityScores.charismaModifier,
              ),
            ),
          ],
        ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Saving Throws Section
        Card(
          elevation: 4,
          shadowColor: colorScheme.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shield,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAVING THROWS',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to roll',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

        _SavingThrowTile(
          name: 'Strength',
          modifier: character.abilityScores.strengthModifier,
          isProficient: false, // TODO: Check actual proficiency
          proficiencyBonus: character.proficiencyBonus,
          onTap: () => showDiceRoller(
            context,
            title: 'Strength Save',
            modifier: character.abilityScores.strengthModifier,
          ),
        ),
        _SavingThrowTile(
          name: 'Dexterity',
          modifier: character.abilityScores.dexterityModifier,
          isProficient: false,
          proficiencyBonus: character.proficiencyBonus,
          onTap: () => showDiceRoller(
            context,
            title: 'Dexterity Save',
            modifier: character.abilityScores.dexterityModifier,
          ),
        ),
        _SavingThrowTile(
          name: 'Constitution',
          modifier: character.abilityScores.constitutionModifier,
          isProficient: false,
          proficiencyBonus: character.proficiencyBonus,
          onTap: () => showDiceRoller(
            context,
            title: 'Constitution Save',
            modifier: character.abilityScores.constitutionModifier,
          ),
        ),
        _SavingThrowTile(
          name: 'Intelligence',
          modifier: character.abilityScores.intelligenceModifier,
          isProficient: false,
          proficiencyBonus: character.proficiencyBonus,
          onTap: () => showDiceRoller(
            context,
            title: 'Intelligence Save',
            modifier: character.abilityScores.intelligenceModifier,
          ),
        ),
        _SavingThrowTile(
          name: 'Wisdom',
          modifier: character.abilityScores.wisdomModifier,
          isProficient: true, // Paladin is proficient in WIS
          proficiencyBonus: character.proficiencyBonus,
          onTap: () => showDiceRoller(
            context,
            title: 'Wisdom Save',
            modifier: character.abilityScores.wisdomModifier + character.proficiencyBonus,
          ),
        ),
                _SavingThrowTile(
                  name: 'Charisma',
                  modifier: character.abilityScores.charismaModifier,
                  isProficient: true, // Paladin is proficient in CHA
                  proficiencyBonus: character.proficiencyBonus,
                  onTap: () => showDiceRoller(
                    context,
                    title: 'Charisma Save',
                    modifier: character.abilityScores.charismaModifier +
                        character.proficiencyBonus,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AbilityScoreCard extends StatelessWidget {
  final String name;
  final int score;
  final int modifier;
  final VoidCallback onTap;

  const _AbilityScoreCard({
    required this.name,
    required this.score,
    required this.modifier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    modifier >= 0 ? '+$modifier' : '$modifier',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$score',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingThrowTile extends StatelessWidget {
  final String name;
  final int modifier;
  final bool isProficient;
  final int proficiencyBonus;
  final VoidCallback onTap;

  const _SavingThrowTile({
    required this.name,
    required this.modifier,
    required this.isProficient,
    required this.proficiencyBonus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalModifier = modifier + (isProficient ? proficiencyBonus : 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isProficient
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              totalModifier >= 0 ? '+$totalModifier' : '$totalModifier',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isProficient
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ),
        title: Text(name),
        trailing: isProficient
            ? Icon(
                Icons.check_circle,
                color: colorScheme.primary,
                size: 20,
              )
            : null,
      ),
    );
  }
}
