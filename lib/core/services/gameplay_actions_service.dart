import '../magic/magic_slots.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/combat_state.dart';
import '../models/condition.dart';
import 'storage_service.dart';
import 'feature_service.dart';

/// Explicit sheet actions. One write per action; failed writes restore its state.
/// Queues use completion signals, so a failed action cannot poison later ones.
class GameplayActionsService {
  GameplayActionsService._();
  static final _queues = HashMap<Character, Future<void>>.identity();

  /// Shared by journal mutations so a save cannot race sheet resource actions.
  static Future<T> serializeCharacter<T>(
          Character character, Future<T> Function() action) =>
      _serial(character, action);

  static Future<T> _serial<T>(
      Character character, Future<T> Function() action) async {
    final previous = _queues[character];
    final signal = Completer<void>();
    _queues[character] = signal.future;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      signal.complete();
      if (identical(_queues[character], signal.future)) {
        _queues.remove(character);
      }
    }
  }

  static Future<void> _write<T>(Character character, T Function() capture,
      FutureOr<void> Function() apply, void Function(T) restore) async {
    final before = capture();
    final timestamp = character.updatedAt;
    try {
      await apply();
      await StorageService.saveCharacter(character);
    } catch (_) {
      restore(before);
      character.updatedAt = timestamp;
      rethrow;
    }
  }

  static void _nonnegative(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value');
  }

  static Future<void> editHealth(Character c,
      {required int current,
      required int maximum,
      required int temporary,
      bool form = false}) {
    _nonnegative(current);
    _nonnegative(maximum);
    _nonnegative(temporary);
    return _serial(
        c,
        () => _write(c, () => _HealthSnapshot(c), () {
              if (form) {
                c.beastCurrentHp = current;
                c.beastMaxHp = maximum;
              } else {
                c.currentHp = current;
                c.maxHp = maximum;
              }
              c.temporaryHp = temporary;
            }, (before) => before.restore(c)));
  }

  static Future<void> changeHealth(Character c, int amount,
      {required bool healing}) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    return _serial(
        c,
        () => _write(
            c,
            () => _HealthSnapshot(c),
            () => healing
                ? c.heal(amount, persist: false)
                : c.takeDamage(amount, persist: false),
            (before) => before.restore(c)));
  }

  static Future<void> editArmorClass(Character c,
      {required bool automatic, required int value}) {
    if (!automatic) _nonnegative(value);
    return _serial(
        c,
        () => _write(
                c,
                () => (
                      c.armorClass,
                      c.armorClassOverride,
                      c.usesAutomaticArmorClass
                    ), () {
              if (automatic) {
                c.clearArmorClassOverride();
              } else {
                c.armorClass = value;
              }
            }, (before) {
              c.armorClass = before.$1;
              c.armorClassOverride = before.$2;
              c.usesAutomaticArmorClass = before.$3;
            }));
  }

  static void _slotLevel(int level) {
    if (level < 1 || level > 9) throw ArgumentError.value(level, 'level');
  }

  static Future<void> editSpellSlot(Character c, int level, int value) {
    _slotLevel(level);
    _nonnegative(value);
    return _serial(c, () => _slotWrite(c, level, value));
  }

  static Future<bool> changeSpellSlot(Character c, int level, int delta) {
    _slotLevel(level);
    return _serial(c, () async {
      final current =
          level <= c.spellSlots.length ? c.spellSlots[level - 1] : 0;
      final next = math.max(0, current + delta);
      if (next == current) return false;
      await _slotWrite(c, level, next);
      return true;
    });
  }

  static Future<void> _slotWrite(Character c, int level, int value) => _write(
          c,
          () => (List<int>.from(c.spellSlots), List<int>.from(c.maxSpellSlots)),
          () => c.setSpellSlotCount(level, value), (before) {
        c.spellSlots = before.$1;
        c.maxSpellSlots = before.$2;
      });

  static Future<void> allocateMagic(Character c, MagicSlots allocation,
          {String? expectedState, Future<void> Function(Character)? write}) =>
      _serial(c, () async {
        if (c.magicData.isNotEmpty && c.magicData['version'] != 1) {
          throw const FormatException('Unsupported magic state.');
        }
        if (expectedState != null &&
            expectedState !=
                jsonEncode([c.spellSlots, c.maxSpellSlots, c.magicData])) {
          throw StateError('Magic state changed.');
        }
        final beforeSlots = List<int>.of(c.spellSlots),
            beforeMaximum = List<int>.of(c.maxSpellSlots);
        final beforeMagic = c.magicData, timestamp = c.updatedAt;
        try {
          allocation.applyTo(c);
          await (write ?? StorageService.saveCharacter)(c);
        } catch (_) {
          c.spellSlots = beforeSlots;
          c.maxSpellSlots = beforeMaximum;
          c.magicData = beforeMagic;
          c.updatedAt = timestamp;
          rethrow;
        }
      });
  static Future<bool> changeMagicSlot(
          Character c, MagicPool pool, int circle, int delta) =>
      _serial(c, () async {
        final state = MagicSlots.read(c),
            old = MagicSlots.read(c).remaining(pool, circle);
        final next = math.max(0, old + delta);
        if (next == old) return false;
        await _magicSlotWrite(c, state, pool, circle, next);
        return true;
      });
  static Future<void> editMagicSlot(
      Character c, MagicPool pool, int circle, int value) {
    _slotLevel(circle);
    _nonnegative(value);
    return _serial(
        c, () => _magicSlotWrite(c, MagicSlots.read(c), pool, circle, value));
  }

  static Future<void> _magicSlotWrite(Character c, MagicSlots state,
          MagicPool pool, int circle, int value) =>
      _write(
          c,
          () => (
                List<int>.of(c.spellSlots),
                List<int>.of(c.maxSpellSlots),
                c.magicData
              ), () {
        if (pool == MagicPool.pact) {
          final p = state.pact;
          if (p == null || p.circle != circle) {
            throw StateError('No selected Pact pool.');
          }
          MagicSlots.allocation(
                  current: state.current,
                  maximum: state.maximum,
                  pact: PactSlots(
                      owner: p.owner,
                      circle: circle,
                      current: value,
                      maximum: p.maximum))
              .applyTo(c);
        } else {
          final slots = List<int>.of(state.current);
          while (slots.length < circle) {
            slots.add(0);
          }
          slots[circle - 1] = value;
          MagicSlots.allocation(
                  current: slots, maximum: state.maximum, pact: state.pact)
              .applyTo(c);
        }
      }, (before) {
        c.spellSlots = before.$1;
        c.maxSpellSlots = before.$2;
        c.magicData = before.$3;
      });

  static CharacterFeature _ownedResource(
      Character c, CharacterFeature feature) {
    for (final owned in c.features) {
      if (identical(owned, feature) && owned.resourcePool != null) return owned;
    }
    final matching = c.features
        .where((f) => f.id == feature.id && f.resourcePool != null)
        .toList();
    if (matching.length != 1) {
      throw StateError('Resource is absent or ambiguous');
    }
    return matching.single;
  }

  static int resourceCurrent(Character c, CharacterFeature f) =>
      Character.isChannelDivinityResource(f)
          ? c.editableChannelDivinityCharges
          : f.resourcePool!.currentUses;

  static Future<void> editResource(
      Character c, CharacterFeature feature, int value) {
    _nonnegative(value);
    return _serial(
        c, () => _resourceWrite(c, _ownedResource(c, feature), value));
  }

  static Future<bool> changeResource(
          Character c, CharacterFeature feature, int delta) =>
      _serial(c, () async {
        final owned = _ownedResource(c, feature);
        final current = resourceCurrent(c, owned);
        final next = math.max(0, current + delta);
        if (current == next) return false;
        await _resourceWrite(c, owned, next);
        return true;
      });

  /// One explicit activation, including any healing it grants. Checks the
  /// actual owned reserve inside the shared queue, never before awaiting it.
  static Future<bool> spendResource(Character c, CharacterFeature feature,
          {int amount = 1, int healing = 0}) =>
      activateResource(c, feature, amount: amount, healing: healing)
          .then((result) => result.spent);

  /// Feedback reports the actual HP restored, including form HP and overfill,
  /// rather than describing the raw die result as healing that never happened.
  static Future<({bool spent, int healed})> activateResource(
      Character c, CharacterFeature feature,
      {int amount = 1, int healing = 0, bool activateSacredWeapon = false}) {
    if (amount < 1) throw ArgumentError.value(amount, 'amount');
    _nonnegative(healing);
    return _serial(c, () async {
      final owned = _ownedResource(c, feature);
      if (activateSacredWeapon && c.isSacredWeaponActive) {
        return (spent: false, healed: 0);
      }
      final current = resourceCurrent(c, owned);
      if (current < amount) return (spent: false, healed: 0);
      var effectiveHealing = 0;
      await _write(
          c,
          () => (
                _HealthSnapshot(c),
                c.channelDivinityCharges,
                [
                  for (final f in c.features)
                    if (f.resourcePool != null)
                      (f.resourcePool!, f.resourcePool!.currentUses)
                ],
                c.isSacredWeaponActive,
              ), () async {
        if (Character.isChannelDivinityResource(owned)) {
          c.setChannelDivinityCharges(current - amount);
        } else {
          owned.resourcePool!.setCurrentUses(current - amount);
        }
        if (activateSacredWeapon) c.isSacredWeaponActive = true;
        if (healing > 0) {
          final form = c.isWildShaped &&
              c.beastCurrentHp != null &&
              c.beastMaxHp != null;
          final before = form ? c.beastCurrentHp! : c.currentHp;
          await c.heal(healing, source: owned.nameEn, persist: false);
          effectiveHealing = (form ? c.beastCurrentHp! : c.currentHp) - before;
        }
      }, (before) {
        before.$1.restore(c);
        c.channelDivinityCharges = before.$2;
        for (final entry in before.$3) {
          entry.$1.currentUses = entry.$2;
        }
        c.isSacredWeaponActive = before.$4;
      });
      return (spent: true, healed: effectiveHealing);
    });
  }

  /// Ending an active effect is independent of its already-spent reserve.
  static Future<bool> endSacredWeapon(Character c) => _serial(c, () async {
        if (!c.isSacredWeaponActive) return false;
        await _write(
            c,
            () => c.isSacredWeaponActive,
            () => c.isSacredWeaponActive = false,
            (before) => c.isSacredWeaponActive = before);
        return true;
      });

  /// The shared Channel Divinity authority also supports legacy characters
  /// whose explicit remainder exists without a hydrated pool definition.
  static Future<bool> spendChannelDivinity(Character c, {int amount = 1}) {
    if (amount < 1) throw ArgumentError.value(amount, 'amount');
    return _serial(c, () async {
      final current = c.channelDivinityCharges;
      if (current < amount) return false;
      await _write(
          c,
          () => (
                current,
                [
                  for (final f in c.channelDivinityResources)
                    (f.resourcePool!, f.resourcePool!.currentUses)
                ]
              ),
          () => c.setChannelDivinityCharges(current - amount), (before) {
        c.channelDivinityCharges = before.$1;
        for (final pool in before.$2) {
          pool.$1.currentUses = pool.$2;
        }
      });
      return true;
    });
  }

  static Future<void> _resourceWrite(
          Character c, CharacterFeature owned, int value) =>
      _write(
          c,
          () => (
                c.channelDivinityCharges,
                [
                  for (final f in c.features)
                    if (f.resourcePool != null)
                      (f.resourcePool!, f.resourcePool!.currentUses)
                ]
              ), () {
        if (Character.isChannelDivinityResource(owned)) {
          c.setChannelDivinityCharges(value);
        } else {
          owned.resourcePool!.setCurrentUses(value);
        }
      }, (before) {
        c.channelDivinityCharges = before.$1;
        for (final entry in before.$2) {
          entry.$1.currentUses = entry.$2;
        }
      });

  static CharacterFeature? arcanumFeature(Character c, int level) {
    final number = RegExp('(^|[^0-9])$level' r'([^0-9]|$)');
    for (final f in c.features) {
      final id = f.id.toLowerCase().replaceAll('_', '-');
      final name = f.nameEn.toLowerCase();
      if ((id.startsWith('mystic-arcanum') && number.hasMatch(id)) ||
          (name.contains('mystic arcanum') && number.hasMatch(name))) {
        return f;
      }
    }
    return null;
  }

  static Future<void> editArcanum(Character c, int level, int value) {
    if (level < 6 || level > 9) throw ArgumentError.value(level, 'level');
    _nonnegative(value);
    return _serial(c, () => _arcanumWrite(c, level, value));
  }

  static Future<bool> changeArcanum(Character c, int level, int delta) {
    if (level < 6 || level > 9) throw ArgumentError.value(level, 'level');
    return _serial(c, () async {
      final current = arcanumFeature(c, level)?.resourcePool?.currentUses ?? 0;
      final next = math.max(0, current + delta);
      if (current == next) return false;
      await _arcanumWrite(c, level, next);
      return true;
    });
  }

  static Future<void> _arcanumWrite(Character c, int level, int value) async {
    final existing = arcanumFeature(c, level);
    final owned = existing ??
        FeatureService.getFeatureById('mystic-arcanum-${level}th-level')
            ?.copyForCharacter();
    if (owned == null) throw StateError('Arcanum definition is unavailable');
    final oldPool = owned.resourcePool;
    final oldCurrent = oldPool?.currentUses;
    final timestamp = c.updatedAt;
    try {
      if (existing == null) c.features.add(owned);
      // Create missing metadata only on an explicit edit/restore action.
      owned.resourcePool ??= ResourcePool(
          currentUses: 0, maxUses: 1, recoveryType: RecoveryType.longRest);
      owned.resourcePool!.setCurrentUses(value);
      await StorageService.saveCharacter(c);
    } catch (_) {
      if (existing == null) c.features.remove(owned);
      owned.resourcePool = oldPool;
      if (oldPool != null) oldPool.currentUses = oldCurrent!;
      c.updatedAt = timestamp;
      rethrow;
    }
  }

  static Future<bool> setCondition(Character c, ConditionType condition,
          {required bool active}) =>
      _serial(c, () async {
        if (c.activeConditions.contains(condition) == active) return false;
        await _write(
            c,
            () => (
                  List<ConditionType>.from(c.activeConditions),
                  List<CombatLogEntry>.from(c.combatState.combatLog)
                ), () {
          if (active) {
            c.addCondition(condition, persist: false);
          } else {
            c.removeCondition(condition, persist: false);
          }
        }, (before) {
          c.activeConditions = before.$1;
          c.combatState.combatLog = before.$2;
        });
        return true;
      });

  static Future<void> editExhaustion(Character c, int value) {
    if (value < 0 || value > 6) throw ArgumentError.value(value, 'value');
    return _serial(
        c,
        () => _write(
            c,
            () => c.exhaustionLevel,
            () => c.exhaustionLevel = value,
            (before) => c.exhaustionLevel = before));
  }

  /// One death saving throw outside the combat screen, by the same rules:
  /// a natural 20 restores 1 HP, a natural 1 counts as two failures, 10 or
  /// more is a success. In combat it is limited to one per round.
  static Future<bool> rollDeathSave(Character c, int roll) {
    if (roll < 1 || roll > 20) throw ArgumentError.value(roll, 'roll');
    return _serial(c, () async {
      final saves = c.deathSaves;
      if (c.currentHp > 0 || saves.isDead || saves.isStabilized) return false;
      if (!c.combatState.canRollDeathSaveThisRound) return false;
      await _write(c, () => _HealthSnapshot(c), () async {
        if (c.combatState.isInCombat) {
          c.combatState.markDeathSaveRolledThisRound();
        }
        if (roll == 20) {
          await c.heal(1, source: 'Death save (nat 20)', persist: false);
        } else if (roll == 1) {
          saves.addFailure();
          saves.addFailure();
        } else if (roll >= 10) {
          saves.addSuccess();
        } else {
          saves.addFailure();
        }
        c.updatedAt = DateTime.now();
      }, (before) => before.restore(c));
      return true;
    });
  }

  static Future<void> rest(Character c, {required bool short}) => _serial(
      c,
      () => _write(c, () => _RestSnapshot(c), () {
            FeatureService.prepareKnownResourcePools(c);
            if (short) {
              c.shortRest();
            } else {
              c.longRest();
            }
          }, (before) => before.restore(c)));
}

