import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/services/feature_service.dart';
import '../character_creation_state.dart';

class FeaturesSpellsStep extends StatelessWidget {
  const FeaturesSpellsStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterCreationState>(
      builder: (context, state, child) {
        if (state.selectedClass == null || state.selectedRace == null) {
          return const Center(child: Text('Please select a race and class first.'));
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
          abilityScores: AbilityScores(),
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
                'Class Features (Level 1)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'As a level 1 ${state.selectedClass!.getName('en')}, you gain the following features:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              
              if (features.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No features available at level 1 for this class (or data missing).'),
                  ),
                )
              else
                ...features.map((feature) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      _getFeatureIcon(feature.iconName), 
                      color: Theme.of(context).colorScheme.primary
                    ),
                    title: Text(feature.nameEn, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(feature.descriptionEn),
                  ),
                )),

              // Placeholder for Spell Selection (Future Implementation)
              if (state.selectedClass!.spellcasting != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Spells',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Spell selection will be available in future updates. For now, please add spells manually in the character sheet after creation.'),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
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
}
