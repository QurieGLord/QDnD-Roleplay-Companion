// Records the README motion clips frame by frame (1/30 s) straight from the
// Flutter engine, with the app's fonts and the Cycle veterans. Opt-in:
// QDND_MEDIA_DIR=/some/dir QDND_MEDIA=lobby,rage,… flutter test test/render/readme_media_test.dart
// Each clip lands in <dir>/<clip>/NNNN.png with crop.json: the logical rect
// of the block it shows (absent for full-screen clips).
import 'dart:convert';
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
import 'package:qd_and_d/features/character_list/character_list_screen.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/features/character_sheet/character_sheet_screen.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/features/expressive_cycle/custom_class_fixture.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/spell_cast_sheet.dart';

final _out = Platform.environment['QDND_MEDIA_DIR'];
final _clips = (Platform.environment['QDND_MEDIA'] ?? '').split(',').toSet();
const _frame = Duration(microseconds: 33333);

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(rootBundle.load('assets/fonts/$f'));
  }
  await loader.load();
}

Widget _app(GlobalKey key, Widget home) => MaterialApp(
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
      home: home,
    );

/// Captures one frame per call into <dir>/<clip>/.
class _Reel {
  _Reel(this.tester, this.key, this.clip) {
    Directory('$_out/$clip').createSync(recursive: true);
  }
  final WidgetTester tester;
  final GlobalKey key;
  final String clip;
  int _n = 0;

