import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../content/item_references.dart';
import '../models/character.dart';
import '../models/item.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';

/// A reference to a personal stack, never a catalog id. Legacy references are
/// accepted only while that exact object still belongs to this inventory.
class InventoryTarget {
  InventoryTarget(Item item)
      : instanceId = item.instanceId,
        legacy = item;
  final String? instanceId;
  final Item legacy;
  int locate(List<Item> items) {
    if (instanceId == null) {
      return items.indexWhere((i) => identical(i, legacy));
    }
    final matches = [
      for (var i = 0; i < items.length; i++)
        if (items[i].instanceId == instanceId) i
    ];
    if (matches.length != 1) throw StateError('Inventory changed');
    return matches.single;
  }
}

class Wallet {
  const Wallet(
      {this.platinum = 0, this.gold = 0, this.silver = 0, this.copper = 0});
  factory Wallet.read(Character c) => Wallet(
      platinum: c.platinumPieces,
      gold: c.goldPieces,
      silver: c.silverPieces,
      copper: c.copperPieces);
  final int platinum, gold, silver, copper;
  int get totalCopper => platinum * 1000 + gold * 100 + silver * 10 + copper;
  List<int> get values => [platinum, gold, silver, copper];
  bool same(Wallet other) => jsonEncode(values) == jsonEncode(other.values);
  void apply(Character c) {
    c.platinumPieces = platinum;
    c.goldPieces = gold;
    c.silverPieces = silver;
    c.copperPieces = copper;
  }
}

class AttunementLimit implements Exception {
  const AttunementLimit();
}

