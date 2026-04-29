import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/settings/library_manager_screen.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_navigation_');

  testWidgets('SettingsScreen opens library manager from content section',
      (tester) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
    );

    final librariesFinder =
        find.byKey(const Key('settings_manage_libraries_tile'));
    await tester.ensureVisible(librariesFinder);
    await pumpInteraction(tester);
    await tester.tap(
      find.descendant(
        of: librariesFinder,
        matching: find.text('Manage Libraries'),
      ),
    );
    await pumpInteraction(tester, const Duration(milliseconds: 450));

    expect(find.byType(LibraryManagerScreen), findsOneWidget);
  });
}
