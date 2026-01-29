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
    var lower = value.toLowerCase().trim();

    // --- PRIORITY CHECKS (Complex patterns & Exact matches) ---
    
    // Handle "Concentration, up to X" pattern
    if (lower.contains('concentration')) {
       var rest = value.replaceAll(RegExp(r'Concentration,\s*', caseSensitive: false), '');
       if (rest.toLowerCase().contains('up to')) {
         rest = rest.replaceAll(RegExp(r'up to', caseSensitive: false), 'вплоть до');
       }
       rest = getLocalizedValue(l10n, rest);
       return '${l10n.concentration}, $rest';
    }
    
    if (lower.contains('up to')) {
      value = value.replaceAll(RegExp(r'up to', caseSensitive: false), 'вплоть до');
      return getLocalizedValue(l10n, value);
    }

    // Duration special cases
    if (lower == 'instantaneous') return 'Мгновенная'; // Should ideally be in l10n
    if (lower == 'until dispelled') return 'Пока не рассеется';
    if (lower == 'special') return 'Особое';

    // Casting Time special cases
    if (lower.contains('1 action') || lower == '1 action') return '1 ${l10n.actionTypeAction.toLowerCase()}';
    if (lower.contains('1 bonus action')) return '1 ${l10n.actionTypeBonus.toLowerCase()}';
    if (lower.contains('1 reaction')) return '1 ${l10n.actionTypeReaction.toLowerCase()}';

    // Range special cases
    if (lower == 'self') return 'На себя';
    if (lower == 'touch') return 'Касание';

    // --- UNIT REPLACEMENTS (Substrings) ---

    // Time units
    if (lower.contains('minutes')) return value.replaceAll('minutes', 'мин.');
    if (lower.contains('minute')) return value.replaceAll('minute', 'мин.');
    if (lower.contains('hours')) return value.replaceAll('hours', 'ч.');
    if (lower.contains('hour')) return value.replaceAll('hour', 'ч.');
    if (lower.contains('round')) return value.replaceAll('round', 'раунд');

    // Distance units
    if (lower.contains('feet')) return value.replaceAll('feet', 'фт.');
    if (lower.contains('foot')) return value.replaceAll('foot', 'фт.');
    if (lower.contains('radius')) return value.replaceAll('radius', 'радиус').replaceAll('feet', 'фт.');

    return value;
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
    final lower = className.toLowerCase();
    switch (lower) {
      case 'barbarian': return 'Варвар';
      case 'bard': return 'Бард';
      case 'cleric': return 'Жрец';
      case 'druid': return 'Друид';
      case 'fighter': return 'Воин';
      case 'monk': return 'Монах';
      case 'paladin': return 'Паладин';
      case 'ranger': return 'Следопыт';
      case 'rogue': return 'Плут';
      case 'sorcerer': return 'Чародей';
      case 'warlock': return 'Колдун';
      case 'wizard': return 'Волшебник';
      case 'artificer': return 'Изобретатель';
      default: return className;
    }
  }
}