import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/services/character_data_service.dart';
import '../../../core/models/race_data.dart';
import '../../../core/models/class_data.dart';
import '../character_creation_state.dart';

class RaceClassStep extends StatefulWidget {
  const RaceClassStep({super.key});

  @override
  State<RaceClassStep> createState() => _RaceClassStepState();
}

class _RaceClassStepState extends State<RaceClassStep> {
  String? _expandedRaceId;
  String? _expandedClassId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    final races = CharacterDataService.getAllRaces();
    final classes = CharacterDataService.getAllClasses();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.chooseRaceClass,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.raceClassSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Race Selection
        Text(
          l10n.race,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (races.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.loadingRaces),
            ),
          )
        else
          ...races.map((race) {
            final isSelected = state.selectedRace?.id == race.id;
            final isExpanded = _expandedRaceId == race.id;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => state.updateRace(race),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  race.getName(locale),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  race.getDescription(locale),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimaryContainer
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: isExpanded ? null : 2,
                                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _expandedRaceId = isExpanded ? null : race.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    Divider(
                      height: 1,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.2)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRaceDetails(context, race, locale, isSelected, l10n),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

        const SizedBox(height: 32),

        // Class Selection
        Text(
          l10n.classLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (classes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.loadingClasses),
            ),
          )
        else
          ...classes.map((classData) {
            final isSelected = state.selectedClass?.id == classData.id;
            final isExpanded = _expandedClassId == classData.id;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => state.updateClass(classData),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSecondaryContainer
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classData.getName(locale),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onSecondaryContainer
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  classData.getDescription(locale),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onSecondaryContainer
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: isExpanded ? null : 2,
                                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.hitDieType(classData.hitDie),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onSecondaryContainer
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onSecondaryContainer
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _expandedClassId = isExpanded ? null : classData.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    Divider(
                      height: 1,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.2)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClassDetails(context, classData, locale, isSelected, l10n),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRaceDetails(BuildContext context, RaceData race, String locale, bool isSelected, AppLocalizations l10n) {
    final textColor = isSelected
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speed
        Row(
          children: [
            Icon(Icons.speed, size: 16, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              l10n.speed(race.speed),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Ability Score Increases
        if (race.abilityScoreIncreases.isNotEmpty) ...[
          Text(
            l10n.abilityScoreIncreases,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: race.abilityScoreIncreases.entries.map<Widget>((entry) {
              return Chip(
                label: Text(
                  '${entry.key.toUpperCase()}: +${entry.value}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Languages
        if (race.languages.isNotEmpty) ...[
          Text(
            l10n.languages,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            race.languages.join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Traits
        if (race.getTraits(locale).isNotEmpty) ...[
          Text(
            l10n.racialTraits,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          ...race.getTraits(locale).map((trait) => Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: textColor)),
                Expanded(
                  child: Text(
                    trait,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildClassDetails(BuildContext context, ClassData classData, String locale, bool isSelected, AppLocalizations l10n) {
    final textColor = isSelected
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hit Die
        Row(
          children: [
            Icon(Icons.favorite, size: 16, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              l10n.hitDieType(classData.hitDie),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Saving Throws
        if (classData.savingThrowProficiencies.isNotEmpty) ...[
          Text(
            l10n.savingThrowProficiencies,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classData.savingThrowProficiencies.map((s) => s.toUpperCase()).join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Skill Proficiencies
        Text(
          l10n.skillProficiencies,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.chooseSkills(classData.skillProficiencies.choose, classData.skillProficiencies.from.join(', ')),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),

        // Armor & Weapon Proficiencies
        if (classData.armorProficiencies.isNotEmpty) ...[
          Text(
            l10n.armorProficiencies,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classData.armorProficiencies.toList().join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (classData.weaponProficiencies.isNotEmpty) ...[
          Text(
            l10n.weaponProficiencies,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classData.weaponProficiencies.toList().join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}
