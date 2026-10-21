import 'package:qd_and_d/core/ui/sheet_drag_region.dart';
import 'package:qd_and_d/shared/widgets/spell_details_sheet.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/search/spell_catalog.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/spell_eligibility_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/spellbook_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/utils/spell_utils.dart';
import 'package:qd_and_d/features/spell_almanac/spell_almanac_screen.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;
import 'spell_preparation_rules_test.dart' as preparation;
import 'package:qd_and_d/core/magic/spell_preparation_rules.dart';
import 'package:qd_and_d/features/spell_almanac/spellbook_controls.dart';

Spell spell(String id,
        {int circle = 1,
        List<String> classes = const ['wizard'],
        String en = 'Magic Shield',
        String ru = 'Магический щит',
        String school = 'Abjuration',
        String? source,
        bool concentration = false,
        bool ritual = false}) =>
    Spell(
        id: id,
        nameEn: en,
        nameRu: ru,
        level: circle,
        school: school,
        castingTime: '1 reaction, which you take when hit',
        range: 'Self (10-foot radius)',
        duration: 'Instantaneous',
        concentration: concentration,
        ritual: ritual,
        components: ['V', 'S'],
        descriptionEn: 'A protective spell.\n\nSecond paragraph.',
        descriptionRu: 'Защитное заклинание.\n\nВторой абзац.',
        availableToClasses: classes,
        sourceId: source);
Character mixed(Map<String, int> levels) {
  final c = fixtures.hero();
  c.level = levels.values.reduce((a, b) => a + b);
  c.characterClass = levels.keys.first;
  c.classes = levels.entries
      .map((e) => CharacterClass(
          id: e.key,
          name: e.key,
          level: e.value,
          isPrimary: e.key == levels.keys.first))
      .toList();
  return c;
}

