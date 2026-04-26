import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_locale_');

  testWidgets('SettingsScreen changes locale to ru', (tester) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
    );

    await tester.tap(find.text('Русский'));
    await pumpInteraction(tester);
    await waitForSetting(tester, 'locale_code', 'ru');

    expect(localeProvider.locale.languageCode, 'ru');
  });
}