/// Inventory, effective AC and money commit together. All modifications are
/// prepared on detached items, serialized with the rest of the character sheet.
class InventoryActionsService {
  static Item clone(Item item) => Item.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(item.toJson())) as Map));
  static List<Item> _ownedCopies(List<Item> items) {
    final used = <String>{};
    return items.map((item) {
      final copy = clone(item);
      if (copy.instanceId == null ||
          copy.instanceId!.isEmpty ||
          !used.add(copy.instanceId!)) {
        copy.instanceId = const Uuid().v4();
        used.add(copy.instanceId!);
      }
      return copy;
    }).toList();
  }

  static Future<void> _change(Character c, void Function(List<Item>) update,
          {Future<void> Function(Character)? write,
          Wallet? wallet,
          Wallet? expectedWallet}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (expectedWallet != null && !expectedWallet.same(Wallet.read(c))) {
          throw StateError('Wallet changed');
        }
        final previous = c.inventory,
            coins = Wallet.read(c),
            timestamp = c.updatedAt,
            ac = c.armorClass,
            override = c.armorClassOverride,
            automatic = c.usesAutomaticArmorClass;
        final next = _ownedCopies(previous);
        update(next);
        if (next.any((i) =>
            i.quantity < 0 ||
            !i.weight.isFinite ||
            i.weight < 0 ||
            i.valueInCopper < 0)) {
          throw ArgumentError('Invalid item values');
        }
        if (wallet != null && wallet.values.any((n) => n < 0)) {
          throw ArgumentError('Invalid wallet');
        }
        try {
          c.inventory = next;
          wallet?.apply(c);
          c.recalculateAC();
          await (write ?? StorageService.saveCharacter)(c);
        } catch (_) {
          c.inventory = previous;
          coins.apply(c);
          c.armorClass = ac;
          c.armorClassOverride = override;
          c.usesAutomaticArmorClass = automatic;
          c.updatedAt = timestamp;
          rethrow;
        }
      });
  static Future<void> add(Character c, Iterable<Item> items,
      {Future<void> Function(Character)? write}) {
    final added = items.map(clone).toList();
    return _change(c, (next) {
      for (final item in added) {
        item.instanceId = const Uuid().v4();
        item.isEquipped = false;
        item.isAttuned = false;
        next.add(item);
      }
    }, write: write);
  }

  static Future<void> _item(Character c, InventoryTarget target,
      void Function(List<Item>, int) update,
      {Future<void> Function(Character)? write}) {
    // Resolve inside the queue, against the live list before legacy IDs migrate.
    return GameplayActionsService.serializeCharacter(c, () async {
      final index = target.locate(c.inventory);
      if (index < 0) {
        throw StateError('Item no longer belongs to this character');
      }
      // Already in the shared queue: commit directly, without queue re-entry.
      await _transactionAt(c, index, update, write: write);
    });
  }

  static Future<void> _transactionAt(
      Character c, int index, void Function(List<Item>, int) update,
      {Future<void> Function(Character)? write}) async {
    final before = c.inventory,
        time = c.updatedAt,
        ac = c.armorClass,
        override = c.armorClassOverride,
        automatic = c.usesAutomaticArmorClass;
    final next = _ownedCopies(before);
    update(next, index);
    if (next.any((i) => i.quantity < 0)) {
      throw ArgumentError('Negative quantity');
    }
    try {
      c.inventory = next;
      c.recalculateAC();
      await (write ?? StorageService.saveCharacter)(c);
    } catch (_) {
      c.inventory = before;
      c.armorClass = ac;
      c.armorClassOverride = override;
      c.usesAutomaticArmorClass = automatic;
      c.updatedAt = time;
      rethrow;
    }
  }

  static Future<void> equip(Character c, InventoryTarget target, bool value,
          {Future<void> Function(Character)? write}) =>
      _item(c, target, (items, index) {
        final item = items[index];
        if (value && item.quantity == 0) throw StateError('Empty stack');
        if (value && item.armorProperties != null) {
          final shield = item.armorProperties!.armorType == ArmorType.shield;
          for (var i = 0; i < items.length; i++) {
            final armor = items[i].armorProperties;
            if (i != index &&
                armor != null &&
                (armor.armorType == ArmorType.shield) == shield) {
              items[i].isEquipped = false;
            }
          }
        }
        item.isEquipped = value;
      }, write: write);
  static Future<void> attune(Character c, InventoryTarget target, bool value,
          {bool allowBeyondLimit = false,
          Future<void> Function(Character)? write}) =>
      _item(c, target, (items, index) {
        final item = items[index];
        if (value && item.quantity == 0) throw StateError('Empty stack');
        if (value &&
            !item.isAttuned &&
            !allowBeyondLimit &&
            items.where((i) => i.isAttuned).length >= 3) {
          throw const AttunementLimit();
        }
        item.isAttuned = value;
      }, write: write);
  static Future<void> quantity(Character c, InventoryTarget target, int value,
          {int? expected, Future<void> Function(Character)? write}) =>
      _item(c, target, (items, index) {
        final item = items[index];
        if (expected != null && item.quantity != expected) {
          throw StateError('Quantity changed');
        }
        if (value < 0) throw ArgumentError('Negative quantity');
        item.quantity = value;
        if (value == 0) {
          item.isEquipped = false;
          item.isAttuned = false;
        }
      }, write: write);
  static Future<void> consume(Character c, InventoryTarget target,
          {Future<void> Function(Character)? write}) =>
      _item(c, target, (items, index) {
        final item = items[index];
        if (item.quantity <= 0) throw StateError('Empty stack');
        item.quantity--;
        if (item.quantity == 0) {
          item.isEquipped = false;
          item.isAttuned = false;
        }
      }, write: write);
  static Future<void> remove(Character c, InventoryTarget target,
          {Future<void> Function(Character)? write}) =>
      _item(c, target, (items, index) => items.removeAt(index), write: write);
  static Future<void> revise(Character c, InventoryTarget target, Item result,
      {required Item expected, Future<void> Function(Character)? write}) {
    final proposal = clone(result), baseline = jsonEncode(expected.toJson());
    return _item(c, target, (items, index) {
      final actual = clone(items[index])..instanceId = expected.instanceId;
      if (jsonEncode(actual.toJson()) != baseline) {
        throw StateError('Item changed during editing');
      }
      if (proposal.quantity < 0 ||
          !proposal.weight.isFinite ||
          proposal.weight < 0 ||
          proposal.valueInCopper < 0) {
        throw ArgumentError('Invalid item');
      }
      proposal.instanceId = items[index].instanceId;
      proposal.id = const Uuid().v4();
      proposal.sourceId = null;
      proposal.isEquipped = items[index].isEquipped && proposal.quantity > 0;
      proposal.isAttuned = items[index].isAttuned && proposal.quantity > 0;
      items[index] = proposal;
      if (proposal.isEquipped && proposal.armorProperties != null) {
        final shield = proposal.armorProperties!.armorType == ArmorType.shield;
        for (var i = 0; i < items.length; i++) {
          final armor = items[i].armorProperties;
          if (i != index &&
              armor != null &&
              (armor.armorType == ArmorType.shield) == shield) {
            items[i].isEquipped = false;
          }
        }
      }
    }, write: write);
  }

  /// C02 · takes the book's newer version into a personal stack. Quantity,
  /// equipment, attunement and the stack itself stay the hero's.
  static Future<void> adoptBookVersion(
      Character c, InventoryTarget target, Item version,
      {required Item expected, Future<void> Function(Character)? write}) {
    final baseline = jsonEncode(expected.toJson());
    return _item(c, target, (items, index) {
      final own = items[index];
      final actual = clone(own)..instanceId = expected.instanceId;
      if (jsonEncode(actual.toJson()) != baseline) {
        throw StateError('Item changed before the update');
      }
      items[index] = ItemReferences.stamp(
          clone(version)
            ..instanceId = own.instanceId
            ..quantity = own.quantity
            ..isEquipped = own.isEquipped
            ..isAttuned = own.isAttuned && version.requiresAttunement
            ..customImagePath = own.customImagePath ?? version.customImagePath,
          version);
    }, write: write);
  }

  static Future<void> split(Character c, InventoryTarget target, int amount,
          {Future<void> Function(Character)? write}) =>
      _item(c, target, (items, index) {
        if (amount <= 0 || amount >= items[index].quantity) {
          throw ArgumentError('Invalid split');
        }
        final copy = clone(items[index])
          ..instanceId = const Uuid().v4()
          ..quantity = amount
          ..isEquipped = false
          ..isAttuned = false;
        items[index].quantity -= amount;
        items.insert(index + 1, copy);
      }, write: write);
  static Future<void> editWallet(Character c, Wallet wallet,
          {required Wallet expected,
          Future<void> Function(Character)? write}) =>
      _change(c, (_) {},
          wallet: wallet, expectedWallet: expected, write: write);
}
