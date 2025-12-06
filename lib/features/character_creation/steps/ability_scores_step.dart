import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'dart:math';
import '../character_creation_state.dart';

class AbilityScoresStep extends StatefulWidget {
  const AbilityScoresStep({super.key});

  @override
  State<AbilityScoresStep> createState() => _AbilityScoresStepState();
}

class _AbilityScoresStepState extends State<AbilityScoresStep> {
  // Standard Array values: 15, 14, 13, 12, 10, 8
  static const List<int> standardArrayValues = [15, 14, 13, 12, 10, 8];

  // Point Buy: 27 points total, costs for scores 8-15
  static const Map<int, int> pointBuyCosts = {
    8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9,
  };

  String _mode = 'standard_array'; // standard_array, point_buy, manual
  String _hpMode = 'max'; // max, average, roll
  int _rolledHP = 0;
  bool _initialized = false;

  String _getAbilityName(String key, AppLocalizations l10n) {
    switch (key) {
      case 'strength': return l10n.abilityStr;
      case 'dexterity': return l10n.abilityDex;
      case 'constitution': return l10n.abilityCon;
      case 'intelligence': return l10n.abilityInt;
      case 'wisdom': return l10n.abilityWis;
      case 'charisma': return l10n.abilityCha;
      default: return key;
    }
  }

  String _getAbilityDesc(String key, AppLocalizations l10n) {
    switch (key) {
      case 'strength': return l10n.strDesc;
      case 'dexterity': return l10n.dexDesc;
      case 'constitution': return l10n.conDesc;
      case 'intelligence': return l10n.intDesc;
      case 'wisdom': return l10n.wisDesc;
      case 'charisma': return l10n.chaDesc;
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Initialize ability scores on first build
    if (!_initialized && state.selectedClass != null) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetScoresForMode(state);
      });
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.assignAbilityScores,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.abilityScoresSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Mode Selection
        _buildModeSelector(context, state, l10n),
        const SizedBox(height: 24),

        // Mode Description
        _buildModeDescription(context, l10n),
        const SizedBox(height: 24),

        // Ability Score Cards
        _buildAbilityCard(context, state, l10n, 'strength', 'STR', Icons.fitness_center),
        _buildAbilityCard(context, state, l10n, 'dexterity', 'DEX', Icons.directions_run),
        _buildAbilityCard(context, state, l10n, 'constitution', 'CON', Icons.favorite),
        _buildAbilityCard(context, state, l10n, 'intelligence', 'INT', Icons.lightbulb),
        _buildAbilityCard(context, state, l10n, 'wisdom', 'WIS', Icons.visibility),
        _buildAbilityCard(context, state, l10n, 'charisma', 'CHA', Icons.people),

        // Point Buy Summary (only in Point Buy mode)
        if (_mode == 'point_buy') ...[
          const SizedBox(height: 16),
          _buildPointBuySummary(context, state, l10n),
        ],

