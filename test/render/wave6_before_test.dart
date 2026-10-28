// "Before" shots of the wave 6 screens (level-up wizard, advancement
// history, character creation) for docs/prototypes/wave6/before.
// Opt-in: QDND_RENDER_DIR=/some/dir, one scene with QDND_RENDER_ONLY=<name>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/character_creation/character_creation_wizard.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/advancement_history_sheet.dart';

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
    dir = await Directory.systemTemp.createTemp('qdnd-w6-before-');
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

  Character hero(String cls, int level) =>
      buildExpressiveCycleCharacters(levels: {cls: level}, idPrefix: 'w6-')
          .firstWhere((c) => c.characterClass == cls);

  final key = GlobalKey();
  Future<void> pump(WidgetTester tester, Widget page,
      {double height = 1200}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(390 * 2, height * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider().darkTheme,
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: page,
        )));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  /// Walks a wizard: takes the average, then «Продолжить», shooting each step.
  Future<void> walk(WidgetTester tester, String prefix,
      {List<String> picks = const []}) async {
    for (var i = 0; i < 8; i++) {
      await capture(tester, '$prefix-$i');
      // Makes the choices a step needs, where its options are on screen.
      for (final pick in picks) {
        final f = find.text(pick);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await settle(tester);
        }
      }
      final average = find.text('Среднее');
      if (average.evaluate().isNotEmpty) {
        await tester.tap(average.first, warnIfMissed: false);
        await settle(tester);
      }
      var next = find.text('Продолжить');
      if (next.evaluate().isEmpty) next = find.text('Далее');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next.last, warnIfMissed: false);
      await settle(tester);
      if (i > 0 &&
          find.text('Продолжить').evaluate().isEmpty &&
          find.text('Далее').evaluate().isEmpty) {
        await capture(tester, '$prefix-${i + 1}');
        break;
      }
    }
  }

  testWidgets('levelup-fighter', (tester) async {
    if (_skip('levelup-fighter')) return;
    await pump(tester, LevelUpScreen(character: hero('fighter', 3)));
    await walk(tester, '01-levelup-fighter', picks: ['Сила', 'Выбрать', 'Ловкость']);
    await finish(tester);
  });

  testWidgets('levelup-wizard', (tester) async {
    if (_skip('levelup-wizard')) return;
    await pump(tester, LevelUpScreen(character: hero('wizard', 4)));
    await walk(tester, '02-levelup-wizard');
    await finish(tester);
  });

  testWidgets('levelup-paladin', (tester) async {
    if (_skip('levelup-paladin')) return;
    await pump(tester, LevelUpScreen(character: hero('paladin', 2)));
    await walk(tester, '03-levelup-paladin',
        picks: ['Клятва Преданности']);
    await finish(tester);
  });

  testWidgets('history', (tester) async {
    if (_skip('history')) return;
    final h = hero('paladin', 6);
    await pump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: TextButton(
                        onPressed: () => showAdvancementHistory(context, h),
                        child: const Text('open'))))),
        height: 844);
    await tester.tap(find.text('open'));
    await settle(tester);
    await capture(tester, '04-history');
    await finish(tester);
  });

  testWidgets('create', (tester) async {
    if (_skip('create')) return;
    await pump(tester, const CharacterCreationWizard(), height: 1400);
    await capture(tester, '05-create-0');
    await tester.enterText(find.byType(EditableText).first, 'Лира');
    await settle(tester);
    for (var i = 1; i < 8; i++) {
      // The forward button sits in the bottom right corner.
      await tester.tapAt(const Offset(372, 1340));
      await settle(tester);
      // The second step needs a race and a class.
      for (final pick in ['Человек', 'Воин']) {
        final f = find.text(pick);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await settle(tester);
        }
      }
      await capture(tester, '05-create-$i');
    }
    await finish(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
