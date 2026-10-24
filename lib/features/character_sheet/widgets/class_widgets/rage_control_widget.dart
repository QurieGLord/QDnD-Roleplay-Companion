import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Barbarian · Rage (prototype `CLASS.barbarian`). Hold the bar to fly into
/// a rage: heat floods in and the instrument flares once. Claws count the
/// rages, three marks light up while it lasts, a fuse burns the minute.
class RageControlWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature rageFeature;
  final VoidCallback? onChanged;

  const RageControlWidget({
    super.key,
    required this.character,
    required this.rageFeature,
    this.onChanged,
  });

  @override
  State<RageControlWidget> createState() => _RageControlWidgetState();
}

class _RageControlWidgetState extends State<RageControlWidget>
    with TickerProviderStateMixin {
  bool _busy = false;
  int _round = 1;
  late final _hold = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))
    ..addListener(_holdTick)
    ..addStatusListener(_holdDone);
  int _ticks = 0;
  late final _stripes = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  Character get _hero => widget.character;
  bool get _ru => instrumentRu(context);

  static const _exhaustion = [
    '',
    'помеха на проверки характеристик',
    'скорость вдвое меньше',
    'помеха на атаки и спасброски',
    'максимум ОЗ вдвое меньше',
    'скорость 0',
    'смерть'
  ];
  static const _exhaustionEn = [
    '',
    'disadvantage on ability checks',
    'speed halved',
    'disadvantage on attacks and saves',
    'hit point maximum halved',
    'speed 0',
    'death'
  ];

  @override
  void dispose() {
    _hold.dispose();
    _stripes.dispose();
    super.dispose();
  }

  void _holdTick() {
    if (_hold.status != AnimationStatus.forward) return;
    if (_hold.value > (_ticks + 1) / 3 && _ticks < 2) {
      _ticks++;
      HapticFeedback.selectionClick();
    }
  }

  void _holdDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // The third beat lands: rage breaks out.
      HapticFeedback.heavyImpact();
      _toggleRage(true).whenComplete(() {
        if (mounted) _hold.value = 0;
      });
    }
  }

  void _holdStart() {
    if (_busy) return;
    _ticks = 0;
    _hold.forward(from: 0);
  }

  void _holdCancel() {
    if (_hold.status != AnimationStatus.forward) return;
    _hold.animateWith(SpringSimulation(AppMotion.snappy, _hold.value, 0, 0));
  }

  CharacterFeature? _feature(String token) {
    final owner = CharacterClassContext(_hero, 'barbarian');
    return _hero.features
        .where((f) =>
            f.id.toLowerCase().contains(token) &&
            owner.canUseFeature(f) &&
            f.minLevel <= owner.level)
        .firstOrNull;
  }

  Future<void> _toggleRage(bool value) async {
    if (_busy) return;
    final ru = _ru;
    final concentration = _hero.concentratingOn;
    if (value && concentration != null) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(ru ? 'Начать ярость?' : 'Enter rage?'),
                  content: Text(ru
                      ? 'Ярость завершит текущую концентрацию.'
                      : 'Rage will end your current concentration.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(ru ? 'Назад' : 'Back')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(ru ? 'Начать ярость' : 'Enter rage'))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    final frenzied = _hero.isFrenzied;
    try {
      final changed = await ClassSessionActionsService.rage(
          _hero, widget.rageFeature.id, value,
          expectedConcentration: concentration);
      if (!mounted || !changed) return;
      HapticFeedback.mediumImpact();
      _round = 1;
      widget.onChanged?.call();
      if (!value && frenzied && mounted) {
        AppSnackBar.success(context,
            ru ? 'Ярость завершилась · истощение +1' : 'Rage ended · exhaustion +1');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            ru
                ? 'Не удалось изменить ярость. Проверь состояние и остаток использований.'
                : 'Could not change rage. Check your conditions and remaining uses.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _helper({bool? reckless, bool? frenzied}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ClassSessionActionsService.helpers(_hero,
          reckless: reckless, frenzied: frenzied);
      HapticFeedback.selectionClick();
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context,
            _ru ? 'Не удалось сохранить умение.' : 'Could not save the feature.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final changed = await showResourceValueEditor(context, _hero, widget.rageFeature);
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.rageFeature.resourcePool;
    if (pool == null) return const SizedBox.shrink();
    final ru = _ru, locale = ru ? 'ru' : 'en';
    final a0 = accentOf(context, 0), a1 = accentOf(context, 1);
    final level = _hero.classLevel('barbarian');
    final dmg = level >= 16 ? 4 : level >= 9 ? 3 : 2;
    final unlimited = ClassSessionActionsService.unlimitedRage(_hero);
    final on = _hero.isRaging, reckless = _hero.isReckless, exh = _hero.exhaustionLevel;
    final frenzy = _feature('frenzy'), recklessFeature = _feature('reckless');
    if (_hero.isReckless && !_stripes.isAnimating && !MediaQuery.disableAnimationsOf(context)) {
      _stripes.repeat(count: 8);
    } else if (!_hero.isReckless && _stripes.isAnimating) {
      _stripes.stop();
    }
    final claws = math.min(6, pool.maxUses);

    return Pulse(
      trigger: on,
      scale: 1.02,
      child: Instrument(
        key: const ValueKey('barbarian-rage'),
        accent: a0,
        title: on ? (ru ? 'В ярости' : 'Raging') : widget.rageFeature.getName(locale),
        about: InstrumentAbout(
            title: widget.rageFeature.getName(locale),
            kicker: ru ? 'Бонусное действие · длительный отдых' : 'Bonus action · long rest',
            paragraphs: widget.rageFeature.getDescription(locale).split(RegExp(r'\n\s*\n')),
            how: ru
                ? 'Удерживайте полосу — ярость начнётся. Стрелка отсчитывает раунды, «Конец» завершает её.'
                : 'Hold the bar to rage. The arrow counts rounds, “End” stops it.'),
        border: on ? a0.withValues(alpha: .7) : null,
        glow: on ? a0 : null,
        background: Stack(children: [
          AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: AppMotion.of(context, const Duration(milliseconds: 700)),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: const Alignment(.7, -1.2),
                        radius: 1.1,
                        colors: [a0.withValues(alpha: .55), a0.withValues(alpha: 0)],
                        stops: const [0, .62]))),
          ),
          AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: AppMotion.of(context, const Duration(milliseconds: 700)),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: const Alignment(-1, 1.2),
                        radius: .8,
                        colors: [a1.withValues(alpha: .4), a1.withValues(alpha: 0)],
                        stops: const [0, .6]))),
          ),
          if (reckless)
            AnimatedBuilder(
                animation: _stripes,
                builder: (context, _) => CustomPaint(
                    painter: _HazardEdges(a1.withValues(alpha: .3), _stripes.value))),
        ]),
        trailing: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: [
          if (exh > 0) ...[
            InstrumentChip('$exh',
                glyph: 'skull',
                color: a1,
                peek: (
                  ru ? 'Истощение $exh' : 'Exhaustion $exh',
                  (ru ? _exhaustion : _exhaustionEn).sublist(1, math.min(7, exh + 1)).join(' · ')
                )),
          ],
          RestChip(
              short: false,
              onEdit: _edit,
              onRestore: () => restoreFeature(context, _hero, widget.rageFeature, done: () => setState(() => widget.onChanged?.call()))),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Peek(
              title: ru ? 'Ярость' : 'Rage',
              text: unlimited
                  ? (ru ? 'Без ограничений' : 'Unlimited')
                  : (ru
                      ? '${pool.currentUses} из ${pool.maxUses} до длительного отдыха'
                      : '${pool.currentUses} of ${pool.maxUses} until a long rest'),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < claws; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _Claw(on: unlimited || i < pool.currentUses, tall: i.isOdd, a0: a0, a1: a1),
                ],
              ]),
            ),
            const Spacer(),
            Peek(
              title: ru ? 'Урон ярости' : 'Rage damage',
              text: ru
                  ? '+$dmg к урону рукопашными атаками на Силе'
                  : '+$dmg to Strength melee damage',
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(unlimited ? '∞' : '+$dmg', style: hugeStyle(context)),
                const SizedBox(height: 4),
                Text(ru ? 'урон' : 'damage',
                    style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          TileRow(gap: 8, children: [
            StateBadge(
                glyph: 'shield',
                label: ru ? 'Стойкость' : 'Resist',
                accent: a0,
                on: on,
                peek: (
                  ru ? 'Сопротивление' : 'Resistance',
                  ru
                      ? 'Дробящий, колющий и рубящий урон по вам — вдвое меньше'
                      : 'Bludgeoning, piercing and slashing damage is halved'
                )),
            StateBadge(
                glyph: 'up',
                label: ru ? 'Сила' : 'Strength',
                accent: a0,
                on: on,
                peek: (
                  ru ? 'Сила' : 'Strength',
                  ru
                      ? 'Преимущество на проверки и спасброски Силы'
                      : 'Advantage on Strength checks and saves'
                )),
            StateBadge(
                key: const ValueKey('barbarian-frenzy'),
                glyph: 'axe',
                label: frenzy?.getName(locale).split(' ').first ?? (ru ? 'Бешенство' : 'Frenzy'),
                accent: a0,
                locked: frenzy == null,
                pressed: _hero.isFrenzied,
                onTap: frenzy != null && on && !_hero.isFrenzied && !_busy
                    ? () => _helper(frenzied: true)
                    : null,
                peek: (
                  frenzy?.getName(locale) ?? (ru ? 'Бешенство' : 'Frenzy'),
                  frenzy == null
                      ? (ru ? 'Путь берсерка, 3 уровень' : 'Path of the Berserker, level 3')
                      : (ru
                          ? 'В ярости — бонусная атака каждый ход. После ярости — 1 степень истощения'
                          : 'While raging, a bonus attack each turn. One level of exhaustion when it ends')
                )),
          ]),
          const SizedBox(height: 14),
          if (on) ...[
            Peek(
              title: ru ? 'Минута ярости' : 'A minute of rage',
              text: ru
                  ? '10 раундов. Кончается раньше, если за ход вы не атаковали и не получили урон'
                  : '10 rounds. Ends early if you neither attacked nor took damage this turn',
              child: Fuse(length: 10, at: _round, accent: a0),
            ),
            const SizedBox(height: 12),
            RoundControl(
              round: _round,
              of: 10,
              accent: a0,
              label: ru ? 'раунд' : 'round',
              endLabel: ru ? 'Конец' : 'End',
              onEnd: _busy ? null : () => _toggleRage(false),
              onNext: () {
                HapticFeedback.selectionClick();
                setState(() => _round = math.min(10, _round + 1));
                if (_round == 10) {
                  AppSnackBar.info(context, ru ? 'Последний раунд ярости' : 'Last round of rage');
                }
              },
            ),
          ] else
            _HoldBar(
              progress: _hold,
              enabled: unlimited || pool.currentUses > 0,
              label: unlimited || pool.currentUses > 0
                  ? (ru ? 'Удерживайте — ярость' : 'Hold to rage')
                  : (ru ? 'Вернёт длительный отдых' : 'A long rest restores it'),
              a0: a0,
              a1: a1,
              onDown: _holdStart,
              onUp: _holdCancel,
            ),
          if (recklessFeature != null) ...[
            const SizedBox(height: 10),
            SwitchRow(
              key: const ValueKey('barbarian-reckless'),
              label: recklessFeature.getName(locale),
              glyph: 'strikes',
              value: reckless,
              accent: a1,
              onChanged: _busy ? null : (v) => _helper(reckless: v),
              peek: (
                recklessFeature.getName(locale),
                ru
                    ? 'Первая атака в ход — с преимуществом. До вашего хода атаки по вам тоже с преимуществом'
                    : 'Your first attack this turn has advantage; attacks against you do too until your next turn'
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Claw extends StatelessWidget {
  const _Claw({required this.on, required this.tall, required this.a0, required this.a1});
  final bool on, tall;
  final Color a0, a1;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Transform(
      transform: Matrix4.skewX(-.28),
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 13,
        height: tall ? 64 : 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: on
              ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [a1, a0])
              : null,
          border: on ? null : Border.all(color: c.outline, width: 2),
        ),
      ),
    );
  }
}

/// Hold to rage: the bar fills with heat, ticking at a third and two
/// thirds; released early it springs back.
class _HoldBar extends StatelessWidget {
  const _HoldBar(
      {required this.progress,
      required this.enabled,
      required this.label,
      required this.a0,
      required this.a1,
      required this.onDown,
      required this.onUp});
  final Animation<double> progress;
  final bool enabled;
  final String label;
  final Color a0, a1;
  final VoidCallback onDown, onUp;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Semantics(
        button: true,
        label: label,
        onTap: enabled ? onDown : null,
        child: Listener(
          key: const ValueKey('barbarian-hold'),
          onPointerDown: enabled ? (_) => onDown() : null,
          onPointerUp: enabled ? (_) => onUp() : null,
          onPointerCancel: enabled ? (_) => onUp() : null,
          child: Container(
            height: 62,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: c.onSurface.withValues(alpha: .08), borderRadius: BorderRadius.circular(31)),
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) {
                final p = progress.value.clamp(0.0, 1.0);
                return Stack(fit: StackFit.expand, children: [
                  // Heat fills the bar under the finger; the full height,
                  // or the fill has no body to show.
                  FractionallySizedBox(
                    widthFactor: p,
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [a1, a0]),
                        boxShadow: [
                          if (p > 0)
                            BoxShadow(color: a0.withValues(alpha: .55 * p), blurRadius: 18, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
                  // The three beats of the hold, each a tick under the finger.
                  for (final third in [1 / 3, 2 / 3])
                    Align(
                      alignment: Alignment(third * 2 - 1, 0),
                      child: Container(
                        width: 2,
                        height: 18,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: (p >= third ? Colors.white : c.onSurface).withValues(alpha: p >= third ? .55 : .14)),
                      ),
                    ),
                  Center(
                    child: Transform.scale(
                      scale: 1 + .06 * p,
                      child: Text(label,
                          style: labelStyle(context, size: 15).copyWith(color: p > .45 ? Colors.white : null)),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Moving hazard stripes along the top and bottom edges (reckless).
class _HazardEdges extends CustomPainter {
  _HazardEdges(this.color, this.t);
  final Color color;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final y in [0.0, size.height - 6]) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, y, size.width, 6));
      for (double x = -28 + t * 28; x < size.width + 20; x += 20) {
        canvas.drawPath(
            Path()
              ..moveTo(x, y + 6)
              ..lineTo(x + 6, y)
              ..lineTo(x + 16, y)
              ..lineTo(x + 10, y + 6)
              ..close(),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HazardEdges old) => old.t != t || old.color != color;
}
