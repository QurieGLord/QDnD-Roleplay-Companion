import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/services/character_data_service.dart';

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

  String _getLocalizedClassName(BuildContext context, String className) {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final classData = CharacterDataService.getClassById(className);
      return classData?.getName(locale) ?? className;
    } catch (e) {
      return className;
    }
  }

  String _getLocalizedSubclassName(BuildContext context, String className, String subclassName) {
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final classData = CharacterDataService.getClassById(className);
      if (classData != null) {
        final subclass = classData.subclasses.firstWhere(
          (s) => s.id == subclassName || s.name.values.contains(subclassName),
          orElse: () => throw Exception('Subclass not found'),
        );
        return subclass.getName(locale);
      }
      return subclassName;
    } catch (e) {
      return subclassName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Localize dynamic fields
    final localizedClassName = _getLocalizedClassName(context, character.characterClass);
    final localizedSubclass = character.subclass != null 
        ? _getLocalizedSubclassName(context, character.characterClass, character.subclass!)
        : null;

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
              // Avatar with class icon or custom image
              Hero(
                tag: 'character-avatar-${character.id}',
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: character.avatarPath == null
                        ? LinearGradient(
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.secondaryContainer,
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: character.avatarPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(character.avatarPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to icon if image fails to load
                              return Icon(
                                _getClassIcon(character.characterClass),
                                size: 32,
                                color: colorScheme.onPrimaryContainer,
                              );
                            },
                          ),
                        )
                      : Icon(
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
                      '${l10n.levelShort} ${character.level} $localizedClassName',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                    if (localizedSubclass != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        localizedSubclass,
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
                          label: '${l10n.armorClassAC} ${character.armorClass}',
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
