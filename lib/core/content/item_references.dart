import '../models/character.dart';
import '../models/item.dart';
import '../services/item_service.dart';
import '../services/storage_service.dart';
import 'content_catalog.dart';
import 'content_identity.dart';

/// C02 · personal item instances on the shared content model (see
/// docs/CONTENT_MODEL_C01_C04_2026-10-29.md).
///
/// An instance keeps its own copy of the definition; [Item.variantId] says
/// which book variant that copy came from and [Item.familyId] which concept
/// it is. Nothing here rewrites a hero's copy: a newer book version is only
/// offered ([bookUpdate]) and taken on the player's tap.
abstract final class ItemReferences {
  /// The variant an item's definition is, personal fields aside. Instances
  /// and book records with the same definition share it.
  static String variantOf(Item item) =>
      ContentIdentityRegistry.variantIdOf(ContentRecords.item(item));

  /// Stamps a new instance with the variant and family of its definition.
  static Item stamp(Item instance, Item definition,
      [ContentIdentityRegistry? registry]) {
    final variant = variantOf(definition);
    instance.variantId = variant;
    instance.familyId =
        (registry ?? ContentIdentityService.current).familyOfVariant(variant);
    return instance;
  }

  /// Links one stored instance. An unlinked one gets a reference only when
  /// its own copy is a known definition, exactly; a linked one follows family
  /// merges. Returns true when anything changed.
  static bool link(Item item, ContentIdentityRegistry registry) {
    var changed = false;
    if (item.variantId == null) {
      final own = variantOf(item);
      if (registry.familyOfVariant(own) == null) return false;
      item.variantId = own;
      changed = true;
    }
    final family = registry.familyOfVariant(item.variantId!);
    if (family != null && family != item.familyId) {
      item.familyId = family;
      changed = true;
    }
    return changed;
  }

  /// Links every saved hero's inventory, one hero at a time; a hero whose
  /// save fails keeps the references it had.
  static Future<({int linked, int deferred})> linkStoredCharacters(
      ContentIdentityRegistry registry,
      {Future<void> Function(Character)? write}) async {
    var linked = 0, deferred = 0;
    for (final hero in StorageService.getAllCharacters()) {
      final before = [
        for (final item in hero.inventory) (item.variantId, item.familyId)
      ];
      var changed = 0;
      for (final item in hero.inventory) {
        if (link(item, registry)) changed++;
      }
      if (changed == 0) continue;
      try {
        await (write ?? StorageService.saveCharacter)(hero);
        linked += changed;
      } catch (_) {
        for (final (i, item) in hero.inventory.indexed) {
          item.variantId = before[i].$1;
          item.familyId = before[i].$2;
        }
        deferred++;
      }
    }
    return (linked: linked, deferred: deferred);
  }

  /// The book's newer version of an instance's definition, if there is one:
  /// the instance is an unchanged copy of its variant, and the record it came
  /// from now says something else. A personally edited copy, a removed book
  /// or an up-to-date copy yields null.
  static Item? bookUpdate(Item instance, {Iterable<Item>? catalog}) {
    final variant = instance.variantId;
    if (variant == null || variantOf(instance) != variant) return null;
    final record = (catalog ?? ItemService.getAllItems())
        .where((i) => i.id == instance.id && i.sourceId == instance.sourceId)
        .firstOrNull;
    if (record == null || variantOf(record) == variant) return null;
    return record;
  }

  /// What a new version changes, by definition field (`descriptionRu`,
  /// `weight`, `weaponProperties` …), for the update's one-line summary.
  static List<String> changes(Item from, Item to) {
    Map<String, dynamic> fields(Item i) => i.toJson()
      ..removeWhere((key, _) => const {
            'id', 'sourceId', 'customImagePath', 'instanceId', 'quantity',
            'isEquipped', 'isAttuned', 'familyId', 'variantId'
          }.contains(key));
    final a = fields(from), b = fields(to);
    return [
      for (final key in {...a.keys, ...b.keys})
        if ('${a[key]}' != '${b[key]}') key
    ];
  }
}
