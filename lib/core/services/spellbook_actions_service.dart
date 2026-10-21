import '../magic/class_spell_grants.dart';
import 'spell_eligibility_service.dart';
import '../magic/spell_preparation_rules.dart';
import '../magic/spellbook_state.dart';
import '../progression/class_spellcasting_profile.dart';
import 'spell_service.dart';
import '../models/character.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';

/// Explicit player edits. Class limits guide preparation; a table exception is
/// explicit. Costs/features are never granted merely by adding a spell.
class SpellbookActionsService {
  static Future<bool> setKnown(
    Character hero,
    String spellId,
    bool known, {
    String? source,
    Future<void> Function(Character)? write,
  }) =>
      _change(hero, spellId, source, known: known, write: write);
  static Future<bool> setPrepared(
    Character hero,
    String spellId,
    bool prepared, {
    required String source,
    bool tableRuling = false,
    Future<void> Function(Character)? write,
  }) =>
      _change(
        hero,
        spellId,
        source,
        prepared: prepared,
        tableRuling: tableRuling,
        write: write,
      );

  static Future<bool> _change(
    Character hero,
    String spellId,
    String? source, {
    bool? known,
    bool? prepared,
    bool tableRuling = false,
    Future<void> Function(Character)? write,
  }) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        if (spellId.trim().isEmpty) {
          throw ArgumentError.value(spellId, 'spellId');
        }
        final state = SpellbookState.read(hero.spellbookData);
        if (source != null &&
            source != 'manual' &&
            !hero.classes.any((c) => source == 'class:${c.id}')) {
          throw StateError('Missing spell source.');
        }
        if (source == null && prepared != null) {
          throw ArgumentError('Preparation requires a source.');
        }
        final unassignedKnown = state.unassignedKnown(hero),
            unassignedPrepared = state.unassignedPrepared(hero);
        final beforeKnown = List<String>.from(hero.knownSpells),
            beforePrepared = List<String>.from(hero.preparedSpells);
        final beforeData = hero.spellbookData, timestamp = hero.updatedAt;
        try {
          if (source != null) {
            if (known != null) {
              final hadLegacyPreparation =
                  known && unassignedPrepared.contains(spellId);
              state.setKnown(source, spellId, known);
              if (hadLegacyPreparation) {
                state.setPrepared(source, spellId, true);
              }
              // Choosing an owner resolves this one legacy record, never others.
              unassignedKnown.remove(spellId);
              unassignedPrepared.remove(spellId);
            } else {
              if (prepared == true && !state.knows(source, spellId)) {
                final id =
                    source.startsWith('class:') ? source.substring(6) : '';
                final spell = SpellService.getSpellById(spellId);
                final direct = ClassSpellcastingProfile.resolve(hero, id)
                            ?.preparation
                            ?.mode ==
                        SpellPreparationMode.prepared &&
                    spell != null &&
                    SpellEligibilityService.classAccess(hero, spell).any((a) =>
                        a.classId == id &&
                        a.state == SpellAccessState.available);
                if (!direct && !tableRuling) {
                  throw StateError('Learn or copy this spell first.');
                }
                state.setKnown(source, spellId, true);
                unassignedKnown.remove(spellId);
                unassignedPrepared.remove(spellId);
              }
              if (prepared == true && !tableRuling) {
                if (hasUnassignedPreparation(hero)) {
                  throw StateError('Assign legacy preparation sources first.');
                }
                final limit = preparationLimit(hero, source);
                final spell = SpellService.getSpellById(spellId);
                if (limit == null || spell == null) {
                  throw StateError('Explicit preparation rules needed.');
                }
                if (spell.level == 0) {
                  throw StateError('Cantrips do not need preparation.');
                }
                if (preparedCount(hero, source) >= limit &&
                    !state.ids(source, 'prepared').contains(spellId)) {
                  throw StateError('Preparation allowance reached.');
                }
              }
              state.setPrepared(source, spellId, prepared!);
            }
          } else {
            // Compatibility edit of a genuinely unassigned spell only. A named
            // source must be chosen to remove a spell owned by several classes.
            if (state.ownersOf(spellId).isNotEmpty) {
              throw StateError('Choose the spell source.');
            }
            if (known == true) {
              unassignedKnown.add(spellId);
            } else {
              unassignedKnown.remove(spellId);
              unassignedPrepared.remove(spellId);
            }
          }
          hero.spellbookData = state.toJson();
          hero.knownSpells = {...unassignedKnown, ...state.allKnown}.toList();
          hero.preparedSpells = {
            ...unassignedPrepared,
            ...state.allPrepared,
          }.toList();
          await (write ?? StorageService.saveCharacter)(hero);
          return true;
        } catch (_) {
          hero.spellbookData = beforeData;
          hero.knownSpells = beforeKnown;
          hero.preparedSpells = beforePrepared;
          hero.updatedAt = timestamp;
          rethrow;
        }
      });
  static int? preparationLimit(Character hero, String source) {
    if (!source.startsWith('class:')) return null;
    final id = source.substring(6);
    try {
      final p = ClassSpellcastingProfile.resolve(hero, id);
      final rules = p?.preparation;
      if (p == null ||
          rules == null ||
          rules.mode == SpellPreparationMode.known) {
        return null;
      }
      final value = p.modifier + p.classLevel ~/ rules.divisor;
      return value < 1 ? 1 : value;
    } catch (_) {
      return null;
    }
  }

  static bool hasUnassignedPreparation(Character hero) =>
      hero.classes.length > 1 &&
      SpellbookState.read(hero.spellbookData)
          .unassignedPrepared(hero)
          .isNotEmpty;

  static int preparedCount(Character hero, String source) {
    final state = SpellbookState.read(hero.spellbookData);
    final ids = state.ids(source, 'prepared');
    ids.removeAll(state.ids(source, 'alwaysPrepared'));
    // An old single-class sheet has one unambiguous preparation allowance;
    // counting its unchanged old records prevents a fresh extra allowance.
    if (hero.classes.length == 1 &&
        source == 'class:${hero.classes.single.id}') {
      ids.addAll(state.unassignedPrepared(hero));
    }
    if (source.startsWith('class:')) {
      ids.removeAll(ClassSpellGrants.ids(hero, source.substring(6))
          .map((id) => ClassSpellGrants.spell(id)?.id)
          .whereType<String>());
    }
    return ids.where((id) => SpellService.getSpellById(id)?.level != 0).length;
  }
}
