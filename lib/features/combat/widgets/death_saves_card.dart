import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/models/character.dart';
import '../../../core/models/combat_state.dart';
import 'package:uuid/uuid.dart';

class DeathSavesCard extends StatelessWidget {
  final Character character;
  final VoidCallback onCharacterUpdated;

  const DeathSavesCard({
    super.key,
    required this.character,
    required this.onCharacterUpdated,
  });

  void _rollDeathSave(BuildContext context) {
    final roll = Random().nextInt(20) + 1;
    final deathSaves = character.deathSaves;

    String message;
    if (roll == 20) {
      // Natural 20 - regain 1 HP
      character.heal(1, source: 'Death save (nat 20)');
      message = 'Natural 20! Regained 1 HP';
    } else if (roll == 1) {
      // Natural 1 - count as 2 failures
      deathSaves.addFailure();
      deathSaves.addFailure();
      message = 'Natural 1! 2 failures';
    } else if (roll >= 10) {
      // Success
      deathSaves.addSuccess();
      message = 'Success! ($roll)';
    } else {
      // Failure
      deathSaves.addFailure();
      message = 'Failure ($roll)';
    }

    // Log to combat
    if (character.combatState.isInCombat) {
      character.combatState.addLogEntry(CombatLogEntry(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        type: CombatLogType.deathSave,
        amount: roll,
        description: message,
        round: character.combatState.currentRound,
      ));
    }

    onCharacterUpdated();

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: roll >= 10 ? Colors.green : Colors.red,
      ),
    );
  }

  void _resetDeathSaves() {
    character.deathSaves.reset();
    onCharacterUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deathSaves = character.deathSaves;

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Death Saves',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                if (deathSaves.isStabilized)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'STABILIZED',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (deathSaves.isDead)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DEAD',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Successes
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Successes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const Spacer(),
                ...List.generate(3, (index) {
                  final isFilled = index < deathSaves.successes;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (isFilled && deathSaves.successes > 0) {
                          // Remove success
                          character.deathSaves.successes--;
                          character.deathSaves.save();
                          onCharacterUpdated();
                        } else if (!isFilled && deathSaves.successes < 3) {
                          // Add success
                          character.deathSaves.addSuccess();
                          onCharacterUpdated();
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? Colors.green
                              : theme.colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: theme.colorScheme.onErrorContainer,
                            width: 2,
                          ),
                        ),
                        child: isFilled
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            // Failures
            Row(
              children: [
                Icon(
                  Icons.cancel,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Failures',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const Spacer(),
                ...List.generate(3, (index) {
                  final isFilled = index < deathSaves.failures;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (isFilled && deathSaves.failures > 0) {
                          // Remove failure
                          character.deathSaves.failures--;
                          character.deathSaves.save();
                          onCharacterUpdated();
                        } else if (!isFilled && deathSaves.failures < 3) {
                          // Add failure
                          character.deathSaves.addFailure();
                          onCharacterUpdated();
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? Colors.red
                              : theme.colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: theme.colorScheme.onErrorContainer,
                            width: 2,
                          ),
                        ),
                        child: isFilled
                            ? const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: deathSaves.isStabilized || deathSaves.isDead
                        ? null
                        : () => _rollDeathSave(context),
                    icon: const Icon(Icons.casino),
                    label: const Text('Roll Death Save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _resetDeathSaves,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
