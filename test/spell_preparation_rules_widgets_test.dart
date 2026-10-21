import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/magic/spell_preparation_rules.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/spell_preparation_rules_editor.dart';
import 'package:qd_and_d/shared/widgets/wild_shape_editor.dart';

void main() {
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: preparation requires explicit choices and remains readable at large text scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SpellPreparationRules? result;
      await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.7)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: SpellPreparationRulesEditor(
                      onChanged: (v) => result = v)))));
      await tester.tap(find.text(locale == 'ru' ? 'Из списка' : 'Class list'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      final half = find
          .text(locale == 'ru' ? 'Половина уровня ↓' : 'Half class level ↓');
      await tester.ensureVisible(half);
      await tester.tap(half);
      await tester.pumpAndSettle();
      expect(result, isNull);
      final ritual =
          find.text(locale == 'ru' ? 'Готовые заклинания' : 'Ready spells');
      await tester.ensureVisible(ritual);
      await tester.tap(ritual);
      await tester.pumpAndSettle();
      expect(result!.mode, SpellPreparationMode.prepared);
      expect(result!.divisor, 2);
      expect(result!.ritual, RitualPreparationMode.prepared);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Wild Shape opens without keyboard focus, validates HP, and retains the draft after a failed save',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        showWildShapeEditor(context, onSubmit: (_, __) async {
                          throw StateError('disk');
                        }),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.autofocus, false);
    }
    await tester.tap(find.text('Transform'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive whole number'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '34');
    await tester.tap(find.text('Transform'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save Wild Shape.'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
}
