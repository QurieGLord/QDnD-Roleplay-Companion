import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../services/character_data_service.dart';

class SpellUtils {
  static Color getSchoolColor(String school, ColorScheme colorScheme) {
    final lower = school.toLowerCase();
    if (lower.contains('abj')) return Colors.blue;
    if (lower.contains('con')) return Colors.purple;
    if (lower.contains('div')) return Colors.cyan;
    if (lower.contains('enc')) return Colors.pink;
    if (lower.contains('evo')) return Colors.red;
    if (lower.contains('ill')) return Colors.indigo;
    if (lower.contains('nec')) return Colors.grey;
    if (lower.contains('tra')) return Colors.green;
    return colorScheme.primary;
  }

  static String getLocalizedSchool(AppLocalizations l10n, String school) {
    final lower = school.toLowerCase();
    if (lower.contains('abjur')) return l10n.schoolAbjuration;
    if (lower.contains('conjur')) return l10n.schoolConjuration;
    if (lower.contains('divin')) return l10n.schoolDivination;
    if (lower.contains('enchant')) return l10n.schoolEnchantment;
    if (lower.contains('evoc')) return l10n.schoolEvocation;
    if (lower.contains('illus')) return l10n.schoolIllusion;
    if (lower.contains('necro')) return l10n.schoolNecromancy;
    if (lower.contains('trans')) return l10n.schoolTransmutation;
    return school;
  }

  static String getLocalizedValue(AppLocalizations l10n, String value) {
    if (!l10n.localeName.startsWith('ru')) return value;
    var result = value;
    // Preserve the full wording (reaction triggers, areas, limits), not just
    // the first recognised phrase. Imported text is never truncated.
    const replacements = {
      'concentration': 'Концентрация',
      'up to': 'вплоть до',
      'instantaneous': 'Мгновенная',
      'until dispelled': 'Пока не рассеется',
      'special': 'Особое',
      'bonus action': 'бонусное действие',
      'action': 'действие',
      'reaction': 'реакция',
      'self': 'На себя',
      'touch': 'Касание',
      'minutes': 'мин.',
      'minute': 'мин.',
      'hours': 'ч.',
      'hour': 'ч.',
      'rounds': 'раундов',
      'round': 'раунд',
      'feet': 'фт.',
      'foot': 'фт.',
      'radius': 'радиус',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }
    return result;
  }

  static String getLocalizedClassName(BuildContext context, String className) {
    // 1. Try dynamic lookup
    try {
      final classData = CharacterDataService.getClassById(className);
      if (classData != null) {
        final locale = Localizations.localeOf(context).languageCode;
        return classData.getName(locale);
      }
    } catch (e) {
      // Ignore
    }

    // 2. Fallback to hardcoded map
    if (Localizations.localeOf(context).languageCode != 'ru') return className;
    final lower = className.toLowerCase();
    switch (lower) {
      case 'barbarian':
        return 'Варвар';
      case 'bard':
        return 'Бард';
      case 'cleric':
        return 'Жрец';
      case 'druid':
        return 'Друид';
      case 'fighter':
        return 'Воин';
      case 'monk':
        return 'Монах';
      case 'paladin':
        return 'Паладин';
      case 'ranger':
        return 'Следопыт';
      case 'rogue':
        return 'Плут';
      case 'sorcerer':
        return 'Чародей';
      case 'warlock':
        return 'Колдун';
      case 'wizard':
        return 'Волшебник';
      case 'artificer':
        return 'Изобретатель';
      default:
        return className;
    }
  }
}
