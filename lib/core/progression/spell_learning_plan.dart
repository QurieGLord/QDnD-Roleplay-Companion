import '../magic/spell_class_membership.dart';
import '../magic/class_spell_grants.dart';
import '../magic/spellbook_state.dart';
import '../models/character.dart';
import '../models/spell.dart';
import '../services/spell_service.dart';
import '../services/spellcasting_service.dart';
import 'character_class_context.dart';
import 'class_spellcasting_profile.dart';

enum SpellLearningKind {
  normal,
  cantrip,
  secret,
  arcanum,
  masteryOne,
  masteryTwo,
  signature,
  ritualBook,
  tome,
  unrestricted
}

class SpellLearningChoice {
  const SpellLearningChoice(this.kind, this.count, this.options,
      {this.allowedSchools = const {}, this.freeSchoolChoices = 0});
  final Set<String> allowedSchools;
  final int freeSchoolChoices;
  final SpellLearningKind kind;
  final int count;
  final List<Spell> options;
  String get key => kind.name;
}

class SpellLearningPlan {
  SpellLearningPlan(
      this.classId, this.choices, this.replacementOptions, this.replaceable,
      {this.needsManualCounts = false});
  final bool needsManualCounts;
  int classLevel = 0;
  bool thirdCaster = false;
  Set<String> replacementSchools = {}, unrestrictedKnown = {};
  final String classId;
  final List<SpellLearningChoice> choices;
  final List<Spell> replacementOptions, replaceable;
  static int cantripCount(String id, int level, {bool third = false}) {
    if (level < 1) return 0;
    if (third) {
      return level < 3 ? 0 : (id == 'rogue' ? 3 : 2) + (level >= 10 ? 1 : 0);
    }
    final first = switch (id) {
      'bard' || 'druid' || 'warlock' => 2,
      'cleric' || 'wizard' => 3,
      'sorcerer' => 4,
      _ => 0
    };
    return first == 0
        ? 0
        : first + (level >= 4 ? 1 : 0) + (level >= 10 ? 1 : 0);
  }

