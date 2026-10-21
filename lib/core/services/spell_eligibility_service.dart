import '../magic/spell_class_membership.dart';
import '../magic/spell_preparation_rules.dart';
import '../magic/class_spell_grants.dart';
import '../models/character.dart';
import '../models/spell.dart';
import '../models/class_data.dart';
import '../models/spell_slots_table.dart';
import '../progression/character_class_context.dart';
import 'feature_service.dart';

enum SpellAccessState { available, future, conditional, unavailable, unknown }

/// Eligibility belongs to a class, not to the character's combined slot table.
/// An available circle is not a free learning choice or a preparation allowance.
class SpellClassAccess {
  const SpellClassAccess({
    required this.classId,
    required this.name,
    required this.classLevel,
    required this.state,
    required this.reason,
    required this.reasonRu,
    this.requiredClassLevel,
    this.spellcastingType,
  });
  final String classId;
  final Map<String, String> name;
  final int classLevel;
  final SpellAccessState state;
  final int? requiredClassLevel;
  final String reason, reasonRu;
  final SpellcastingType? spellcastingType;
  String label(String locale) => name[locale] ?? name['en'] ?? classId;
  String explanation(String locale) => locale == 'ru' ? reasonRu : reason;
}

class SpellEligibilityService {
  static List<SpellClassAccess> classAccess(Character hero, Spell spell) => [
        for (final entry in hero.classes) _access(hero, entry.id, spell),
      ];

  /// Resolve personal snapshots once for a whole catalog, not once per row.
  static SpellEligibilityResult Function(Spell) forCharacter(Character hero) {
    final definitions = {
      for (final entry in hero.classes)
        entry.id: CharacterClassContext(
          hero,
          FeatureService.classKey(entry.id),
        ).definition,
    };
    final expanded = {
      for (final id in definitions.keys)
        id: ClassSpellGrants.ids(hero, id, expanded: true)
            .map((s) => ClassSpellGrants.spell(s)?.id)
            .whereType<String>()
            .toSet()
    };
    final guaranteed = {
      for (final id in definitions.keys)
        id: ClassSpellGrants.ids(hero, id)
            .map((s) => ClassSpellGrants.spell(s)?.id)
            .whereType<String>()
            .toSet()
    };
    return (spell) => _summarize([
          for (final id in definitions.keys)
            _access(hero, id, spell,
                definition: definitions[id],
                resolved: true,
                expandedIds: expanded[id],
                guaranteedIds: guaranteed[id]),
        ]);
  }

