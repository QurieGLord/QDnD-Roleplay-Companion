import '../utils/frame_memo.dart';
import 'spell_preparation_rules.dart';
import 'class_spell_grants.dart';
import '../models/character.dart';
import '../models/spell.dart';
import '../progression/class_spellcasting_profile.dart';
import '../progression/character_class_context.dart';
import '../services/spell_service.dart';
import '../services/gameplay_actions_service.dart';
import 'spellbook_state.dart';
import 'magic_slots.dart';
import 'casting_constraints.dart';

enum SpellUseMethod {
  sharedSlot,
  pactSlot,
  cantrip,
  ritual,
  mastery,
  signature,
  arcanum
}

class SpellUseSource {
  const SpellUseSource(
      {required this.id,
      required this.name,
      required this.ability,
      required this.modifier,
      required this.attack,
      required this.saveDC,
      required this.ready,
      required this.ritual});
  final String id, ability;
  final Map<String, String> name;
  final int modifier, attack, saveDC;
  final bool ready, ritual;
  String label(String locale) => name[locale] ?? name['en'] ?? id;
}

class SpellUseOption {
  const SpellUseOption(
      {required this.source,
      required this.spellId,
      required this.method,
      required this.circle});
  final SpellUseSource source;
  final String spellId;
  final SpellUseMethod method;
  final int circle;
  String get key =>
      '${source.id}|$spellId|${method.name}|$circle|${source.ability}';
}

/// Builds actual choices from personal ownership and the current payment pools.
/// A slot's circle never chooses the casting ability or teaches a spell.
class SpellUse {
  // A magic tab asks the same questions for every spell row, several times
  // per row; within one frame's build the answers are shared (FrameMemo).
  static List<SpellUseSource> sources(Character hero, Spell spell,
          {String? manualAbility}) =>
      List.of(FrameMemo.shared(hero, ('sources', spell.id, manualAbility),
          () => _sources(hero, spell, manualAbility: manualAbility)));

  static List<SpellUseSource> _sources(Character hero, Spell spell,
      {String? manualAbility}) {
    final book = SpellbookState.read(hero.spellbookData);
    final owners = book.ownersOf(spell.id).toSet();
    final guaranteed = <String>{};
    for (final entry in hero.classes) {
      if (ClassSpellGrants.ids(hero, entry.id)
          .any((id) => ClassSpellGrants.spell(id)?.id == spell.id)) {
        owners.add('class:${entry.id}');
        guaranteed.add('class:${entry.id}');
      }
    }
    final unassigned = book.unassignedKnown(hero).contains(spell.id) ||
        book.unassignedPrepared(hero).contains(spell.id);
    // A single legacy class can use its old sheet without a batch migration.
    if (unassigned && hero.classes.length == 1) {
      owners.add('class:${hero.classes.single.id}');
    }
    final result = <SpellUseSource>[];
    for (final id in owners) {
      if (id.startsWith('class:')) {
        final classId = id.substring(6);
        ClassSpellcastingProfile? profile;
        try {
          profile = ClassSpellcastingProfile.resolve(hero, classId);
        } catch (_) {
          continue;
        }
        if (profile == null) continue;
        final prepared = guaranteed.contains(id) ||
            book.ids(id, 'prepared').contains(spell.id) ||
            book.ids(id, 'alwaysPrepared').contains(spell.id) ||
            (unassigned &&
                hero.classes.length == 1 &&
                hero.preparedSpells.contains(spell.id));
        final ritualOnly = book.ids(id, 'ritualOnly').contains(spell.id) &&
            !book.ids(id, 'known').contains(spell.id) &&
            !prepared;
        final rules = profile.preparation;
        final ready = !ritualOnly &&
            (spell.level == 0 ||
                rules?.mode == SpellPreparationMode.known ||
                prepared);
        final ritual = spell.ritual &&
            ((rules?.ritual == RitualPreparationMode.book) ||
                (rules?.ritual == RitualPreparationMode.prepared && ready) ||
                book.ids(id, 'ritualOnly').contains(spell.id));
        result.add(SpellUseSource(
            id: id,
            name: CharacterClassContext(hero, classId).definition?.name ??
                {'en': classId},
            ability: profile.ability,
            modifier: profile.modifier,
            attack: profile.attackBonus,
            saveDC: profile.saveDC,
            ready: ready,
            ritual: ritual));
      } else if (id == 'manual' && manualAbility != null) {
        if (!{
          'intelligence',
          'wisdom',
          'charisma',
          'strength',
          'dexterity',
          'constitution'
        }.contains(manualAbility)) {
          throw ArgumentError('Unknown casting ability.');
        }
        final score = hero.abilityScores.toJson()[manualAbility] as int;
        final mod = hero.abilityScores.getModifier(score),
            attack = hero.proficiencyBonus + mod;
        result.add(SpellUseSource(
            id: id,
            name: {'ru': 'Решение стола', 'en': 'Table ruling'},
            ability: manualAbility,
            modifier: mod,
            attack: attack,
            saveDC: 8 + attack,
            ready: true,
            ritual: false));
      }
    }
    return result;
  }

