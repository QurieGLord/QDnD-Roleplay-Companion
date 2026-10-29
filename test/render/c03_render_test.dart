// Renders the C03 «Сверка с библиотеками» page and its version sheet with the
// app's fonts, for review on a phone-sized canvas. Opt-in:
// QDND_RENDER_DIR=/some/dir flutter test test/render/c03_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/hero_reconciliation.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/character_list/hero_reconciliation_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../core/content/hero_reconciliation_test.dart' show variantOf;
import '../multiclass_magic_flow_test.dart' as flow;

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
    dir = await Directory.systemTemp.createTemp('qdnd-c03-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await _font('Rubik',
        ['Rubik-Regular.ttf', 'Rubik-Medium.ttf', 'Rubik-SemiBold.ttf']);
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

  testWidgets('C03 page and version sheet', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    addTearDown(tester.view.reset);
    // Built-in spells, and a second book that words some of them otherwise.
    final base = SpellService.getAllSpells()
        .where((s) => s.sourceId == null)
        .take(40)
        .toList();
    Spell other(Spell s) => Spell.fromJson({
          ...s.toJson(),
          'id': '${s.id}-book',
          'sourceId': 'book',
          'descriptionRu': 'Другой перевод: ${s.descriptionRu}',
          'descriptionEn': 'Another wording: ${s.descriptionEn}',
        });
    final picked = [base[3], base[11], base[19]];
    final sorcerer = CharacterDataService.getClassById('sorcerer')!;
    final classes = ContentCatalog<ClassData>([
      sorcerer,
      variantOf(sorcerer, 'sorcerer-a', 'book-a', 6),
      variantOf(sorcerer, 'sorcerer-b', 'book-b', 8),
    ].map(ContentRecords.characterClass));
    final hero = flow.mixed({'sorcerer': 5})
      ..name = 'Лира'
      ..knownSpells = [for (final s in picked) '${s.id}-book'];
    final found = HeroReconciliation.settle(hero,
        spellNames: {
          for (final s in picked) '${s.id}-book': [s.nameRu]
        },
        spells: ContentCatalog(
            [...base, ...picked.map(other)].map(ContentRecords.spell)),
        classes: classes);
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
      home: HeroReconciliationPage(
          hero: hero, found: found, write: (_) async {}),
    ));
    await tester.pumpAndSettle();
    Future<void> shot(String name) => tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
    await shot('c03-page');
    await tester.tap(find.byKey(ValueKey('reconcile-spell-${picked.first.nameRu}')));
    await tester.pumpAndSettle();
    await shot('c03-versions');
    await tester.tap(find.textContaining('Другой перевод').first);
    await tester.pumpAndSettle();
    await shot('c03-version-picked');
    await tester.tap(find.byKey(const ValueKey('content-variant-take')));
    await tester.pumpAndSettle();
    await shot('c03-changed');
  }, skip: _out == null);
}