Widget app(Widget child,
        {String locale = 'ru', double scale = 1, double keyboard = 0}) =>
    MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!),
        home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-almanac-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets(
      'A namespaced book caster copies before preparation; a list caster prepares directly',
      (tester) async {
    for (final mode in [
      SpellPreparationMode.book,
      SpellPreparationMode.prepared
    ]) {
      final c = preparation.foreign(preparation: SpellPreparationRules(mode));
      final s = spell('custom-book-spell', classes: ['Moon Mage']);
      await tester.pumpWidget(app(Scaffold(
          body: SingleChildScrollView(
              child: SpellbookControls(
                  key: ValueKey(mode),
                  hero: c,
                  spell: s,
                  onChanged: () {},
                  onBusyChanged: (_) {})))));
      await tester.tap(find.text('Лунный маг'));
      await tester.pumpAndSettle();
      if (mode == SpellPreparationMode.book) {
        expect(find.text('Вписать в книгу'), findsOneWidget);
        expect(find.byKey(const ValueKey('almanac-prepare')), findsNothing);
      } else {
        expect(
            find.byKey(const ValueKey('almanac-change-known')), findsNothing);
        expect(find.text('Подготовить'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });
  test(
      'A shared third-circle slot cannot teach a wizard 1 a third-circle spell',
      () {
    final c = mixed({'cleric': 5, 'wizard': 1})..spellSlots = [4, 3, 3];
    final access = SpellEligibilityService.checkEligibility(
        c, spell('fireball', circle: 3));
    expect(access.canLearn, false);
    expect(access.canLearnAtLevel, 5);
    expect(
        access.sources.singleWhere((a) => a.classId == 'wizard').classLevel, 1);
    expect(access.sources.singleWhere((a) => a.classId == 'cleric').state,
        SpellAccessState.unavailable);
  });
  test(
      'Secondary class list works in either order; each source has its own level',
      () {
    for (final levels in [
      {'fighter': 8, 'wizard': 3},
      {'wizard': 3, 'fighter': 8}
    ]) {
      final access = SpellEligibilityService.checkEligibility(
          mixed(levels), spell('misty-step', circle: 2));
      expect(access.canLearn, true);
      expect(
          access.sources
              .where((a) => a.state == SpellAccessState.available)
              .single
              .classId,
          'wizard');
    }
  });
  test(
      'Pact circles stop at five; Arcanum remains a separate conditional choice',
      () {
    expect(
        SpellEligibilityService.checkEligibility(mixed({'warlock': 10}),
            spell('six', circle: 6, classes: ['warlock'])).canLearnAtLevel,
        11);
    final result = SpellEligibilityService.checkEligibility(
        mixed({'warlock': 20}), spell('nine', circle: 9, classes: ['warlock']));
    expect(result.state, SpellAccessState.conditional);
    expect(result.canLearn, false);
  });
  test(
      'Paladin 1 cannot borrow casting from the total level or learn a cantrip by default',
      () {
    final c = mixed({'fighter': 10, 'paladin': 1});
    expect(
        SpellEligibilityService.checkEligibility(
            c, spell('bless', classes: ['paladin'])).canLearnAtLevel,
        2);
    expect(
        SpellEligibilityService.checkEligibility(
            c, spell('light', circle: 0, classes: ['paladin'])).state,
        SpellAccessState.conditional);
  });
  test('Third-caster schools use the subclass owner, not total character level',
      () {
    final c = mixed({'fighter': 3, 'wizard': 8});
    c.classes.first.subclass = 'eldritch-knight';
    final access = SpellEligibilityService.classAccess(
        c, spell('charm', school: 'Enchantment', classes: ['wizard']));
    expect(access.first.state, SpellAccessState.conditional);
    expect(access.last.state, SpellAccessState.available);
  });
  test('Damaged saved rules do not fall back to a currently installed class',
      () {
    final c = mixed({'wizard': 20});
    c.classes.single.rulesSnapshot = {'version': 99};
    expect(SpellEligibilityService.checkEligibility(c, spell('one')).state,
        SpellAccessState.unknown);
  });
  test(
      'Batched catalog availability equals individual access and never writes the hero',
      () {
    final c = mixed({'cleric': 3, 'wizard': 1}),
        before = jsonEncode(c.toJson());
    final evaluate = SpellEligibilityService.forCharacter(c);
    for (final s in [
      spell('one'),
      spell('three', circle: 3),
      spell('cleric', classes: ['cleric'])
    ]) {
      expect(evaluate(s).state,
          SpellEligibilityService.checkEligibility(c, s).state);
    }
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Search supports both languages, word forms, typos and bounded spell synonyms',
      () {
    final c = SpellCatalog([
      spell('fire', en: 'Burning Hands', ru: 'Огненные ладони'),
      spell('shield'),
      spell('heal', en: 'Cure Wounds', ru: 'Лечение ран')
    ]);
    for (final q in ['огненная', 'огненые', 'burnng', 'пламя']) {
      expect(
          c.select(SpellCatalogFilter(query: q), locale: 'en').map((s) => s.id),
          contains('fire'),
          reason: q);
    }
    expect(
        c
            .select(const SpellCatalogFilter(query: 'исцеление'), locale: 'ru')
            .map((s) => s.id),
        contains('heal'));
    expect(
        c.select(const SpellCatalogFilter(query: 'щит'), locale: 'en').first.id,
        'shield');
    expect(
        c.select(const SpellCatalogFilter(query: 'nonsensezz'), locale: 'ru'),
        isEmpty);
  });
  test(
      'Different books remain independent; combined filters and reset are deterministic',
      () {
    final c = SpellCatalog([
      spell('b', source: 'book-b', ritual: true),
      spell('a', source: 'book-a', ritual: true),
      spell('z', circle: 2)
    ]);
    expect(
        c
            .select(const SpellCatalogFilter(query: 'shield'), locale: 'en')
            .map((s) => s.id),
        ['a', 'b', 'z']);
    expect(
        c
            .select(
                const SpellCatalogFilter(
                    sourceId: 'book-a', circle: 1, ritual: AlmanacProperty.yes),
                locale: 'en')
            .single
            .id,
        'a');
    expect(
        c
            .select(const SpellCatalogFilter(ritual: AlmanacProperty.no),
                locale: 'en')
            .single
            .id,
        'z');
    expect(c.select(const SpellCatalogFilter(), locale: 'en'), hasLength(3));
  });
  test(
      'Missing translations fall back without losing imported descriptions or reaction clauses',
      () {
    final s = spell('partial', ru: '')
      ..descriptionRu = ''
      ..materialComponents = 'A feather';
    expect(s.getName('ru'), 'Magic Shield');
    expect(s.getDescription('ru'), contains('protective'));
    expect(s.getMaterialComponents('ru'), 'A feather');
    final en = lookupAppLocalizations(const Locale('en'));
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(SpellUtils.getLocalizedValue(en, s.castingTime), s.castingTime);
    expect(SpellUtils.getLocalizedValue(ru, s.castingTime),
        contains('which you take when hit'));
  });
  test(
      'Two class owners survive removing only one, including independent preparation',
      () async {
    final c = mixed({'cleric': 3, 'wizard': 2}),
        id = SpellService.getAllSpells().firstWhere((s) => s.level == 1).id;
    await SpellbookActionsService.setKnown(c, id, true, source: 'class:cleric');
    await SpellbookActionsService.setKnown(c, id, true, source: 'class:wizard');
    await SpellbookActionsService.setPrepared(c, id, true,
        source: 'class:wizard');
    await SpellbookActionsService.setKnown(c, id, false,
        source: 'class:cleric');
    expect(c.knownSpells, [id]);
    expect(c.preparedSpells, [id]);
    expect(SpellbookState.read(c.spellbookData).ownersOf(id), ['class:wizard']);
  });
  test(
      'Assigning one legacy prepared spell preserves preparation and other legacy records',
      () async {
    final c = mixed({'wizard': 3})
      ..knownSpells = ['old', 'other']
      ..preparedSpells = ['old', 'other'];
    await SpellbookActionsService.setKnown(c, 'old', true,
        source: 'class:wizard');
    expect(c.preparedSpells.toSet(), {'old', 'other'});
    final state = SpellbookState.read(c.spellbookData);
    expect(state.ids('class:wizard', 'prepared'), {'old'});
    expect(state.unassignedKnown(c), {'other'});
  });
  test(
      'Failed spellbook write restores membership, preparation, ownership and timestamp',
      () async {
    final c = mixed({'wizard': 3})
      ..knownSpells = ['old']
      ..preparedSpells = ['old'];
    final before = jsonEncode(c.toJson());
    await expectLater(
        SpellbookActionsService.setKnown(c, 'old', true, source: 'class:wizard',
            write: (c) async {
          c.updatedAt = DateTime(2050);
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Spellbook edits serialize with gameplay, including an earlier failed write',
      () async {
    final c = mixed({'wizard': 3});
    final gate = Completer<void>();
    final first = GameplayActionsService.serializeCharacter(c, () async {
      await gate.future;
    });
    final add = SpellbookActionsService.setKnown(c, 'one', true,
        source: 'class:wizard');
    expect(c.knownSpells, isEmpty);
    gate.complete();
    await first;
    await add;
    expect(c.knownSpells, ['one']);
    await expectLater(
        SpellbookActionsService.setKnown(c, 'two', true, source: 'class:wizard',
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    await SpellbookActionsService.setKnown(c, 'three', true,
        source: 'class:wizard');
    expect(c.knownSpells, ['one', 'three']);
  });
  test(
      'Preparation allowance uses class level and minimum one, not total level',
      () {
    final c = mixed({'wizard': 1, 'cleric': 10});
    expect(SpellbookActionsService.preparationLimit(c, 'class:wizard'), 1);
    expect(SpellbookActionsService.preparationLimit(c, 'class:cleric'), 10);
    expect(SpellbookActionsService.preparationLimit(c, 'manual'), isNull);
  });
  test('Over-preparation requires an explicit table ruling and remains saved',
      () async {
    final c = mixed({'wizard': 1});
    final ids = SpellService.getAllSpells()
        .where((s) => s.level == 1)
        .take(2)
        .map((s) => s.id)
        .toList();
    for (final id in ids) {
      await SpellbookActionsService.setKnown(c, id, true,
          source: 'class:wizard');
    }
    await SpellbookActionsService.setPrepared(c, ids.first, true,
        source: 'class:wizard');
    await expectLater(
        SpellbookActionsService.setPrepared(c, ids.last, true,
            source: 'class:wizard'),
        throwsStateError);
    await SpellbookActionsService.setPrepared(c, ids.last, true,
        source: 'class:wizard', tableRuling: true);
    expect(c.preparedSpells.toSet(), ids.toSet());
  });
  test(
      'Hive restart, clone and ID remapping retain source ownership without sharing maps',
      () async {
    final c = mixed({'wizard': 3});
    await SpellbookActionsService.setKnown(c, 'old', true,
        source: 'class:wizard');
    final clone = QdndBundleCodec.cloneCharacter(c);
    final state = SpellbookState.read(clone.spellbookData);
    state.setKnown('class:wizard', 'clone-only', true);
    clone.spellbookData = state.toJson();
    expect(SpellbookState.read(c.spellbookData).allKnown, {'old'});
    final remapped = SpellbookState.read(c.spellbookData)
        .remap(spell: (s) => 'new-$s', classId: (s) => 'new-$s');
    expect(SpellbookState.read(remapped).ids('class:new-wizard', 'known'),
        {'new-old'});
    await Hive.close();
    await StorageService.init();
    expect(
        SpellbookState.read(StorageService.getCharacter(c.id)!.spellbookData)
            .ids('class:wizard', 'known'),
        {'old'});
  });
  test(
      'Unknown future spellbook versions are retained and rejected before edits',
      () async {
    final c = mixed({'wizard': 3})
      ..spellbookData = {'version': 99, 'sources': {}, 'future': 'retained'};
    final before = jsonEncode(c.spellbookData);
    await expectLater(
        SpellbookActionsService.setKnown(c, 'one', true,
            source: 'class:wizard'),
        throwsFormatException);
    expect(jsonEncode(c.spellbookData), before);
  });
  testWidgets(
      'Search reset clears visible text and pending debounce; filters cancel without committing',
      (tester) async {
    await tester
        .pumpWidget(app(SpellAlmanacScreen(character: mixed({'wizard': 3}))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('almanac-search')), 'nonsensezz');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Заклинания не найдены'), findsOneWidget);
    await tester.tap(find.byTooltip('Сбросить').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('almanac-search')))
            .controller!
            .text,
        isEmpty);
    await tester.tap(find.byKey(const ValueKey('almanac-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Фильтры'), findsOneWidget);
    await tester.tap(find.text('Школа'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Воплощение'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Almanac remains usable with a keyboard and large type on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(
        SpellAlmanacScreen(character: mixed({'wizard': 3})),
        scale: 1.7,
        keyboard: 280));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Details assign a legacy spell, preserve preparation and expose the other owner',
      (tester) async {
    final c = mixed({'wizard': 3, 'cleric': 2})
      ..knownSpells = ['shield']
      ..preparedSpells = ['shield'];
    await tester.pumpWidget(app(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => showResponsiveSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => SpellDetailsSheet(
                        spell: spell('shield', classes: ['wizard', 'cleric']),
                        character: c,
                        editable: true)),
                child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('almanac-change-known')), 300,
        scrollable: find
            .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.byType(Scrollable))
            .first);
    final wizard = find.widgetWithText(ChoiceChip, 'Волшебник');
    await tester.ensureVisible(wizard);
    await tester.tap(wizard);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('almanac-change-known')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('almanac-change-known')));
      // Hive writes use the real event loop, outside widget-test fake time.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(SpellbookState.read(c.spellbookData).ids('class:wizard', 'known'),
        {'shield'});
    expect(c.preparedSpells, ['shield']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Long spell headings and large type scroll inside details rather than overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showResponsiveSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => SpellDetailsSheet(
                            spell: spell('long',
                                ru: 'Очень длинное название заклинания из необычной книги приключений'),
                            character: mixed({'wizard': 3}),
                            editable: true)),
                    child: const Text('Open')))),
        scale: 1.8));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test('Ambiguous legacy preparation does not create a second free allowance',
      () async {
    final c = mixed({'wizard': 3, 'cleric': 2})
      ..knownSpells = ['old']
      ..preparedSpells = ['old'];
    final id = SpellService.getAllSpells().firstWhere((s) => s.level == 1).id;
    await SpellbookActionsService.setKnown(c, id, true, source: 'class:wizard');
    expect(SpellbookActionsService.hasUnassignedPreparation(c), true);
    await expectLater(
        SpellbookActionsService.setPrepared(c, id, true,
            source: 'class:wizard'),
        throwsStateError);
    await SpellbookActionsService.setPrepared(c, id, true,
        source: 'class:wizard', tableRuling: true);
    expect(c.preparedSpells, containsAll(['old', id]));
  });
  testWidgets(
      'Search has its own accessibility region without the hero heading',
      (tester) async {
    final c = mixed({'wizard': 3});
    c.name = 'Элара';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(SpellAlmanacScreen(character: c)));
    await tester.pumpAndSettle();
    final node =
        tester.getSemantics(find.byKey(const ValueKey('almanac-search')));
    expect(node.label, isNot(contains('Элара')));
    expect(node.rect.height, lessThan(140));
    semantics.dispose();
  });
  test('Spell counts use Russian plurals and English stays English', () {
    final ru = lookupAppLocalizations(const Locale('ru')),
        en = lookupAppLocalizations(const Locale('en'));
    expect(ru.spellsCount(1), '1 заклинание');
    expect(ru.spellsCount(3), '3 заклинания');
    expect(ru.spellsCount(11), '11 заклинаний');
    expect(ru.spellsCount(21), '21 заклинание');
    expect(en.spellsCount(1), '1 spell');
    expect(en.spellsCount(3), '3 spells');
  });
}