  static String? arcanumSpell(Character hero, int circle) {
    final book = SpellbookState.read(hero.spellbookData);
    final raw = (hero.spellbookData['sources'] as Map?)?['class:warlock'];
    Object? binding;
    if (raw is Map && raw['arcanum'] is Map) {
      binding = (raw['arcanum'] as Map)['$circle'];
    }
    if (binding is String) return binding;
    // Old sheets with exactly one personal spell of this circle are unambiguous.
    final ids = book.ids('class:warlock', 'known');
    if (hero.classes.length == 1 && hero.classLevel('warlock') > 0) {
      ids.addAll(book.unassignedKnown(hero));
    }
    final choices = ids
        .where((id) => SpellService.getSpellById(id)?.level == circle)
        .toList();
    return choices.length == 1 ? choices.single : null;
  }

  static List<SpellUseOption> options(Character hero, Spell spell,
          {String? manualAbility, bool tableException = false}) =>
      List.of(FrameMemo.shared(
          hero,
          ('options', spell.id, manualAbility, tableException),
          () => _options(hero, spell,
              manualAbility: manualAbility, tableException: tableException)));

  static List<SpellUseOption> _options(Character hero, Spell spell,
      {String? manualAbility, bool tableException = false}) {
    final slots = MagicSlots.read(hero);
    final result = <SpellUseOption>[];
    for (final source in sources(hero, spell, manualAbility: manualAbility)) {
      if (!tableException &&
          CastingConstraints.forSource(hero, spell, source.id).isNotEmpty) {
        continue;
      }
      void add(SpellUseMethod method, int circle) => result.add(SpellUseOption(
          source: source, spellId: spell.id, method: method, circle: circle));
      if (source.ritual) add(SpellUseMethod.ritual, spell.level);
      if (!source.ready) continue;
      if (spell.level == 0) {
        add(SpellUseMethod.cantrip, 0);
        continue;
      }
      for (final circle in slots.availableCircles(spell.level)) {
        add(SpellUseMethod.sharedSlot, circle);
      }
      if (slots.pact != null &&
          slots.pact!.circle >= spell.level &&
          slots.pact!.current > 0) {
        add(SpellUseMethod.pactSlot, slots.pact!.circle);
      }
      if (source.id == 'class:wizard') {
        if (hero.classLevel('wizard') >= 18 &&
            spell.level <= 2 &&
            hero.spellMasterySpells.contains(spell.id)) {
          add(SpellUseMethod.mastery, spell.level);
        }
        if (hero.classLevel('wizard') >= 20 &&
            spell.level == 3 &&
            hero.signatureSpells.contains(spell.id) &&
            !(hero.signatureSpellsUsed[spell.id] ?? false)) {
          add(SpellUseMethod.signature, spell.level);
        }
      }
      if (source.id == 'class:warlock' &&
          spell.level >= 6 &&
          hero.classLevel('warlock') >= 11 + (spell.level - 6) * 2 &&
          arcanumSpell(hero, spell.level) == spell.id &&
          (GameplayActionsService.arcanumFeature(hero, spell.level)
                      ?.resourcePool
                      ?.currentUses ??
                  0) >
              0) {
        add(SpellUseMethod.arcanum, spell.level);
      }
    }
    return result;
  }

  static List<Spell> visible(Character hero) {
    final book = SpellbookState.read(hero.spellbookData);
    final ids = {
      ...hero.knownSpells,
      ...hero.preparedSpells,
      ...book.allKnown,
      for (final entry in hero.classes)
        for (final id in ClassSpellGrants.ids(hero, entry.id))
          if (ClassSpellGrants.spell(id) != null) ClassSpellGrants.spell(id)!.id
    };
    return ids.map(SpellService.getSpellById).whereType<Spell>().toList();
  }

  static bool ready(Character hero, Spell spell) =>
      sources(hero, spell).any((s) => s.ready);
}
