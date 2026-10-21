import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/item.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/features/character_sheet/tabs/inventory_tab.dart';
import 'package:qd_and_d/features/inventory/create_item_screen.dart';
import 'package:qd_and_d/features/inventory/inventory_sheets.dart';
import 'package:qd_and_d/features/inventory/widgets/equipment_deck.dart';
import 'package:qd_and_d/features/inventory/widgets/inventory_item_tile.dart';
import 'multiclass_magic_flow_test.dart' as flow;
import 'multiclass_sheet_integration_test.dart' as widgets;
import 'inventory_actions_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-inventory-widgets-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await ItemService.loadItems();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: equipment, pack and long names adapt at large text, search matches both languages',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = flow.mixed({'fighter': 1})
        ..inventory = [
          fixtures.item(equipped: true)
            ..nameRu =
                'Длинный клинок с именем древнего защитника северных дорог',
          fixtures.item(id: 'armor', armor: true, equipped: true),
          fixtures.item(
              id: 'shield', armor: true, shield: true, equipped: true),
          fixtures.item(id: 'charm', attuned: true)..isMagical = true
        ];
      await tester.pumpWidget(
          widgets.app(InventoryTab(character: c), scale: 1.5, locale: locale));
      await tester.pumpAndSettle();
      expect(find.byType(EquipmentDeck), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(TextField), 350,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sword');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.inventory, hasLength(4));
    });
  }
  testWidgets('A hold offers contextual actions and does not mutate the item',
      (tester) async {
    final c = flow.mixed({'fighter': 1})
      ..inventory = [fixtures.item(equipped: true)];
    await tester.pumpWidget(widgets.app(InventoryTab(character: c)));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(InventoryItemTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Item details'), findsOneWidget);
    expect(find.text('Unequip'), findsOneWidget);
    expect(c.inventory.single.isEquipped, true);
    expect(c.inventory.single.instanceId, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Wallet opens without keyboard, rejects invalid data and cancel preserves values',
      (tester) async {
    final c = flow.mixed({'fighter': 1})..goldPieces = 450;
    await tester.pumpWidget(widgets.app(Builder(
        builder: (context) => TextButton(
            onPressed: () => showInventoryWallet(context, c),
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, false);
    await tester.enterText(
        find.byKey(const ValueKey('wallet-denomination-1')), '-1');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Whole number of zero or more'), findsOneWidget);
    expect(c.goldPieces, 450);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['ru', 'en']) {
    testWidgets(
        '$locale: Forge accepts decimal value with stable currency and preserves every declared armor property',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = fixtures.item(armor: true)
        ..nameRu = 'Панцирь'
        ..nameEn = 'Breastplate'
        ..requiresAttunement = true
        ..isMagical = true;
      original.armorProperties = ArmorProperties(
          baseAC: 14,
          armorType: ArmorType.medium,
          addDexModifier: true,
          maxDexBonus: 2,
          strengthRequirement: 13,
          stealthDisadvantage: true);
      original.valueInCopper = 1525;
      Item? result;
      await tester.pumpWidget(widgets.app(
          Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    result = await Navigator.push<Item>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CreateItemScreen(initialItem: original)));
                  },
                  child: const Text('Open'))),
          locale: locale));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find
          .widgetWithText(TextButton, locale == 'ru' ? 'Сохранить' : 'Save')
          .first);
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.valueInCopper, 1525);
      expect(result!.armorProperties!.maxDexBonus, 2);
      expect(result!.armorProperties!.strengthRequirement, 13);
      expect(result!.armorProperties!.stealthDisadvantage, true);
      expect(result!.requiresAttunement, true);
      expect(tester.takeException(), isNull);
    });
  }
}
