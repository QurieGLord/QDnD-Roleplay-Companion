import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../magic/magic_slots.dart';
import '../magic/spell_session_effects.dart';
import '../magic/spell_use.dart';
import '../magic/casting_constraints.dart';
import '../models/character.dart';
import '../models/spell.dart';
import '../models/combat_state.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';
import 'spell_service.dart';
import 'catalog_definition_signature.dart';

class SpellCastResult {
  const SpellCastResult(this.option, this.concentrationChanged);
  final SpellUseOption option;
  final bool concentrationChanged;
}

/// The sheet and combat share this transaction: fresh validation, one cost,
/// concentration and one log entry; a failed save restores all related state.
class SpellCastActionsService {
  static Future<SpellCastResult> cast(
          Character hero, Spell spell, SpellUseOption choice,
          {required String locale,
          String? expectedConcentration,
          bool tableException = false,
          String? expectedRestrictions,
          bool requireCurrentCatalog = false,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        if (requireCurrentCatalog) {
          final current = SpellService.getSpellById(spell.id);
          if (current == null ||
              current.sourceId != spell.sourceId ||
              CatalogDefinitionSignature.of(current.toJson()) !=
                  CatalogDefinitionSignature.of(spell.toJson())) {
            throw StateError('The spell source changed before confirmation.');
          }
        }
        final restrictions =
            CastingConstraints.signature(hero, spell, choice.source.id);
        if (tableException &&
            (expectedRestrictions == null ||
                expectedRestrictions != restrictions)) {
          throw StateError('Casting restrictions changed before confirmation.');
        }
        final valid = SpellUse.options(hero, spell,
                tableException: tableException,
                manualAbility:
                    choice.source.id == 'manual' ? choice.source.ability : null)
            .where((o) => o.key == choice.key)
            .firstOrNull;
        if (valid == null ||
            valid.source.attack != choice.source.attack ||
            valid.source.saveDC != choice.source.saveDC) {
          throw StateError(
              'The selected casting method is no longer available.');
        }
        if (spell.concentration &&
            hero.concentratingOn != expectedConcentration) {
          throw StateError('Concentration changed before confirmation.');
        }
        final current = List<int>.of(hero.spellSlots),
            maximum = List<int>.of(hero.maxSpellSlots);
        final magic = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(hero.magicData)) as Map);
        final signature = Map<String, bool>.of(hero.signatureSpellsUsed);
        final pools = [
          for (final f in hero.features)
            if (f.resourcePool != null)
              (f.resourcePool!, f.resourcePool!.currentUses)
        ];
        final oldMark = (hero.isHuntersMarkActive, hero.huntersMarkTarget);
        final oldConcentration = hero.concentratingOn,
            timestamp = hero.updatedAt;
        final logs = List<CombatLogEntry>.of(hero.combatState.combatLog);
        try {
          switch (valid.method) {
            case SpellUseMethod.sharedSlot:
              MagicSlots.spendOn(hero, MagicPool.shared, valid.circle);
            case SpellUseMethod.pactSlot:
              MagicSlots.spendOn(hero, MagicPool.pact, valid.circle);
            case SpellUseMethod.signature:
              hero.signatureSpellsUsed[spell.id] = true;
            case SpellUseMethod.arcanum:
              GameplayActionsService.arcanumFeature(hero, valid.circle)!
                  .resourcePool!
                  .use(1);
            case SpellUseMethod.cantrip:
            case SpellUseMethod.ritual:
            case SpellUseMethod.mastery:
              break;
          }
          SpellSessionEffects.applyConcentration(hero, spell);
          final source = valid.source.label(locale);
          final method = switch (valid.method) {
            SpellUseMethod.sharedSlot => locale == 'ru'
                ? 'ячейка ${valid.circle}-го круга'
                : 'circle ${valid.circle} slot',
            SpellUseMethod.pactSlot => locale == 'ru'
                ? 'Магия договора, ${valid.circle}-й круг'
                : 'Pact Magic, circle ${valid.circle}',
            SpellUseMethod.ritual => locale == 'ru' ? 'ритуал' : 'ritual',
            SpellUseMethod.mastery =>
              locale == 'ru' ? 'Мастерство заклинаний' : 'Spell Mastery',
            SpellUseMethod.signature =>
              locale == 'ru' ? 'Фирменное заклинание' : 'Signature Spell',
            SpellUseMethod.arcanum =>
              locale == 'ru' ? 'Таинственный арканум' : 'Mystic Arcanum',
            SpellUseMethod.cantrip => locale == 'ru' ? 'заговор' : 'cantrip'
          };
          hero.combatState.addLogEntry(CombatLogEntry(
              id: const Uuid().v4(),
              timestamp: DateTime.now(),
              type: CombatLogType.other,
              description:
                  '${spell.getName(locale)} · $source · $method${tableException && CastingConstraints.forSource(hero, spell, choice.source.id).isNotEmpty ? (locale == "ru" ? " · исключение стола" : " · table exception") : ""}',
              round: hero.combatState.currentRound));
          await (write ?? StorageService.saveCharacter)(hero);
          return SpellCastResult(
              valid, spell.concentration && oldConcentration != spell.id);
        } catch (_) {
          hero.spellSlots = current;
          hero.maxSpellSlots = maximum;
          hero.magicData = magic;
          hero.signatureSpellsUsed = signature;
          hero.concentratingOn = oldConcentration;
          hero.isHuntersMarkActive = oldMark.$1;
          hero.huntersMarkTarget = oldMark.$2;
          hero.combatState.combatLog = logs;
          hero.updatedAt = timestamp;
          for (final pool in pools) {
            pool.$1.currentUses = pool.$2;
          }
          rethrow;
        }
      });
}
