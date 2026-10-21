import '../models/class_data.dart';

enum SpellPreparationMode { known, prepared, book }

enum RitualPreparationMode { none, prepared, book }

/// Declared preparation is independent of slot progression and source IDs.
class SpellPreparationRules {
  const SpellPreparationRules(this.mode,
      {this.divisor = 1, this.ritual = RitualPreparationMode.none});
  final SpellPreparationMode mode;
  final int divisor;
  final RitualPreparationMode ritual;
  Map<String, dynamic> toJson() => {
        'version': 1,
        'mode': mode.name,
        'divisor': divisor,
        'ritual': ritual.name
      };
  static SpellPreparationRules? fromJson(Object? raw) {
    if (raw is! Map || raw['version'] != 1) return null;
    final mode = SpellPreparationMode.values
        .where((v) => v.name == raw['mode'])
        .firstOrNull;
    final ritual = RitualPreparationMode.values
        .where((v) => v.name == raw['ritual'])
        .firstOrNull;
    final divisor = raw['divisor'];
    if (mode == null ||
        ritual == null ||
        divisor is! int ||
        !{1, 2}.contains(divisor)) {
      return null;
    }
    return SpellPreparationRules(mode, divisor: divisor, ritual: ritual);
  }

  static SpellPreparationRules? resolve(ClassData data) {
    if (data.rulesMetadata.containsKey('spellPreparation')) {
      return fromJson(data.rulesMetadata['spellPreparation']);
    }
    if (data.rulesEdition != '2014' ||
        data.sourceId != null ||
        data.rulesMetadata['origin'] != 'bundled') {
      return null;
    }
    return switch (data.id) {
      'wizard' => const SpellPreparationRules(SpellPreparationMode.book,
          ritual: RitualPreparationMode.book),
      'cleric' || 'druid' => const SpellPreparationRules(
          SpellPreparationMode.prepared,
          ritual: RitualPreparationMode.prepared),
      'paladin' =>
        const SpellPreparationRules(SpellPreparationMode.prepared, divisor: 2),
      'bard' => const SpellPreparationRules(SpellPreparationMode.known,
          ritual: RitualPreparationMode.prepared),
      'ranger' ||
      'sorcerer' ||
      'warlock' ||
      'fighter' ||
      'rogue' =>
        const SpellPreparationRules(SpellPreparationMode.known),
      _ => null,
    };
  }
}
