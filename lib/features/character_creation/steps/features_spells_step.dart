import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/models/spell_slots_table.dart';
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
          race: state.selectedRace!.id,
          characterClass: state.selectedClass!.id,
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

        // Get standard features from FeatureService
        final standardFeatures = FeatureService.getFeaturesForCharacter(tempChar);
        
        // Get features from the ClassData object itself (for imported/custom classes)
        final classFeatures = state.selectedClass!.features[1] ?? [];
        
        // Merge lists, avoiding duplicates by ID
        final allFeatures = [...standardFeatures];
        final existingIds = standardFeatures.map((f) => f.id).toSet();
        
        for (var feature in classFeatures) {
          if (!existingIds.contains(feature.id)) {
            allFeatures.add(feature);
            existingIds.add(feature.id);
          }
        }

        final features = allFeatures;

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
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFeatureIcon(feature.iconName), 
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature.getName(locale), 
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (feature.actionEconomy != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _getLocalizedActionEconomy(l10n, feature.actionEconomy!).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10, 
                                          color: Theme.of(context).colorScheme.secondary, 
                                          fontWeight: FontWeight.bold, 
                                          letterSpacing: 0.5
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          feature.getDescription(locale),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

              // Spell Selection
              if (state.selectedClass!.spellcasting != null) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.spellsStepTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectSpellsInstruction,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                
                // Fetch and display spells
                FutureBuilder<List<dynamic>>(
                  future: Future.wait([
                    Future.value(true) 
                  ]),
                  builder: (context, snapshot) {
                    // Get available spells
                    final classId = state.selectedClass!.id;
                    final classSpells = SpellService.getSpellsForClass(classId);
                    final level0Spells = classSpells.where((s) => s.level == 0).toList();
                    final level1Spells = classSpells.where((s) => s.level == 1).toList();
                    
                    // Check slots for Level 1 logic
                    final spellcasting = state.selectedClass!.spellcasting;
                    final casterType = spellcasting?.type ?? 'none';
                    final slots = SpellSlotsTable.getSlots(1, casterType);
                    // Check if we have any Level 1 slots (index 0) or if it's Pact Magic (handled differently but usually has slot at lvl 1)
                    final hasLevel1Slots = slots.isNotEmpty && slots[0] > 0;

                    if (classSpells.isEmpty) {
                       return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(l10n.noSpellsFoundForClass(state.selectedClass!.getName(locale))),
                        ),
                      );
                    }

                    // If no cantrips and no level 1 slots (e.g. Paladin Level 1), show message
                    if (level0Spells.isEmpty && !hasLevel1Slots) {
                       return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text("No spells available at level 1 for this class."), // Fallback string or add to arb
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (level0Spells.isNotEmpty) ...[
                          Text(l10n.cantrips, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...level0Spells.map((spell) => _buildSpellCard(context, spell, state, locale)),
                          const SizedBox(height: 16),
                        ],
                        
                        // Only show Level 1 spells if the class actually has slots at Level 1
                        if (level1Spells.isNotEmpty && hasLevel1Slots) ...[
                          Text(l10n.level1Spells, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...level1Spells.map((spell) => _buildSpellCard(context, spell, state, locale)),
                        ],
                      ],
                    );
                  }
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpellCard(BuildContext context, dynamic spell, CharacterCreationState state, String locale) {
    final isSelected = state.selectedSpells.contains(spell.id);
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => state.toggleSpell(spell.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_fix_high, 
                      color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spell.getName(locale),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        Text(
                          spell.school,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) => state.toggleSpell(spell.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                spell.getDescription(locale),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
