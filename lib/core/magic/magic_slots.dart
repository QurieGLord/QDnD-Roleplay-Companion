import 'dart:convert';
import 'dart:math' as math;
import '../models/character.dart';
import '../progression/class_spellcasting_profile.dart';
import '../models/spell_slots_table.dart';

enum MagicPool { shared, pact }

class PactSlots {
  const PactSlots(
      {required this.owner,
      required this.circle,
      required this.current,
      required this.maximum});
  final String owner;
  final int circle, current, maximum;
  Map<String, dynamic> toJson() => {
        'owner': owner,
        'circle': circle,
        'current': current,
        'maximum': maximum
      };
}

/// Separate payment pools. Reading a legacy sheet does not migrate or refill it.
/// A mixed legacy remainder has no reliable split and must be resolved explicitly.
class MagicSlots {
  MagicSlots._(this.current, this.maximum, this.pact);
  final List<int> current, maximum;
  final PactSlots? pact;
  static bool getExplicit(Character c) => c.magicData.isNotEmpty;
  factory MagicSlots.read(Character c) {
    void slots(List<int> a) {
      if (a.length > 9 || a.any((n) => n < 0)) {
        throw const FormatException('Invalid spell slot values.');
      }
    }

    slots(c.spellSlots);
    slots(c.maxSpellSlots);
    if (c.magicData.isNotEmpty) {
      if (c.magicData['version'] != 1) {
        throw const FormatException('Unsupported magic state.');
      }
      if (c.magicData['created'] != null) {
        final created = c.magicData['created'];
        if (created is! Map ||
            created.entries.any((e) =>
                int.tryParse('${e.key}') == null ||
                int.parse('${e.key}') < 1 ||
                int.parse('${e.key}') > 9 ||
                e.value is! int ||
                e.value < 0)) {
          throw const FormatException('Invalid created slots.');
        }
      }
      final raw = c.magicData['pact'];
      PactSlots? pact;
      if (raw != null) {
        if (raw is! Map ||
            raw['owner'] is! String ||
            !c.classes.any((entry) => entry.id == raw['owner']) ||
            raw['circle'] is! int ||
            raw['current'] is! int ||
            raw['maximum'] is! int ||
            raw['circle'] < 1 ||
            raw['circle'] > 9 ||
            raw['current'] < 0 ||
            raw['maximum'] < 0) {
          throw const FormatException('Invalid Pact slots.');
        }
        pact = PactSlots(
            owner: raw['owner'],
            circle: raw['circle'],
            current: raw['current'],
            maximum: raw['maximum']);
      }
      return MagicSlots._(
          List.of(c.spellSlots), List.of(c.maxSpellSlots), pact);
    }
    final owners = c.classes.where((entry) {
      try {
        return ClassSpellcastingProfile.resolve(c, entry.id)?.isPact == true;
      } catch (_) {
        return false;
      }
    }).toList();
    if (owners.length > 1) {
      throw StateError('Multiple unresolved Pact sources.');
    }
    if (owners.isEmpty) {
      return MagicSlots._(
          List.of(c.spellSlots), List.of(c.maxSpellSlots), null);
    }
    if (c.classes.length != 1) {
      throw StateError('Legacy mixed slots need an explicit allocation.');
    }
    final owner = owners.single;
    final norm = SpellSlotsTable.getPactSlots(owner.level);
    if (norm.isEmpty) throw StateError('Invalid Pact progression.');
    final circle = norm.length;
    int at(List<int> values, int i) => i < values.length ? values[i] : 0;
    final pact = PactSlots(
        owner: owner.id,
        circle: circle,
        current: at(c.spellSlots, circle - 1),
        maximum: at(c.maxSpellSlots, circle - 1));
    final shared = List<int>.of(c.spellSlots),
        maximum = List<int>.of(c.maxSpellSlots);
    if (circle <= shared.length) shared[circle - 1] = 0;
    if (circle <= maximum.length) maximum[circle - 1] = 0;
    return MagicSlots._(shared, maximum, pact);
  }
  static MagicSlots allocation(
      {required List<int> current,
      required List<int> maximum,
      PactSlots? pact}) {
    if (current.length > 9 ||
        maximum.length > 9 ||
        [...current, ...maximum].any((n) => n < 0) ||
        pact != null &&
            (pact.owner.isEmpty ||
                pact.circle < 1 ||
                pact.circle > 9 ||
                pact.current < 0 ||
                pact.maximum < 0)) {
      throw ArgumentError('Invalid spell slot allocation.');
    }
    return MagicSlots._(List.of(current), List.of(maximum), pact);
  }

