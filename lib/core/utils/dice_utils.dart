import 'package:flutter/material.dart';

class DiceUtils {
  /// Localizes dice notation (e.g., "1d6" -> "1к6" for Russian).
  static String formatDice(String diceString, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'ru') {
      return diceString.replaceAll('d', 'к').replaceAll('D', 'К');
    }
    return diceString;
  }
}
