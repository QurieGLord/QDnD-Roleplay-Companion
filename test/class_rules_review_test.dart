import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/features/character_level_up/widgets/class_rules_review.dart';

void main() {
  testWidgets(
      'Missing mechanics require an explicit choice, do not mutate the book, and stay readable in RU/EN',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = (await FC5Parser.parseCompendium(
            '<compendium><class><name>Home Knight</name></class></compendium>',
            sourceId: 'home'))
        .classes
        .single;
    for (final locale in ['ru', 'en']) {
      ClassData? result;
      await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: Scaffold(
              body: ClassRulesReview(
                  key: ValueKey(locale),
                  data: data,
                  onResolved: (v) => result = v))));
      final apply = find.byKey(const ValueKey('class-rules-apply'));
      await tester.scrollUntilVisible(apply, 220);
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.scrollUntilVisible(find.text('d10'), -220);
      final neighboringChip = tester.getTopLeft(find.text('d12')) -
          tester.getTopLeft(find.text('d10'));
      await tester.tap(find.text('d10'));
      await tester.pumpAndSettle();
      expect(
          tester.getTopLeft(find.text('d12')) -
              tester.getTopLeft(find.text('d10')),
          neighboringChip);
      await tester.scrollUntilVisible(apply, 220);
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.scrollUntilVisible(
          find.text(locale == 'ru' ? 'Без заклинательства' : 'No spellcasting'),
          -220);
      await tester.ensureVisible(find
          .text(locale == 'ru' ? 'Без заклинательства' : 'No spellcasting'));
      await tester.tap(find
          .text(locale == 'ru' ? 'Без заклинательства' : 'No spellcasting'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pump();
      expect(result!.hitDie, 10);
      expect(result!.declares('hitDie'), true);
      expect(result!.rulesEdition, '2014');
      expect(result!.spellcasting, isNull);
      expect(data.declares('hitDie'), false);
      expect(data.rulesEdition, 'unknown');
      expect(tester.takeException(), isNull);
    }
  });
}
