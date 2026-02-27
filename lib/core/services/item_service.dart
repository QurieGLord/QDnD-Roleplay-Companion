import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/item.dart';
import 'storage_service.dart';

/// Service for managing D&D items (weapons, armor, gear)
/// Loads items from JSON database and provides item templates
class ItemService {
  static List<Item> _itemTemplates = [];
  static bool _isInitialized = false;

  /// Load all items from JSON database and Local Storage
  /// Should be called once during app initialization
  static Future<void> loadItems() async {
    if (_isInitialized) {
      print('⚠️ ItemService: Already initialized, skipping...');
      return;
    }

    try {
      print('📦 ItemService: Loading items from JSON and Storage...');
      _itemTemplates = [];

      // 1. Load standard JSON items from assets
      try {
        final String jsonString =
            await rootBundle.loadString('assets/data/items.json');
        final List<dynamic> jsonList = json.decode(jsonString);

        final assetItems = jsonList.map((json) {
          return Item.fromJson(json as Map<String, dynamic>);
        }).toList();

        _itemTemplates.addAll(assetItems);
        print('   - Loaded ${assetItems.length} items from assets');
      } catch (e) {
        print('❌ ItemService: Failed to load asset items: $e');
      }

      // 2. Load custom items from Storage (e.g. imported from XML)
      try {
        final storedItems = StorageService.getAllItems();
        if (storedItems.isNotEmpty) {
          _itemTemplates.addAll(storedItems);
          print('   - Loaded ${storedItems.length} items from storage');
        }
      } catch (e) {
        print('❌ ItemService: Failed to load stored items: $e');
      }

      _isInitialized = true;

      print(
          '✅ ItemService: Total loaded ${_itemTemplates.length} item templates');
      print(
          '   - Weapons: ${_itemTemplates.where((i) => i.type == ItemType.weapon).length}');
      print(
          '   - Armor: ${_itemTemplates.where((i) => i.type == ItemType.armor).length}');
      print(
          '   - Gear: ${_itemTemplates.where((i) => i.type == ItemType.gear).length}');
    } catch (e, stackTrace) {
      print('❌ ItemService: Fatal error loading items: $e');
      print('Stack trace: $stackTrace');
      // Don't clear templates here, keep what we managed to load
      _isInitialized = false;
      rethrow;
    }
  }

  /// Reload items (e.g. after import)
  static Future<void> reload() async {
    print('🔄 ItemService: Reloading items...');
    _isInitialized = false;
    await loadItems();
  }

  /// Get all item templates
  static List<Item> getAllItems() {
    if (!_isInitialized) {
      print('⚠️ ItemService: Not initialized! Call loadItems() first.');
      return [];
    }
    return List.from(_itemTemplates);
  }

  /// Get items filtered by type
  static List<Item> getItemsByType(ItemType type) {
    if (!_isInitialized) {
      print('⚠️ ItemService: Not initialized! Call loadItems() first.');
      return [];
    }
    return _itemTemplates.where((item) => item.type == type).toList();
  }

  /// Get weapons only
  static List<Item> getWeapons() {
    return getItemsByType(ItemType.weapon);
  }

  /// Get armor only (including shields)
  static List<Item> getArmor() {
    return getItemsByType(ItemType.armor);
  }

  /// Get gear only
  static List<Item> getGear() {
    return getItemsByType(ItemType.gear);
  }

  /// Find item template by ID
  static Item? getItemById(String id) {
    if (!_isInitialized) {
      print('⚠️ ItemService: Not initialized! Call loadItems() first.');
      return null;
    }

    try {
      return _itemTemplates.firstWhere((item) => item.id == id);
    } catch (e) {
      print('⚠️ ItemService: Item not found with id: $id');
      return null;
    }
  }

  /// Create a new Item instance from template
  /// This creates a copy that can be added to character inventory
  static Item? createItemFromTemplate(String templateId, {int quantity = 1}) {
    final template = getItemById(templateId);
    if (template == null) {
      print(
          '❌ ItemService: Cannot create item - template not found: $templateId');
      return null;
    }

    // Create a new Item instance from the template
    return Item(
      id: template.id,
      nameEn: template.nameEn,
      nameRu: template.nameRu,
      descriptionEn: template.descriptionEn,
      descriptionRu: template.descriptionRu,
      type: template.type,
      rarity: template.rarity,
      quantity: quantity,
      weight: template.weight,
      valueInCopper: template.valueInCopper,
      isEquipped: false, // New items start unequipped
      isAttuned: false,
      weaponProperties: template.weaponProperties != null
          ? WeaponProperties(
              damageDice: template.weaponProperties!.damageDice,
              damageType: template.weaponProperties!.damageType,
              weaponTags:
                  List<String>.from(template.weaponProperties!.weaponTags),
              range: template.weaponProperties!.range,
              longRange: template.weaponProperties!.longRange,
              versatileDamageDice:
                  template.weaponProperties!.versatileDamageDice,
            )
          : null,
      armorProperties: template.armorProperties != null
          ? ArmorProperties(
              baseAC: template.armorProperties!.baseAC,
              armorType: template.armorProperties!.armorType,
              addDexModifier: template.armorProperties!.addDexModifier,
              maxDexBonus: template.armorProperties!.maxDexBonus,
              strengthRequirement:
                  template.armorProperties!.strengthRequirement,
              stealthDisadvantage:
                  template.armorProperties!.stealthDisadvantage,
            )
          : null,
      isMagical: template.isMagical,
      iconName: template.iconName,
    );
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Get total number of item templates
  static int get itemCount => _itemTemplates.length;
}
