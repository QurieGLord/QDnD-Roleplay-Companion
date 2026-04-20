import 'package:flutter/material.dart';

import '../../../core/services/character_data_service.dart';

String getLocalizedRaceName(BuildContext context, String raceName) {
  try {
    final locale = Localizations.localeOf(context).languageCode;
    final raceData = CharacterDataService.getRaceById(raceName);
    return raceData?.getName(locale) ?? raceName;
  } catch (_) {
    return raceName;
  }
}

String getLocalizedClassName(BuildContext context, String className) {
  try {
    final locale = Localizations.localeOf(context).languageCode;
    final classData = CharacterDataService.getClassById(className);
    return classData?.getName(locale) ?? className;
  } catch (_) {
    return className;
  }
}

String getLocalizedSubclassName(
  BuildContext context,
  String className,
  String subclassName,
) {
  try {
    final locale = Localizations.localeOf(context).languageCode;
    final classData = CharacterDataService.getClassById(className);
    if (classData != null) {
      final subclass = classData.subclasses.firstWhere(
        (entry) =>
            entry.id == subclassName ||
            entry.name.values.contains(subclassName),
        orElse: () => throw StateError('Subclass not found'),
      );
      return subclass.getName(locale);
    }
    return subclassName;
  } catch (_) {
    return subclassName;
  }
}

IconData getClassIcon(String className) {
  final lowerClass = className.toLowerCase();
  if (lowerClass.contains('paladin')) return Icons.shield_rounded;
  if (lowerClass.contains('wizard')) return Icons.auto_fix_high_rounded;
  if (lowerClass.contains('fighter')) return Icons.sports_martial_arts_rounded;
  if (lowerClass.contains('rogue')) return Icons.visibility_off_rounded;
  if (lowerClass.contains('cleric')) return Icons.health_and_safety_rounded;
  if (lowerClass.contains('barbarian')) return Icons.fitness_center_rounded;
  if (lowerClass.contains('bard')) return Icons.music_note_rounded;
  if (lowerClass.contains('druid')) return Icons.forest_rounded;
  if (lowerClass.contains('monk')) return Icons.self_improvement_rounded;
  if (lowerClass.contains('ranger')) return Icons.terrain_rounded;
  if (lowerClass.contains('sorcerer')) return Icons.bolt_rounded;
  if (lowerClass.contains('warlock')) return Icons.dark_mode_rounded;
  return Icons.person_rounded;
}

Color resolveClassAccent(ColorScheme colorScheme, String className) {
  final lowerClass = className.toLowerCase();

  if (lowerClass.contains('wizard') ||
      lowerClass.contains('sorcerer') ||
      lowerClass.contains('warlock')) {
    return colorScheme.primary;
  }

  if (lowerClass.contains('cleric') ||
      lowerClass.contains('paladin') ||
      lowerClass.contains('bard')) {
    return colorScheme.secondary;
  }

  if (lowerClass.contains('rogue') ||
      lowerClass.contains('ranger') ||
      lowerClass.contains('druid') ||
      lowerClass.contains('monk')) {
    return colorScheme.tertiary;
  }

  if (lowerClass.contains('fighter') || lowerClass.contains('barbarian')) {
    return Color.lerp(colorScheme.secondary, colorScheme.primary, 0.35) ??
        colorScheme.primary;
  }

  return colorScheme.primary;
}
