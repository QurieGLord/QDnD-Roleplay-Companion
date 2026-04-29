import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/features/character_creation/character_creation_state.dart';
import 'package:qd_and_d/features/character_creation/steps/basic_info_step.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('name input updates character creation state', (tester) async {
    final state = CharacterCreationState();

    await tester.pumpWidget(_wrapBasicInfo(state: state));
    await tester.enterText(
      find.byKey(const Key('basic_info_name_field')),
      'Seraphina Vale',
    );

    expect(state.name, 'Seraphina Vale');
  });

  testWidgets('alignment tile toggles select and unselect', (tester) async {
    final state = CharacterCreationState();

    await tester.pumpWidget(_wrapBasicInfo(state: state));

    await tester.tap(find.byKey(const Key('alignment_LG')));
    await tester.pump();
    expect(state.alignment, 'Lawful Good');

    await tester.tap(find.byKey(const Key('alignment_LG')));
    await tester.pump();
    expect(state.alignment, isNull);
  });

  testWidgets('ru alignment grid keeps stable tile geometry on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = CharacterCreationState();

    await tester.pumpWidget(
      _wrapBasicInfo(state: state, locale: const Locale('ru')),
    );

    expect(find.text('ЗД'), findsOneWidget);
    expect(find.text('НД'), findsOneWidget);
    expect(find.text('ХД'), findsOneWidget);
    expect(find.text('LG'), findsNothing);
    expect(find.text('NG'), findsNothing);
    expect(find.text('CG'), findsNothing);

    final keys = [
      'alignment_LG',
      'alignment_NG',
      'alignment_CG',
      'alignment_LN',
      'alignment_TN',
      'alignment_CN',
      'alignment_LE',
      'alignment_NE',
      'alignment_CE',
    ];
    final sizes = keys
        .map((key) => tester.getSize(find.byKey(Key(key))))
        .toList(growable: false);

    for (final size in sizes.skip(1)) {
      expect(size.width, closeTo(sizes.first.width, 0.01));
      expect(size.height, closeTo(sizes.first.height, 0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('age field does not show numeric placeholder', (tester) async {
    final state = CharacterCreationState();

    await tester.pumpWidget(_wrapBasicInfo(state: state));

    expect(find.byKey(const Key('basic_info_age_field')), findsOneWidget);
    expect(find.text('25'), findsNothing);
  });

  testWidgets('backstory editor saves text and only closes the editor',
      (tester) async {
    final state = CharacterCreationState();

    await tester.pumpWidget(_wrapBasicInfo(state: state));
    await tester
        .ensureVisible(find.byKey(const Key('basic_info_backstory_card')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('basic_info_reveal_backstory')), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const Key('basic_info_reveal_backstory')))
          .dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );

    await tester.tap(find.byKey(const Key('basic_info_backstory_card')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('basic_info_backstory_editor')),
      'Born under a comet and raised among old maps.',
    );
    expect(state.backstory, 'Born under a comet and raised among old maps.');

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('basic_info_backstory_editor')), findsNothing);
    expect(find.byKey(const Key('basic_info_scroll_view')), findsOneWidget);
    expect(state.backstory, 'Born under a comet and raised among old maps.');
  });

  testWidgets('expanded sections keep parent list drag-scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = CharacterCreationState();

    await tester.pumpWidget(_wrapBasicInfo(state: state));
    await tester.ensureVisible(find.text('Personality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personality'));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Personality Traits'),
      'Keeps careful notes.\nSmiles when plans become complicated.',
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;

    await tester.drag(
      find.byKey(const Key('basic_info_scroll_view')),
      const Offset(0, -220),
    );
    await tester.pump();

    expect(scrollable.position.pixels, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}

Widget _wrapBasicInfo({
  required CharacterCreationState state,
  Locale locale = const Locale('en'),
}) {
  return ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: const Scaffold(body: BasicInfoStep()),
    ),
  );
}