  static SpellClassAccess _access(
    Character hero,
    String id,
    Spell spell, {
    ClassData? definition,
    bool resolved = false,
    Set<String>? expandedIds,
    guaranteedIds,
  }) {
    final owner = CharacterClassContext(hero, FeatureService.classKey(id));
    final data = resolved ? definition : owner.definition;
    SpellClassAccess result(
      SpellAccessState state,
      String en,
      String ru, {
      int? at,
      SpellcastingType? type,
    }) =>
        SpellClassAccess(
          classId: id,
          name: data?.name ?? {'en': owner.entry?.name ?? id},
          classLevel: owner.level,
          state: state,
          reason: en,
          reasonRu: ru,
          requiredClassLevel: at,
          spellcastingType: type,
        );
    if (data == null || data.rulesEdition != '2014') {
      return result(
        SpellAccessState.unknown,
        'The saved rules do not describe spell access.',
        'В сохранённых правилах не описана доступность заклинаний.',
      );
    }
    final bundled =
        data.sourceId == null && data.rulesMetadata['origin'] == 'bundled';
    var casting = data.spellcasting?.type.toLowerCase();
    var listId = FeatureService.classKey(data.id);
    var restrictedSchools = <String>{};
    // Supported bundled subclasses borrow the wizard list. Their exceptional
    // school choices are conditional, never inferred from the total level.
    if (casting == null && bundled && owner.subclass != null) {
      final s = owner.subclass!.toLowerCase().replaceAll(RegExp('[_-]+'), ' ');
      if ((listId == 'fighter' && s == 'eldritch knight') ||
          (listId == 'rogue' && s == 'arcane trickster')) {
        casting = 'third';
        restrictedSchools = listId == 'fighter'
            ? {'abjuration', 'evocation'}
            : {'illusion', 'enchantment'};
        listId = 'wizard';
      }
    }
    if (casting == null) {
      return result(
        SpellAccessState.unavailable,
        'This class has no described spellcasting.',
        'Для этого класса не описано заклинательство.',
      );
    }
    if (casting == 'pact_magic') casting = 'pact';
    if (!{'full', 'half', 'third', 'pact'}.contains(casting)) {
      return result(
        SpellAccessState.unknown,
        'This source needs explicit spellcasting rules.',
        'Для этого источника нужны явные правила заклинательства.',
      );
    }
    final names = {
      listId,
      FeatureService.classKey(data.name['en'] ?? ''),
      FeatureService.classKey(data.name['ru'] ?? ''),
      FeatureService.classKey(id),
    };
    final membership = SpellClassMembership.check(spell, names, owner.subclass);
    final matches = membership.matches;
    final expanded = (expandedIds ??
            ClassSpellGrants.ids(hero, id, expanded: true)
                .map((key) => ClassSpellGrants.spell(key)?.id)
                .whereType<String>()
                .toSet())
        .contains(spell.id);
    final guaranteed = (guaranteedIds ??
            ClassSpellGrants.ids(hero, id)
                .map((key) => ClassSpellGrants.spell(key)?.id)
                .whereType<String>()
                .toSet())
        .contains(spell.id);
    if (!matches && !expanded && !guaranteed && membership.conditional) {
      return result(
          SpellAccessState.conditional,
          'This list entry requires a specified subclass or another source condition.',
          'Этот список требует указанного подкласса или другого условия источника.');
    }
    if (!matches && !expanded && !guaranteed) {
      return result(
        SpellAccessState.unavailable,
        'Outside this class spell list; an additional feature may grant access.',
        'Вне списка этого класса; доступ может дать отдельное умение.',
      );
    }
    final preparation = SpellPreparationRules.resolve(data);
    if (preparation == null && spell.level > 0) {
      return result(
          SpellAccessState.unknown,
          'Set how this class learns and prepares spells in Magic rules.',
          'Укажи, как этот класс изучает и готовит заклинания, в правилах магии.');
    }
    final type = casting == 'pact'
        ? SpellcastingType.pactMagic
        : preparation?.mode == SpellPreparationMode.known
            ? SpellcastingType.known
            : SpellcastingType.prepared;
    if (spell.level < 0 || spell.level > 9) {
      return result(
        SpellAccessState.unknown,
        'Unrecognised spell circle.',
        'Неизвестный круг заклинания.',
      );
    }
    if (spell.level == 0) {
      if (bundled && {'paladin', 'ranger'}.contains(data.id)) {
        return result(
          SpellAccessState.conditional,
          'A feature or a table ruling is needed to learn this cantrip.',
          'Для этого заговора нужно отдельное умение или решение стола.',
          type: type,
        );
      }
      final at = casting == 'third' ? 3 : 1;
      return result(
        owner.level >= at
            ? SpellAccessState.available
            : SpellAccessState.future,
        owner.level >= at
            ? 'In this class spell list.'
            : 'Available at class level $at.',
        owner.level >= at
            ? 'Есть в списке этого класса.'
            : 'Доступно на $at-м уровне класса.',
        at: at,
        type: type,
      );
    }
    if (casting == 'pact' && spell.level > 5) {
      final at = 11 + (spell.level - 6) * 2;
      return result(
        owner.level < at
            ? SpellAccessState.future
            : SpellAccessState.conditional,
        'Mystic Arcanum: a separate choice at class level $at; not a Pact slot.',
        'Таинственный арканум: отдельный выбор на $at-м уровне класса, без ячейки Магии договора.',
        at: at,
        type: type,
      );
    }
    int? at;
    for (var level = 1; level <= 20; level++) {
      if (SpellSlotsTable.getSlots(level, casting).length >= spell.level) {
        at = level;
        break;
      }
    }
    if (at == null) {
      return result(
        SpellAccessState.unavailable,
        'This class does not reach this circle.',
        'Этот класс не получает этот круг.',
        type: type,
      );
    }
    if (owner.level < at) {
      return result(
        SpellAccessState.future,
        'Available at class level $at.',
        'Доступно на $at-м уровне класса.',
        at: at,
        type: type,
      );
    }
    if (restrictedSchools.isNotEmpty &&
        !restrictedSchools.contains(spell.school.toLowerCase())) {
      return result(
        SpellAccessState.conditional,
        'Uses an unrestricted school choice from this subclass.',
        'Нужен свободный выбор школы, положенный этому подклассу.',
        at: at,
        type: type,
      );
    }
    return result(
      SpellAccessState.available,
      type == SpellcastingType.prepared
          ? 'Within this class circle; book and preparation rules still apply.'
          : 'Within this class circle; learning choices still apply.',
      type == SpellcastingType.prepared
          ? 'Круг доступен классу; действуют правила книги и подготовки.'
          : 'Круг доступен классу; действуют правила изучения.',
      at: at,
      type: type,
    );
  }

