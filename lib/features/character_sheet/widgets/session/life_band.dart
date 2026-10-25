import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/models/character.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/companion_kit.dart';
import '../../../../core/ui/expressive_hold_surface.dart';
import '../../../../core/ui/expressive_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../class_widgets/instrument/instrument_kit.dart';
import 'hp_keypad_sheet.dart';
import 'value_editors.dart';

/// Wave 3 (`docs/prototypes/wave3`, `.life` and `.brink`): the hero's health
/// as one block that changes its mind. Standing, it is the life band — a
/// large number and a bar the finger drags: left is damage, right is
/// healing. At 0 HP the same block becomes the brink with its lamps,
/// skulls and the death-save die; back on their feet the number climbs
/// from zero.
class LifeSection extends StatefulWidget {
  const LifeSection(
      {super.key, required this.character, this.onChanged, this.random});
  final Character character;
  final VoidCallback? onChanged;
  final math.Random? random;
  @override
  State<LifeSection> createState() => _LifeSectionState();
}

enum _Kind { life, brink, stable, dead }

class _LifeSectionState extends State<LifeSection> {
  bool _busy = false;
  _Kind? _was;
  bool _rise = false, _fell = false;

  Character get _c => widget.character;
  bool get _form =>
      _c.isWildShaped && _c.beastCurrentHp != null && _c.beastMaxHp != null;

  _Kind get _kind => _form || _c.currentHp > 0
      ? _Kind.life
      : _c.deathSaves.isDead
          ? _Kind.dead
          : _c.deathSaves.isStabilized
              ? _Kind.stable
              : _Kind.brink;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sheet(HpChange mode) => _run(() async {
        await showHpKeypad(context, _c, mode: mode);
      });

  Future<void> _edit() => _run(() async {
        await showHealthValueEditor(context, _c, form: _form);
      });

  Future<void> _scrub(int delta) => _run(() async {
        if (delta > 0) {
          await GameplayActionsService.changeHealth(_c, delta, healing: true);
        } else {
          await GameplayActionsService.takeHit(_c, -delta);
        }
        if (delta < 0 && _c.currentHp == 0) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      });

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    if (_was != null && _was != kind) {
      // Rising from the brink, the number counts up from zero; falling,
      // the brink arrives with a flash.
      _rise = _was != _Kind.life && kind == _Kind.life;
      _fell = _was == _Kind.life && kind != _Kind.life;
    }
    _was = kind;
    final d = AppMotion.of(context, AppMotion.gentleSettle);
    return CalmSize(
      duration: d,
      curve: AppMotion.gentleCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, const Duration(milliseconds: 520)),
        switchInCurve: AppMotion.snappyCurve,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) =>
            Stack(alignment: Alignment.topCenter, children: [
          for (final p in previous)
            Positioned(left: 0, right: 0, top: 0, child: p),
          if (current != null) current,
        ]),
        transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
                position: Tween(begin: const Offset(0, .04), end: Offset.zero)
                    .animate(a),
                child: child)),
        child: kind == _Kind.life
            ? _LifeBand(
                key: const ValueKey('life'),
                character: _c,
                form: _form,
                busy: _busy,
                rise: _rise,
                onSheet: _sheet,
                onEdit: _edit,
                onScrub: _scrub)
            : _Brink(
                key: ValueKey('brink-${kind.name}'),
                character: _c,
                busy: _busy,
                fell: _fell,
                random: widget.random,
                onRun: _run,
                onSheet: _sheet),
      ),
    );
  }
}

/* ---------------------------------------------------------------- life */

class _LifeBand extends StatefulWidget {
  const _LifeBand({
    super.key,
    required this.character,
    required this.form,
    required this.busy,
    required this.rise,
    required this.onSheet,
    required this.onEdit,
    required this.onScrub,
  });
  final Character character;
  final bool form, busy, rise;
  final void Function(HpChange) onSheet;
  final VoidCallback onEdit;
  final void Function(int delta) onScrub;
  @override
  State<_LifeBand> createState() => _LifeBandState();
}

class _LifeBandState extends State<_LifeBand> with TickerProviderStateMixin {
  late final _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  int? _delta; // while the finger drags the bar
  double _dragX = 0, _width = 1;
  late int _last = _current;

