import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qd_and_d/features/journal_cycle/journal_cycle_screen.dart';

Future<void> start(WidgetTester tester, {double scale = 1}) async {
  tester.view.reset();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate
    ],
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const JournalCycleScreen(),
  ));
  await tester.pumpAndSettle();
}

Future<void> focusElian(WidgetTester tester) async {
  await tester.tap(find.text('Все истории'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Элиан'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Russian road query finds the inflected quest title',
      (tester) async {
    await start(tester);
    await tester.enterText(find.byType(TextField), 'дорога');
    await tester.pumpAndSettle();
    expect(find.text('Угроза на северной дороге'), findsOneWidget);
    expect(find.text('Найти Элиана'), findsNothing);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.text('Найти Элиана'), findsOneWidget);
  });

  testWidgets(
      'Focus filters quests and notes together; search further narrows it',
      (tester) async {
    await start(tester);
    await focusElian(tester);
    expect(find.text('Найти Элиана'), findsOneWidget);
    expect(find.text('Угроза на северной дороге'), findsNothing);
    await tester.enterText(find.byType(TextField), 'письмо');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Письмо из Лесной гавани'));
    expect(find.text('Последние слова'), findsNothing);
    expect(find.text('Письмо из Лесной гавани'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Overview quest changes immediately and detail navigation keeps focus',
      (tester) async {
    await start(tester);
    await focusElian(tester);
    await tester.tap(find.text('Обзор'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обзор связей'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Найти Элиана'), 220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Завершить задание'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Вернуть в активные'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Последние слова'), -220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Последние слова'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Письмо из Лесной гавани'));
    await tester.tap(find.text('Письмо из Лесной гавани'));
    await tester.pumpAndSettle();
    expect(find.textContaining('В письме есть имя'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Последние слова'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Элиан'), findsOneWidget);
    expect(find.text('Угроза на северной дороге'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Atlas selector changes the story in place and applies it to the journal',
      (tester) async {
    await start(tester);
    await tester.tap(find.text('Обзор'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обзор связей'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Лесная гавань'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Письмо связывает гавань'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Показать в журнале'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Показать в журнале'));
    await tester.pumpAndSettle();
    expect(find.text('Лесная гавань'), findsOneWidget);
    expect(find.text('Угроза на северной дороге'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Atlas remains readable at large text', (tester) async {
    await start(tester, scale: 1.6);
    await tester.tap(find.text('Обзор'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обзор связей'));
    await tester.pumpAndSettle();
    expect(find.text('Атлас историй'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Найти Элиана'), 220,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Timeline uses session order, not note edit order',
      (tester) async {
    await start(tester);
    await focusElian(tester);
    await tester.tap(find.text('Нить'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('session-6')), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Сессия 6'), findsWidgets);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('session-2')), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Сессия 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'New notes are local to the selected story and demo reset removes them',
      (tester) async {
    await start(tester);
    await focusElian(tester);
    await tester.tap(find.text('Запись'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Моя зацепка');
    await tester.enterText(
        find.byType(TextFormField).last, 'Спросить у смотрителя пристани');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Моя зацепка'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Моя зацепка'), findsOneWidget);
    await tester.tap(find.byTooltip('Настройки демо'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить историю демо'));
    await tester.pumpAndSettle();
    expect(find.text('Моя зацепка'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text and English have no layout errors in each mode',
      (tester) async {
    await start(tester, scale: 1.6);
    for (final mode in ['Обзор', 'Нить', 'Фокус']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Настройки демо'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Journal'), findsOneWidget);
    for (final mode in ['Overview', 'Timeline', 'Focus']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
