import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/features/character_level_up/widgets/advancement_choice_captions.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/features/character_level_up/steps/hp_increase_step.dart';
import 'package:qd_and_d/features/character_level_up/steps/asi_step.dart';
import 'package:qd_and_d/features/character_level_up/widgets/advancement_layout.dart';
import 'progression_widgets_test.dart' show app;

void main() {
  testWidgets(
      'Compact wording is used only for the matching built-in rule, not a same-ID homebrew',
      (tester) async {
    final raw = await tester.runAsync(
        () => rootBundle.loadString('assets/data/features/srd_features.json'));
    final rows = jsonDecode(raw!) as List;
    final feature = CharacterFeature.fromJson(Map<String, dynamic>.from(
        rows.firstWhere((r) => r['id'] == 'metamagic-distant-spell') as Map));
    Widget render() => app(Builder(
        builder: (context) => Text(AdvancementChoiceCaptions.forFeature(
                feature, AppLocalizations.of(context)!) ??
            'Original source text')));
    await tester.pumpWidget(render());
    await tester.pumpAndSettle();
    expect(find.text('Double range; touch becomes 30 feet.'), findsOneWidget);
    feature.descriptionEn = 'A different table rule.';
    await tester.pumpWidget(render());
    await tester.pumpAndSettle();
    expect(find.text('Original source text'), findsOneWidget);
  });
  testWidgets(
      'HP result includes the owned bonus, keeps the roll on screen, and continues only on demand',
      (tester) async {
    final rolls = <int>[];
    var averages = 0;
    await tester.pumpWidget(app(HpIncreaseStep(
        hitDie: 6,
        conMod: 0,
        additionalHp: 1,
        currentHp: 18,
        maximumHp: 30,
        onAverage: () => averages++,
        onRoll: rolls.add)));
    // The new maximum rolls to 35 beside the gain.
    expect(tester.widget<RollingNumber>(find.byType(RollingNumber)).value, 35);
    expect(find.text('+5'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('hp-method-roll')));
    await tester.tap(find.byKey(const ValueKey('hp-method-roll')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(rolls, isEmpty);
    expect(averages, 0);
    await tester.tap(find.text('Continue'));
    expect(rolls, hasLength(1));
    expect(rolls.single, inInclusiveRange(1, 6));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'A tabletop die can be entered without advancing or changing the roll on cancellation',
      (tester) async {
    final rolls = <int>[];
    await tester.pumpWidget(app(HpIncreaseStep(
        hitDie: 10,
        conMod: -1,
        currentHp: 0,
        maximumHp: 20,
        onAverage: () {},
        onRoll: rolls.add)));
    final manual = find.byKey(const ValueKey('hp-method-manual'));
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(manual, 180, scrollable: scroll);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, false);
    await tester.enterText(find.byType(TextFormField), '7');
    await tester.tap(find.text('Use result'));
    await tester.pumpAndSettle();
    expect(rolls, isEmpty);
    expect(tester.widget<RollingNumber>(find.byType(RollingNumber)).value, 26);
    expect(find.text('+6'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(rolls, [7]);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        'Two ability points can be reassigned without stale allocations at large text in $locale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = AbilityScores(
          strength: 14,
          dexterity: 14,
          constitution: 18,
          intelligence: 10,
          wisdom: 10,
          charisma: 10);
      var assigned = <String, int>{};
      var advanced = 0;
      await tester.pumpWidget(app(
          AsiStep(
              currentScores: base,
              onAllocationChanged: (value) => assigned = value,
              onNext: () => advanced++),
          locale: locale,
          dark: locale == 'ru',
          scale: 1.4));
      final list = find.byType(Scrollable).first;
      final con = find.byKey(const ValueKey('asi-ability-constitution'));
      await tester.scrollUntilVisible(con, 160, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(con);
      await tester.pumpAndSettle();
      await tester.tap(con);
      await tester.pumpAndSettle();
      expect(assigned['constitution'], 2);
      expect(base.constitution, 18);
      final firstPoint = find.byKey(const ValueKey('asi-point-0'));
      await tester.scrollUntilVisible(firstPoint, -160, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(firstPoint);
      await tester.pumpAndSettle();
      final str = find.byKey(const ValueKey('asi-ability-strength'));
      await tester.ensureVisible(str);
      await tester.tap(str);
      await tester.pumpAndSettle();
      expect(assigned['constitution'], 1);
      expect(assigned['strength'], 1);
      expect(assigned.values.fold<int>(0, (a, b) => a + b), 2);
      final footer =
          tester.widget<AdvancementFooter>(find.byType(AdvancementFooter));
      footer.onPressed!();
      expect(advanced, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'At the ability limit a point cannot be consumed by an unavailable increase',
      (tester) async {
    final scores = AbilityScores(
        strength: 20,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10);
    var changed = 0;
    await tester.pumpWidget(app(AsiStep(
        currentScores: scores,
        onAllocationChanged: (_) => changed++,
        onNext: () {})));
    await tester.tap(find.byKey(const ValueKey('asi-ability-strength')));
    await tester.pumpAndSettle();
    expect(changed, 0);
    expect(
        tester
            .widget<AdvancementFooter>(find.byType(AdvancementFooter))
            .onPressed,
        isNull);
  });
}
