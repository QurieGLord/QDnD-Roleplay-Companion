import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/ui/companion_surface.dart';
import '../session/expressive_hold_surface.dart';

enum FighterTactic { secondWind, actionSurge, indomitable }

/// These controls form one connected composition. They retain independent
/// hit regions and resource semantics; the join never merges their actions.
class FighterTacticsCluster extends MultiChildRenderObjectWidget {
  FighterTacticsCluster(
      {super.key,
      required Widget primary,
      required Widget secondary,
      required this.overlap})
      : super(children: [primary, secondary]);
  final double overlap;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _TacticsJoin(overlap);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _TacticsJoin).overlap = overlap;
  }
}

class _JoinParentData extends ContainerBoxParentData<RenderBox> {}

class _TacticsJoin extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox,
            ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            ContainerBoxParentData<RenderBox>> {
  _TacticsJoin(this._overlap);
  double _overlap;
  set overlap(double value) {
    if (_overlap == value) return;
    _overlap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _JoinParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final box = BoxConstraints.tightFor(width: width);
    final primary = firstChild!, secondary = childAfter(primary)!;
    primary.layout(box, parentUsesSize: true);
    secondary.layout(box, parentUsesSize: true);
    final join = _overlap.clamp(0.0, primary.size.height);
    (primary.parentData! as ContainerBoxParentData<RenderBox>).offset =
        Offset.zero;
    (secondary.parentData! as ContainerBoxParentData<RenderBox>).offset =
        Offset(0, primary.size.height - join);
    size = constraints.constrain(
        Size(width, primary.size.height + secondary.size.height - join));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final primary = firstChild!, secondary = childAfter(primary)!;
    context.paintChild(
        secondary,
        offset +
            (secondary.parentData! as ContainerBoxParentData<RenderBox>)
                .offset);
    context.paintChild(primary, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // The foreground panel owns the narrow overlap. Secondary controls start
    // below that seam, so neither the die nor a counter can spend another pool.
    final primary = firstChild!, secondary = childAfter(primary)!;
    for (final child in [primary, secondary]) {
      final offset =
          (child.parentData! as ContainerBoxParentData<RenderBox>).offset;
      if (result.addWithPaintOffset(
          offset: offset,
          position: position,
          hitTest: (result, position) =>
              child.hitTest(result, position: position))) {
        return true;
      }
    }
    return false;
  }
}

class FighterTacticsSurface extends StatelessWidget {
  const FighterTacticsSurface(
      {super.key,
      required this.tactic,
      required this.name,
      required this.current,
      required this.maximum,
      required this.recovery,
      required this.onEdit,
      required this.onActivate,
      this.bonus = 0,
      this.lastRoll,
      this.lastHealing,
      this.busy = false,
      this.compact = false,
      this.joined = false});
  final FighterTactic tactic;
  final String name, recovery;
  final int current, maximum, bonus;
  final int? lastRoll, lastHealing;
  final bool busy, compact, joined;
  final VoidCallback onEdit;
  final VoidCallback? onActivate;
  bool get _hero => tactic == FighterTactic.secondWind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l = AppLocalizations.of(context)!;
    final available = current > 0;
    final tone = switch (tactic) {
      FighterTactic.secondWind => c.secondaryContainer,
      FighterTactic.actionSurge => c.primaryContainer,
      FighterTactic.indomitable => c.tertiaryContainer,
    };
    final accent = switch (tactic) {
      FighterTactic.secondWind => c.secondary,
      FighterTactic.actionSurge => c.primary,
      FighterTactic.indomitable => c.tertiary,
    };
    final prompt = switch (tactic) {
      FighterTactic.secondWind => l.fighterSecondWindPrompt,
      FighterTactic.actionSurge => l.fighterSurgePrompt,
      FighterTactic.indomitable => l.fighterIndomitablePrompt,
    };
    final formula =
        '${Localizations.localeOf(context).languageCode == 'ru' ? '1к10' : '1d10'} + $bonus';
    final title = Text(name,
        style: t.textTheme.titleLarge?.copyWith(
            fontSize: _hero ? 24 : 20,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -.65,
            color: c.onSurface));
    final reserve = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: c.surface.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: c.shadow.withValues(alpha: .025),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ],
            border:
                Border.all(color: c.surface.withValues(alpha: .7), width: .7)),
        child: CompanionReserve(current: current, maximum: maximum));
    final shape = _TacticShape(tactic, joined: joined);
    final fill = available ? tone : c.surfaceContainer;
    final background = AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        decoration: companionDecoration(context,
            shape: shape, color: fill, accent: accent, raised: _hero),
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                18, !_hero && joined ? 36 : 18, 16, _hero && joined ? 36 : 18),
            child: _hero
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _VitalEmblem(
                                  accent: accent, background: c.surface),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 132),
                                              child: title)))),
                              const SizedBox(width: 8),
                              reserve,
                            ]),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        lastHealing != null && !available
                                            ? '+$lastHealing ${l.hpShort}'
                                            : '$formula ${l.hpShort}',
                                        style: t.textTheme.headlineMedium
                                            ?.copyWith(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -.9,
                                                height: 1.12,
                                                color: c.onSurface)),
                                    const SizedBox(height: 6),
                                    Text(recovery,
                                        style: t.textTheme.bodySmall?.copyWith(
                                            fontSize: 13,
                                            color: c.onSurfaceVariant)),
                                    if (lastRoll != null) ...[
                                      const SizedBox(height: 4),
                                      Text(l.fighterLastRoll(lastRoll!, bonus),
                                          style: t.textTheme.bodySmall),
                                    ],
                                  ])),
                              const SizedBox(width: 8),
                              _WindDie(
                                  accent: accent,
                                  available: available && !busy,
                                  busy: busy),
                            ]),
                      ])
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(children: [
                          Icon(
                              tactic == FighterTactic.actionSurge
                                  ? Icons.bolt_rounded
                                  : Icons.refresh_rounded,
                              size: 36,
                              color: available ? accent : c.onSurfaceVariant),
                          const Spacer(),
                          reserve,
                        ]),
                        const SizedBox(height: 12),
                        title,
                        const SizedBox(height: 6),
                        Text(recovery,
                            style: t.textTheme.bodySmall?.copyWith(
                                fontSize: 13, color: c.onSurfaceVariant)),
                      ])));
    return ExpressiveHoldSurface(
        enabled: !busy,
        excludeChildSemantics: true,
        onTap: available ? onActivate : null,
        onHold: onEdit,
        semanticLabel:
            '$name. ${l.sheetCounterDescription(current, maximum)}. $prompt. $recovery.',
        hint: available ? l.sheetTapHoldHint : l.sheetHoldToEdit,
        child: background);
  }
}