  static SpellEligibilityResult checkEligibility(Character hero, Spell spell) {
    return _summarize(classAccess(hero, spell));
  }

  static SpellEligibilityResult _summarize(List<SpellClassAccess> all) {
    final ranked = all.toList()
      ..sort((a, b) {
        int rank(SpellAccessState s) => switch (s) {
              SpellAccessState.available => 0,
              SpellAccessState.conditional => 1,
              SpellAccessState.future => 2,
              SpellAccessState.unknown => 3,
              SpellAccessState.unavailable => 4,
            };
        final r = rank(a.state).compareTo(rank(b.state));
        return r != 0
            ? r
            : (a.requiredClassLevel ?? 99).compareTo(
                b.requiredClassLevel ?? 99,
              );
      });
    final best = ranked.firstOrNull;
    return SpellEligibilityResult(
      canLearn: best?.state == SpellAccessState.available,
      canLearnAtLevel: best?.state == SpellAccessState.future
          ? best?.requiredClassLevel
          : null,
      reason: best?.reason ?? 'No class spell list.',
      reasonRu: best?.reasonRu ?? 'Нет списка заклинаний класса.',
      spellcastingType: best?.spellcastingType,
      sources: all,
      state: best?.state ?? SpellAccessState.unavailable,
    );
  }

  static List<Spell> getAvailableSpells(Character hero, List<Spell> spells) =>
      spells
          .where(
            (s) => classAccess(hero, s).any(
              (a) => {
                SpellAccessState.available,
                SpellAccessState.future,
                SpellAccessState.conditional,
              }.contains(a.state),
            ),
          )
          .toList();
  static List<Spell> getLearnableSpells(Character hero, List<Spell> spells) =>
      spells.where((s) => checkEligibility(hero, s).canLearn).toList();
  static List<Spell> getFutureSpells(Character hero, List<Spell> spells) =>
      spells
          .where(
            (s) => checkEligibility(hero, s).state == SpellAccessState.future,
          )
          .toList();
}

class SpellEligibilityResult {
  const SpellEligibilityResult({
    required this.canLearn,
    this.canLearnAtLevel,
    required this.reason,
    required this.reasonRu,
    this.spellcastingType,
    this.isAlwaysPrepared = false,
    this.sources = const [],
    this.state = SpellAccessState.unavailable,
  });
  final bool canLearn, isAlwaysPrepared;
  final int? canLearnAtLevel;
  final String reason, reasonRu;
  final SpellcastingType? spellcastingType;
  final List<SpellClassAccess> sources;
  final SpellAccessState state;
}

enum SpellcastingType { none, prepared, known, pactMagic }
