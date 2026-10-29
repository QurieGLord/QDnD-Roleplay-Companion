import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/hero_reconciliation.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_list/hero_reconciliation_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../multiclass_magic_flow_test.dart' as flow;

Spell spell(String id, String? source, String en, String ru,
        {String text = 'A bright streak.'}) =>
    Spell(
        id: id,
        sourceId: source,
        nameEn: en,
        nameRu: ru,
        level: 3,
        school: 'Evocation',
        castingTime: '1 action',
        range: '150 feet',
        duration: 'Instantaneous',
        concentration: false,
        ritual: false,
        components: const ['V', 'S'],
        descriptionEn: text,
        descriptionRu: text,
        availableToClasses: const ['sorcerer']);

ClassData variantOf(ClassData base, String id, String source, int hitDie) =>
    ClassData(
        id: id,
        name: base.name,
        description: base.description,
        hitDie: hitDie,
        primaryAbilities: base.primaryAbilities,
        savingThrowProficiencies: base.savingThrowProficiencies,
        armorProficiencies: base.armorProficiencies,
        weaponProficiencies: base.weaponProficiencies,
        skillProficiencies: base.skillProficiencies,
        subclasses: base.subclasses,
        subclassLevel: base.subclassLevel,
        spellcasting: base.spellcasting,
        features: base.features,
        sourceId: source);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-reconcile-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final fire = spell('fireball', null, 'Fireball', 'Огненный шар');
  final fireBook = spell('fireball-xge', 'xge', 'Fireball', 'Огненный шар',
      text: 'Another wording.');
  final shield = spell('shield', null, 'Shield', 'Щит');
  final shieldCopy = spell('shield-phb', 'phb', 'Shield', 'Щит');
  ContentCatalog<Spell> spells() => ContentCatalog(
      [fireBook, fire, shield, shieldCopy].map(ContentRecords.spell));
  ContentCatalog<ClassData> classes() {
    final base = CharacterDataService.getClassById('sorcerer')!;
    return ContentCatalog([
      base,
      variantOf(base, 'sorcerer-tce', 'tce', 8),
    ].map(ContentRecords.characterClass));
  }

  test('names settle on the lead version; only real versions are listed', () {
    final hero = flow.mixed({'sorcerer': 5})
      ..knownSpells = ['fireball-xge', 'shield-phb', 'unknown_spell']
      ..preparedSpells = ['fireball-xge'];
    final found = HeroReconciliation.settle(hero,
        spellNames: {
          'fireball-xge': ['Огненный шар'],
          'shield-phb': ['Shield'],
          'unknown_spell': ['Unknown spell'],
        },
        spells: spells(),
        classes: classes());
    // The first book loaded no longer wins: the base book leads.
    expect(hero.knownSpells, ['fireball', 'shield', 'unknown_spell']);
    expect(hero.preparedSpells, ['fireball']);
    expect(hero.classes.single.id, 'sorcerer');
    // Exact copies are no question; differing versions and classes are.
    expect(found.map((a) => (a.kind, a.original)), [
      (ContentKind.spell, 'Огненный шар'),
      (ContentKind.characterClass, hero.classes.single.name),
    ]);
    final refs = hero.spellbookData['contentReferences'] as Map;
    expect(refs['fireball']['originalNames'], ['Огненный шар']);
    expect(refs['fireball']['origin'], 'fc5');
    expect(refs['fireball']['variantKey'], ContentRecords.spell(fire).variantKey);
    expect(refs.containsKey('unknown_spell'), isFalse);
  });

  test('choosing another version moves the reference and keeps the name',
      () async {
    final hero = flow.mixed({'sorcerer': 5})..knownSpells = ['fireball'];
    final found = HeroReconciliation.settle(hero,
        spellNames: {
          'fireball': ['Fireball']
        },
        spells: spells(),
        classes: classes());
    final spellChoice = found.firstWhere((a) => a.kind == ContentKind.spell);
    final classChoice =
        found.firstWhere((a) => a.kind == ContentKind.characterClass);
    final other = spellChoice.versions.firstWhere((r) => r.id == 'fireball-xge');
    final tce = classChoice.versions.firstWhere((r) => r.id == 'sorcerer-tce');
    var saved = 0;
    await HeroReconciliation.apply(hero, [(spellChoice, other), (classChoice, tce)],
        write: (_) async => saved++);
    expect(saved, 1);
    expect(hero.knownSpells, ['fireball-xge']);
    expect(hero.classes.single.id, 'sorcerer-tce');
    final refs = hero.spellbookData['contentReferences'] as Map;
    expect(refs.containsKey('fireball'), isFalse);
    expect(refs['fireball-xge']['originalNames'], ['Fireball']);
  });

  testWidgets('the page lists the versions and saves the choice',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final hero = flow.mixed({'sorcerer': 5})..knownSpells = ['fireball'];
    final found = HeroReconciliation.settle(hero,
        spellNames: {
          'fireball': ['Fireball']
        },
        spells: spells(),
        classes: classes());
    var saved = 0;
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: HeroReconciliationPage(
            hero: hero, found: found, write: (_) async => saved++)));
    await tester.pumpAndSettle();
    expect(find.text('СВЕРКА С БИБЛИОТЕКАМИ'), findsOneWidget);
    expect(find.text('Принять основные'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reconcile-spell-Fireball')));
    await tester.pumpAndSettle();
    // The other version: the one not marked as chosen now.
    await tester.tap(find.text('Another wording.'));
    await tester.pumpAndSettle();
    // A tap only selects; the island takes the version.
    expect(find.text('Взять эту версию'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('content-variant-take')));
    await tester.pumpAndSettle();
    expect(find.text('Принять · 1 изменение'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hero-reconcile-accept')));
    await tester.pumpAndSettle();
    expect(saved, 1);
    expect(hero.knownSpells, ['fireball-xge']);
  });
}
