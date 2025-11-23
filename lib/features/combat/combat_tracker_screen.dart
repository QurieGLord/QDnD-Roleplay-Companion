import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/models/character.dart';
import 'widgets/hp_manager_card.dart';
import 'widgets/death_saves_card.dart';
import 'widgets/conditions_card.dart';
import 'widgets/combat_log_view.dart';
import 'widgets/combat_summary_card.dart';
import 'dart:math';
import 'dart:async';

class CombatTrackerScreen extends StatefulWidget {
  final Character character;

  const CombatTrackerScreen({
    super.key,
    required this.character,
  });

  @override
  State<CombatTrackerScreen> createState() => _CombatTrackerScreenState();
}

class _CombatTrackerScreenState extends State<CombatTrackerScreen> {
  late Character _character;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // Update UI every second if in combat (for timer display)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Get fresh character from Hive
        final box = Hive.box<Character>('characters');
        final character = box.get(widget.character.key);
        if (character?.combatState.isInCombat ?? false) {
          setState(() {
            // Force rebuild every second to update timer
          });
        }
      }
    });
  }

  void _startCombat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Combat'),
        content: const Text('Roll for initiative?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final initiativeRoll = _rollInitiative();
              Navigator.pop(context);
              _character.combatState.startCombat(initiativeRoll);
              await _character.save();
              if (mounted) {
                setState(() {
                  // Combat started, UI will update
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Initiative: $initiativeRoll'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Roll'),
          ),
        ],
      ),
    );
  }

  int _rollInitiative() {
    final d20 = Random().nextInt(20) + 1;
    final bonus = _character.initiativeBonus;
    return d20 + bonus;
  }

  void _endCombat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Combat'),
        content: const Text('Are you sure you want to end combat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _character.combatState.endCombat();
              await _character.save();
              // Small delay to ensure Hive save completes
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                setState(() {
                  // Combat ended, force full rebuild
                });
              }
            },
            child: const Text('End Combat'),
          ),
        ],
      ),
    );
  }

  void _nextRound() {
    setState(() {
      _character.combatState.currentRound++;
      _character.save();
    });
  }

  void _onCharacterUpdated() async {
    // Force immediate rebuild of parent widget
    // Add small delay to ensure Hive save completes
    await Future.delayed(const Duration(milliseconds: 10));
    if (mounted) {
      setState(() {
        // This triggers ValueListenableBuilder to re-read from Hive
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: Hive.box<Character>('characters').listenable(),
      builder: (context, Box<Character> box, _) {
        // Get the latest version of character from Hive
        // Force re-read by accessing through box
        final character = box.get(widget.character.key) ?? widget.character;
        final isInCombat = character.combatState.isInCombat;

        return _buildScaffold(context, theme, character, isInCombat);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, ThemeData theme, Character character, bool isInCombat) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${character.name} - Combat Tracker'),
        actions: [
          if (isInCombat)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'End Combat',
              onPressed: _endCombat,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Combat Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Combat Status',
                          style: theme.textTheme.titleLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isInCombat
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isInCombat ? 'IN COMBAT' : 'OUT OF COMBAT',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isInCombat
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isInCombat) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Round',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${character.combatState.currentRound}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Initiative',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${character.combatState.initiative}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _nextRound,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next Round'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // HP Manager Card
            HpManagerCard(
              key: ValueKey('hp_${character.currentHp}_${character.temporaryHp}'),
              character: character,
              onCharacterUpdated: _onCharacterUpdated,
            ),
            const SizedBox(height: 16),

            // Death Saves Card (only show if at 0 HP)
            if (character.currentHp <= 0) ...[
              DeathSavesCard(
                character: character,
                onCharacterUpdated: _onCharacterUpdated,
              ),
              const SizedBox(height: 16),
            ],

            // Conditions Card
            ConditionsCard(
              character: character,
              onCharacterUpdated: _onCharacterUpdated,
            ),
            const SizedBox(height: 16),

            // Combat Summary (only show if in combat)
            if (isInCombat) ...[
              CombatSummaryCard(
                combatState: character.combatState,
              ),
              const SizedBox(height: 16),
            ],

            // Combat Log
            CombatLogView(
              combatLog: character.combatState.combatLog,
            ),
          ],
        ),
      ),
      floatingActionButton: !isInCombat
          ? FloatingActionButton.extended(
              onPressed: _startCombat,
              icon: const Icon(Icons.sports_martial_arts),
              label: const Text('Start Combat'),
            )
          : null,
    );
  }
}