class _TacticShape extends OutlinedBorder {
  const _TacticShape(this.tactic, {required this.joined, super.side});
  final FighterTactic tactic;
  final bool joined;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  _TacticShape copyWith({BorderSide? side}) =>
      _TacticShape(tactic, joined: joined, side: side ?? this.side);
  @override
  ShapeBorder scale(double t) => copyWith(side: side.scale(t));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = rect;
    if (!joined) return Path()..addRRect(BorderRadius.circular(28).toRRect(r));
    if (tactic == FighterTactic.secondWind) {
      final b = r.bottom - 28, m = r.center.dx;
      return Path()
        ..moveTo(r.left + 30, r.top)
        ..lineTo(r.right - 34, r.top)
        ..quadraticBezierTo(r.right, r.top, r.right, r.top + 34)
        ..lineTo(r.right, b - 30)
        ..quadraticBezierTo(r.right, b, r.right - 30, b)
        ..lineTo(m + 44, b)
        ..quadraticBezierTo(m + 33, b, m + 26, b + 7)
        ..lineTo(m + 4, r.bottom - 3)
        ..quadraticBezierTo(m, r.bottom + 1, m - 4, r.bottom - 3)
        ..lineTo(m - 26, b + 7)
        ..quadraticBezierTo(m - 33, b, m - 44, b)
        ..lineTo(r.left + 30, b)
        ..quadraticBezierTo(r.left, b, r.left, b - 30)
        ..lineTo(r.left, r.top + 30)
        ..quadraticBezierTo(r.left, r.top, r.left + 30, r.top)
        ..close();
    }
    final base = Path()..addRRect(BorderRadius.circular(28).toRRect(r));
    // Leave space for the matching point of Second Wind, rather than drawing
    // an arbitrary notch unrelated to the controls above it.
    final cut = Path();
    if (tactic == FighterTactic.actionSurge) {
      cut
        ..moveTo(r.right - 50, r.top - 1)
        ..lineTo(r.right + 1, r.top - 1)
        ..lineTo(r.right + 1, r.top + 32)
        ..close();
    } else {
      cut
        ..moveTo(r.left - 1, r.top - 1)
        ..lineTo(r.left + 50, r.top - 1)
        ..lineTo(r.left - 1, r.top + 32)
        ..close();
    }
    return Path.combine(PathOperation.difference, base, cut);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.width == 0) return;
    canvas.drawPath(getOuterPath(rect.deflate(side.width / 2)), side.toPaint());
  }
}

