import 'dart:math' as math;
import '../models/character.dart';
import '../models/combat_state.dart';
import '../models/death_saves.dart';
import '../progression/character_class_rules.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';

class HitDieRoll {
  const HitDieRoll(this.classId, this.value);
  final String classId;
  final int value;
}

class HitDiceRestService {
  static Future<int> shortRest(Character hero, List<HitDieRoll> rolls,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        if (hero.hitDice.length != hero.classes.length) {
          throw StateError('Hit Dice need an explicit per-class allocation.');
        }
        final previousDice = List<int>.of(hero.hitDice),
            slots = List<int>.of(hero.spellSlots),
            magic = hero.magicData;
        final hp = hero.currentHp,
            beastHp = hero.beastCurrentHp,
            death = DeathSaves.fromJson(hero.deathSaves.toJson());
        final combat = CombatState.fromJson(hero.combatState.toJson()),
            signature = Map<String, bool>.of(hero.signatureSpellsUsed);
        final pools = [
          for (final f in hero.features)
            if (f.resourcePool != null)
              (f.resourcePool!, f.resourcePool!.currentUses)
        ];
        final wild = hero.wildShapeCharges,
            channel = hero.channelDivinityCharges,
            timestamp = hero.updatedAt;
        try {
          var rolledHealing = 0;
          for (final roll in rolls) {
            final index = hero.classes.indexWhere((c) => c.id == roll.classId);
            if (index < 0 || hero.hitDice[index] < 1) {
              throw StateError('No selected Hit Die remains.');
            }
            final data = CharacterClassRules.resolve(hero.classes[index]).data;
            if (!data.declares('hitDie') ||
                roll.value < 1 ||
                roll.value > data.hitDie) {
              throw StateError('Invalid Hit Die roll.');
            }
            hero.hitDice[index]--;
            rolledHealing += math.max(
                0, roll.value + hero.abilityScores.constitutionModifier);
          }
          final before = hero.isWildShaped && hero.beastCurrentHp != null
              ? hero.beastCurrentHp!
              : hero.currentHp;
          await hero.heal(rolledHealing, persist: false, source: 'Hit Dice');
          final after = hero.isWildShaped && hero.beastCurrentHp != null
              ? hero.beastCurrentHp!
              : hero.currentHp;
          final healed = after - before;
          // Character.heal logs a requested amount; short-rest feedback reflects
          // the actual change, including zero and overfilled health.
          if (hero.combatState.isInCombat &&
              hero.combatState.combatLog.length > combat.combatLog.length) {
            final log = hero.combatState.combatLog.last;
            log.amount = healed;
            hero.combatState.totalHealing = combat.totalHealing + healed;
          }
          hero.shortRest();
          await (write ?? StorageService.saveCharacter)(hero);
          return healed;
        } catch (_) {
          hero.hitDice = previousDice;
          hero.spellSlots = slots;
          hero.magicData = magic;
          hero.currentHp = hp;
          hero.beastCurrentHp = beastHp;
          hero.deathSaves = death;
          hero.combatState = combat;
          hero.signatureSpellsUsed = signature;
          hero.wildShapeCharges = wild;
          hero.channelDivinityCharges = channel;
          hero.updatedAt = timestamp;
          for (final pool in pools) {
            pool.$1.currentUses = pool.$2;
          }
          rethrow;
        }
      });
}