  List<int> availableCircles(int minimum) => [
        for (var i = 0; i < current.length; i++)
          if (i + 1 >= minimum && current[i] > 0) i + 1
      ];
  int remaining(MagicPool pool, int circle) => pool == MagicPool.pact
      ? (pact?.circle == circle ? pact!.current : 0)
      : circle > 0 && circle <= current.length
          ? current[circle - 1]
          : 0;
  void applyTo(Character c) {
    c.spellSlots = List.of(current);
    c.maxSpellSlots = List.of(maximum);
    // Retain unrelated future-compatible properties of a known payload.
    c.magicData = {
      ...Map<String, dynamic>.from(jsonDecode(jsonEncode(c.magicData)) as Map),
      'version': 1,
      'pact': pact?.toJson()
    };
  }

  static void spendOn(Character c, MagicPool pool, int circle) {
    MagicSlots.read(c).spend(pool, circle).applyTo(c);
    if (pool == MagicPool.shared && c.magicData['created'] is Map) {
      final created = Map<String, dynamic>.from(c.magicData['created'] as Map),
          n = created['$circle'];
      if (n is int && n > 0) created['$circle'] = n - 1;
      c.magicData = {...c.magicData, 'created': created};
    }
  }

  static void expireCreated(Character c) {
    final created = c.magicData['created'];
    if (created is! Map) return;
    final state = MagicSlots.read(c),
        next = List<int>.of(MagicSlots.read(c).current);
    for (final entry in created.entries) {
      final circle = int.tryParse('${entry.key}'), value = entry.value;
      if (circle == null ||
          circle < 1 ||
          circle > 9 ||
          value is! int ||
          value < 0) {
        throw const FormatException('Invalid temporary slots.');
      }
      if (circle <= next.length) {
        next[circle - 1] = math.max(0, next[circle - 1] - value);
      }
    }
    MagicSlots.allocation(
            current: next, maximum: state.maximum, pact: state.pact)
        .applyTo(c);
    c.magicData = {...c.magicData, 'created': <String, int>{}};
  }

  MagicSlots spend(MagicPool pool, int circle) {
    if (circle < 1 || circle > 9 || remaining(pool, circle) <= 0) {
      throw StateError('No selected slot remains.');
    }
    if (pool == MagicPool.pact) {
      final p = pact!;
      return MagicSlots._(
          List.of(current),
          List.of(maximum),
          PactSlots(
              owner: p.owner,
              circle: p.circle,
              current: p.current - 1,
              maximum: p.maximum));
    }
    final next = List<int>.of(current);
    next[circle - 1]--;
    return MagicSlots._(next, List.of(maximum), pact);
  }

  MagicSlots recover({required bool short}) {
    final p = pact;
    final shared = List.of(current);
    if (!short) {
      while (shared.length < maximum.length) {
        shared.add(0);
      }
      for (var i = 0; i < maximum.length; i++) {
        shared[i] = math.max(shared[i], maximum[i]);
      }
    }
    return MagicSlots._(
        shared,
        List.of(maximum),
        p == null
            ? null
            : PactSlots(
                owner: p.owner,
                circle: p.circle,
                current: math.max(p.current, p.maximum),
                maximum: p.maximum));
  }
}