class _VitalEmblem extends StatelessWidget {
  const _VitalEmblem({required this.accent, required this.background});
  final Color accent, background;
  @override
  Widget build(BuildContext context) => Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
          color: background.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(18)),
      child: Center(
          child: SizedBox(
              width: 38,
              height: 38,
              child: CustomPaint(painter: _HeartPainter(accent, background)))));
}

class _HeartPainter extends CustomPainter {
  _HeartPainter(this.color, this.line);
  final Color color, line;
  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.scale(s.width / 40, s.height / 40);
    final heart = Path()
      ..moveTo(20, 36)
      ..cubicTo(11, 30, 1, 20, 1, 12)
      ..cubicTo(1, 1, 14, -1, 20, 7)
      ..cubicTo(26, -1, 39, 1, 39, 12)
      ..cubicTo(39, 20, 29, 30, 20, 36)
      ..close();
    canvas.drawPath(heart, Paint()..color = color);
    canvas.clipPath(heart);
    canvas.drawPath(
        Path()
          ..moveTo(1, 19)
          ..lineTo(11, 19)
          ..lineTo(15, 11)
          ..lineTo(20, 29)
          ..lineTo(25, 16)
          ..lineTo(29, 21)
          ..lineTo(39, 21),
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeartPainter old) =>
      old.color != color || old.line != line;
}

class _WindDie extends StatelessWidget {
  const _WindDie(
      {required this.accent, required this.available, required this.busy});
  final Color accent;
  final bool available, busy;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final ink = available ? accent : c.onSurfaceVariant;
    return Container(
        width: 88,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.surface.withValues(alpha: .96),
                  c.surface.withValues(alpha: .4)
                ]),
            border:
                Border.all(color: c.surface.withValues(alpha: .85), width: 1)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: 48,
              child: busy
                  ? Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: ink)))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(
                          width: 37,
                          height: 46,
                          child: CustomPaint(painter: _WindDiePainter(ink))),
                      Icon(Icons.play_arrow_rounded, color: ink, size: 20),
                    ])),
          Text(
              '${Localizations.localeOf(context).languageCode == 'ru' ? 'к' : 'd'}10',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: c.onSurface)),
        ]));
  }
}

class _WindDiePainter extends CustomPainter {
  _WindDiePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final top = Offset(s.width / 2, 2),
        left = Offset(1, s.height / 2),
        right = Offset(s.width - 1, s.height / 2),
        bottom = Offset(s.width / 2, s.height - 2);
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .09));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..moveTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant _WindDiePainter old) => old.color != color;
}
