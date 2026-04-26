import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_render_');

  testWidgets('SettingsScreen renders redesigned control surfaces', (
    tester,
  ) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings_language_segmented')), findsOneWidget);
    expect(find.byKey(const Key('settings_theme_segmented')), findsOneWidget);
    expect(
      find.byKey(const Key('settings_high_contrast_toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_palette_qMonokai')), findsOneWidget);
    expect(find.byKey(const Key('settings_manage_libraries_tile')), findsOneWidget);
  });

  testWidgets('SettingsScreen keeps core sections on narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 824);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
      disableAnimations: true,
    );

    await tester.drag(
      find.byKey(const Key('settings_scroll_view')),
      const Offset(0, -1800),
    );
    await pumpInteraction(tester);

    expect(
      tester.getRect(find.byKey(const Key('settings_manage_libraries_tile'))).top,
      lessThan(824),
    );
    expect(find.byKey(const Key('settings_theme_segmented')), findsOneWidget);
    expect(find.byKey(const Key('settings_palette_qMonokai')), findsOneWidget);
    expect(find.byKey(const Key('settings_manage_libraries_tile')), findsOneWidget);
  });
}
