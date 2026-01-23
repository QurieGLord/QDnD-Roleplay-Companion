import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../character_creation_state.dart';

class SkillsStep extends StatelessWidget {
  const SkillsStep({super.key});

  static const Map<String, IconData> skillIcons = {
    'acrobatics': Icons.sports_gymnastics,
    'animal_handling': Icons.pets,
    'arcana': Icons.auto_awesome,
    'athletics': Icons.fitness_center,
    'deception': Icons.theater_comedy,
    'history': Icons.menu_book,
    'insight': Icons.psychology,
    'intimidation': Icons.warning,
    'investigation': Icons.search,
    'medicine': Icons.medical_services,
    'nature': Icons.park,
    'perception': Icons.visibility,
    'performance': Icons.music_note,
    'persuasion': Icons.handshake,
    'religion': Icons.church,
    'sleight_of_hand': Icons.pan_tool,
    'stealth': Icons.nightlight,
    'survival': Icons.hiking,
  };

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

  String _getSkillDesc(String skillId, AppLocalizations l10n) {
    switch (skillId) {
      case 'acrobatics': return l10n.skillAcrobaticsDesc;
      case 'animal_handling': return l10n.skillAnimalHandlingDesc;
      case 'arcana': return l10n.skillArcanaDesc;
      case 'athletics': return l10n.skillAthleticsDesc;
      case 'deception': return l10n.skillDeceptionDesc;
      case 'history': return l10n.skillHistoryDesc;
      case 'insight': return l10n.skillInsightDesc;
      case 'intimidation': return l10n.skillIntimidationDesc;
      case 'investigation': return l10n.skillInvestigationDesc;
      case 'medicine': return l10n.skillMedicineDesc;
      case 'nature': return l10n.skillNatureDesc;
      case 'perception': return l10n.skillPerceptionDesc;
      case 'performance': return l10n.skillPerformanceDesc;
      case 'persuasion': return l10n.skillPersuasionDesc;
      case 'religion': return l10n.skillReligionDesc;
      case 'sleight_of_hand': return l10n.skillSleightOfHandDesc;
      case 'stealth': return l10n.skillStealthDesc;
      case 'survival': return l10n.skillSurvivalDesc;
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    if (state.selectedClass == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.selectClassFirst,
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    final availableSkills = state.selectedClass!.skillProficiencies.from;
    final maxSkills = state.selectedClass!.skillProficiencies.choose;
    final selectedCount = state.selectedSkills.length;
    final isComplete = selectedCount == maxSkills;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.chooseSkillsTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.selectSkillProficiencies(maxSkills, state.selectedClass!.getName(locale)),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Progress Card
        Card(
          color: isComplete
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isComplete ? Icons.check_circle : Icons.info_outline,
                      color: isComplete
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isComplete
                            ? l10n.allSkillsSelected
                            : l10n.chooseMoreSkills(maxSkills - selectedCount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isComplete
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    Text(
                      '$selectedCount / $maxSkills',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isComplete
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: selectedCount / maxSkills,
                  backgroundColor: isComplete
                      ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2)
                      : theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.2),
                  color: isComplete
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSecondaryContainer,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Skills List
        ...availableSkills.map((skill) {
          final isSelected = state.selectedSkills.contains(skill);
          final canSelect = selectedCount < maxSkills || isSelected;
          final skillIcon = skillIcons[skill] ?? Icons.star;

          return Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : null,
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: canSelect ? () => state.toggleSkill(skill) : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Checkbox
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : canSelect
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    // Skill Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        skillIcon,
                        size: 24,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : canSelect
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Skill Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getSkillName(skill, l10n),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : canSelect
                                      ? null
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSkillDesc(skill, l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : canSelect
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
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