  factory SpellLearningPlan.forAdvance(
      Character before, Character after, String classId,
      {Iterable<String> pending = const [], Map<String, int>? manualCounts}) {
    final profile = ClassSpellcastingProfile.resolve(after, classId);
    if (profile == null) return SpellLearningPlan(classId, [], [], []);
    final context = CharacterClassContext(after, classId),
        data = context.definition!;
    final manual =
        data.sourceId != null || data.rulesMetadata['origin'] != 'bundled';
    if (manual && manualCounts?['confirmed'] != 1) {
      return SpellLearningPlan(classId, [], [], [], needsManualCounts: true);
    }
    final level = context.level,
        old = before.classes.where((c) => c.id == classId).firstOrNull?.level ??
            0;
    final third = profile.progression == 'third';
    final book = SpellbookState.read(before.spellbookData);
    final known = book.ids('class:$classId', 'known');
    if (before.classes.length == 1 && old > 0) {
      known.addAll(book.unassignedKnown(before));
    }
    final effective = {...known, ...pending};
    final classList = {
      for (final s in (manual && manualCounts?['all'] == 1
          ? SpellService.getAllSpells()
          : SpellService.getAllSpells().where((s) => SpellClassMembership.check(
                  s,
                  third
                      ? ['wizard', classId, ...data.name.values]
                      : [classId, ...data.name.values],
                  context.subclass)
              .matches)))
        s.id: s,
      for (final s in ClassSpellGrants.expanded(after, classId)) s.id: s
    }.values.toList();
    int knownCount(int value) => value < 1
        ? 0
        : third
            ? const [
                0,
                0,
                0,
                3,
                4,
                4,
                4,
                5,
                6,
                6,
                7,
                8,
                8,
                9,
                10,
                10,
                11,
                11,
                11,
                12,
                13
              ][value]
            : SpellcastingService.getSpellsKnownCount(classId, value);
    var normal = manual
        ? (manualCounts?['normal'] ?? 0)
        : classId == 'wizard'
            ? (old == 0 ? 6 : 2)
            : knownCount(level) - knownCount(old);
    if (normal < 0) normal = 0;
    final secrets = !manual &&
            classId == 'bard' &&
            ([10, 14, 18].contains(level) ||
                level == 6 &&
                    context.subclass != null &&
                    context.subclass!.toLowerCase().contains('lore'))
        ? 2
        : 0;
    if (classId == 'bard' && [10, 14, 18].contains(level)) {
      normal = (normal - secrets).clamp(0, 100);
    }
    var cantrips = manual
        ? (manualCounts?['cantrip'] ?? 0)
        : cantripCount(classId, level, third: third) -
            cantripCount(classId, old, third: third) +
            (classId == 'druid' &&
                    old < 2 &&
                    level >= 2 &&
                    context.subclass != null &&
                    context.subclass!.toLowerCase().contains('land')
                ? 1
                : 0);
    if (third && classId == 'rogue' && old < 3 && level >= 3) cantrips--;
    final restrictedSchools = third
        ? (classId == 'fighter'
            ? {'abjuration', 'evocation'}
            : {'illusion', 'enchantment'})
        : <String>{};
    final freeSchools = third && [3, 8, 14, 20].contains(level) ? 1 : 0;
    if (freeSchools > 0 && normal > 0) {
      normal--;
    }
    final choices = <SpellLearningChoice>[];
    if (normal > 0) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.normal,
          normal,
          classList
              .where((s) =>
                  s.level > 0 &&
                  s.level <= profile.learningCircle &&
                  !known.contains(s.id) &&
                  (restrictedSchools.isEmpty ||
                      restrictedSchools.contains(s.school.toLowerCase())))
              .toList(),
          allowedSchools: restrictedSchools,
          freeSchoolChoices: 0));
    }
    if (freeSchools > 0) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.unrestricted,
          1,
          classList
              .where((s) =>
                  s.level > 0 &&
                  s.level <= profile.learningCircle &&
                  !known.contains(s.id))
              .toList()));
    }
    if (cantrips > 0) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.cantrip,
          cantrips,
          classList
              .where((s) =>
                  s.level == 0 &&
                  !known.contains(s.id) &&
                  !(third &&
                      classId == 'rogue' &&
                      old < 3 &&
                      s.id == ClassSpellGrants.spell('mage-hand')?.id))
              .toList()));
    }
    if (secrets > 0) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.secret,
          secrets,
          SpellService.getAllSpells()
              .where((s) =>
                  s.level <= profile.learningCircle && !known.contains(s.id))
              .toList()));
    }
    if (!manual && classId == 'warlock' && [11, 13, 15, 17].contains(level)) {
      final circle = 6 + (level - 11) ~/ 2;
      choices.add(SpellLearningChoice(
          SpellLearningKind.arcanum,
          1,
          classList
              .where((s) => s.level == circle && !known.contains(s.id))
              .toList()));
    }
    if (!manual && classId == 'wizard' && level == 18) {
      for (final entry in [
        (SpellLearningKind.masteryOne, 1),
        (SpellLearningKind.masteryTwo, 2)
      ]) {
        choices.add(SpellLearningChoice(
            entry.$1,
            1,
            SpellService.getAllSpells()
                .where((s) => effective.contains(s.id) && s.level == entry.$2)
                .toList()));
      }
    }
    if (!manual && classId == 'wizard' && level == 20) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.signature,
          2,
          SpellService.getAllSpells()
              .where((s) => effective.contains(s.id) && s.level == 3)
              .toList()));
    }
    final ritualFeature = after.features.any((f) => {
          'book-of-ancient-secrets',
          'eldritch-invocation-book-of-ancient-secrets'
        }.contains(f.id));
    final hadRitualFeature = before.features.any((f) => {
          'book-of-ancient-secrets',
          'eldritch-invocation-book-of-ancient-secrets'
        }.contains(f.id));
    if (classId == 'warlock' && ritualFeature && !hadRitualFeature) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.ritualBook,
          2,
          SpellService.getAllSpells()
              .where((s) => s.level == 1 && s.ritual && !known.contains(s.id))
              .toList()));
    }
    bool tome(Character c) =>
        c.features.any((f) => f.id.replaceAll('_', '-') == 'pact-of-the-tome');
    if (!manual && classId == 'warlock' && tome(after) && !tome(before)) {
      choices.add(SpellLearningChoice(
          SpellLearningKind.tome,
          3,
          SpellService.getAllSpells()
              .where((s) => s.level == 0 && !known.contains(s.id))
              .toList()));
    }
    final replaces = old > 0 &&
        ({'bard', 'sorcerer', 'warlock', 'ranger'}.contains(classId) ||
            third && old >= 3);
    final result = SpellLearningPlan(
        classId,
        choices,
        replaces
            ? classList
                .where((s) =>
                    s.level > 0 &&
                    s.level <= profile.learningCircle &&
                    !known.contains(s.id))
                .toList()
            : [],
        replaces
            ? SpellService.getAllSpells()
                .where((s) =>
                    known.contains(s.id) &&
                    s.level > 0 &&
                    (classId != 'warlock' || s.level <= 5) &&
                    !book
                        .ids('class:$classId', 'alwaysPrepared')
                        .contains(s.id))
                .toList()
            : []);
    result.classLevel = level;
    result.thirdCaster = third;
    result.replacementSchools = restrictedSchools;
    result.unrestrictedKnown = book.ids('class:$classId', 'unrestricted');
    // A legacy out-of-school spell has an evident unrestricted origin.
    // Same-school legacy entries are not assigned a guessed learning history.
    if (third) {
      result.unrestrictedKnown.addAll(result.replaceable
          .where((s) => !restrictedSchools.contains(s.school.toLowerCase()))
          .map((s) => s.id));
    }
    return result;
  }
  List<Spell> replacementsFor(String? old) => replacementOptions
      .where((s) =>
          replacementSchools.isEmpty ||
          unrestrictedKnown.contains(old) ||
          replacementSchools.contains(s.school.toLowerCase()))
      .toList();
  void validate(Map<String, List<String>> selected,
      {String? replaceOld, String? replaceNew}) {
    if (needsManualCounts) {
      throw StateError('Confirm the source learning choices.');
    }
    final acquired = <String>{};
    for (final choice in choices) {
      final ids = selected[choice.key] ?? [];
      if (ids.length != choice.count ||
          ids.toSet().length != ids.length ||
          ids.any((id) => !choice.options.any((s) => s.id == id))) {
        throw StateError('Incomplete spell choice: ${choice.key}');
      }
      if (choice.allowedSchools.isNotEmpty &&
          ids
                  .where((id) => !choice.allowedSchools.contains(choice.options
                      .firstWhere((s) => s.id == id)
                      .school
                      .toLowerCase()))
                  .length >
              choice.freeSchoolChoices) {
        throw StateError('Choose spells from the subclass schools.');
      }
      if ({
        SpellLearningKind.normal,
        SpellLearningKind.cantrip,
        SpellLearningKind.secret,
        SpellLearningKind.arcanum,
        SpellLearningKind.ritualBook,
        SpellLearningKind.tome,
        SpellLearningKind.unrestricted
      }.contains(choice.kind)) {
        if (ids.any(acquired.contains)) {
          throw StateError('A spell was selected twice.');
        }
        acquired.addAll(ids);
      }
    }
    if ((replaceOld == null) != (replaceNew == null) ||
        replaceOld != null &&
            (!replaceable.any((s) => s.id == replaceOld) ||
                !replacementsFor(replaceOld).any((s) => s.id == replaceNew) ||
                acquired.contains(replaceNew))) {
      throw StateError('Incomplete spell replacement.');
    }
  }

  void apply(Character after, Map<String, List<String>> selected,
      {String? replaceOld, String? replaceNew}) {
    validate(selected, replaceOld: replaceOld, replaceNew: replaceNew);
    final book = SpellbookState.read(after.spellbookData),
        source = 'class:$classId';
    if (replaceOld != null) {
      final unrestricted = unrestrictedKnown.contains(replaceOld);
      book.setKnown(source, replaceOld, false);
      book.setKnown(source, replaceNew!, true);
      if (unrestricted) book.addUnrestricted(source, replaceNew);
    }
    for (final choice in choices) {
      for (final id in selected[choice.key] ?? <String>[]) {
        switch (choice.kind) {
          case SpellLearningKind.masteryOne:
          case SpellLearningKind.masteryTwo:
            after.spellMasterySpells =
                {...after.spellMasterySpells, id}.toList();
          case SpellLearningKind.signature:
            after.signatureSpells = {...after.signatureSpells, id}.toList();
            after.signatureSpellsUsed[id] =
                after.signatureSpellsUsed[id] ?? false;
          case SpellLearningKind.arcanum:
            book.bindArcanum(source, SpellService.getSpellById(id)!.level, id);
          case SpellLearningKind.ritualBook:
            book.addRitual(source, id);
          case SpellLearningKind.unrestricted:
            book.addUnrestricted(source, id);
          case SpellLearningKind.normal:
          case SpellLearningKind.cantrip:
          case SpellLearningKind.secret:
          case SpellLearningKind.tome:
            book.setKnown(source, id, true);
        }
      }
    }
    if (thirdCaster && classId == 'rogue' && classLevel == 3) {
      final mageHand = ClassSpellGrants.spell('mage-hand');
      if (mageHand == null) throw StateError('Missing Mage Hand.');
      book.setKnown(source, mageHand.id, true);
    }
    after.spellbookData = book.toJson();
    after.knownSpells = {
      ...after.knownSpells.where((id) => id != replaceOld),
      ...book.allKnown
    }.toList();
    after.preparedSpells = {
      ...after.preparedSpells.where((id) => id != replaceOld),
      ...book.allPrepared
    }.toList();
  }
}
