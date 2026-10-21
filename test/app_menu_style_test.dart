import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/ui/app_menu_style.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-menu-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets(
      'Quest status dropdown opens with shared rounding and supports selection',
      (tester) async {
    final c = fixtures.hero()
      ..quests.add(Quest(id: 'q', title: 'Find the keeper'));
    await tester.runAsync(() => StorageService.saveCharacter(c));
    final provider = ThemeProvider();
    await tester.pumpWidget(MaterialApp(
        theme: provider.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: JournalEntryPage(character: c, entryKey: 'q:q')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<QuestStatus>), 140,
        scrollable: find.byType(Scrollable).first);
    final button = tester.widget<DropdownButton<QuestStatus>>(
        find.byType(DropdownButton<QuestStatus>));
    expect(button.borderRadius, AppMenuStyle.radius);
    expect(button.elevation, 4);
    expect(button.dropdownColor,
        provider.lightTheme.colorScheme.surfaceContainerHigh);
    await tester.runAsync(() async {
      await tester.tap(find.byType(DropdownButtonFormField<QuestStatus>));
    });
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Completed'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(c.quests.single.status, QuestStatus.completed);
    expect(tester.takeException(), isNull);
    provider.dispose();
  });
  test(
      'Material menus share the same shape and palette in light and dark themes',
      () {
    final provider = ThemeProvider();
    for (final theme in [provider.lightTheme, provider.darkTheme]) {
      expect(theme.popupMenuTheme.shape, AppMenuStyle.shape);
      expect(theme.dropdownMenuTheme.menuStyle!.shape!.resolve({}),
          AppMenuStyle.shape);
      expect(
          theme.popupMenuTheme.color, theme.colorScheme.surfaceContainerHigh);
    }
    provider.dispose();
  });
}
