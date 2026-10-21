import '../magic/casting_constraints.dart';
import '../magic/class_action_state.dart';
import '../magic/companion_state.dart';
import '../models/combat_state.dart';
import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../magic/spell_session_effects.dart';
import '../models/character.dart';
import '../progression/character_class_context.dart';
import 'gameplay_actions_service.dart';
import 'feature_service.dart';
import 'storage_service.dart';

class ClassSessionActionsService {
  static Future<void> editCompanion(Character c, CompanionState value,
          {required CompanionState? expected,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (CharacterClassContext(c, 'ranger').entry == null ||
            value.current < 0 ||
            value.maximum < 0 ||
            value.name.trim().isEmpty) {
          throw StateError('Invalid companion.');
        }
        if (jsonEncode(CompanionState.read(c)?.toJson()) !=
            jsonEncode(expected?.toJson())) {
          throw StateError('The companion changed during editing.');
        }
        await _companionWrite(c, value, write);
      });
  static Future<void> changeCompanionHealth(Character c, int amount,
          {required bool healing, Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (CharacterClassContext(c, 'ranger').entry == null || amount < 1) {
          throw StateError('Invalid companion action.');
        }
        final state = CompanionState.read(c);
        if (state == null) throw StateError('Record this companion first.');
        final next = healing
            ? max(state.current, min(state.maximum, state.current + amount))
            : max(0, state.current - amount);
        await _companionWrite(
            c,
            CompanionState(
                name: state.name, current: next, maximum: state.maximum),
            write);
      });
  static Future<void> _companionWrite(Character c, CompanionState value,
      Future<void> Function(Character)? write) async {
    final magic = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(c.magicData)) as Map),
        slots = List<int>.of(c.spellSlots),
        maximum = List<int>.of(c.maxSpellSlots),
        time = c.updatedAt;
    try {
      ClassActionState.setCompanion(c, value.toJson());
      await (write ?? StorageService.saveCharacter)(c);
    } catch (_) {
      c.magicData = magic;
      c.spellSlots = slots;
      c.maxSpellSlots = maximum;
      c.updatedAt = time;
      rethrow;
    }
  }

  static Future<({int? roll, bool success})> divineIntervention(Character c,
          {required String locale,
          int Function()? rollPercentile,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        final owner = CharacterClassContext(c, 'cleric');
        if (owner.level < 10 ||
            owner.definition?.rulesEdition != '2014' ||
            c.divineInterventionUsed ||
            ClassActionState.interventionAttempted(c) ||
            CastingConstraints.incapacitated(c) ||
            (c.isWildShaped && c.beastCurrentHp != null
                    ? c.beastCurrentHp!
                    : c.currentHp) <=
                0 ||
            !c.features.any((f) =>
                f.id.replaceAll('_', '-') == 'divine-intervention' &&
                owner.acceptsFeature(f))) {
          throw StateError('Divine Intervention is unavailable.');
        }
        final roll = owner.level >= 20
            ? null
            : (rollPercentile ?? () => Random().nextInt(100) + 1)();
        if (roll != null && (roll < 1 || roll > 100)) {
          throw ArgumentError.value(roll, 'roll');
        }
        final success = roll == null || roll <= owner.level;
        final before = (
          c.divineInterventionUsed,
          jsonDecode(jsonEncode(c.magicData)),
          List<int>.of(c.spellSlots),
          List<int>.of(c.maxSpellSlots),
          List<CombatLogEntry>.of(c.combatState.combatLog),
          c.updatedAt
        );
        try {
          c.divineInterventionUsed = success;
          ClassActionState.setInterventionAttempted(c, true);
          c.combatState.addLogEntry(CombatLogEntry(
              id: const Uuid().v4(),
              timestamp: DateTime.now(),
              type: CombatLogType.other,
              description: locale == 'ru'
                  ? 'Божественное вмешательство · ${roll ?? 'без броска'} · ${success ? 'успех' : 'повтор после продолжительного отдыха'}'
                  : 'Divine Intervention · ${roll ?? 'no roll'} · ${success ? 'success' : 'retry after a long rest'}',
              round: c.combatState.currentRound));
          await (write ?? StorageService.saveCharacter)(c);
          return (roll: roll, success: success);
        } catch (_) {
          c.divineInterventionUsed = before.$1;
          c.magicData = Map<String, dynamic>.from(before.$2 as Map);
          c.spellSlots = before.$3;
          c.maxSpellSlots = before.$4;
          c.combatState.combatLog = before.$5;
          c.updatedAt = before.$6;
          rethrow;
        }
      });

  static Future<void> resetDivineIntervention(Character c,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (CharacterClassContext(c, 'cleric').level < 10) {
          throw StateError('Missing class ability.');
        }
        final used = c.divineInterventionUsed,
            magic = Map<String, dynamic>.from(
                jsonDecode(jsonEncode(c.magicData)) as Map),
            slots = List<int>.of(c.spellSlots),
            maxSlots = List<int>.of(c.maxSpellSlots),
            time = c.updatedAt;
        try {
          ClassActionState.setInterventionAttempted(c, false);
          c.divineInterventionUsed = false;
          await (write ?? StorageService.saveCharacter)(c);
        } catch (_) {
          c.divineInterventionUsed = used;
          c.magicData = magic;
          c.spellSlots = slots;
          c.maxSpellSlots = maxSlots;
          c.updatedAt = time;
          rethrow;
        }
      });

  /// Session marks are explicit player actions; they do not grant resources.
  static Future<void> hidden(Character c, bool hidden,
          {bool rangerCamouflage = false,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        final owner =
            CharacterClassContext(c, rangerCamouflage ? 'ranger' : 'rogue');
        if (owner.level < (rangerCamouflage ? 10 : 1)) {
          throw StateError('This class action is unavailable.');
        }
        final before = (c.isHidden, c.isHiddenInPlainSight, c.updatedAt);
        try {
          if (rangerCamouflage) {
            c.isHiddenInPlainSight = hidden;
          } else {
            c.isHidden = hidden;
          }
          await (write ?? StorageService.saveCharacter)(c);
        } catch (_) {
          c.isHidden = before.$1;
          c.isHiddenInPlainSight = before.$2;
          c.updatedAt = before.$3;
          rethrow;
        }
      });

  static Future<bool> huntersMark(Character c,
          {String? target,
          bool drop = false,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (!c.isHuntersMarkActive) return false;
        final before = (
          c.isHuntersMarkActive,
          c.huntersMarkTarget,
          c.concentratingOn,
          c.updatedAt
        );
        try {
          if (drop) {
            c.isHuntersMarkActive = false;
            c.huntersMarkTarget = null;
            if (SpellSessionEffects.concentratingOnMark(c)) {
              c.concentratingOn = null;
            }
          } else {
            c.huntersMarkTarget = target?.trim();
          }
          await (write ?? StorageService.saveCharacter)(c);
          return true;
        } catch (_) {
          c.isHuntersMarkActive = before.$1;
          c.huntersMarkTarget = before.$2;
          c.concentratingOn = before.$3;
          c.updatedAt = before.$4;
          rethrow;
        }
      });

  static Future<void> helpers(Character c,
          {bool? reckless,
          bool? frenzied,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        final owner = CharacterClassContext(c, 'barbarian');
        bool acquired(String token) => c.features.any((f) =>
            f.id.toLowerCase().contains(token) &&
            owner.acceptsFeature(f) &&
            f.minLevel <= owner.level &&
            FeatureService.matchesSubclass(
                f.associatedSubclass, owner.subclass));
        if (owner.entry == null ||
            reckless == true && (owner.level < 2 || !acquired('reckless')) ||
            frenzied == true &&
                (owner.level < 3 || !c.isRaging || !acquired('frenzy'))) {
          throw StateError('The rage helper is unavailable.');
        }
        final before = (c.isReckless, c.isFrenzied, c.updatedAt);
        try {
          if (reckless != null) c.isReckless = reckless;
          if (frenzied != null) c.isFrenzied = frenzied;
          await (write ?? StorageService.saveCharacter)(c);
        } catch (_) {
          c.isReckless = before.$1;
          c.isFrenzied = before.$2;
          c.updatedAt = before.$3;
          rethrow;
        }
      });
  static Future<void> beastHealth(Character c, int current,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (current < 0 || c.beastCurrentHp == null) {
          throw StateError('Invalid form HP.');
        }
        final before = (c.beastCurrentHp, c.isWildShaped, c.updatedAt);
        try {
          c.beastCurrentHp = current;
          if (current == 0) c.isWildShaped = false;
          await (write ?? StorageService.saveCharacter)(c);
        } catch (_) {
          c.beastCurrentHp = before.$1;
          c.isWildShaped = before.$2;
          c.updatedAt = before.$3;
          rethrow;
        }
      });
  static bool unlimitedRage(Character c) {
    final owner = CharacterClassContext(c, 'barbarian'),
        data = owner.definition;
    return owner.level >= 20 &&
        data?.rulesEdition == '2014' &&
        data?.sourceId == null &&
        data?.rulesMetadata['origin'] == 'bundled';
  }

  static Future<bool> rage(Character c, String featureId, bool active,
          {String? expectedConcentration,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (c.isRaging == active) return false;
        final owner = CharacterClassContext(c, 'barbarian');
        final features = c.features
            .where((f) => f.id == featureId && owner.acceptsFeature(f))
            .toList();
        if (owner.level < 1 ||
            features.length != 1 ||
            features.single.resourcePool == null) {
          throw StateError('Missing rage source.');
        }
        final pool = features.single.resourcePool!;
        if (active &&
            (CastingConstraints.incapacitated(c) ||
                !unlimitedRage(c) && pool.currentUses < 1)) {
          throw StateError('Rage cannot start.');
        }
        if (active && c.concentratingOn != expectedConcentration) {
          throw StateError('Concentration changed.');
        }
        final mark = (c.isHuntersMarkActive, c.huntersMarkTarget);
        final before = (
          c.isRaging,
          c.isReckless,
          c.isFrenzied,
          c.exhaustionLevel,
          c.concentratingOn,
          pool.currentUses,
          c.updatedAt
        );
        try {
          if (active) {
            if (!unlimitedRage(c)) pool.use(1);
            SpellSessionEffects.endConcentration(c);
          } else if (c.isFrenzied) {
            c.exhaustionLevel++;
          }
          c.isRaging = active;
          c.isReckless = false;
          c.isFrenzied = false;
          await (write ?? StorageService.saveCharacter)(c);
          return true;
        } catch (_) {
          c.isRaging = before.$1;
          c.isReckless = before.$2;
          c.isFrenzied = before.$3;
          c.exhaustionLevel = before.$4;
          c.concentratingOn = before.$5;
          c.isHuntersMarkActive = mark.$1;
          c.huntersMarkTarget = mark.$2;
          pool.currentUses = before.$6;
          c.updatedAt = before.$7;
          rethrow;
        }
      });

  static Future<bool> wildShape(Character c, bool active,
          {int? hp, String? name, Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(c, () async {
        if (c.isWildShaped == active) return false;
        final owner = CharacterClassContext(c, 'druid');
        if (owner.level < 2) {
          throw StateError('Wild Shape requires its own class level.');
        }
        if (active &&
            (hp == null ||
                hp < 1 ||
                CastingConstraints.incapacitated(c) ||
                !CastingConstraints.coreDruid(c, 20) &&
                    c.wildShapeCharges < 1)) {
          throw StateError('Wild Shape cannot start.');
        }
        final before = (
          c.isWildShaped,
          c.wildShapeCharges,
          c.beastMaxHp,
          c.beastCurrentHp,
          c.beastName,
          c.updatedAt
        );
        try {
          if (active) {
            if (!CastingConstraints.coreDruid(c, 20)) c.wildShapeCharges--;
            c.beastMaxHp = hp;
            c.beastCurrentHp = hp;
            c.beastName = name;
          }
          c.isWildShaped = active;
          await (write ?? StorageService.saveCharacter)(c);
          return true;
        } catch (_) {
          c.isWildShaped = before.$1;
          c.wildShapeCharges = before.$2;
          c.beastMaxHp = before.$3;
          c.beastCurrentHp = before.$4;
          c.beastName = before.$5;
          c.updatedAt = before.$6;
          rethrow;
        }
      });
}
