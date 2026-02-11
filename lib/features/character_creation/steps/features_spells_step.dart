import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/models/spell_slots_table.dart';
import '../../../core/models/class_data.dart';
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

  String _getLocalizedSchool(AppLocalizations l10n, String school) {
    switch (school.toLowerCase()) {
      case 'abjuration': return l10n.schoolAbjuration;
      case 'conjuration': return l10n.schoolConjuration;
      case 'divination': return l10n.schoolDivination;
      case 'enchantment': return l10n.schoolEnchantment;
      case 'evocation': return l10n.schoolEvocation;
      case 'illusion': return l10n.schoolIllusion;
      case 'necromancy': return l10n.schoolNecromancy;
      case 'transmutation': return l10n.schoolTransmutation;
      default: return school;
    }
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
        
        // Subclass Selection Logic
        final showSubclassSelection = state.selectedClass!.subclasses.isNotEmpty && 
                                     state.selectedClass!.subclassLevel <= 1;

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
              
              // Subclass Selection UI
              if (showSubclassSelection) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              l10n.selectSubclass, // Ensure this key exists or use fallback
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<SubclassData>(
                              value: state.selectedSubclass,
                              hint: Text(l10n.choose),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: state.selectedClass!.subclasses.map((subclass) {
                                return DropdownMenuItem<SubclassData>(
                                  value: subclass,
                                  child: Text(
                                    subclass.getName(locale),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  state.updateSubclass(value);
                                }
                              },
                            ),
                          ),
                        ),
                        if (state.selectedSubclass != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.selectedSubclass!.getDescription(locale),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              if (features.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noFeaturesAtLevel1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

                    // If no cantrips and no level 1 slots (e.g. Paladin Level 1), show message
                    if (level0Spells.isEmpty && !hasLevel1Slots) {
                       return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_fix_off, // Different icon for spells
                              size: 32,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noSpellsAtLevel1,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // --- Spell Manager Logic ---
                    final limits = state.getSpellLimits();
                    
                    // Count currently selected
                    int selectedCantripsCount = 0;
                    int selectedLvl1Count = 0;
                    
                    for (var id in state.selectedSpells) {
                      // We have to check the level of the selected ID. 
                      // Since we have the full lists here, we can check containment.
                      if (level0Spells.any((s) => s.id == id)) selectedCantripsCount++;
                      if (level1Spells.any((s) => s.id == id)) selectedLvl1Count++;
                    }

                    return DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(
                                child: Text(
                                  l10n.cantripsTab(selectedCantripsCount, limits.cantrips),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Tab(
                                child: Text(
                                  limits.spellsKnown >= 999 
                                    ? l10n.level1TabAll
                                    : l10n.level1TabKnown(selectedLvl1Count, limits.spellsKnown),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            labelColor: Theme.of(context).colorScheme.primary,
                            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                            indicatorColor: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 400, // Fixed height for scrolling inside tabs
                            child: TabBarView(
                              children: [
                                // Tab 1: Cantrips
                                level0Spells.isEmpty 
                                    ? Center(child: Text(l10n.noSpellsFound))
                                    : ListView(
                                        children: level0Spells.map((spell) {
                                          final isSelected = state.selectedSpells.contains(spell.id);
                                          // Disable if not selected AND limit reached
                                          final isEnabled = isSelected || selectedCantripsCount < limits.cantrips;
                                          
                                          return _buildSpellCard(
                                            context, 
                                            spell, 
                                            state, 
                                            locale, 
                                            isEnabled: isEnabled
                                          );
                                        }).toList(),
                                      ),
                                
                                // Tab 2: Level 1 Spells
                                level1Spells.isEmpty 
                                    ? Center(child: Text(l10n.noSpellsFound))
                                    : ListView(
                                        children: level1Spells.map((spell) {
                                          final isSelected = state.selectedSpells.contains(spell.id);
                                          // Disable if not selected AND limit reached (unless unlimited)
                                          final isEnabled = isSelected || 
                                                            limits.spellsKnown >= 999 || 
                                                            selectedLvl1Count < limits.spellsKnown;
                                          
                                          return _buildSpellCard(
                                            context, 
                                            spell, 
                                            state, 
                                            locale, 
                                            isEnabled: isEnabled
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSpellCard(
    BuildContext context, 
    dynamic spell, 
    CharacterCreationState state, 
    String locale, 
    {bool isEnabled = true}
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isSelected = state.selectedSpells.contains(spell.id);
    final theme = Theme.of(context);
    final cardColor = isEnabled 
        ? (isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    final textColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withOpacity(0.4);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 0,
      color: isSelected ? null : theme.colorScheme.surface, // Use default surface for unselected to stand out less
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: isEnabled ? () => state.toggleSpell(spell.id) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardColor,
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
                              color: isSelected ? theme.colorScheme.primary : textColor,
                            ),
                          ),
                          Text(
                            _getLocalizedSchool(l10n, spell.school),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      onChanged: isEnabled ? (val) => state.toggleSpell(spell.id) : null,
                      activeColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  spell.getDescription(locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
