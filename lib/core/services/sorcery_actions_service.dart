import '../magic/magic_slots.dart';
import '../models/character.dart';
import '../models/character_feature.dart';
import 'feature_service.dart';
import 'gameplay_actions_service.dart';
import 'qdnd_bundle_codec.dart';
import 'storage_service.dart';

class SorceryActionsService {
  static const _ids = {
    'font-of-magic',
    'font_of_magic',
    'sorcery-points',
    'sorcery_points',
    'sorcerer_points'
  };
  static const creationCosts = {1: 2, 2: 3, 3: 5, 4: 6, 5: 7};

  static CharacterFeature? _find(Character c, CharacterFeature? definition) {
    final candidates = c.features
        .where((f) =>
            definition == null ? _ids.contains(f.id) : f.id == definition.id)
        .toList();
    if (candidates.length > 1) {
      throw StateError('Ambiguous Sorcery Points resource.');
    }
    return candidates.firstOrNull;
  }

  static int _maximum(Character c, CharacterFeature? definition) {
    final reference = definition?.resourcePool;
    if (reference?.calculationFormula != null) {
      return FeatureService.tryCalculateMaxUses(
              c, reference!.calculationFormula,
              classId: definition!.associatedClass) ??
          reference.maxUses;
    }
    return reference?.maxUses ?? c.classLevel('sorcerer');
  }

  /// A missing saved remainder is displayed as zero; reading never acquires,
  /// refills, attaches a template, or writes any state.
  static ResourcePool view(Character c, {CharacterFeature? definition}) {
    final found = _find(c, definition);
    return found?.resourcePool ??
        ResourcePool(
            currentUses: 0,
            maxUses: _maximum(c, definition),
            recoveryType: RecoveryType.longRest);
  }

  static ResourcePool _ensure(Character c, CharacterFeature? definition) {
    var owned = _find(c, definition);
    if (owned == null) {
      owned = (definition ?? FeatureService.getFeatureById('font-of-magic'))
              ?.copyForCharacter() ??
          CharacterFeature(
              id: 'font-of-magic',
              nameEn: 'Font of Magic',
              nameRu: 'Источник магии',
              descriptionEn: 'Sorcery Points',
              descriptionRu: 'Единицы чародейства',
              type: FeatureType.resourcePool,
              minLevel: 2,
              associatedClass: 'sorcerer');
      // Copy definitions, not another character's mutable remainder.
      owned.resourcePool = null;
      c.features.add(owned);
    }
    return owned.resourcePool ??= ResourcePool(
        currentUses: 0,
        maxUses: _maximum(c, definition),
        recoveryType:
            definition?.resourcePool?.recoveryType ?? RecoveryType.longRest,
        calculationFormula: definition?.resourcePool?.calculationFormula);
  }

  static Future<bool> _change(Character c, bool Function(Character) action,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        final draft = QdndBundleCodec.cloneCharacter(c);
        if (!action(draft)) return false;
        final features = c.features;
        final slots = c.spellSlots;
        final timestamp = c.updatedAt;
        final magic = c.magicData;
        final maximums = c.maxSpellSlots;
        try {
          c.features = draft.features;
          c.spellSlots = draft.spellSlots;
          c.maxSpellSlots = draft.maxSpellSlots;
          c.magicData = draft.magicData;
          await (write ?? StorageService.saveCharacter)(c);
          return true;
        } catch (_) {
          c.features = features;
          c.spellSlots = slots;
          c.maxSpellSlots = maximums;
          c.magicData = magic;
          c.updatedAt = timestamp;
          rethrow;
        }
      });
  static Future<bool> setCurrent(Character c, int value,
      {CharacterFeature? definition}) {
    if (value < 0) throw ArgumentError.value(value, 'value');
    return _change(c, (draft) {
      _ensure(draft, definition).setCurrentUses(value);
      return true;
    });
  }

  static Future<bool> spend(Character c, int cost,
      {CharacterFeature? definition}) {
    if (cost < 0) throw ArgumentError.value(cost, 'cost');
    if (cost == 0) return Future.value(true);
    return _change(c, (draft) {
      final pool = _ensure(draft, definition);
      if (pool.currentUses < cost) return false;
      pool.currentUses -= cost;
      return true;
    });
  }

  static Future<bool> convert(Character c, int circle,
      {required bool creating,
      CharacterFeature? definition,
      Future<void> Function(Character)? write,
      MagicPool payment = MagicPool.shared}) {
    if (circle < 1 || circle > (creating ? 5 : 9)) {
      throw ArgumentError.value(circle, 'circle');
    }
    return _change(c, (draft) {
      final pool = _ensure(draft, definition);
      if (creating) {
        final cost = creationCosts[circle]!;
        if (pool.currentUses < cost) return false;
        pool.currentUses -= cost;

        final state = MagicSlots.read(draft);
        final next = List<int>.of(state.current);
        while (next.length < circle) {
          next.add(0);
        }
        next[circle - 1]++;
        MagicSlots.allocation(
                current: next, maximum: state.maximum, pact: state.pact)
            .applyTo(draft);
        final created =
            Map<String, dynamic>.from(draft.magicData['created'] as Map? ?? {});
        created['$circle'] = (created['$circle'] as int? ?? 0) + 1;
        draft.magicData = {...draft.magicData, 'created': created};
      } else {
        if (MagicSlots.read(draft).remaining(payment, circle) < 1) {
          return false;
        }
        MagicSlots.spendOn(draft, payment, circle);
        // Conversion is an explicit gain; table-granted excess is retained.
        pool.currentUses += circle;
      }
      return true;
    }, write: write);
  }
}
