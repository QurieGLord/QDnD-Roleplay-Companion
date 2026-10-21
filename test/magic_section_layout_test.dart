import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities/sections/magic_section.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('ru')]) {
    for (final scenario in [(390.0, 1.0), (320.0, 2.0), (600.0, 1.0)]) {
      testWidgets(
          'magic and almanac share a row: ${locale.languageCode} $scenario',
          (tester) async {
        tester.view.physicalSize = Size(scenario.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        late AppLocalizations l10n;
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AbilitiesMagicSection(
                    stats: const [],
                    onOpenSpellAlmanac: () => opened++,
                  ),
                ),
              )),
            );
          }),
        ));
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('spell-almanac-button'));
        expect(tester.getCenter(button).dy,
            closeTo(tester.getCenter(find.text(l10n.magic)).dy, 1));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(find.byTooltip(l10n.spellAlmanac), findsOneWidget);
        // The fixed-width test font makes mobile labels wider than device fonts.
        // Check mobile alignment/accessibility and a full label on a wider screen.
        if (scenario.$1 == 600) {
          expect(find.text(l10n.spellAlmanac), findsOneWidget);
        }
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