        // HP Selection Section
        if (state.selectedClass != null) ...[
          const SizedBox(height: 32),
          _buildHPSection(context, state, l10n),
        ],
      ],
    );
  }

  Widget _buildHPSection(BuildContext context, CharacterCreationState state, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final hitDie = state.selectedClass?.hitDie ?? 8;
    final conScore = state.abilityScores['constitution'] ?? 10;
    final racialBonus = state.selectedRace?.abilityScoreIncreases['constitution'] ?? 0;
    final finalCon = conScore + racialBonus;
    final conMod = (finalCon ~/ 2) - 5;
    final conModStr = conMod >= 0 ? '+$conMod' : '$conMod';

    int currentHP = 0;
    switch (_hpMode) {
      case 'max':
        currentHP = hitDie + conMod;
        break;
      case 'average':
        final avgRoll = ((hitDie / 2) + 1).ceil();
        currentHP = avgRoll + conMod;
        break;
      case 'roll':
        currentHP = _rolledHP > 0 ? _rolledHP + conMod : 0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.startingHitPoints,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // HP Display and Controls
        Card(
          elevation: 4,
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HP Display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentHP > 0 ? '$currentHP HP' : '— HP',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.hitDieConMod(hitDie, conModStr),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // HP Mode Selector
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'max', label: const Text('Max'), icon: const Icon(Icons.trending_up, size: 16)),
                    ButtonSegment(value: 'average', label: Text(l10n.average), icon: const Icon(Icons.functions, size: 16)),
                    ButtonSegment(value: 'roll', label: Text(l10n.roll), icon: const Icon(Icons.casino, size: 16)),
                  ],
                  selected: {_hpMode},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _hpMode = newSelection.first;
                      if (_hpMode == 'roll' && _rolledHP == 0) {
                        // Auto-roll on first selection
                        final random = Random();
                        _rolledHP = random.nextInt(hitDie) + 1;
                      }
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return theme.colorScheme.onErrorContainer.withValues(alpha: 0.2);
                      }
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.all(theme.colorScheme.onErrorContainer),
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Roll button for roll mode
        if (_hpMode == 'roll') ...[
          const SizedBox(height: 8),
          Center(
            child: FilledButton.tonal(
              onPressed: () {
                setState(() {
                  final random = Random();
                  _rolledHP = random.nextInt(hitDie) + 1;
                });
              },
              child: Text(l10n.reRoll(hitDie, _rolledHP)),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Info card
        Card(
          color: theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hpMode == 'max'
                        ? l10n.hpMaxDesc
                        : _hpMode == 'average'
                            ? l10n.hpAvgDesc(((hitDie / 2) + 1).ceil())
                            : l10n.hpRollDesc(hitDie),
                    style: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontSize: 12,
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

  Widget _buildModeSelector(BuildContext context, CharacterCreationState state, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.allocationMethod,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'standard_array',
                  label: Text(l10n.standardArray.split(' ').first), // "Standard"
                  icon: const Icon(Icons.grid_4x4),
                ),
                ButtonSegment(
                  value: 'point_buy',
                  label: Text(l10n.pointBuy.split(' ').first), // "Point"
                  icon: const Icon(Icons.calculate),
                ),
                ButtonSegment(
                  value: 'manual',
                  label: Text(l10n.manualEntry.split(' ').first), // "Manual"
                  icon: const Icon(Icons.edit),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _mode = newSelection.first;
                  _resetScoresForMode(state);
                });
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeDescription(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    String title, description;

    switch (_mode) {
      case 'standard_array':
        title = l10n.standardArray;
        description = l10n.standardArrayDesc;
        break;
      case 'point_buy':
        title = l10n.pointBuy;
        description = l10n.pointBuyDesc;
        break;
      case 'manual':
        title = l10n.manualEntry;
        description = l10n.manualEntryDesc;
        break;
      default:
        title = '';
        description = '';
    }

    return Card(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilityCard(
    BuildContext context,
    CharacterCreationState state,
    AppLocalizations l10n,
    String key,
    String abbr,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final score = state.abilityScores[key] ?? 10;
    final name = _getAbilityName(key, l10n);
    final description = _getAbilityDesc(key, l10n);

    // Get racial bonus if race is selected
    final racialBonus = state.selectedRace?.abilityScoreIncreases[key] ?? 0;
    final finalScore = score + racialBonus;
    final finalModifier = (finalScore ~/ 2) - 5;
    final finalModifierStr = finalModifier >= 0 ? '+$finalModifier' : '$finalModifier';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildScoreControl(context, state, key, score),
              ],
            ),
            // Racial bonus indicator
            if (racialBonus > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.racialBonus(racialBonus, finalScore, finalModifierStr),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreControl(
    BuildContext context,
    CharacterCreationState state,
    String key,
    int score,
  ) {
    final modifier = (score ~/ 2) - 5;
    final modifierStr = modifier >= 0 ? '+$modifier' : '$modifier';

    switch (_mode) {
      case 'standard_array':
        return _buildStandardArrayDropdown(context, state, key, score, modifierStr);
      case 'point_buy':
        return _buildPointBuyButtons(context, state, key, score, modifierStr);
      case 'manual':
        return _buildManualSlider(context, state, key, score, modifierStr);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStandardArrayDropdown(
    BuildContext context,
    CharacterCreationState state,
    String key,
    int score,
    String modifierStr,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: score,
        underline: const SizedBox(),
        isDense: true,
        dropdownColor: theme.colorScheme.primaryContainer,
        items: standardArrayValues.map((value) {
          final mod = (value ~/ 2) - 5;
          final modStr = mod >= 0 ? '+$mod' : '$mod';
          return DropdownMenuItem(
            value: value,
            child: Text(
              '$value ($modStr)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            state.updateAbilityScore(key, newValue);
          }
        },
      ),
    );
  }

  Widget _buildPointBuyButtons(
    BuildContext context,
    CharacterCreationState state,
    String key,
    int score,
    String modifierStr,
  ) {
    final theme = Theme.of(context);
    final canDecrease = score > 8;
    final canIncrease = score < 15 && _getPointsRemaining(state) >= _getIncreaseCost(score);

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle),
          onPressed: canDecrease
              ? () => state.updateAbilityScore(key, score - 1)
              : null,
          color: theme.colorScheme.primary,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                '$score',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                modifierStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: canIncrease
              ? () => state.updateAbilityScore(key, score + 1)
              : null,
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildManualSlider(
    BuildContext context,
    CharacterCreationState state,
    String key,
    int score,
    String modifierStr,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                '$score',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                modifierStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 150,
          child: Slider(
            value: score.toDouble(),
            min: 3,
            max: 18,
            divisions: 15,
            label: '$score ($modifierStr)',
            onChanged: (value) {
              state.updateAbilityScore(key, value.toInt());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPointBuySummary(BuildContext context, CharacterCreationState state, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final remaining = _getPointsRemaining(state);
    const total = 27;
    final used = total - remaining;

    return Card(
      color: remaining == 0
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              remaining == 0 ? Icons.check_circle : Icons.warning,
              color: remaining == 0
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.pointsUsed(used, total, remaining),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: remaining == 0
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetScoresForMode(CharacterCreationState state) {
    switch (_mode) {
      case 'standard_array':
        _assignStandardArray(state);
        break;
      case 'point_buy':
        // Set all to 8 (costs 0 points)
        for (var ability in state.abilityScores.keys) {
          state.updateAbilityScore(ability, 8);
        }
        break;
      case 'manual':
        // Set all to 10 (average)
        for (var ability in state.abilityScores.keys) {
          state.updateAbilityScore(ability, 10);
        }
        break;
    }
  }

  void _assignStandardArray(CharacterCreationState state) {
    // Standard Array values: 15, 14, 13, 12, 10, 8
    final values = [15, 14, 13, 12, 10, 8];

    // Get primary abilities from selected class
    final primaryAbilities = state.selectedClass?.primaryAbilities ?? [];

    // All abilities in priority order
    final abilities = ['strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma'];

    // Intelligent assignment based on class
    if (primaryAbilities.isNotEmpty) {
      // Priority order:
      // 1. Primary abilities (15, 14, ...)
      // 2. Constitution (always important for HP)
      // 3. Other abilities

      final prioritized = <String>[];

      // Add primary abilities first
      for (var ability in primaryAbilities) {
        if (abilities.contains(ability)) {
          prioritized.add(ability);
        }
      }

      // Add constitution if not already in primaries (for HP)
      if (!prioritized.contains('constitution')) {
        prioritized.add('constitution');
      }

      // Add remaining abilities
      for (var ability in abilities) {
        if (!prioritized.contains(ability)) {
          prioritized.add(ability);
        }
      }

      // Assign values in priority order
      for (int i = 0; i < prioritized.length && i < values.length; i++) {
        state.updateAbilityScore(prioritized[i], values[i]);
      }
    } else {
      // No class selected - use default assignment
      state.updateAbilityScore('strength', 15);
      state.updateAbilityScore('dexterity', 14);
      state.updateAbilityScore('constitution', 13);
      state.updateAbilityScore('intelligence', 12);
      state.updateAbilityScore('wisdom', 10);
      state.updateAbilityScore('charisma', 8);
    }
  }

  int _getPointsRemaining(CharacterCreationState state) {
    int spent = 0;
    for (var score in state.abilityScores.values) {
      spent += pointBuyCosts[score] ?? 0;
    }
    return 27 - spent;
  }

  int _getIncreaseCost(int currentScore) {
    if (currentScore >= 15) return 999; // Can't go above 15
    return (pointBuyCosts[currentScore + 1] ?? 0) - (pointBuyCosts[currentScore] ?? 0);
  }
}