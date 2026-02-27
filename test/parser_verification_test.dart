import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/models/item.dart';

void main() {
  test('Verify bilingual_test_compendium.xml parsing', () async {
    final file = File('bilingual_test_compendium.xml');
    final xmlContent = await file.readAsString();

    final result = await FC5Parser.parseCompendium(xmlContent);

    // --- Verify Races ---
    expect(result.races.length, 2);
    final elf = result.races.firstWhere((r) => r.name['en'] == 'Silicon Elf');
    expect(elf.name['ru'], 'Кремниевый Эльф');
    expect(elf.speed, 30);
    expect(elf.abilityScoreIncreases['dexterity'], 2);
    expect(elf.abilityScoreIncreases['intelligence'], 1);

    // Check traits
    expect(elf.traits.isNotEmpty, true);
    final trance = elf.traits.firstWhere((t) => t.nameEn == 'Wireless Trance');
    expect(trance.nameRu, 'Беспроводной Транс');
    expect(trance.descriptionEn, contains("You don't need sleep"));
    expect(trance.descriptionRu, contains("Вам не нужен сон"));

    // --- Verify Classes ---
    expect(result.classes.length, 2);
    final wizard =
        result.classes.firstWhere((c) => c.name['en'] == 'Code Wizard');
    expect(wizard.name['ru'], 'Код-Волшебник');
    expect(wizard.hitDie, 6);

    // Check Proficiencies (Skills)
    // XML: Arcana ---RU--- Магия, History ---RU--- История, Investigation ---RU--- Расследование, Logic ---RU--- Логика
    expect(wizard.skillProficiencies.from.contains('Arcana'), true);
    expect(wizard.skillProficiencies.from.contains('History'), true);
    expect(wizard.skillProficiencies.from.contains('Investigation'), true);
    // Ensure ---RU--- is stripped from the key
    expect(wizard.skillProficiencies.from.any((s) => s.contains('---RU---')),
        false);

    // Check NumSkills
    expect(wizard.skillProficiencies.choose, 2);

    // Check Features (from autolevel)
    // Level 1: Cache Slots, Syntax Highlighting
    final level1Features = wizard.features[1];
    expect(level1Features, isNotNull);
    expect(level1Features!.any((f) => f.nameEn == 'Cache Slots'), true);
    expect(level1Features.any((f) => f.nameRu == 'Слоты Кэша'), true);

    // Check Feature Description
    final cacheSlots =
        level1Features.firstWhere((f) => f.nameEn == 'Cache Slots');
    expect(cacheSlots.descriptionEn, contains("pool of temporary memory"));
    expect(cacheSlots.descriptionRu, contains("пул временной памяти"));

    // --- Verify Backgrounds ---
    expect(result.backgrounds.length, 2);
    final legacy = result.backgrounds
        .firstWhere((b) => b.name['en'] == 'Legacy Maintainer');
    expect(legacy.name['ru'], 'Поддержка Легаси');

    // Check Proficiencies
    // XML: History ---RU--- История, Investigation ---RU--- Расследование
    expect(legacy.skillProficiencies.contains('History'), true);
    expect(legacy.skillProficiencies.contains('Investigation'), true);
    expect(legacy.skillProficiencies.any((s) => s.contains('---RU---')), false);

    // Check Traits (merged into Feature)
    expect(legacy.feature.name['en'], contains('Ancient Knowledge'));
    expect(legacy.feature.getDescription('en'),
        contains('languages that no one speaks'));
    expect(legacy.feature.getDescription('ru'),
        contains('языки, на которых никто больше не говорит'));

    // --- Verify Items ---
    final keyboard =
        result.items.firstWhere((i) => i.nameEn == 'Keyboard of Warriors');
    expect(keyboard.nameRu, 'Клавиатура Воинов');
    expect(keyboard.type, ItemType.weapon);

    // --- Verify Spells ---
    final helloWorld =
        result.spells.firstWhere((s) => s.nameEn == 'Hello World');
    expect(helloWorld.nameRu, 'Привет Мир');
    expect(helloWorld.descriptionRu, contains('Вы создаете парящий текст'));
  });
}
