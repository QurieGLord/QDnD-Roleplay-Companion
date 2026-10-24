// Renders the Magic tab of every Cycle hero to PNG for a side-by-side check
// against docs/prototypes/wave2. Opt-in: QDND_RENDER_DIR=/some/dir.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/features/expressive_cycle/custom_class_fixture.dart';
import 'package:qd_and_d/features/character_list/character_list_screen.dart';
import 'package:qd_and_d/features/character_sheet/widgets/overview_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/instrument/instrument_kit.dart' show Peek, TumbleDie, DieShape;
import 'package:qd_and_d/l10n/app_localizations.dart';

final _out = Platform.environment['QDND_RENDER_DIR'];

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
    dir = await Directory.systemTemp.createTemp('qdnd-render-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    stdout.writeln('R init');
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    stdout.writeln('R data');
    await _font('Rubik', ['Rubik-Regular.ttf', 'Rubik-Medium.ttf', 'Rubik-SemiBold.ttf']);
    try {
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    } catch (_) {}
    await _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf']);
  });
  tearDownAll(() async {
    if (_out == null) return;
    await Hive.close();
  });


  // QDND_RENDER_SCROLL=<cards>: scroll the deck by that many cards first.
  testWidgets('render the lobby', (tester) async {
    if (_out == null) return;
    final roster = [...buildExpressiveCycleCharacters(), buildCustomClassCycleCharacter()];
    await tester.runAsync(() async {
      for (final hero in roster) {
        await Hive.box<Character>('characters').put(hero.id, hero);
      }
    });
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
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
      home: const CharacterListScreen(),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final cards = double.tryParse(Platform.environment['QDND_RENDER_SCROLL'] ?? '');
    if (cards != null) {
      final scrollable = find.descendant(
          of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.pixels + cards * 84);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/lobby${cards == null ? '' : '-$cards'}.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    addTearDown(tester.view.reset);
  });

  // QDND_RENDER_OVERVIEW=<class>: the Overview page of that Cycle hero.
  final overview = Platform.environment['QDND_RENDER_OVERVIEW'];
  testWidgets('render the overview', (tester) async {
    if (_out == null || overview == null) return;
    final hero = buildExpressiveCycleCharacters()
        .firstWhere((h) => h.characterClass.contains(overview));
    await tester.runAsync(() => Hive.box<Character>('characters').put(hero.id, hero));
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 1700 * 2);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
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
      home: Scaffold(body: OverviewTab(character: hero, onCharacterUpdated: () {})),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/overview-$overview.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    addTearDown(tester.view.reset);
  });

  testWidgets('render a peek bubble', (tester) async {
    if (_out == null || Platform.environment['QDND_RENDER_PEEK'] == null) return;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 500 * 2);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
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
      home: Scaffold(
        body: Align(
          alignment: const Alignment(0, .6),
          child: Peek(
            title: 'Безрассудная атака',
            text: 'Первая атака в ход — с преимуществом. До вашего хода атаки по вам тоже с преимуществом',
            child: Container(width: 160, height: 60, color: Colors.white10),
          ),
        ),
      ),
    ));
    await tester.longPress(find.byType(Peek));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/peek.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pump(const Duration(seconds: 5));
    addTearDown(tester.view.reset);
  });

  testWidgets('render dice', (tester) async {
    if (_out == null || Platform.environment['QDND_RENDER_DICE'] == null) return;
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 220 * 3);
    final key = GlobalKey();
    var roll = 0;
    late StateSetter redraw;
    Widget row(double size) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final (shape, sides) in [
            (DieShape.d4, 4), (DieShape.d6, 6), (DieShape.d8, 8), (DieShape.d10, 10), (DieShape.d12, 12), (DieShape.d20, 20)
          ])
            TumbleDie(
                shape: shape,
                label: roll == 0 ? 'к$sides' : '$sides',
                accent: const Color(0xFFFF6188),
                rollKey: roll,
                sides: sides,
                natural: roll == 0 ? null : sides,
                size: size),
        ]);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider().darkTheme,
      builder: (context, child) => RepaintBoundary(key: key, child: child),
      home: Scaffold(
        body: StatefulBuilder(builder: (context, set) {
          redraw = set;
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [row(42), const SizedBox(height: 30), row(58)]);
        }),
      ),
    ));
    Future<void> shot(String name) => tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$_out/dice-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        });
    await tester.pump();
    await shot('rest');
    redraw(() => roll = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await shot('air');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot('max');
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot('settled');
    await tester.pump(const Duration(seconds: 3));
    addTearDown(tester.view.reset);
  });
}
