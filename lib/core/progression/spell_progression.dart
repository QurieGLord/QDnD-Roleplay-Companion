import '../models/spell_slots_table.dart';

enum ProgressionEdition { srd2014, srd2024 }

enum CasterProgression { none, full, half, third, pact }

class ClassCasterLevel {
  const ClassCasterLevel(this.classId, this.level, this.progression);
  final String classId;
  final int level;
  final CasterProgression progression;
}

class PactSlotNorm {
  const PactSlotNorm(this.circle, this.count);
  final int circle;
  final int count;
}

/// Keeps shared capacity, per-class learning limits, and Pact capacity apart.
class SpellProgression {
  SpellProgression._(this.sharedSlots, this.learningCircles, this.pact);
  final List<int> sharedSlots;
  final Map<String, int> learningCircles;
  final PactSlotNorm? pact;

  factory SpellProgression.calculate(Iterable<ClassCasterLevel> classes,
      {required ProgressionEdition edition}) {
    final entries = classes.toList();
    if (entries.isEmpty ||
        entries.any(
            (c) => c.classId.trim().isEmpty || c.level < 1 || c.level > 20) ||
        entries.fold(0, (sum, c) => sum + c.level) > 20 ||
        entries.map((c) => c.classId).toSet().length != entries.length) {
      throw ArgumentError('Invalid caster class levels.');
    }
    if (edition == ProgressionEdition.srd2024 &&
        entries.any((c) => c.progression == CasterProgression.third)) {
      throw UnsupportedError(
          'Third-caster subclass rules require their explicit 2024 source.');
    }
    final ordinary = entries
        .where((c) =>
            c.progression != CasterProgression.none &&
            c.progression != CasterProgression.pact)
        .where((c) => _ownSlots(c, edition).isNotEmpty)
        .toList();
    final pacts =
        entries.where((c) => c.progression == CasterProgression.pact).toList();
    if (pacts.length > 1) {
      throw ArgumentError('Multiple unresolved Pact progressions.');
    }
    List<int> shared;
    if (ordinary.isEmpty) {
      shared = [];
    } else if (ordinary.length == 1) {
      shared = _ownSlots(ordinary.single, edition);
    } else {
      var effective = 0;
      for (final c in ordinary) {
        switch (c.progression) {
          case CasterProgression.full:
            effective += c.level;
          case CasterProgression.half:
            effective += edition == ProgressionEdition.srd2014
                ? c.level ~/ 2
                : (c.level + 1) ~/ 2;
          case CasterProgression.third:
            effective += c.level ~/ 3;
          case CasterProgression.none || CasterProgression.pact:
            break;
        }
      }
      shared = SpellSlotsTable.getSlots(effective, 'full');
    }
    PactSlotNorm? pact;
    if (pacts.isNotEmpty) {
      final slots = SpellSlotsTable.getPactSlots(pacts.single.level);
      pact = PactSlotNorm(slots.length, slots.last);
    }
    return SpellProgression._(
        List.unmodifiable(shared),
        Map.unmodifiable(
            {for (final c in entries) c.classId: _ownSlots(c, edition).length}),
        pact);
  }

  static List<int> _ownSlots(ClassCasterLevel c, ProgressionEdition edition) {
    if (c.progression == CasterProgression.none) return [];
    if (c.progression == CasterProgression.half &&
        edition == ProgressionEdition.srd2024) {
      return SpellSlotsTable.getSlots((c.level + 1) ~/ 2, 'full');
    }
    return SpellSlotsTable.getSlots(c.level, c.progression.name);
  }
}
