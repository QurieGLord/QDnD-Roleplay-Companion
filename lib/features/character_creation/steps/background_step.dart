import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/services/character_data_service.dart';
import '../character_creation_state.dart';

class BackgroundStep extends StatelessWidget {
  const BackgroundStep({super.key});

  String _getSkillName(String skillId, AppLocalizations l10n) {
    switch (skillId) {
      case 'acrobatics': return l10n.skillAcrobatics;
      case 'animal_handling': return l10n.skillAnimalHandling;
      case 'arcana': return l10n.skillArcana;
      case 'athletics': return l10n.skillAthletics;
      case 'deception': return l10n.skillDeception;
      case 'history': return l10n.skillHistory;
      case 'insight': return l10n.skillInsight;
      case 'intimidation': return l10n.skillIntimidation;
      case 'investigation': return l10n.skillInvestigation;
      case 'medicine': return l10n.skillMedicine;
      case 'nature': return l10n.skillNature;
      case 'perception': return l10n.skillPerception;
      case 'performance': return l10n.skillPerformance;
      case 'persuasion': return l10n.skillPersuasion;
      case 'religion': return l10n.skillReligion;
      case 'sleight_of_hand': return l10n.skillSleightOfHand;
      case 'stealth': return l10n.skillStealth;
      case 'survival': return l10n.skillSurvival;
      default: return skillId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final backgrounds = CharacterDataService.getAllBackgrounds();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.chooseBackground,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.backgroundDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        if (backgrounds.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.noBackgroundsAvailable),
            ),
          )
        else
          ...backgrounds.map((background) {
            final isSelected = state.selectedBackground?.id == background.id;
            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => state.updateBackground(background),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              background.getName(locale),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        background.getDescription(locale),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (background.skillProficiencies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: background.skillProficiencies.map((skill) {
                            return Chip(
                              label: Text(_getSkillName(skill, l10n)),
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}