  Character get _c => widget.character;
  int get _current => widget.form ? _c.beastCurrentHp! : _c.currentHp;
  int get _maximum => math.max(1, widget.form ? _c.beastMaxHp! : _c.maxHp);
  int get _temp => widget.form ? 0 : _c.temporaryHp;

  @override
  void initState() {
    super.initState();
    if (widget.rise) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !MediaQuery.disableAnimationsOf(context)) {
          _glow.forward(from: 0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _LifeBand old) {
    super.didUpdateWidget(old);
    final now = _current;
    if (now != _last && !MediaQuery.disableAnimationsOf(context)) {
      if (now < _last) {
        _shake.forward(from: 0);
      } else {
        _glow.forward(from: 0);
      }
    }
    _last = now;
  }

  @override
  void dispose() {
    _shake.dispose();
    _glow.dispose();
    super.dispose();
  }

  Color _hpColor(BuildContext context, int hp) {
    final c = Theme.of(context).colorScheme;
    final p = hp / _maximum;
    return hp == 0
        ? c.outline
        : p > .5
            ? c.primary
            : p > .25
                ? accentOf(context, 1)
                : accentOf(context, 0);
  }

  // The prototype's scrub: the whole bar is ~0.9 of the maximum, damage
  // spends temporary HP first, ticks every 5.
  int _deltaAt(double dx) => (dx / _width * _maximum * .9).round();

  void _start(DragStartDetails d) {
    if (widget.busy) return;
    _dragX = d.localPosition.dx;
    setState(() => _delta = 0);
  }

  void _move(DragUpdateDetails d) {
    if (_delta == null) return;
    final next = _deltaAt(d.localPosition.dx - _dragX);
    if ((next.abs() ~/ 5) != (_delta!.abs() ~/ 5)) {
      HapticFeedback.selectionClick();
    }
    setState(() => _delta = next);
  }

  void _end([DragEndDetails? _]) {
    final delta = _delta;
    setState(() => _delta = null);
    if (delta == null || delta == 0) return;
    final current = _current, temp = _temp;
    if (delta > 0 && current >= _maximum) return;
    if (delta < 0 && current == 0 && temp == 0) return;
    widget.onScrub(delta > 0 ? math.min(delta, _maximum - current) : delta);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final current = _current, maximum = _maximum, temp = _temp;
    // The label is honest about a zero maximum; the bar divides by one.
    final shownMax = widget.form ? _c.beastMaxHp! : _c.maxHp;
    final delta = _delta;
    final shieldUse = delta != null && delta < 0 ? math.min(temp, -delta) : 0;
    final target = delta == null
        ? current
        : delta < 0
            ? (current + delta + shieldUse).clamp(0, maximum)
            : (current + delta).clamp(0, maximum);
    final hpc = _hpColor(context, delta == null ? current : target);
    final heal = AppPaletteRoles.heal(context);
    final a4 = accentOf(context, 4);
    const radius = BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
        bottomRight: Radius.circular(32),
        bottomLeft: Radius.circular(20));
    final p0 = current / maximum, p1 = target / maximum;
    final shieldW = math.min(1.0, temp / maximum);
    final numberStyle = AppType.numeric(t.textTheme.displayLarge).copyWith(
        fontFamily: AppType.display,
        fontSize: 76,
        height: .86,
        fontWeight: FontWeight.w600,
        letterSpacing: -3,
        color: hpc);

    final band = Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
          borderRadius: radius,
          color: Color.alphaBlend(
              c.secondary.withValues(alpha: .08), c.surfaceContainer)),
      clipBehavior: Clip.antiAlias,
      child: Stack(clipBehavior: Clip.none, children: [
        // The corner glow takes the colour of the hero's health.
        Positioned(
          right: -80,
          top: -90,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    hpc.withValues(alpha: .30),
                    hpc.withValues(alpha: 0)
                  ], stops: const [
                    0,
                    .65
                  ])),
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.form)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text((_c.beastName ?? l10n.sheetHealthForm).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: capStyle(context, accentOf(context, 3))),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Semantics(
                key: const ValueKey('life-number'),
                button: true,
                label: '$current / $shownMax',
                excludeSemantics: true,
                onTap:
                    widget.busy ? null : () => widget.onSheet(HpChange.damage),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.busy
                      ? null
                      : () => widget.onSheet(HpChange.damage),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RollingNumber(target,
                              from: widget.rise ? 0 : null, style: numberStyle),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('/ $shownMax',
                                style: AppType.numeric(t.textTheme.titleLarge)
                                    .copyWith(
                                        fontFamily: AppType.display,
                                        fontSize: 24,
                                        height: 1,
                                        fontWeight: FontWeight.w600,
                                        color: c.onSurfaceVariant)),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!widget.form)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _TempShield(
                    value: temp,
                    busy: widget.busy,
                    onTap: () => widget.onSheet(HpChange.temporary)),
              ),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            _width = math.max(1, box.maxWidth);
            final w = _width;
            final lo = math.min(p0, p1), hi = math.max(p0, p1);
            final duration = delta == null
                ? AppMotion.of(context, const Duration(milliseconds: 520))
                : Duration.zero;
            return Semantics(
              label: ru
                  ? 'Протяните: влево — урон, вправо — лечение'
                  : 'Drag: left for damage, right for healing',
              child: GestureDetector(
                key: const ValueKey('life-bar'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _start,
                onHorizontalDragUpdate: _move,
                onHorizontalDragEnd: _end,
                onHorizontalDragCancel: _end,
                child: SizedBox(
                  height: 30,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: c.onSurface.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(15))),
                    ),
                    AnimatedPositioned(
                      duration: duration,
                      curve: AppMotion.snappyCurve,
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: w * (delta == null ? p0 : lo),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(colors: [
                            Color.lerp(accentOf(context, 1), hpc, .7)!,
                            hpc
                          ]),
                        ),
                      ),
                    ),
                    if (delta != null && delta != 0)
                      Positioned(
                        left: w * lo,
                        width: w * (hi - lo),
                        top: 0,
                        bottom: 0,
                        child: _Stripes(
                            color: delta < 0 ? c.primary : heal,
                            solid: delta > 0,
                            radius: 15),
                      ),
                    if (temp > 0)
                      AnimatedPositioned(
                        duration: duration,
                        curve: AppMotion.snappyCurve,
                        left: w * (p0 - math.min(p0, shieldW)),
                        width: w * shieldW,
                        top: -4,
                        bottom: -4,
                        child: _Stripes(color: a4, ring: true, radius: 17),
                      ),
                    if (delta != null) ...[
                      Positioned(
                        left: w * p1 - 3,
                        top: -7,
                        child: Container(
                          width: 6,
                          height: 44,
                          decoration: BoxDecoration(
                              color: c.onSurface,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                    color: c.surface.withValues(alpha: .6),
                                    spreadRadius: 4)
                              ]),
                        ),
                      ),
                      Positioned(
                        left: (w * p1).clamp(w * .08, w * .92) - 60,
                        width: 120,
                        bottom: 40,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: delta < 0
                                    ? c.primary
                                    : delta > 0
                                        ? heal
                                        : c.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                delta == 0
                                    ? (ru ? 'Протяните' : 'Drag')
                                    : delta < 0
                                        ? '−${-delta}${shieldUse > 0 ? (ru ? ' · щит $shieldUse' : ' · shield $shieldUse') : ''}'
                                        : '+${target - current}',
                                maxLines: 1,
                                style: TextStyle(
                                    fontFamily: AppType.display,
                                    fontSize: 15,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        delta == 0 ? c.onSurface : c.surface)),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(children: [
            InstrumentGlyph('swap', size: 15, color: c.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  widget.form
                      ? '${l10n.sheetHealthBase}: ${_c.currentHp} / ${_c.maxHp}'
                      : ru
                          ? 'Протяните полосу: влево — урон, вправо — лечение'
                          : 'Drag the bar: left for damage, right for healing',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 13,
                      height: 1.3,
                      color: c.onSurfaceVariant)),
            ),
          ]),
        ]),
      ]),
    );

    return ExpressiveHoldSurface(
      enabled: !widget.busy && delta == null,
      semanticLabel: widget.form ? l10n.sheetHealthForm : l10n.hitPoints,
      hint: l10n.sheetHoldToEdit,
      onHold: widget.onEdit,
      child: AnimatedBuilder(
        animation: Listenable.merge([_shake, _glow]),
        builder: (context, child) {
          final s = _shake.value;
          // 20% −7, 40% +6, 60% −3, back to rest.
          final x = s < .2
              ? -7 * s / .2
              : s < .4
                  ? -7 + 13 * (s - .2) / .2
                  : s < .6
                      ? 6 - 9 * (s - .4) / .2
                      : -3 + 3 * (s - .6) / .4;
          final g = _glow.isAnimating ? 1 - _glow.value : 0.0;
          return Transform.translate(
            offset: Offset(_shake.isAnimating ? x : 0, 0),
            child: Stack(children: [
              child!,
              if (g > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                              color: heal.withValues(alpha: g), width: 2)),
                    ),
                  ),
                ),
            ]),
          );
        },
        child: band,
      ),
    );
  }
}

