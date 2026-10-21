import 'package:qd_and_d/features/inventory/inventory_presentation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/services/inventory_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_export_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_import_service.dart';
import 'multiclass_magic_flow_test.dart' as flow;

Item item(
        {String id = 'longsword',
        int quantity = 1,
        bool equipped = false,
        bool attuned = false,
        bool armor = false,
        bool shield = false}) =>
    Item(
        id: id,
        nameEn: armor ? 'Armor' : 'Sword',
        nameRu: armor ? 'Доспех' : 'Меч',
        descriptionEn: 'A personal item',
        descriptionRu: 'Личный предмет',
        type: armor ? ItemType.armor : ItemType.weapon,
        rarity: ItemRarity.common,
        quantity: quantity,
        isEquipped: equipped,
        isAttuned: attuned,
        weight: 3,
        armorProperties: armor
            ? ArmorProperties(
                baseAC: shield ? 2 : 16,
                armorType: shield ? ArmorType.shield : ArmorType.heavy,
                addDexModifier: false)
            : null,
        weaponProperties: armor
            ? null
            : WeaponProperties(
                damageDice: '1d8',
                damageType: DamageType.slashing,
                weaponTags: ['versatile']));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-inventory-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await ItemService.loadItems();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'Prices keep exact copper values across denominations and never truncate fractional copper',
      () {
    expect(itemValueInCopper('15,25', 'GP'), 1525);
    expect(itemValueInCopper('0.1', 'SP'), 1);
    expect(itemValueInCopper('0.25', 'PP'), 250);
    expect(itemValueInCopper('0', 'CP'), 0);
    expect(() => itemValueInCopper('0.5', 'CP'), throwsFormatException);
    expect(() => itemValueInCopper('0.01', 'SP'), throwsFormatException);
  });
  test(
      'Catalog identity is separate; copies and nested weapon properties are independent',
      () async {
    final c = flow.mixed({'fighter': 1}), template = item();
    await InventoryActionsService.add(c, [template, template],
        write: (_) async {});
    expect(c.inventory.map((i) => i.id), ['longsword', 'longsword']);
    expect(c.inventory.map((i) => i.instanceId).toSet(), hasLength(2));
    c.inventory[0].weaponProperties!.weaponTags.add('magic');
    expect(c.inventory[1].weaponProperties!.weaponTags, ['versatile']);
    expect(template.weaponProperties!.weaponTags, ['versatile']);
  });
  test(
      'Removing one legacy duplicate never removes its sibling; reading does not migrate',
      () async {
    final c = flow.mixed({'fighter': 1})..inventory = [item(), item()];
    final first = c.inventory.first, second = c.inventory.last;
    expect(
        QdndBundleCodec.cloneCharacter(c)
            .inventory
            .every((i) => i.instanceId == null),
        true);
    await InventoryActionsService.remove(c, InventoryTarget(first),
        write: (_) async {});
    expect(c.inventory, hasLength(1));
    expect(c.inventory.single.instanceId, isNotNull);
    expect(second.instanceId, isNull);
    expect(c.inventory.single.id, second.id);
    await expectLater(
        InventoryActionsService.remove(c, InventoryTarget(first),
            write: (_) async {}),
        throwsStateError);
    expect(c.inventory, hasLength(1));
  });
  test(
      'New armor replaces only armor; shield is independent; manual AC stays authoritative',
      () async {
    final c = flow.mixed({'fighter': 1})
      ..inventory = [
        item(id: 'old', armor: true, equipped: true),
        item(id: 'new', armor: true),
        item(id: 'shield', armor: true, shield: true, equipped: true)
      ];
    c.armorClass = 19;
    await InventoryActionsService.equip(
        c, InventoryTarget(c.inventory[1]), true,
        write: (_) async {});
    expect(c.inventory.map((i) => i.isEquipped), [false, true, true]);
    expect(c.armorClass, 19);
    c.clearArmorClassOverride();
    expect(c.armorClass, 18);
    await InventoryActionsService.remove(c, InventoryTarget(c.inventory[1]),
        write: (_) async {});
    expect(c.armorClass, 12 + c.abilityScores.dexterityModifier);
  });
  test(
      'Attunement counts packed items, rejects a fourth normally, accepts an explicit table exception',
      () async {
    final c = flow.mixed({'fighter': 1})
      ..inventory = [
        item(attuned: true),
        item(attuned: true),
        item(attuned: true),
        item()
      ];
    final target = InventoryTarget(c.inventory.last);
    await expectLater(
        InventoryActionsService.attune(c, target, true, write: (_) async {}),
        throwsA(isA<AttunementLimit>()));
    expect(c.inventory.last.isAttuned, false);
    await InventoryActionsService.attune(c, target, true,
        allowBeyondLimit: true, write: (_) async {});
    expect(c.inventory.where((i) => i.isAttuned), hasLength(4));
    await InventoryActionsService.equip(
        c, InventoryTarget(c.inventory.last), true,
        write: (_) async {});
    await InventoryActionsService.equip(
        c, InventoryTarget(c.inventory.last), false,
        write: (_) async {});
    expect(c.inventory.last.isAttuned, true);
  });
  test(
      'A failed write restores objects, wallet, AC and timestamp; no half-migration',
      () async {
    final c = flow.mixed({'fighter': 1})..inventory = [item(armor: true)];
    final before = jsonEncode(c.toJson()), original = c.inventory.single;
    await expectLater(
        InventoryActionsService.equip(c, InventoryTarget(original), true,
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    expect(identical(c.inventory.single, original), true);
    expect(original.instanceId, isNull);
    await expectLater(
        InventoryActionsService.editWallet(c, const Wallet(gold: 450),
            expected: Wallet.read(c), write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Concurrent additions serialize; repeated removal cannot delete the next identical item',
      () async {
    final c = flow.mixed({'fighter': 1});
    await Future.wait([
      InventoryActionsService.add(c, [item()], write: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }),
      InventoryActionsService.add(c, [item()], write: (_) async {})
    ]);
    expect(c.inventory, hasLength(2));
    final target = InventoryTarget(c.inventory.first);
    await InventoryActionsService.remove(c, target, write: (_) async {});
    await expectLater(
        InventoryActionsService.remove(c, target, write: (_) async {}),
        throwsStateError);
    expect(c.inventory, hasLength(1));
  });
  test(
      'Zero quantity stays readable, stops equipment; split creates a separate personal stack',
      () async {
    final c = flow.mixed({'fighter': 1})
      ..inventory = [item(quantity: 8, equipped: true, attuned: true)];
    await InventoryActionsService.split(
        c, InventoryTarget(c.inventory.single), 3,
        write: (_) async {});
    expect(c.inventory.map((i) => i.quantity), [5, 3]);
    expect(c.inventory.map((i) => i.instanceId).toSet(), hasLength(2));
    expect(c.inventory.last.isEquipped, false);
    expect(c.inventory.last.isAttuned, false);
    await InventoryActionsService.quantity(
        c, InventoryTarget(c.inventory.first), 0,
        write: (_) async {});
    expect(c.inventory, hasLength(2));
    expect(c.inventory.first.isEquipped, false);
    expect(c.inventory.first.isAttuned, false);
    await expectLater(
        InventoryActionsService.equip(
            c, InventoryTarget(c.inventory.first), true,
            write: (_) async {}),
        throwsStateError);
  });
  test(
      'Wallet preserves denominations and detects a stale editor; invalid data cannot overwrite it',
      () async {
    final c = flow.mixed({'fighter': 1});
    final before = Wallet.read(c);
    await InventoryActionsService.editWallet(
        c, const Wallet(platinum: 1, gold: 450, silver: 3, copper: 7),
        expected: before, write: (_) async {});
    expect(Wallet.read(c).totalCopper, 46037);
    await expectLater(
        InventoryActionsService.editWallet(c, const Wallet(gold: 0),
            expected: before, write: (_) async {}),
        throwsStateError);
    await expectLater(
        InventoryActionsService.editWallet(c, const Wallet(gold: -1),
            expected: Wallet.read(c), write: (_) async {}),
        throwsArgumentError);
    expect(c.goldPieces, 450);
  });
  test(
      'Stale quantity, impossible split, empty consumption and negative additions leave no changes',
      () async {
    final c = flow.mixed({'fighter': 1});
    await InventoryActionsService.add(c, [item(quantity: 4)],
        write: (_) async {});
    final target = InventoryTarget(c.inventory.single);
    await InventoryActionsService.quantity(c, target, 6, write: (_) async {});
    await expectLater(
        InventoryActionsService.quantity(c, target, 7,
            expected: 4, write: (_) async {}),
        throwsStateError);
    final before = jsonEncode(c.toJson());
    await expectLater(
        InventoryActionsService.split(c, target, 6, write: (_) async {}),
        throwsArgumentError);
    await expectLater(
        InventoryActionsService.add(c, [item(quantity: -1)],
            write: (_) async {}),
        throwsArgumentError);
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Editing a personal item never mutates the library; stale edits cannot overwrite consumption',
      () async {
    final c = flow.mixed({'fighter': 1});
    final template = ItemService.createItemFromTemplate('longsword')!;
    await InventoryActionsService.add(c, [template], write: (_) async {});
    final original = InventoryActionsService.clone(c.inventory.single),
        target = InventoryTarget(c.inventory.single);
    final edited = InventoryActionsService.clone(original)
      ..nameRu = 'Клинок рассвета'
      ..quantity = 2;
    await InventoryActionsService.revise(c, target, edited,
        expected: original, write: (_) async {});
    expect(c.inventory.single.instanceId, original.instanceId);
    expect(c.inventory.single.id, isNot(original.id));
    expect(
        ItemService.getItemById('longsword')!.nameRu, isNot('Клинок рассвета'));
    await InventoryActionsService.consume(
        c, InventoryTarget(c.inventory.single),
        write: (_) async {});
    await expectLater(
        InventoryActionsService.revise(c, target, edited,
            expected: original, write: (_) async {}),
        throwsStateError);
    expect(c.inventory.single.quantity, 1);
  });
  test(
      'Using the last item retains the empty stack and cannot spend below zero',
      () async {
    final c = flow.mixed({'fighter': 1});
    await InventoryActionsService.add(c, [item()], write: (_) async {});
    final target = InventoryTarget(c.inventory.single);
    await InventoryActionsService.consume(c, target, write: (_) async {});
    expect(c.inventory.single.quantity, 0);
    await expectLater(
        InventoryActionsService.consume(c, target, write: (_) async {}),
        throwsStateError);
    expect(c.inventory.single.quantity, 0);
  });
  test(
      'Local restart and native bundle keep independent identity and required attunement',
      () async {
    final c = flow.mixed({'fighter': 1})..id = 'inventory-transfer';
    final one = item()..requiresAttunement = true;
    await InventoryActionsService.add(c, [one, one]);
    final ids = c.inventory.map((i) => i.instanceId).toList();
    final box = Hive.box<Character>('characters');
    await box.flush();
    await box.close();
    await StorageService.init();
    final loaded = StorageService.getCharacter(c.id)!;
    expect(loaded.inventory.map((i) => i.instanceId), ids);
    expect(loaded.inventory.every((i) => i.requiresAttunement), true);
    final file = File('${dir.path}/inventory.qdnd');
    await QdndBundleExportService.exportCharacterToFile(loaded, file);
    final imported = await QdndBundleImportService.importFile(file);
    expect(imported.character, isNotNull);
    expect(imported.character.inventory.map((i) => i.instanceId), ids);
    await InventoryActionsService.remove(
        imported.character, InventoryTarget(imported.character.inventory.first),
        write: (_) async {});
    expect(imported.character.inventory, hasLength(1));
  });
}
