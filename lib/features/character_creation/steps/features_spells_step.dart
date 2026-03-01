import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/models/spell_slots_table.dart';
import '../../../core/models/class_data.dart';
import '../../../core/constants/ranger_options.dart';
import '../character_creation_state.dart';

class FeaturesSpellsStep extends StatelessWidget {
  const FeaturesSpellsStep({super.key});

  static const Map<String, List<String>> _fightingStyleOptions = {
    'fighter': [
      'archery',
      'defense',
      'dueling',
      'great_weapon',
      'protection',
      'two_weapon'
    ],
    'paladin': ['defense', 'dueling', 'great_weapon', 'protection'],
    'ranger': ['archery', 'defense', 'dueling', 'two_weapon'],
  };

  // Map internal style names to potential Feature IDs
  // We check multiple patterns because IDs might vary (e.g. generic vs class-specific)
  String? _findFeatureIdForStyle(String style, String classId) {
    // Try class specific first
    final classSpecificId =
        '$classId-fighting-style-$style'; // e.g. fighter-fighting-style-archery
    if (FeatureService.getFeatureById(classSpecificId) != null) {
      return classSpecificId;
    }

    // Try generic
    final genericId = 'fighting-style-$style'; // e.g. fighting-style-archery
    if (FeatureService.getFeatureById(genericId) != null) return genericId;

    // Try alternate generic (e.g. great-weapon-fighting)
    if (style == 'great_weapon') {
      if (FeatureService.getFeatureById(
              'fighting-style-great-weapon-fighting') !=
          null) {
        return 'fighting-style-great-weapon-fighting';
      }
      if (FeatureService.getFeatureById(
              '$classId-fighting-style-great-weapon-fighting') !=
          null) {
        return '$classId-fighting-style-great-weapon-fighting';
      }
    }
    if (style == 'two_weapon') {
      if (FeatureService.getFeatureById('fighting-style-two-weapon-fighting') !=
          null) {
        return 'fighting-style-two-weapon-fighting';
      }
      if (FeatureService.getFeatureById(
              '$classId-fighting-style-two-weapon-fighting') !=
          null) {
        return '$classId-fighting-style-two-weapon-fighting';
      }
    }

    return null;
  }