class _HealthSnapshot {
  _HealthSnapshot(Character c)
      : hp = c.currentHp,
        maximum = c.maxHp,
        temporary = c.temporaryHp,
        beastHp = c.beastCurrentHp,
        beastMaximum = c.beastMaxHp,
        form = c.isWildShaped,
        raging = c.isRaging,
        frenzied = c.isFrenzied,
        exhaustion = c.exhaustionLevel,
        successes = c.deathSaves.successes,
        failures = c.deathSaves.failures,
        combat = CombatState.fromJson(c.combatState.toJson());
  final int hp, maximum, temporary, exhaustion, successes, failures;
  final int? beastHp, beastMaximum;
  final bool form, raging, frenzied;
  final CombatState combat;
  void restore(Character c) {
    c.currentHp = hp;
    c.maxHp = maximum;
    c.temporaryHp = temporary;
    c.beastCurrentHp = beastHp;
    c.beastMaxHp = beastMaximum;
    c.isWildShaped = form;
    c.isRaging = raging;
    c.isFrenzied = frenzied;
    c.exhaustionLevel = exhaustion;
    c.deathSaves.successes = successes;
    c.deathSaves.failures = failures;
    c.combatState = combat;
  }
}

class _RestSnapshot {
  _RestSnapshot(Character c)
      : hp = c.currentHp,
        slots = List.from(c.spellSlots),
        magic = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(c.magicData)) as Map),
        dice = List.from(c.hitDice),
        wildShape = c.wildShapeCharges,
        channel = c.channelDivinityCharges,
        arcane = c.arcaneRecoveryUsed,
        natural = c.naturalRecoveryUsed,
        signature = Map.from(c.signatureSpellsUsed),
        poolReferences = [for (final f in c.features) (f, f.resourcePool)],
        pools = [
          for (final f in c.features)
            if (f.resourcePool != null)
              (f.resourcePool!, f.resourcePool!.currentUses)
        ];
  final int hp, wildShape, channel;
  final bool arcane, natural;
  final List<int> slots, dice;
  final Map<String, dynamic> magic;
  final Map<String, bool> signature;
  final List<(ResourcePool, int)> pools;
  final List<(CharacterFeature, ResourcePool?)> poolReferences;
  void restore(Character c) {
    for (final entry in poolReferences) {
      entry.$1.resourcePool = entry.$2;
    }
    c.currentHp = hp;
    c.spellSlots = slots;
    c.magicData = magic;
    c.hitDice = dice;
    c.wildShapeCharges = wildShape;
    c.channelDivinityCharges = channel;
    c.arcaneRecoveryUsed = arcane;
    c.naturalRecoveryUsed = natural;
    c.signatureSpellsUsed = signature;
    for (final entry in pools) {
      entry.$1.currentUses = entry.$2;
    }
  }
}
