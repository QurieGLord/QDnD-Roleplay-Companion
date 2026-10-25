// Dumps the veteran Cycle heroes as JSON for prototypes. Opt-in: QDND_DUMP=path.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('dump veterans', () async {
    final out = Platform.environment['QDND_DUMP'];
    if (out == null) return;
    final dir = await Directory.systemTemp.createTemp('qdnd-dump-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    final heroes = buildExpressiveCycleCharacters(levels: veteranCycleLevels, idPrefix: veteranCycleIdPrefix);
    final data = [
      for (final h in heroes)
        {
          'id': h.characterClass,
          'name': h.name,
          'level': h.level,
          'sub': h.subclass,
          'hp': h.maxHp,
          'ac': h.armorClass,
          'speed': h.speed,
          'pb': h.proficiencyBonus,
          'init': h.initiativeBonus,
          'abilities': h.abilityScores.toJson(),
          'hitDie': CharacterClassRules.resolve(h.classes.single).data.hitDie,
          'slots': h.maxSpellSlots,
          'resources': [
            for (final f in h.features)
              if (f.resourcePool != null && f.resourcePool!.maxUses > 0)
                {'id': f.id, 'ru': f.nameRu, 'max': f.resourcePool!.maxUses, 'rest': f.resourcePool!.recoveryType.name}
          ],
          'saves': h.savingThrowProficiencies,
          'weapons': [for (final i in h.inventory) if (i.isEquipped) i.nameRu],
        }
    ];
    File(out).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(data));
  });
}
