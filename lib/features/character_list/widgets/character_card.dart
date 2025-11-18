import 'package:flutter/material.dart';
import '../../../core/models/character.dart';

class CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with class icon
              Hero(
                tag: 'character-avatar-${character.id}',
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getClassIcon(character.characterClass),
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Character Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${character.level} ${character.characterClass}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                    if (character.subclass != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        character.subclass!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.favorite,
                          label: '${character.currentHp}/${character.maxHp}',
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.shield,
                          label: 'AC ${character.armorClass}',
                          color: colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
