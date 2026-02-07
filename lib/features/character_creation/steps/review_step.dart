import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../character_creation_state.dart';

class ReviewStep extends StatelessWidget {
  const ReviewStep({super.key});

  String _formatModifier(int score) {
    final mod = (score ~/ 2) - 5;
    return mod >= 0 ? '+$mod' : '$mod';
  }

  String _getLocalizedSkill(AppLocalizations l10n, String skill) {
    final normalizedKey = skill.toLowerCase().replaceAll('-', '_');
    switch (normalizedKey) {
      case 'athletics': return l10n.skillAthletics;
      case 'acrobatics': return l10n.skillAcrobatics;
      case 'sleight_of_hand': return l10n.skillSleightOfHand;
      case 'stealth': return l10n.skillStealth;
      case 'arcana': return l10n.skillArcana;
      case 'history': return l10n.skillHistory;
      case 'investigation': return l10n.skillInvestigation;
      case 'nature': return l10n.skillNature;
      case 'religion': return l10n.skillReligion;
      case 'animal_handling': return l10n.skillAnimalHandling;
      case 'insight': return l10n.skillInsight;
      case 'medicine': return l10n.skillMedicine;
      case 'perception': return l10n.skillPerception;
      case 'survival': return l10n.skillSurvival;
      case 'deception': return l10n.skillDeception;
      case 'intimidation': return l10n.skillIntimidation;
      case 'performance': return l10n.skillPerformance;
      case 'persuasion': return l10n.skillPersuasion;
      default: return skill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Hero Section
        Card(
          elevation: 8,
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar or default icon
                if (state.avatarPath != null)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.onPrimaryContainer,
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.file(
                        File(state.avatarPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 64,
                            color: theme.colorScheme.onPrimaryContainer,
                          );
                        },
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                const SizedBox(height: 16),
                Text(
                  l10n.characterReady,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.reviewChoices,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Character Name Hero
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.name.isEmpty ? l10n.unnamed : state.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (state.selectedRace != null && state.selectedClass != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${state.selectedRace!.getName(locale)} ${state.selectedClass!.getName(locale)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Basic Info
        _buildSection(
          context,
          l10n.basicInfo,
          [
            _buildInfoRow(context, l10n.charName, state.name),
            _buildInfoRow(context, l10n.race, state.selectedRace?.getName(locale) ?? '—'),
            _buildInfoRow(context, l10n.classLabel, state.selectedClass?.getName(locale) ?? '—'),
            if (state.selectedBackground != null)
              _buildInfoRow(context, l10n.background, state.selectedBackground!.getName(locale)),
          ],
        ),

        const SizedBox(height: 24),

        // Ability Scores Section
        _buildSectionHeader(context, l10n.abilities, Icons.auto_graph),
        const SizedBox(height: 12),
        _buildAbilityScoresGrid(context, state, l10n),

        const SizedBox(height: 24),

        // Skills Section
        if (state.selectedSkills.isNotEmpty) ...[
          _buildSectionHeader(context, '${l10n.skillProficiencies} (${state.selectedSkills.length})', Icons.stars),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.selectedSkills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getLocalizedSkill(l10n, skill),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Combat Stats
        if (state.selectedClass != null && state.selectedRace != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(context, l10n.combatStats, Icons.shield),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  l10n.hpShort, // 'HP' -> 'ОЗ'
                  '${state.selectedClass!.hitDie + ((state.abilityScores['constitution']! ~/ 2) - 5)}',
                  Icons.favorite,
                  theme.colorScheme.errorContainer,
                  theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  l10n.armorClassAC, // 'AC' -> 'КД'
                  '${10 + ((state.abilityScores['dexterity']! ~/ 2) - 5)}',
                  Icons.security,
                  theme.colorScheme.tertiaryContainer,
                  theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  l10n.initiativeINIT, // 'Initiative' -> 'ИНИЦ'
                  _formatModifier(state.abilityScores['dexterity']!),
                  Icons.flash_on,
                  theme.colorScheme.secondaryContainer,
                  theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  l10n.speedSPEED, // 'Speed' -> 'СКР'
                  '${state.selectedRace!.speed} ${l10n.unitCm == 'см' ? 'фт.' : 'ft'}', // Localization of ft? Using simple check.
                  Icons.directions_run,
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        // Info Footer
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.level1Info,
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildAbilityScoresGrid(BuildContext context, CharacterCreationState state, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final abilities = [
      ('strength', l10n.abilityStrAbbr, l10n.abilityStr, Icons.fitness_center),
      ('dexterity', l10n.abilityDexAbbr, l10n.abilityDex, Icons.directions_run),
      ('constitution', l10n.abilityConAbbr, l10n.abilityCon, Icons.favorite),
      ('intelligence', l10n.abilityIntAbbr, l10n.abilityInt, Icons.lightbulb),
      ('wisdom', l10n.abilityWisAbbr, l10n.abilityWis, Icons.visibility),
      ('charisma', l10n.abilityChaAbbr, l10n.abilityCha, Icons.people),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.0,
      children: abilities.map((ability) {
        final key = ability.$1;
        final abbr = ability.$2;
        // final fullName = ability.$3; // Unused in card, maybe tooltip?
        final icon = ability.$4;
        final baseScore = state.abilityScores[key]!;
        final racialBonus = state.selectedRace?.abilityScoreIncreases[key] ?? 0;
        final finalScore = baseScore + racialBonus;
        final finalModifier = (finalScore ~/ 2) - 5;
        final modifierStr = finalModifier >= 0 ? '+$finalModifier' : '$finalModifier';

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(height: 2),
                Text(
                  abbr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$finalScore',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 20,
                  ),
                ),
                Text(
                  modifierStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                if (racialBonus > 0) ...[
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '$baseScore+$racialBonus',
                      style: TextStyle(
                        fontSize: 8,
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color bgColor,
    Color textColor,
  ) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
