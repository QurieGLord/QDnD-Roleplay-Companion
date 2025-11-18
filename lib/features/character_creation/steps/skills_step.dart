import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../character_creation_state.dart';

class SkillsStep extends StatelessWidget {
  const SkillsStep({super.key});

  // D&D 5e skills with descriptions and icons
  static const Map<String, String> skillDescriptions = {
    'acrobatics': 'Dexterity - Balance, tumbling, aerial maneuvers',
    'animal_handling': 'Wisdom - Calming animals, riding, training',
    'arcana': 'Intelligence - Magic, spells, magical items',
    'athletics': 'Strength - Climbing, jumping, swimming',
    'deception': 'Charisma - Lying, disguising, misleading',
    'history': 'Intelligence - Historical events, legends',
    'insight': 'Wisdom - Reading intentions, detecting lies',
    'intimidation': 'Charisma - Threats, coercion',
    'investigation': 'Intelligence - Finding clues, deduction',
    'medicine': 'Wisdom - Stabilizing, diagnosing',
    'nature': 'Intelligence - Terrain, plants, animals',
    'perception': 'Wisdom - Spotting, hearing, detecting',
    'performance': 'Charisma - Music, dance, acting',
    'persuasion': 'Charisma - Diplomacy, negotiations',
    'religion': 'Intelligence - Deities, rites, prayers',
    'sleight_of_hand': 'Dexterity - Pickpocketing, tricks',
    'stealth': 'Dexterity - Hiding, moving silently',
    'survival': 'Wisdom - Tracking, foraging, navigation',
  };

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

  String _formatSkillName(String skill) {
    return skill.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);

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
              'Please select a class first',
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
          'Choose Skills',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select $maxSkills skill proficiencies for your ${state.selectedClass!.name['en']}.',
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
                            ? 'All skills selected!'
                            : 'Choose ${maxSkills - selectedCount} more skill${maxSkills - selectedCount == 1 ? '' : 's'}',
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
                            _formatSkillName(skill),
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
                            skillDescriptions[skill] ?? skill,
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
