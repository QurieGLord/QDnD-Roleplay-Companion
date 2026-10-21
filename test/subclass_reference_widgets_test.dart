import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/progression/character_class_context.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/import_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/subclass_details_sheet.dart';
import 'subclass_reference_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-reference-widgets-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await ItemService.loadItems();
    await SpellService.loadSpells();
    await CharacterDataService.loadAllData();
    await ImportService.importCompendiumXmlContentDetailed(
        fixture.book('Paladin', 'Oath of Ash', 'First description.',
            translatedName: 'Клятва пепла',
            translatedText: 'Описание первой книги.'),
        sourceName: 'Книга А');
    await ImportService.importCompendiumXmlContentDetailed(
        fixture.book('Paladin', 'Oath of Ash', 'Second description.',
            translatedName: 'Клятва пепла',
            translatedText: 'Описание второй книги.'),
        sourceName: 'Книга Б');
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        'Conflicting references have a usable source choice at large text in $locale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hero = fixture.hero('paladin', 'Oath of Ash');
      final theme = ThemeProvider();
      await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          theme: theme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.7)),
              child: child!),
          home: Scaffold(
              body:
                  SubclassDetailsSheet(character: hero, classId: 'paladin'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          CharacterClassContext(hero, 'paladin').subclassReference!.ambiguous,
          isTrue);
      await tester.ensureVisible(find.text('Книга А'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Книга А'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(
          CharacterClassContext(hero, 'paladin').subclassReference!.ambiguous,
          isFalse);
      expect(CharacterClassContext(hero, 'paladin').subclassName('ru'),
          'Клятва пепла');
      expect(
          find.text(
              locale == 'ru' ? 'Описание первой книги.' : 'First description.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