/// Temporary HP as a shield pill; faded when there is none.
class _TempShield extends StatelessWidget {
  const _TempShield(
      {required this.value, required this.busy, required this.onTap});
  final int value;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a4 = accentOf(context, 4);
    final zero = value == 0;
    final fg = zero ? c.onSurfaceVariant : a4;
    final ru = instrumentRu(context);
    return Peek(
      title: ru ? 'Временные ОЗ' : 'Temporary HP',
      text: ru
          ? 'Щит поверх здоровья: урон сначала снимает его'
          : 'A shield over health: damage takes it first',
      accent: a4,
      child: Pressable(
        key: const ValueKey('life-temp'),
        onTap: busy ? null : onTap,
        scale: .94,
        semanticLabel: ru ? 'Временные ОЗ: $value' : 'Temporary HP: $value',
        child: Opacity(
          opacity: zero ? .45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: ShapeDecoration(
              color: zero ? null : a4.withValues(alpha: .18),
              shape: StadiumBorder(
                  side: BorderSide(
                      color: zero
                          ? c.onSurface.withValues(alpha: .18)
                          : a4.withValues(alpha: .55),
                      width: 1.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('shield', size: 15, color: fg),
              const SizedBox(width: 6),
              RollingNumber(value,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 13,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Diagonal stripes: the shield of temporary HP, or the ghost of a change
/// while the finger drags.
class _Stripes extends StatelessWidget {
  const _Stripes(
      {required this.color,
      this.solid = false,
      this.ring = false,
      required this.radius});
  final Color color;
  final bool solid, ring;
  final double radius;
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _StripePainter(color, solid, ring, radius),
      );
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color, this.solid, this.ring, this.radius);
  final Color color;
  final bool solid, ring;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final rr =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rr);
    if (solid) {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = color.withValues(alpha: .6));
    } else {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = color.withValues(alpha: ring ? .35 : .25));
      final paint = Paint()
        ..color = color.withValues(alpha: ring ? .7 : .55)
        ..strokeWidth = ring ? 4 : 6;
      final step = ring ? 8.0 : 12.0;
      for (var x = -size.height; x < size.width + size.height; x += step) {
        canvas.drawLine(
            Offset(x, size.height), Offset(x + size.height, 0), paint);
      }
    }
    canvas.restore();
    if (ring) {
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: .8));
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.color != color || old.solid != solid || old.ring != ring;
}

/* --------------------------------------------------------------- brink */

class _Brink extends StatefulWidget {
  const _Brink({
    super.key,
    required this.character,
    required this.busy,
    required this.fell,
    required this.onRun,
    required this.onSheet,
    this.random,
  });
  final Character character;
  final bool busy, fell;
  final Future<void> Function(Future<void> Function()) onRun;
  final void Function(HpChange) onSheet;
  final math.Random? random;
  @override
  State<_Brink> createState() => _BrinkState();
}

class _BrinkState extends State<_Brink> with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  final _dieKey = GlobalKey();
  int _rollKey = 0;
  int? _face;
  String? _out;
  bool _rolling = false;
  late int _s = widget.character.deathSaves.successes,
      _f = widget.character.deathSaves.failures;
  // Marks that appeared since the last frame play their moment.
  int _litFrom = 3, _struckFrom = 3;

  @override
  void initState() {
    super.initState();
    if (widget.fell) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !MediaQuery.disableAnimationsOf(context)) {
          _flash.forward(from: 0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _Brink old) {
    super.didUpdateWidget(old);
    final saves = widget.character.deathSaves;
    _litFrom = saves.successes > _s ? _s : 3;
    _struckFrom = saves.failures > _f ? _f : 3;
    if (saves.failures > _f) HapticFeedback.mediumImpact();
    _s = saves.successes;
    _f = saves.failures;
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    final c = widget.character;
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    if (_rolling || widget.busy) return;
    if (!c.combatState.canRollDeathSaveThisRound) {
      AppSnackBar.warning(context, l10n.deathSaveAlreadyRolled);
      return;
    }
    final r = (widget.random ?? math.Random()).nextInt(20) + 1;
    setState(() {
      _rolling = true;
      _face = r;
      _out = null;
      _rollKey++;
    });
    await Future<void>.delayed(MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 760));
    if (!mounted) return;
    final color = r >= 10
        ? AppPaletteRoles.heal(context)
        : Theme.of(context).colorScheme.primary;
    final dieContext = _dieKey.currentContext;
    if (dieContext != null && dieContext.mounted) {
      floatUp(dieContext, '$r', color);
    }
    await widget.onRun(() async {
      await GameplayActionsService.rollDeathSave(c, r);
      HapticFeedback.mediumImpact();
    });
    if (!mounted) return;
    setState(() {
      _rolling = false;
      _out = r == 20
          ? (ru ? '20! Герой встаёт с 1 ОЗ' : '20! Back up with 1 HP')
          : r == 1
              ? (ru ? '1 — два провала' : '1 — two failures')
              : r >= 10
                  ? (ru ? '$r — успех' : '$r — success')
                  : (ru ? '$r — провал' : '$r — failure');
      if (c.deathSaves.isStabilized) {
        _out = ru ? 'Три успеха — стабилен' : 'Three successes — stable';
      }
      if (c.deathSaves.isDead) _out = ru ? 'Три провала' : 'Three failures';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final ru = instrumentRu(context);
    final hero = widget.character;
    final saves = hero.deathSaves;
    final dead = saves.isDead, stable = saves.isStabilized;
    final heal = AppPaletteRoles.heal(context);
    final title = dead
        ? (ru ? 'Герой пал' : 'Fallen')
        : stable
            ? (ru ? 'Стабилен' : 'Stable')
            : (ru ? 'На пороге' : 'On the brink');
    final sub = dead
        ? (ru
            ? 'Три провала. Мастер может решить иначе — вернуть героя можно вручную.'
            : 'Three failures. The GM may rule otherwise — bring the hero back by hand.')
        : stable
            ? (ru
                ? 'Без сознания, но больше не бросает. Любое лечение поднимет героя.'
                : 'Unconscious but no longer rolling. Any healing brings the hero back.')
            : (ru
                ? 'Без сознания. Каждый ход — спасбросок от смерти: 10+ успех, 20 — встаёт с 1 ОЗ, 1 — два провала.'
                : 'Unconscious. Each turn a death saving throw: 10+ succeeds, 20 stands up with 1 HP, 1 counts twice.');
    final glow = dead
        ? const Color(0xFF1A1612)
        : stable
            ? heal.withValues(alpha: .20)
            : c.primary.withValues(alpha: .22);
    Widget cap(String text) => Text(text.toUpperCase(),
        style: TextStyle(
            fontFamily: AppType.body,
            fontSize: 11.5,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: c.onSurfaceVariant));
    Widget column(String label, List<Widget> marks, {bool right = false}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: c.onSurface.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(20)),
            child: Column(
                crossAxisAlignment:
                    right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  cap(label),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final m in marks)
                      Padding(
                          padding: const EdgeInsets.only(right: 6), child: m)
                  ]),
                ]),
          ),
        );

    return AnimatedBuilder(
      animation: _flash,
      builder: (context, child) => Stack(children: [
        child!,
        if (_flash.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: RadialGradient(
                      center: const Alignment(0, -.6),
                      radius: .9,
                      colors: [
                        c.primary.withValues(alpha: .55 * (1 - _flash.value)),
                        c.primary.withValues(alpha: 0)
                      ]),
                ),
              ),
            ),
          ),
      ]),
      child: Container(
        key: const ValueKey('brink'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
              center: const Alignment(0, -1),
              radius: 1.2,
              colors: [
                Color.alphaBlend(glow, c.surfaceContainer),
                c.surfaceContainer
              ]),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          cap(ru
              ? '0 ОЗ · ${hero.maxHp} максимум'
              : '0 HP · ${hero.maxHp} maximum'),
          const SizedBox(height: 6),
          Row(children: [
            Flexible(
              child: Text(title,
                  style: const TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6)),
            ),
            const SizedBox(width: 10),
            Peek(
              title: title,
              text: sub,
              tap: true,
              accent: dead
                  ? c.outline
                  : stable
                      ? heal
                      : c.primary,
              child: Container(
                key: const ValueKey('brink-info'),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.onSurface.withValues(alpha: .08)),
                child: InstrumentGlyph('info',
                    size: 17, color: c.onSurfaceVariant),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            column(ru ? 'Успехи' : 'Successes', [
              for (var i = 0; i < 3; i++)
                _Lamp(
                    lit: i < saves.successes,
                    ignite: i >= _litFrom && i < saves.successes)
            ]),
            const SizedBox(width: 10),
            column(
                ru ? 'Провалы' : 'Failures',
                [
                  for (var i = 0; i < 3; i++)
                    _Skull(
                        on: i < saves.failures,
                        strike: i >= _struckFrom && i < saves.failures)
                ],
                right: true),
          ]),
          if (!dead && !stable) ...[
            const SizedBox(height: 14),
            Center(
              child: Semantics(
                button: true,
                label: ru ? 'Спасбросок от смерти' : 'Death saving throw',
                child: GestureDetector(
                  key: const ValueKey('brink-die'),
                  onTap: _roll,
                  child: TumbleDie(
                    key: _dieKey,
                    shape: DieShape.d20,
                    label: _face == null || _rolling
                        ? (ru ? 'к20' : 'd20')
                        : '$_face',
                    accent: c.onSurface,
                    rollKey: _rollKey,
                    natural: _rolling ? null : _face,
                    size: 104,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(ru ? 'Коснитесь — спасбросок' : 'Tap to roll',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 12,
                      color: c.onSurfaceVariant)),
            ),
          ],
          AnimatedSwitcher(
            duration: AppMotion.of(context, const Duration(milliseconds: 420)),
            transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                    scale: Tween(begin: .9, end: 1.0).animate(a),
                    child: child)),
            child: _out == null
                ? const SizedBox(height: 14)
                : Padding(
                    key: ValueKey(_out),
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_out!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w600)),
                  ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            if (dead)
              Expanded(
                child: ToneButton(
                  key: const ValueKey('brink-revive'),
                  kind: ToneKind.tonal,
                  expand: true,
                  icon: const InstrumentGlyph('heart', size: 18),
                  label: ru ? 'Вернуть с 1 ОЗ' : 'Back with 1 HP',
                  onPressed: widget.busy
                      ? null
                      : () => widget.onRun(() async {
                            await GameplayActionsService.changeHealth(hero, 1,
                                healing: true);
                            HapticFeedback.mediumImpact();
                          }),
                ),
              )
            else ...[
              Expanded(
                child: ToneButton(
                  key: const ValueKey('brink-heal'),
                  kind: ToneKind.tonal,
                  expand: true,
                  icon: const InstrumentGlyph('heart', size: 18),
                  label: ru ? 'Лечение' : 'Heal',
                  onPressed: widget.busy
                      ? null
                      : () => widget.onSheet(HpChange.healing),
                ),
              ),
              if (!stable) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Peek(
                    title: ru ? 'Стабилизация' : 'Stabilize',
                    text: ru
                        ? 'Медицина Сл 10 или «Щадящий» — герой больше не бросает'
                        : 'Medicine DC 10 or Spare the Dying — no more rolls',
                    accent: heal,
                    child: ToneButton(
                      key: const ValueKey('brink-stabilize'),
                      kind: ToneKind.plain,
                      expand: true,
                      icon: const LineIcon('check', size: 18),
                      label: ru ? 'Стабилен' : 'Stable',
                      onPressed: widget.busy
                          ? null
                          : () => widget.onRun(() async {
                                await GameplayActionsService.combat(
                                    hero, () => hero.deathSaves.successes = 3);
                                HapticFeedback.lightImpact();
                              }),
                    ),
                  ),
                ),
              ],
            ],
          ]),
        ]),
      ),
    );
  }
}

