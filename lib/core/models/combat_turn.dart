import 'combat_state.dart';

/// What a use costs from the hero's turn.
enum TurnCost { action, bonus, reaction, free }

extension TurnCostKey on TurnCost {
  String get key => switch (this) {
        TurnCost.action => 'act',
        TurnCost.bonus => 'bonus',
        TurnCost.reaction => 'react',
        TurnCost.free => 'free',
      };

  /// Reads a feature's or spell's economy word ("action", "bonus_action",
  /// "1 bonus action", "1 реакция", …).
  static TurnCost parse(String? value) {
    final v = (value ?? '').toLowerCase();
    if (v.contains('bonus') || v.contains('бонус')) return TurnCost.bonus;
    if (v.contains('reaction') || v.contains('реакц')) return TurnCost.reaction;
    if (v.contains('action') || v.contains('действ')) return TurnCost.action;
    return TurnCost.free;
  }
}

/// An effect on the round tape: a name, an icon, an accent and the rounds
/// it has left. Rage, Sacred Weapon and concentration mirror the hero's own
/// flags; ending the effect ends the flag.
class CombatEffect {
  const CombatEffect({
    required this.key,
    required this.name,
    required this.icon,
    required this.accent,
    required this.left,
    required this.max,
    this.concentration = false,
  });

  /// `rage`, `sacred`, `conc` (the concentration spell), or a feature key.
  final String key, name, icon;
  final int accent, left, max;
  final bool concentration;

  CombatEffect copyWith({int? left}) => CombatEffect(
      key: key,
      name: name,
      icon: icon,
      accent: accent,
      left: left ?? this.left,
      max: max,
      concentration: concentration);

  Map<String, dynamic> toJson() => {
        'k': key,
        'n': name,
        'ic': icon,
        'acc': accent,
        'left': left,
        'max': max,
        if (concentration) 'conc': true,
      };

  static CombatEffect? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['k'], name = raw['n'], left = raw['left'], max = raw['max'];
    if (key is! String || name is! String || left is! int || max is! int) {
      return null;
    }
    return CombatEffect(
        key: key,
        name: name,
        icon: raw['ic'] is String ? raw['ic'] as String : 'timer',
        accent: raw['acc'] is int ? raw['acc'] as int : 4,
        left: left,
        max: max,
        concentration: raw['conc'] == true);
  }
}

/// A typed view over `CombatState.turn`: the hero's spent tokens, feet
/// moved, attacks of the Attack action and the effects of the round.
/// Mutators change the map in place; callers save through the shared
/// action path.
class CombatTurn {
  CombatTurn(this.state);
  final CombatState state;
  Map<String, dynamic> get _m => state.turn;

  Map<String, dynamic> get _used {
    final raw = _m['used'];
    if (raw is Map<String, dynamic>) return raw;
    final copy = <String, dynamic>{
      if (raw is Map) ...raw.cast<String, dynamic>()
    };
    _m['used'] = copy;
    return copy;
  }

  bool used(TurnCost cost) =>
      cost != TurnCost.free &&
      (_m['used'] is Map) &&
      (_m['used'] as Map)[cost.key] == true;
  void setUsed(TurnCost cost, bool value) {
    if (cost == TurnCost.free) return;
    _used[cost.key] = value;
  }

  int get moved => _m['moved'] is int ? _m['moved'] as int : 0;
  set moved(int value) => _m['moved'] = value < 0 ? 0 : value;

  bool get dash => _m['dash'] == true;
  set dash(bool value) => _m['dash'] = value;

  int get attacks => _m['attacks'] is int ? _m['attacks'] as int : 0;
  set attacks(int value) => _m['attacks'] = value < 0 ? 0 : value;

  bool get sneakUsed => _m['sneak'] == true;
  set sneakUsed(bool value) => _m['sneak'] = value;

  /// A concentration save the last damage asked for (its DC), until rolled.
  int? get check => _m['check'] is int ? _m['check'] as int : null;
  set check(int? value) =>
      value == null ? _m.remove('check') : _m['check'] = value;

  /// Uncanny Dodge: the next damage from an attack is halved.
  bool get halveNext => _m['halve'] == true;
  set halveNext(bool value) => _m['halve'] = value;

  List<CombatEffect> get effects => [
        for (final raw
            in (_m['effects'] is List ? _m['effects'] as List : const []))
          if (CombatEffect.fromJson(raw) case final e?) e
      ];
  set effects(List<CombatEffect> value) =>
      _m['effects'] = [for (final e in value) e.toJson()];

  CombatEffect? effect(String key) =>
      effects.where((e) => e.key == key).firstOrNull;

  /// Adds an effect, replacing one with the same key; a new concentration
  /// effect replaces the old one.
  void addEffect(CombatEffect effect) => effects = [
        effect,
        for (final e in effects)
          if (e.key != effect.key && !(effect.concentration && e.concentration))
            e
      ];

  void removeEffect(String key) => effects = [
        for (final e in effects)
          if (e.key != key) e
      ];

  void removeConcentration() => effects = [
        for (final e in effects)
          if (!e.concentration) e
      ];

  /// A new round: the turn is fresh and every effect has one round less.
  /// Returns the effects whose time ran out.
  List<CombatEffect> advance() {
    _m['used'] = <String, dynamic>{};
    moved = 0;
    dash = false;
    attacks = 0;
    sneakUsed = false;
    final ended = <CombatEffect>[], next = <CombatEffect>[];
    for (final e in effects) {
      if (e.left > 1) {
        next.add(e.copyWith(left: e.left - 1));
      } else {
        ended.add(e);
      }
    }
    effects = next;
    return ended;
  }
}
