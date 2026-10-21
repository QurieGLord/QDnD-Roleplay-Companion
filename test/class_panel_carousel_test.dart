import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/shared/class_panel_deck.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

Widget app(Widget child,
        {bool reduced = false, double scale = 1, String locale = 'ru'}) =>
    MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(body: child));
ClassPanelEntry panel(String id, double height) => ClassPanelEntry(
    id: id,
    name: id,
    level: 3,
    child: SizedBox(height: height, child: Text('Body $id')));
Finder get viewport => find.byKey(const ValueKey('class-panel-carousel'));

void main() {
  testWidgets(
      'An inline swipe follows the finger, adapts height, and leaves shared magic below the carousel',
      (tester) async {
    await tester.pumpWidget(app(SingleChildScrollView(
        child: Column(children: [
      ClassPanelDeck(panels: [panel('fighter', 120), panel('wizard', 360)]),
      const Text('Shared magic', key: ValueKey('shared-magic')),
    ]))));
    await tester.pumpAndSettle();
    expect(tester.getSize(viewport).height, closeTo(126, 1));
    final gesture = await tester.startGesture(tester.getCenter(viewport));
    await gesture.moveBy(const Offset(-240, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final during = tester.getSize(viewport).height;
    expect(during, greaterThan(126));
    expect(during, lessThanOrEqualTo(366));
    await gesture.moveBy(const Offset(-360, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Body wizard'), findsOneWidget);
    expect(find.text('Body fighter'), findsNothing);
    expect(tester.getSize(viewport).height, closeTo(366, 1));
    expect(tester.getTopLeft(find.byKey(const ValueKey('shared-magic'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(viewport).dy));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'A class swipe stays inside the section while vertical gestures scroll the sheet',
      (tester) async {
    final outer = PageController(), scroll = ScrollController();
    addTearDown(outer.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(app(PageView(controller: outer, children: [
      SingleChildScrollView(
          controller: scroll,
          child: Column(children: [
            ClassPanelDeck(
                panels: [panel('fighter', 300), panel('rogue', 300)]),
            const SizedBox(height: 1000),
          ])),
      const Text('Another sheet tab'),
    ])));
    await tester.pumpAndSettle();
    await tester.drag(viewport, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Body rogue'), findsOneWidget);
    expect(outer.page, 0);
    await tester.drag(viewport, const Offset(-5, -160));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(find.text('Body rogue'), findsOneWidget);
    expect(outer.page, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Hidden panels preserve local expansion and counters; the viewport follows content changes',
      (tester) async {
    await tester.pumpWidget(app(const SingleChildScrollView(
        child: ClassPanelDeck(panels: [
      ClassPanelEntry(
          id: 'first', name: 'First', level: 1, child: _StatePanel()),
      ClassPanelEntry(
          id: 'second',
          name: 'Second',
          level: 2,
          child: SizedBox(height: 100, child: Text('Second body'))),
      ClassPanelEntry(
          id: 'third',
          name: 'Third',
          level: 3,
          child: SizedBox(height: 100, child: Text('Third body'))),
    ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand 0'));
    await tester.pumpAndSettle();
    final height = tester.getSize(viewport).height;
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-third')));
    await tester.pumpAndSettle();
    expect(find.text('Expand 1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-first')));
    await tester.pumpAndSettle();
    expect(find.text('Expand 1'), findsOneWidget);
    expect(tester.getSize(viewport).height, closeTo(height, 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Selection follows class identity after reordering or removing a class',
      (tester) async {
    var panels = [
      panel('first', 100),
      panel('second', 180),
      panel('third', 240)
    ];
    late StateSetter redraw;
    await tester.pumpWidget(app(StatefulBuilder(builder: (context, setState) {
      redraw = setState;
      return SingleChildScrollView(child: ClassPanelDeck(panels: panels));
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('class-panel-tab-second')));
    await tester.pumpAndSettle();
    redraw(() => panels = [panels[2], panels[0], panels[1]]);
    await tester.pumpAndSettle();
    expect(find.text('Body second'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    redraw(() => panels = [panels[0], panels[1]]);
    await tester.pumpAndSettle();
    expect(find.text('Body third'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: large text and reduced motion retain a usable class selector',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(
          SingleChildScrollView(
              child: ClassPanelDeck(panels: [
            panel('First class', 100),
            panel('Second class', 180),
            panel('Third class', 220),
          ])),
          reduced: true,
          scale: 1.7,
          locale: locale));
      await tester.pumpAndSettle();
      await tester.drag(viewport, const Offset(-310, 0));
      await tester.pumpAndSettle();
      expect(find.text('Body Second class'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _StatePanel extends StatefulWidget {
  const _StatePanel();
  @override
  State<_StatePanel> createState() => _StatePanelState();
}

class _StatePanelState extends State<_StatePanel> {
  int count = 0;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: count > 0 ? 300 : 100,
      child: Align(
          alignment: Alignment.topCenter,
          child: TextButton(
              onPressed: () => setState(() => count++),
              child: Text('Expand $count'))));
}
