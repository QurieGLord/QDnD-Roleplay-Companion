// Shots of the ported wave 5 screens, checked side by side with the accepted
// prototype (docs/prototypes/wave5/index.html).
// Opt-in: QDND_RENDER_DIR=/some/dir, one scene with QDND_RENDER_ONLY=<name>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/models/compendium_source.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/features/character_edit/character_edit_screen.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/core/services/fc5_compendium_zip_service.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/features/character_list/hero_transfer.dart';
import 'package:qd_and_d/features/settings/library_import.dart';
import 'package:qd_and_d/features/settings/library_manager_screen.dart';
import 'package:qd_and_d/features/settings/settings_screen.dart';
import 'package:qd_and_d/features/splash/splash_screen.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

final _out = Platform.environment['QDND_RENDER_DIR'];
final _only = Platform.environment['QDND_RENDER_ONLY'];
bool _skip(String name) => _out == null || (_only != null && _only != name);

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(rootBundle.load('assets/fonts/$f'));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    if (_out == null) return;
    dir = await Directory.systemTemp.createTemp('qdnd-w5-render-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    await _font('Rubik',
        ['Rubik-Regular.ttf', 'Rubik-Medium.ttf', 'Rubik-SemiBold.ttf']);
    try {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    } catch (_) {}
    await _font('Inter', [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf'
    ]);
  });
  tearDownAll(() async {
    if (_out == null) return;
    await Hive.close();
  });

  Future<void> shoot(WidgetTester tester, String name, Widget page,
      {double height = 844,
      bool basic = false,
      bool light = false,
      int frames = 30,
      Future<void> Function(WidgetTester)? act}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(390 * 2, height * 2);
    final key = GlobalKey();
    final theme = ThemeProvider();
    await tester.pump();
    if (basic) await tester.runAsync(() => theme.setBasicMode(true));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, t, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: t.lightTheme,
            darkTheme: t.darkTheme,
            themeMode: light ? ThemeMode.light : ThemeMode.dark,
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child),
            home: page,
          ),
        )));
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (act != null) {
      await act(tester);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() => theme.setBasicMode(false));
    addTearDown(tester.view.reset);
  }

  testWidgets('settings', (tester) async {
    if (_skip('settings')) return;
    await shoot(tester, '01-settings', const SettingsScreen(), height: 1900);
  });

  testWidgets('settings-basic', (tester) async {
    if (_skip('settings-basic')) return;
    await shoot(tester, '02-settings-basic', const SettingsScreen(),
        height: 1100, basic: true);
  });

  testWidgets('settings-light', (tester) async {
    if (_skip('settings-light')) return;
    await shoot(tester, '03-settings-light', const SettingsScreen(),
        height: 1100, light: true);
  });

  testWidgets('splash', (tester) async {
    if (_skip('splash')) return;
    // Mid-roll and after the die turned into the mark.
    await shoot(
        tester, '04-splash-roll', SplashScreen(next: (_) => const SizedBox()),
        frames: 10);
  });

  testWidgets('splash-landed', (tester) async {
    if (_skip('splash-landed')) return;
    await shoot(
        tester, '05-splash-landed', SplashScreen(next: (_) => const SizedBox()),
        frames: 40);
  });
  // Sample shelf: one XML and one ZIP of three modules (no personal data).
  Future<void> seedShelf(WidgetTester tester) => tester.runAsync(() async {
        final day = DateTime(2026, 10, 12);
        await StorageService.saveSource(CompendiumSource(
            id: 'w5-xml',
            name: 'Хроники ветра.xml',
            importedAt: day,
            spellCount: 23,
            itemCount: 14,
            featCount: 3));
        for (final (i, m, n) in [
          (0, 'Заклинания', [0, 361, 0, 0, 0, 0]),
          (1, 'Снаряжение', [512, 0, 0, 0, 0, 0]),
          (2, 'Персонажи', [0, 0, 41, 13, 26, 74]),
        ]) {
          await StorageService.saveSource(CompendiumSource(
              id: 'w5-zip-$i',
              name: '$m.xml',
              importedAt: day.add(const Duration(days: 2)),
              itemCount: n[0],
              spellCount: n[1],
              raceCount: n[2],
              classCount: n[3],
              backgroundCount: n[4],
              featCount: n[5],
              archiveId: 'w5-archive',
              archiveName: 'Сборник стола',
              moduleName: m,
              modulePath: 'compendium/$m.xml',
              sourceKind: 'zip_module'));
        }
      });

  testWidgets('library', (tester) async {
    if (_skip('library')) return;
    await seedShelf(tester);
    await shoot(tester, '06-library', const LibraryManagerScreen(),
        height: 1300, act: (tester) async {
      await tester.tap(find.bySemanticsLabel('Сборник стола'));
    });
  });

  testWidgets('library-empty', (tester) async {
    if (_skip('library-empty')) return;
    await tester.runAsync(() => StorageService.deleteSources(
        ['w5-xml', 'w5-zip-0', 'w5-zip-1', 'w5-zip-2']));
    await shoot(tester, '07-library-empty', const LibraryManagerScreen());
  });
  late final paladin = buildExpressiveCycleCharacters(
          levels: veteranCycleLevels, idPrefix: veteranCycleIdPrefix)
      .firstWhere((c) => c.characterClass == 'paladin');

  // A page with one button that opens a sheet; the shot is taken with the
  // sheet up.
  Widget opener(void Function(BuildContext) open) => Scaffold(
        body: Builder(
            builder: (context) => Center(
                child: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open')))),
      );
  Future<void> tapOpen(WidgetTester tester) => tester.tap(find.text('open'));

  testWidgets('editor', (tester) async {
    if (_skip('editor')) return;
    await shoot(tester, '08-editor', CharacterEditScreen(character: paladin),
        height: 2200);
  });

  testWidgets('transfer', (tester) async {
    if (_skip('transfer')) return;
    await shoot(tester, '09-transfer',
        opener((context) => showHeroTransfer(context, paladin)),
        height: 1000, act: tapOpen);
  });

  testWidgets('zip', (tester) async {
    if (_skip('zip')) return;
    FC5CompendiumZipEntryPreview e(String name, List<int> n,
            {int monsters = 0, bool combined = false}) =>
        FC5CompendiumZipEntryPreview(
            rawPath: 'pack/$name.xml',
            displayPath: 'pack/$name.xml',
            displayName: name,
            sizeBytes: 1000,
            items: n[0],
            spells: n[1],
            races: n[2],
            classes: n[3],
            backgrounds: n[4],
            feats: n[5],
            monsters: monsters,
            warningCount: 0,
            errorCount: 0,
            isCombinedCandidate: combined);
    final preview = FC5CompendiumZipPreview(
        archiveName: 'Сборник стола',
        ignoredFileCount: 2,
        totalUncompressedBytes: 4300000,
        entries: [
          e('Compendium', [512, 361, 41, 13, 26, 74],
              monsters: 120, combined: true),
          e('Заклинания', [0, 361, 0, 0, 0, 0]),
          e('Снаряжение', [512, 0, 0, 0, 0, 0]),
          e('Бестиарий', [0, 0, 0, 0, 0, 0], monsters: 120),
        ]);
    await shoot(
        tester,
        '10-zip',
        opener((context) => showCompanionSheet<void>(context,
            builder: (_) =>
                ZipChoiceSheet(preview: preview, fileBytes: 4300000))),
        height: 1700,
        act: tapOpen);
  });

  testWidgets('splash-strip', (tester) async {
    if (_skip('splash-strip')) return;
    // The throw frame by frame: in flight, first bounce, the 20, the morph.
    for (final f in [4, 9, 12, 18, 22, 26, 29, 34]) {
      await shoot(tester, '11-splash-$f',
          SplashScreen(next: (_) => const SizedBox()),
          frames: f, height: 700);
    }
  });

  testWidgets('library-srd', (tester) async {
    if (_skip('library-srd')) return;
    await seedShelf(tester);
    await shoot(tester, '12-library-srd', const LibraryManagerScreen(),
        height: 1400, act: (tester) async {
      await tester.tap(find.bySemanticsLabel('SRD 2014').first);
    });
  });

  testWidgets('pick-hero', (tester) async {
    if (_skip('pick-hero')) return;
    await tester.runAsync(() => StorageService.saveCharacter(paladin));
    await shoot(tester, '13-pick-hero',
        opener((context) => showHeroTransferPicker(context)),
        height: 900, act: tapOpen);
    await tester.runAsync(() => StorageService.deleteCharacter(paladin.id));
  });
}
