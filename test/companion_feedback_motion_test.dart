import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/ui/companion_surface.dart';
import 'package:qd_and_d/core/ui/companion_motion.dart';
import 'package:qd_and_d/core/journal/journal_graph.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/features/journal/journal_atlas_page.dart';
import 'package:qd_and_d/features/character_sheet/widgets/expandable_character_card.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

Widget app(Widget child, {bool reduced = false, double scale = 1}) =>
    MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(body: child));

void main() {
  testWidgets('A short swipe neither deforms a surface nor invokes its action',
      (tester) async {
    var taps = 0, holds = 0;
    await tester.pumpWidget(app(Center(
        child: CompanionSurface(
            onTap: () => taps++,
            onLongPress: () => holds++,
            child: const SizedBox(width: 200, height: 60)))));
    await tester.pumpAndSettle();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(CompanionSurface)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    for (final scope in tester
        .widgetList<CompanionMotionScope>(find.byType(CompanionMotionScope))) {
      expect(scope.amount, 0);
    }
    await gesture.moveBy(const Offset(80, -40));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(holds, 0);
    for (final scope in tester
        .widgetList<CompanionMotionScope>(find.byType(CompanionMotionScope))) {
      expect(scope.amount, 0);
    }
  });

  testWidgets(
      'Reduced motion leaves the contour still and keeps one tap available',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(
        Center(
            child: CompanionSurface(
                onTap: () => taps++,
                child: const SizedBox(width: 200, height: 60))),
        reduced: true));
    await tester.pumpAndSettle();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(CompanionSurface)));
    await tester.pump(const Duration(milliseconds: 260));
    for (final scope in tester
        .widgetList<CompanionMotionScope>(find.byType(CompanionMotionScope))) {
      expect(scope.amount, 0);
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets(
      'Atlas filters the visible story, survives no matches and exits without an undo history',
      (tester) async {
    final hero = fixtures.hero();
    hero.journalNotes = [
      JournalNote(
          id: 'one',
          title: 'A shared letter',
          content: 'A meeting at the gate.'),
      JournalNote(
          id: 'two', title: 'The journey', content: 'Another encounter.')
    ];
    final graph = JournalGraph(entities: [
      JournalEntity(id: 'a', name: 'Arden'),
      JournalEntity(id: 'b', name: 'Elian'),
      JournalEntity(id: 'c', name: 'Northroad', kind: JournalEntityKind.place)
    ]);
    graph.forRecord('n:one').manual.addAll({'a', 'b'});
    graph.forRecord('n:two').manual.addAll({'a', 'c'});
    hero.journalData = graph.toJson();
    final before = QdndBundleCodec.characterToJson(hero);
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => JournalAtlasPage(character: hero))),
            child: const Text('Open atlas')))));
    await tester.tap(find.text('Open atlas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('atlas-entity-a')), findsOneWidget);
    expect(find.text('Shared entries: 1'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'Northroad');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('atlas-entity-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('atlas-entity-a')), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzzz-no-match');
    await tester.pumpAndSettle();
    expect(find.text('Story not found'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('journal-story-carousel')),
        const Offset(-490, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('atlas-entity-b')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('atlas-exit')));
    await tester.pumpAndSettle();
    expect(find.byType(JournalAtlasPage), findsNothing);
    expect(QdndBundleCodec.characterToJson(hero), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'The refreshed hero card fits narrow large text without writing the sheet',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hero = fixtures.hero()
      ..name = 'A hero with a long personal name'
      ..level = 20;
    hero.classes.single.level = 20;
    final before = QdndBundleCodec.characterToJson(hero);
    var rolled = 0;
    await tester.pumpWidget(app(
        SingleChildScrollView(
            child: ExpandableCharacterCard(
                character: hero,
                isExpanded: false,
                onDicePressed: () => rolled++)),
        scale: 1.8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(QdndBundleCodec.characterToJson(hero), before);
    final button = find.byType(IconButton).first;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(rolled, 1);
  });
}
