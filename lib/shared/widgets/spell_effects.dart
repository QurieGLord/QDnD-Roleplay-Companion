import '../../core/models/character.dart';
import '../../core/progression/character_class_context.dart';

/// What a chosen slot gives, as one large value and a short line under it
/// (prototype `EFFECT`). Only spells whose effect can be stated in one
/// line are listed; the rest show their facts alone.
typedef SpellEffect = ({String value, String label, String? duration});

String _plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

int _cantripDice(int level) => level >= 17
    ? 4
    : level >= 11
        ? 3
        : level >= 5
            ? 2
            : 1;

/// [circle] is the slot level chosen (the spell's own for a cantrip),
/// [mod] the casting modifier of the source.
SpellEffect? spellEffect(String spellId, int circle, int mod, Character hero, {required bool ru}) {
  final k = ru ? 'к' : 'd';
  // The noun alone; the number is the large value above it.
  String w(int count, String one, String few, String many, String en) =>
      ru ? _plural(count, one, few, many) : (count == 1 ? en : '${en}s');
  String targets(int count) => w(count, 'цель', 'цели', 'целей', 'target');
  final life = CharacterClassContext(hero, 'cleric').subclass?.toLowerCase().contains('life') == true;
  final lifeBonus = life ? 2 + circle : 0;
  final total = hero.classes.fold<int>(0, (t, e) => t + e.level);
  SpellEffect e(Object value, String ruLabel, String enLabel, [String? duration]) =>
      (value: '$value', label: ru ? ruLabel : enLabel, duration: duration);
  final heal = lifeBonus > 0 ? (ru ? 'лечения · с Адептом жизни' : 'healing · Disciple of Life') : (ru ? 'лечения' : 'healing');
  return switch (spellId.replaceAll('_', '-')) {
    'healing-word' => (value: '$circle${k}4 + ${mod + lifeBonus}', label: heal, duration: null),
    'cure-wounds' => (value: '$circle${k}8 + ${mod + lifeBonus}', label: heal, duration: null),
    'thunderwave' => e('${circle + 1}${k}8', 'звуком · отталкивает на 10 фт.', 'thunder · pushes 10 ft.'),
    'sleep' => e('${5 + 2 * (circle - 1)}${k}8', 'ОЗ существ засыпают', 'HP of creatures fall asleep'),
    'charm-person' || 'command' => (value: '$circle', label: targets(circle), duration: null),
    'shatter' => e('${circle + 1}${k}8', 'звуком в сфере 10 фт.', 'thunder in a 10-ft. sphere'),
    'invisibility' => (value: '${circle - 1}', label: targets(circle - 1), duration: null),
    'bless' => (
        value: '${circle + 2}',
        label: '${targets(circle + 2)} · ${ru ? '+1к4 к атакам и спасброскам' : '+1d4 to attacks and saves'}',
        duration: null
      ),
    'guiding-bolt' => e('${circle + 3}${k}6', 'излучением · следующая атака с преимуществом', 'radiant · next attack has advantage'),
    'moonbeam' => e('$circle${k}10', 'излучением в столпе света', 'radiant in a beam of light'),
    'aid' => e('+${5 * (circle - 1)}', 'к ОЗ трёх целей', 'HP for three targets'),
    'hunters-mark' => e('+1${k}6', 'урона по цели', 'damage to the target',
        circle >= 5 ? (ru ? '24 ч.' : '24 h') : circle >= 3 ? (ru ? '8 ч.' : '8 h') : (ru ? '1 ч.' : '1 h')),
    'burning-hands' => e('${circle + 2}${k}6', 'огнём в конусе 15 фт.', 'fire in a 15-ft. cone'),
    'scorching-ray' => (
        value: '${circle + 1}',
        label: '${w(circle + 1, 'луч', 'луча', 'лучей', 'ray')} ${ru ? 'по 2к6 огнём' : 'of 2d6 fire'}',
        duration: null
      ),
    'fireball' => e('${circle + 5}${k}6', 'огнём в сфере 20 фт.', 'fire in a 20-ft. sphere'),
    'hellish-rebuke' => e('${circle + 1}${k}10', 'огнём · реакцией', 'fire · reaction'),
    'hold-person' => (
        value: '${circle - 1}',
        label: w(circle - 1, 'гуманоид', 'гуманоида', 'гуманоидов', 'humanoid'),
        duration: null
      ),
    'counterspell' => e('≤ $circle', 'круг прерывается без проверки', 'level ends with no check'),
    'fly' => (
        value: '${circle - 2}',
        label: '${targets(circle - 2)} · ${ru ? 'полёт 60 фт.' : 'fly 60 ft.'}',
        duration: null
      ),
    'banishment' => (value: '${circle - 3}', label: targets(circle - 3), duration: null),
    'hold-monster' => (value: '${circle - 4}', label: targets(circle - 4), duration: null),
    'magic-missile' => (
        value: '${circle + 2}',
        label: '${w(circle + 2, 'снаряд', 'снаряда', 'снарядов', 'dart')} ${ru ? 'по 1к4 + 1' : 'of 1d4 + 1'}',
        duration: null
      ),
    'lightning-bolt' => e('${circle + 5}${k}6', 'электричеством в линии 100 фт.', 'lightning in a 100-ft. line'),
    'ice-storm' => e('${circle - 2}${k}8 + 4${k}6', 'дробящим и холодом', 'bludgeoning and cold'),
    'shield' => e('+5', 'КД до начала вашего хода', 'AC until your next turn'),
    'mage-armor' => e(ru ? '13 + ЛОВ' : '13 + DEX', 'КД без доспехов', 'AC without armour'),
    'divine-favor' => e('+1${k}4', 'излучением к атакам оружием', 'radiant on weapon attacks'),
    'heroism' => e('+$mod', 'временных ОЗ в начале каждого хода', 'temporary HP each turn'),
    'shield-of-faith' => e('+2', 'к КД цели', 'AC for the target'),
    'misty-step' => e(ru ? '30 фт.' : '30 ft.', 'телепортация', 'teleport'),
    'haste' => e('×2', 'скорость · +2 КД · ещё действие', 'speed · +2 AC · an extra action'),
    'eldritch-blast' => e('${_cantripDice(total)} × ${k}10', 'силовым, по лучу',
        'force, per beam'),
    'fire-bolt' => e('${_cantripDice(total)}${k}10', 'огнём', 'fire'),
    'sacred-flame' => e('${_cantripDice(total)}${k}8', 'излучением · спасбросок Ловкости', 'radiant · Dexterity save'),
    _ => null,
  };
}
