import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/features/character_creation/character_creation_wizard.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('next FAB starts compact on the first step', (tester) async {
    await tester.pumpWidget(_wrapWizard());
    await tester.pump();

    expect(
        find.byKey(const Key('character_creation_next_fab')), findsOneWidget);
    expect(
      find.byKey(const Key('character_creation_next_fab_compact_icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('character_creation_next_fab_extended_label')),
      findsNothing,
    );
  });

  testWidgets('next FAB expands near bottom and compacts after scrolling up',
      (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapWizard());
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('basic_info_scroll_view')),
      const Offset(0, -2200),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('character_creation_next_fab_extended_label')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('basic_info_scroll_view')),
      const Offset(0, 2200),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('character_creation_next_fab_compact_icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('character_creation_next_fab_extended_label')),
      findsNothing,
    );
  });
}

Widget _wrapWizard() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      );
    },
    home: const CharacterCreationWizard(),
  );
}
