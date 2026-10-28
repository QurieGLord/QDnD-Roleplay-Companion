import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/content_identity.dart';
import 'package:qd_and_d/core/content/item_references.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/services/inventory_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

import '../../multiclass_magic_flow_test.dart' as flow;

Item rope({String description = 'Fifty feet of hempen rope.', double weight = 10}) =>
    Item(
        id: 'rope',
        sourceId: 'phb',
        nameEn: 'Rope',
        nameRu: 'Верёвка',
        descriptionEn: description,
        descriptionRu: 'Пеньковая верёвка.',
        type: ItemType.gear,
        rarity: ItemRarity.common,
        weight: weight);

ContentIdentityRegistry registryOf(List<Item> items) {
  var n = 0;
  return ContentIdentityRegistry.empty()
    ..reconcile(ContentKind.item,
        ContentCatalog(items.map(ContentRecords.item)).families,
        newId: () => 'f${n++}');
}

void main() {
  test('a new instance is stamped with its definition; personal fields aside',
      () {
    final book = rope();
    final registry = registryOf([book]);
    final instance = ItemReferences.stamp(
        InventoryActionsService.clone(book)
          ..instanceId = 'a'
          ..quantity = 3
          ..isEquipped = true,
        book,
        registry);
    expect(instance.variantId, ItemReferences.variantOf(book));
    expect(instance.familyId,
        registry.familyOfRecord(ContentKind.item, 'phb', 'rope'));
    // Personal fields and the references themselves are not the definition.
    expect(ItemReferences.variantOf(instance), instance.variantId);
  });

  test('migration links only exact copies, once', () {
    final book = rope();
    final registry = registryOf([book]);
    final copy = InventoryActionsService.clone(book)..quantity = 2;
    final edited = InventoryActionsService.clone(book)..weight = 4;
    expect(ItemReferences.link(copy, registry), isTrue);
    expect(copy.variantId, ItemReferences.variantOf(book));
    expect(ItemReferences.link(copy, registry), isFalse);
    // A copy that matches no known definition stays as it is.
    expect(ItemReferences.link(edited, registry), isFalse);
    expect(edited.variantId, isNull);
    expect(edited.familyId, isNull);
  });

  test('a newer book version is offered for an unchanged copy only', () {
    final old = rope();
    final instance = ItemReferences.stamp(
        InventoryActionsService.clone(old)..instanceId = 'a', old,
        registryOf([old]));
    final updated = rope(description: 'Fifty feet of silk rope.', weight: 5);
    expect(ItemReferences.bookUpdate(instance, catalog: [old]), isNull);
    expect(ItemReferences.bookUpdate(instance, catalog: [updated]),
        same(updated));
    expect(ItemReferences.changes(instance, updated),
        unorderedEquals(['descriptionEn', 'weight']));
    // The book was removed: nothing to offer.
    expect(ItemReferences.bookUpdate(instance, catalog: const []), isNull);
    // A personally edited copy is the hero's own and is left alone.
    final personal = InventoryActionsService.clone(instance)..weight = 1;
    expect(ItemReferences.bookUpdate(personal, catalog: [updated]), isNull);
  });

  test('taking the new version keeps the stack, equipment and attunement',
      () async {
    final old = rope();
    final hero = flow.mixed({'fighter': 1});
    hero.inventory = [
      ItemReferences.stamp(
          InventoryActionsService.clone(old)
            ..instanceId = 'stack'
            ..quantity = 2
            ..isEquipped = true,
          old,
          registryOf([old]))
    ];
    final updated = rope(weight: 5);
    final owned = hero.inventory.single;
    await InventoryActionsService.adoptBookVersion(
        hero, InventoryTarget(owned), updated,
        expected: InventoryActionsService.clone(owned), write: (_) async {});
    final now = hero.inventory.single;
    expect(now.instanceId, 'stack');
    expect(now.quantity, 2);
    expect(now.isEquipped, isTrue);
    expect(now.weight, 5);
    expect(now.variantId, ItemReferences.variantOf(updated));
    expect(ItemReferences.bookUpdate(now, catalog: [updated]), isNull);
    // A sheet that changed meanwhile is not overwritten.
    final stale = InventoryActionsService.clone(now)..quantity = 9;
    await expectLater(
        InventoryActionsService.adoptBookVersion(
            hero, InventoryTarget(now), rope(weight: 7),
            expected: stale, write: (_) async {}),
        throwsStateError);
    expect(hero.inventory.single.weight, 5);
  });

  test('the references survive JSON and stay out of the definition', () {
    final book = rope();
    final instance = ItemReferences.stamp(
        InventoryActionsService.clone(book), book, registryOf([book]));
    final back = Item.fromJson(instance.toJson());
    expect(back.variantId, instance.variantId);
    expect(back.familyId, instance.familyId);
    expect(book.toJson().containsKey('variantId'), isFalse);
  });

  test('the references survive the Hive store', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('qdnd-item-refs-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    try {
      await StorageService.init();
      final book = rope();
      final hero = flow.mixed({'fighter': 1})
        ..inventory = [
          ItemReferences.stamp(
              InventoryActionsService.clone(book)..instanceId = 'a',
              book,
              registryOf([book]))
        ];
      await StorageService.saveCharacter(hero);
      await Hive.close();
      await StorageService.init();
      final stored = StorageService.getCharacter(hero.id)!.inventory.single;
      expect(stored.variantId, hero.inventory.single.variantId);
      expect(stored.familyId, hero.inventory.single.familyId);
    } finally {
      await Hive.close();
      await dir.delete(recursive: true);
    }
  });
}