  Future<void> shot() => tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        // Twice the logical size: crisp on a README at full width.
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$_out/$clip/${(_n++).toString().padLeft(4, '0')}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });

  /// Advances time frame by frame, capturing each.
  Future<void> hold(int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(_frame);
      await shot();
    }
  }

  void crop(Rect r) => File('$_out/$clip/crop.json')
      .writeAsStringSync(jsonEncode({'l': r.left, 't': r.top, 'w': r.width, 'h': r.height}));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    if (_out == null) return;
    dir = await Directory.systemTemp.createTemp('qdnd-media-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
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

  List<Character> veterans() => buildExpressiveCycleCharacters(levels: veteranCycleLevels, idPrefix: veteranCycleIdPrefix);

  Future<GlobalKey> phone(WidgetTester tester, Widget home, {double height = 844}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(390 * 2, height * 2);
    final key = GlobalKey();
    await tester.pumpWidget(_app(key, home));
    for (var i = 0; i < 20; i++) {
      await tester.pump(_frame);
    }
    return key;
  }

  Future<Character> put(WidgetTester tester, Character hero) async {
    await tester.runAsync(() => Hive.box<Character>('characters').put(hero.id, hero));
    return hero;
  }

  testWidgets('lobby: the viscous deck and the party line', (tester) async {
    if (_out == null || !_clips.contains('lobby')) return;
    await tester.runAsync(() async {
      // The data-class hero sorts after the twelve veterans.
      for (final h in [...veterans(), buildCustomClassCycleCharacter()..id = '${veteranCycleIdPrefix}zz-rune-guard']) {
        await Hive.box<Character>('characters').put(h.id, h);
      }
    });
    final key = await phone(tester, const CharacterListScreen());
    final reel = _Reel(tester, key, 'lobby');
    await reel.hold(12);
    // A slow, deliberate drag through two cards, then a release.
    final deck = find.byType(SingleChildScrollView).first;
    final start = tester.getCenter(deck);
    final g = await tester.startGesture(start);
    var t = Duration.zero;
    for (var i = 0; i < 30; i++) {
      t += _frame;
      await g.moveBy(const Offset(0, -5.2), timeStamp: t);
      await tester.pump(_frame);
      await reel.shot();
    }
    await g.up(timeStamp: t + _frame);
    await reel.hold(34);
    // A tap on a sigil far down the party line.
    final party = find.byKey(const ValueKey('lobby-party-line'));
    await tester.tapAt(tester.getTopLeft(party) + const Offset(16 + 48 * 5 + 24, 29));
    await reel.hold(40);
    // And a quick throw back to the top: the deck lands softly.
    final back = await tester.startGesture(tester.getCenter(deck));
    var tb = Duration.zero;
    for (var i = 0; i < 8; i++) {
      tb += _frame;
      await back.moveBy(const Offset(0, 34), timeStamp: tb);
      await tester.pump(_frame);
      await reel.shot();
    }
    await back.up(timeStamp: tb + _frame);
    await reel.hold(46);
    addTearDown(tester.view.reset);
  });

  testWidgets('rage: hold to break out', (tester) async {
    if (_out == null || !_clips.contains('rage')) return;
    final hero = await put(tester, veterans().firstWhere((h) => h.characterClass == 'barbarian'));
    final key = await phone(tester, Scaffold(body: AbilitiesTab(character: hero)), height: 600);
    final reel = _Reel(tester, key, 'rage');
    await reel.hold(10);
    final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('barbarian-hold'))));
    await reel.hold(24);
    await g.up();
    await reel.hold(40);
    reel.crop(tester.getRect(find.byKey(const ValueKey('barbarian-rage'))));
    addTearDown(tester.view.reset);
  });

  testWidgets('bard: notes cross to the allies', (tester) async {
    if (_out == null || !_clips.contains('bard')) return;
    final hero = await put(tester, veterans().firstWhere((h) => h.characterClass == 'bard'));
    final key = await phone(tester, Scaffold(body: AbilitiesTab(character: hero)), height: 600);
    final reel = _Reel(tester, key, 'bard');
    await reel.hold(10);
    Finder note(int i) => find.byKey(ValueKey('note-$i'));
    for (final i in [0, 1]) {
      await tester.runAsync(() async {
        await tester.tap(note(i));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await reel.hold(26);
    }
    // An ally uses the first held note: it rolls in place.
    await tester.tap(note(0));
    await reel.hold(40);
    reel.crop(tester.getRect(find.byKey(const ValueKey('bard-inspiration'))));
    addTearDown(tester.view.reset);
  });

  testWidgets('wind: the d10 of Second Wind', (tester) async {
    if (_out == null || !_clips.contains('wind')) return;
    final hero = await put(tester, veterans().firstWhere((h) => h.characterClass == 'fighter')..currentHp = 40);
    final key = await phone(tester, Scaffold(body: AbilitiesTab(character: hero)), height: 600);
    final reel = _Reel(tester, key, 'wind');
    await reel.hold(10);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('fighter-action-second-wind')));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await reel.hold(50);
    reel.crop(tester.getRect(find.byKey(const ValueKey('fighter-second-wind'))));
    addTearDown(tester.view.reset);
  });

  testWidgets('volley: Eldritch Blast fires its beams', (tester) async {
    if (_out == null || !_clips.contains('volley')) return;
    final hero = await put(tester, veterans().firstWhere((h) => h.characterClass == 'warlock'));
    final key = await phone(tester, Scaffold(body: AbilitiesTab(character: hero)), height: 900);
    final reel = _Reel(tester, key, 'volley');
    await reel.hold(10);
    await tester.tap(find.byKey(const ValueKey('warlock-volley')));
    await reel.hold(46);
    reel.crop(tester.getRect(find.byKey(const ValueKey('warlock-eldritch-blast'))));
    addTearDown(tester.view.reset);
  });

  testWidgets('druid: the hero becomes the beast', (tester) async {
    if (_out == null || !_clips.contains('druid')) return;
    final hero = await put(tester, veterans().firstWhere((h) => h.characterClass == 'druid'));
    late StateSetter redraw;
    final key = await phone(
        tester,
        Scaffold(
            body: StatefulBuilder(builder: (context, set) {
          redraw = set;
          return AbilitiesTab(key: ValueKey(hero.isWildShaped), character: hero);
        })),
        height: 700);
    final reel = _Reel(tester, key, 'druid');
    reel.crop(Rect.fromLTWH(0, 0, 390, 420));
    await reel.hold(12);
    redraw(() {
      hero.isWildShaped = true;
      hero.beastName = 'Бурый медведь';
      hero.beastMaxHp = 34;
      hero.beastCurrentHp = 34;
    });
    await reel.hold(40);
    addTearDown(tester.view.reset);
  });

  testWidgets('cast: the effect follows the chosen slot', (tester) async {
    if (_out == null || !_clips.contains('cast')) return;
    final hero = await put(tester, veterans().firstWhere((h) => h.characterClass == 'cleric'));
    final spell = SpellService.getSpellById('cure-wounds')!;
    final key = await phone(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: TextButton(onPressed: () => showSpellCastSheet(context, hero, spell), child: const Text('open'))))));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 24; i++) {
      await tester.pump(_frame);
    }
    final reel = _Reel(tester, key, 'cast');
    await reel.hold(12);
    for (final circle in [3, 5, 2]) {
      await tester.tap(find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> && (w.key as ValueKey<String>).value == 'cast-rung-sharedSlot-$circle'));
      await reel.hold(24);
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('shots: stills for the banner', (tester) async {
    if (_out == null || !_clips.contains('shots')) return;
    Directory('$_out/shots').createSync(recursive: true);
    Future<void> still(GlobalKey key, String name) => tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$_out/shots/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        });
    final paladin = await put(tester, veterans().firstWhere((h) => h.characterClass == 'paladin'));
    var key = await phone(tester, ChangeNotifierProvider(create: (_) => ThemeProvider(), child: CharacterSheetScreen(character: paladin)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(_frame);
    }
    await still(key, 'sheet');
    final cleric = await put(tester, veterans().firstWhere((h) => h.characterClass == 'cleric'));
    key = await phone(tester, Scaffold(body: SafeArea(child: AbilitiesTab(character: cleric))));
    await still(key, 'magic');
    addTearDown(tester.view.reset);
  });
}
