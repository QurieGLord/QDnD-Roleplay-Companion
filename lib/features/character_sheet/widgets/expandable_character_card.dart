import 'package:flutter/material.dart';
import '../../../core/models/character.dart';

class ExpandableCharacterCard extends StatelessWidget {
  final Character character;
  final bool isExpanded;
  final VoidCallback onDicePressed;

  const ExpandableCharacterCard({
    super.key,
    required this.character,
    required this.isExpanded,
    required this.onDicePressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Hero(
                  tag: 'character-avatar-${character.id}',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getClassIcon(character.characterClass),
                      size: 40,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        character.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${character.race} • Level ${character.level}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        character.characterClass,
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (character.subclass != null)
                        Text(
                          character.subclass!,
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dice button (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              onPressed: onDicePressed,
              icon: Icon(
                Icons.casino,
                color: colorScheme.onPrimaryContainer,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getClassIcon(String className) {
    final lowerClass = className.toLowerCase();
    if (lowerClass.contains('paladin')) return Icons.shield_outlined;
    if (lowerClass.contains('wizard')) return Icons.auto_fix_high;
    if (lowerClass.contains('fighter')) return Icons.sports_martial_arts;
    if (lowerClass.contains('rogue')) return Icons.visibility_off;
    if (lowerClass.contains('cleric')) return Icons.health_and_safety;
    if (lowerClass.contains('barbarian')) return Icons.fitness_center;
    if (lowerClass.contains('bard')) return Icons.music_note;
    if (lowerClass.contains('druid')) return Icons.nature;
    if (lowerClass.contains('monk')) return Icons.self_improvement;
    if (lowerClass.contains('ranger')) return Icons.terrain;
    if (lowerClass.contains('sorcerer')) return Icons.bolt;
    if (lowerClass.contains('warlock')) return Icons.dark_mode;
    return Icons.person;
  }
}
