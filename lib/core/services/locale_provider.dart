import 'package:flutter/material.dart';
import 'storage_service.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _kLocaleKey = 'locale_code';
  Locale _locale;

  LocaleProvider() : _locale = const Locale('en') {
    _loadLocale();
  }

  Locale get locale => _locale;

  void _loadLocale() {
    final String? savedCode = StorageService.getSetting(_kLocaleKey);
    if (savedCode != null) {
      _locale = Locale(savedCode);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'ru'].contains(locale.languageCode)) return;
    
    _locale = locale;
    await StorageService.saveSetting(_kLocaleKey, locale.languageCode);
    notifyListeners();
  }
}