/// A lantern of a death-save success; a new one ignites.
class _Lamp extends StatelessWidget {
  const _Lamp({required this.lit, required this.ignite});
  final bool lit, ignite;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final heal = AppPaletteRoles.heal(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final stroke = lit ? heal : c.onSurface.withValues(alpha: .25);
    final fill =
        lit ? heal.withValues(alpha: .14) : c.onSurface.withValues(alpha: .06);
    final glass = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 38 50">'
        '<path d="M12 8h14l4 8v20l-4 8H12l-4-8V16z" fill="${_hex(fill)}" fill-opacity="${fill.a.toStringAsFixed(2)}" '
        'stroke="${_hex(stroke)}" stroke-opacity="${stroke.a.toStringAsFixed(2)}" stroke-width="2"/></svg>';
    final flame = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 38 50">'
        '<path d="M19 18c3 4 6 7 6 12a6 6 0 0 1-12 0c0-4 3-6 4-9 1 2 2 3 2 5 1-2 1-5 0-8z" fill="${_hex(heal)}"/></svg>';
    Widget flameLayer(double scale, double opacity) => Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
              scale: scale,
              alignment: const Alignment(0, .2),
              child: SvgPicture.string(flame, width: 32, height: 42)),
        );
    return SizedBox(
      width: 32,
      height: 42,
      child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (lit)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: ignite && !still ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: AppMotion.enter,
                builder: (context, g, _) => IgnorePointer(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          heal.withValues(
                              alpha: .55 *
                                  (g < .35
                                      ? g / .35
                                      : 1 - .65 * (g - .35) / .65)),
                          heal.withValues(alpha: 0)
                        ], stops: const [
                          0,
                          .65
                        ])),
                  ),
                ),
              ),
            SvgPicture.string(glass, width: 32, height: 42),
            if (lit)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: ignite && !still ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: 900),
                builder: (context, p, _) {
                  // .1 → 1.45 → .85 → 1.08 → 1
                  final s = p < .35
                      ? .1 + 1.35 * (p / .35)
                      : p < .6
                          ? 1.45 - .6 * ((p - .35) / .25)
                          : p < .8
                              ? .85 + .23 * ((p - .6) / .2)
                              : 1.08 - .08 * ((p - .8) / .2);
                  return flameLayer(s, p < .35 ? p / .35 : 1);
                },
              ),
          ]),
    );
  }
}

/// A skull of a death-save failure; a new one is struck in.
class _Skull extends StatelessWidget {
  const _Skull({required this.on, required this.strike});
  final bool on, strike;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final box = AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 420)),
      curve: AppMotion.snappyCurve,
      width: 34,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? c.primary.withValues(alpha: .30) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: on ? c.primary : c.onSurface.withValues(alpha: .12),
            width: 2),
      ),
      child: InstrumentGlyph('skull',
          size: 22, color: on ? c.primary : c.onSurface.withValues(alpha: .25)),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: strike && !still ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 640),
      builder: (context, p, child) {
        // 2 / −18° / 0 → .88 / 4° → 1.14 → 1.06
        final scale = p < .45
            ? 2 - 1.12 * (p / .45)
            : p < .7
                ? .88 + .26 * ((p - .45) / .25)
                : 1.14 - .08 * ((p - .7) / .3);
        final turn = p < .45 ? -18 + 22 * (p / .45) : 4 * (1 - (p - .45) / .55);
        return Opacity(
          opacity: (p / .3).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: turn * math.pi / 180,
            child: Transform.scale(scale: on ? scale : 1, child: child),
          ),
        );
      },
      child: box,
    );
  }
}
