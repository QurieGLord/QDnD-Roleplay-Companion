import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/services/feature_service.dart';
import '../character_creation_state.dart';

class FeaturesSpellsStep extends StatelessWidget {
  const FeaturesSpellsStep({super.key});

  String _getLocalizedActionEconomy(AppLocalizations l10n, String economy) {
    final lower = economy.toLowerCase();
    if (lower.contains('bonus')) return l10n.actionTypeBonus;
    if (lower.contains('reaction')) return l10n.actionTypeReaction;
    if (lower.contains('action')) return l10n.actionTypeAction;
    if (lower.contains('free')) return l10n.actionTypeFree;
    return economy;
  }

  IconData _getFeatureIcon(String? iconName) {
    switch (iconName) {
      case 'healing': return Icons.favorite;
      case 'visibility': return Icons.visibility;
      case 'flash_on': return Icons.flash_on;
      case 'swords': return Icons.shield;
      case 'auto_fix_high': return Icons.auto_fix_high;
      case 'health_and_safety': return Icons.health_and_safety;
      case 'auto_awesome': return Icons.auto_awesome;
      default: return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterCreationState>(
      builder: (context, state, child) {
        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context).languageCode;

        if (state.selectedClass == null || state.selectedRace == null) {
          return Center(child: Text(l10n.selectClassFirst));
        }

        // Create temporary character to check for features
        final tempChar = Character(
          id: const Uuid().v4(),
          name: 'Temp',
          race: state.selectedRace!.id, // Use ID for service lookup
          characterClass: state.selectedClass!.id, // Use ID for service lookup
          subclass: state.selectedSubclass?.id,
          level: 1,
          maxHp: 10,
          currentHp: 10,
          abilityScores: AbilityScores(
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10,
          ),
          spellSlots: [],
          maxSpellSlots: [],
        );

        final features = FeatureService.getFeaturesForCharacter(tempChar);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.featuresStepTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.featuresStepSubtitle(state.selectedClass!.getName(locale)),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              
              if (features.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(l10n.noFeaturesAtLevel1),
                  ),
                )
              else
                ...features.map((feature) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getFeatureIcon(feature.iconName), 
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature.getName(locale), 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                  ),
                                  if (feature.actionEconomy != null)
                                    Text(
                                      _getLocalizedActionEconomy(l10n, feature.actionEconomy!).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10, 
                                        color: Theme.of(context).colorScheme.secondary, 
                                        fontWeight: FontWeight.w600, 
                                        letterSpacing: 0.5
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feature.getDescription(locale),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

              // Placeholder for Spell Selection (Future Implementation)
              if (state.selectedClass!.spellcasting != null) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.spellsStepTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(l10n.spellsStepPlaceholder),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}