  static const List<String> _draconicAncestryIds = [
    'dragon-ancestor-black---acid-damage',
    'dragon-ancestor-blue---lightning-damage',
    'dragon-ancestor-brass---fire-damage',
    'dragon-ancestor-bronze---lightning-damage',
    'dragon-ancestor-copper---acid-damage',
    'dragon-ancestor-gold---fire-damage',
    'dragon-ancestor-green---poison-damage',
    'dragon-ancestor-red---fire-damage',
    'dragon-ancestor-silver---cold-damage',
    'dragon-ancestor-white---cold-damage',
  ];

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
      case 'abjuration':
        return l10n.schoolAbjuration;
      case 'conjuration':
        return l10n.schoolConjuration;
      case 'divination':
        return l10n.schoolDivination;
      case 'enchantment':
        return l10n.schoolEnchantment;
      case 'evocation':
        return l10n.schoolEvocation;
      case 'illusion':
        return l10n.schoolIllusion;
      case 'necromancy':
        return l10n.schoolNecromancy;
      case 'transmutation':
        return l10n.schoolTransmutation;
      default:
        return school;
    }
  }

  IconData _getFeatureIcon(String? iconName) {
    switch (iconName) {
      case 'healing':
        return Icons.favorite;
      case 'visibility':
        return Icons.visibility;
      case 'flash_on':
        return Icons.flash_on;
      case 'swords':
        return Icons.shield;
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'auto_awesome':
        return Icons.auto_awesome;
      default:
        return Icons.star;
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
        final standardFeatures =
            FeatureService.getFeaturesForCharacter(tempChar);

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

        // Filter and Categorize Features
        final choiceFeatures = <CharacterFeature>[];
        final passiveFeatures = <CharacterFeature>[];

        for (var f in allFeatures) {
          // Skip known individual option features
          if (f.id.startsWith('dragon-ancestor-')) continue;

          if (f.id.contains('fighting-style')) {
            if (f.id.endsWith('fighting-style')) {
              choiceFeatures.add(f); // Parent Fighting Style
            }
            continue; // Skip specific styles
          }

          if (f.id == 'dragon-ancestor') {
            choiceFeatures.add(f);
            continue;
          }

          if (f.id == 'expertise' || f.id.contains('expertise')) {
            choiceFeatures.add(f);
            continue;
          }

          if (f.id == 'favored-enemy' || f.id == 'natural-explorer') {
            choiceFeatures.add(f);
            continue;
          }

          // Default to passive
          passiveFeatures.add(f);
        }

        // Subclass Selection Logic
        final showSubclassSelection =
            state.selectedClass!.subclasses.isNotEmpty &&
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

              // 1. Subclass Selector (Highest Priority)
              if (showSubclassSelection) ...[
                _buildSubclassSelection(context, state, l10n, locale),
                const SizedBox(height: 24),
              ],

              if (choiceFeatures.isEmpty && passiveFeatures.isEmpty)
                _buildNoFeaturesMessage(context, l10n)
              else
                ...choiceFeatures.map((feature) => _buildFeatureItem(context, state, feature, l10n, locale)),

              // 4. Passive Features
              if (passiveFeatures.isNotEmpty) ...[
                if (choiceFeatures.isNotEmpty) const Divider(height: 32),
                ...passiveFeatures.map((feature) => _buildFeatureItem(context, state, feature, l10n, locale)),
              ],

              // Spell Selection
              if (state.selectedClass!.spellcasting != null) ...[
                const SizedBox(height: 24),
                _buildSpellSelection(context, state, l10n, locale),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(BuildContext context, CharacterCreationState state, CharacterFeature feature, AppLocalizations l10n, String locale) {
    final id = feature.id.toLowerCase();
    
    // 1. Гибкий перехват для Избранного врага
    if (id.contains('favored') || id.contains('enemy')) {
      return _buildFavoredEnemyChoice(context, state, feature, l10n, locale);
    }
    
    // 2. Гибкий перехват для Исследователя природы
    if (id.contains('natural') || id.contains('explorer')) {
      return _buildNaturalExplorerChoice(context, state, feature, l10n, locale);
    }
    
    // Другие специфичные выборы
    if (id == 'dragon-ancestor') {
      return _buildDraconicAncestryChoice(context, state, feature, l10n, locale);
    }
    if (id.endsWith('fighting-style')) {
      return _buildFightingStyleChoice(context, state, feature, l10n, locale);
    }
    
    // 3. Стандартный рендер для всего остального
    return _buildFeatureCard(context, feature, locale, l10n);
  }

  Widget _buildSubclassSelection(BuildContext context,
      CharacterCreationState state, AppLocalizations l10n, String locale) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
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
                  l10n.selectSubclass,
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
    );
  }

  Widget _buildNoFeaturesMessage(BuildContext context, AppLocalizations l10n) {
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
            Icons.info_outline,
            size: 32,
            color:
                Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
    );
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature,
      String locale, AppLocalizations l10n) {
    return Card(
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (feature.actionEconomy != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getLocalizedActionEconomy(
                                    l10n, feature.actionEconomy!)
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
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
    );
  }

  Widget _buildFightingStyleChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    final classId = state.selectedClass!.id.toLowerCase();
    final styles =
        _fightingStyleOptions[classId] ?? _fightingStyleOptions['fighter']!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).colorScheme.secondary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_martial_arts,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(feature.getDescription(locale)),
            const SizedBox(height: 16),
            Text(l10n.chooseFightingStyle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: styles.map((style) {
                final featureId = _findFeatureIdForStyle(style, classId);
                if (featureId == null) {
                  return const SizedBox.shrink(); // Skip if not found
                }

                final styleFeature = FeatureService.getFeatureById(featureId);
                final name =
                    styleFeature?.getName(locale) ?? style.toUpperCase();
                final isSelected =
                    state.selectedFeatureOptions[feature.id] == featureId;

                return ChoiceChip(
                  label: Text(name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      state.selectFeatureOption(feature.id, featureId);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraconicAncestryChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).colorScheme.secondary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(feature.getDescription(locale)),
            const SizedBox(height: 16),
            Text(l10n.choose,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: state.selectedFeatureOptions[feature.id],
              items: _draconicAncestryIds.map((id) {
                final f = FeatureService.getFeatureById(id);
                final name = f?.getName(locale) ?? id;

                return DropdownMenuItem(
                  value: id,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  state.selectFeatureOption(feature.id, value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoredEnemyChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.gps_fixed, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(l10n.choose,
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: state.selectedFeatureOptions['favored_enemy'],
              items: RangerOptions.favoredEnemies.entries.map((entry) {
                final name = locale == 'ru' ? entry.value['ru']! : entry.value['en']!;
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  state.selectFeatureOption('favored_enemy', value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNaturalExplorerChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.terrain, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(l10n.choose,
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: state.selectedFeatureOptions['natural_explorer'],
              items: RangerOptions.naturalExplorers.entries.map((entry) {
                final name = locale == 'ru' ? entry.value['ru']! : entry.value['en']!;
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  state.selectFeatureOption('natural_explorer', value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellSelection(BuildContext context,
      CharacterCreationState state, AppLocalizations l10n, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            future: Future.wait([Future.value(true)]),
            builder: (context, snapshot) {
              // Get available spells
              final classId = state.selectedClass!.id;
              final classSpells = SpellService.getSpellsForClass(classId);
              final level0Spells =
                  classSpells.where((s) => s.level == 0).toList();
              final level1Spells =
                  classSpells.where((s) => s.level == 1).toList();

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
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_fix_off, // Different icon for spells
                        size: 32,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noSpellsAtLevel1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                if (level0Spells.any((s) => s.id == id)) {
                  selectedCantripsCount++;
                }
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
                            l10n.cantripsTab(
                                selectedCantripsCount, limits.cantrips),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Tab(
                          child: Text(
                            limits.spellsKnown >= 999
                                ? l10n.level1TabAll
                                : l10n.level1TabKnown(
                                    selectedLvl1Count, limits.spellsKnown),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
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
                                  padding: const EdgeInsets.only(bottom: 80),
                                  children: level0Spells.map((spell) {
                                    final isSelected =
                                        state.selectedSpells.contains(spell.id);
                                    // Disable if not selected AND limit reached
                                    final isEnabled = isSelected ||
                                        selectedCantripsCount < limits.cantrips;

                                    return _buildSpellCard(
                                        context, spell, state, locale,
                                        isEnabled: isEnabled, l10n: l10n);
                                  }).toList(),
                                ),

                          // Tab 2: Level 1 Spells
                          level1Spells.isEmpty
                              ? Center(child: Text(l10n.noSpellsFound))
                              : ListView(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  children: level1Spells.map((spell) {
                                    final isSelected =
                                        state.selectedSpells.contains(spell.id);
                                    // Disable if not selected AND limit reached (unless unlimited)
                                    final isEnabled = isSelected ||
                                        limits.spellsKnown >= 999 ||
                                        selectedLvl1Count < limits.spellsKnown;

                                    return _buildSpellCard(
                                        context, spell, state, locale,
                                        isEnabled: isEnabled, l10n: l10n);
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
      ],
    );
  }

  Widget _buildSpellCard(BuildContext context, dynamic spell,
      CharacterCreationState state, String locale,
      {bool isEnabled = true, required AppLocalizations l10n}) {
    final isSelected = state.selectedSpells.contains(spell.id);
    final theme = Theme.of(context);
    final cardColor = isEnabled
        ? (isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final textColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 0,
      color: isSelected ? null : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
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
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
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
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : textColor,
                            ),
                          ),
                          Text(
                            _getLocalizedSchool(l10n, spell.school),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      onChanged: isEnabled
                          ? (val) => state.toggleSpell(spell.id)
                          : null,
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
                    color: textColor.withValues(alpha: 0.8),
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
