import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'companion_motion.dart';
import 'expressive_hold_surface.dart';
import 'expressive_kit.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// Shared geometry, not a shared layout: each class composes its own controls.
enum CompanionContour { soft, facet, cadence, seal, fold, focus }

class CompanionShape extends OutlinedBorder {
  const CompanionShape(
      {this.contour = CompanionContour.soft, this.morph = 0, super.side});
  final double morph;
  final CompanionContour contour;
  BorderRadius get _baseRadius => switch (contour) {
        CompanionContour.soft => BorderRadius.circular(28),
        CompanionContour.facet => const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(36),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(16)),
        CompanionContour.cadence => const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(40)),
        CompanionContour.seal => BorderRadius.circular(36),
        CompanionContour.fold => const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(32),
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(16)),
        CompanionContour.focus => const BorderRadius.only(
            topLeft: Radius.circular(36),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(36)),
      };
  BorderRadius get radius => BorderRadius.lerp(_baseRadius,
      _baseRadius + BorderRadius.circular(AppRadii.sm), morph.clamp(0.0, 1.0))!;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  CompanionShape copyWith({BorderSide? side}) =>
      CompanionShape(contour: contour, morph: morph, side: side ?? this.side);
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is CompanionShape && a.contour == contour) {
      return CompanionShape(
          contour: contour,
          morph: ui.lerpDouble(a.morph, morph, t)!,
          side: BorderSide.lerp(a.side, side, t));
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is CompanionShape && b.contour == contour) {
      return CompanionShape(
          contour: contour,
          morph: ui.lerpDouble(morph, b.morph, t)!,
          side: BorderSide.lerp(side, b.side, t));
    }
    return super.lerpTo(b, t);
  }

  @override
  ShapeBorder scale(double t) => copyWith(side: side.scale(t));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return Path();
    if (rect.shortestSide < 40) return Path()..addRRect(radius.toRRect(rect));
    final inset = (rect.height * .035).clamp(0.0, 10.0) * (1 - morph * .25);
    if (contour == CompanionContour.facet) {
      final span = (rect.width * .12).clamp(0.0, 24.0);
      final base =
          Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - inset);
      return Path()
        ..addRRect(radius.toRRect(base))
        ..moveTo(rect.center.dx - span, base.bottom - 1)
        ..quadraticBezierTo(
            rect.center.dx - 8, base.bottom, rect.center.dx, rect.bottom)
        ..quadraticBezierTo(rect.center.dx + 8, base.bottom,
            rect.center.dx + span, base.bottom - 1)
        ..close();
    }
    final base = Path()..addRRect(radius.toRRect(rect));
    if (contour == CompanionContour.seal) {
      final cuts = Path()
        ..moveTo(rect.left - 1, rect.center.dy - 12)
        ..lineTo(rect.left + 5, rect.center.dy)
        ..lineTo(rect.left - 1, rect.center.dy + 12)
        ..close()
        ..moveTo(rect.right + 1, rect.center.dy - 12)
        ..lineTo(rect.right - 5, rect.center.dy)
        ..lineTo(rect.right + 1, rect.center.dy + 12)
        ..close();
      return Path.combine(PathOperation.difference, base, cuts);
    }
    if (contour == CompanionContour.cadence) {
      final cut = Path()
        ..moveTo(rect.left + rect.width * .25, rect.top - 1)
        ..quadraticBezierTo(rect.center.dx, rect.top + 12,
            rect.left + rect.width * .75, rect.top - 1)
        ..close();
      return Path.combine(PathOperation.difference, base, cut);
    }
    return base;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(radius.toRRect(rect).deflate(side.width));
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.solid && side.width > 0) {
      canvas.drawPath(
          getOuterPath(rect.deflate(side.width / 2)), side.toPaint());
    }
  }
}

/// A single restrained lighting model across the sheet. Shadows stay outside
/// the clip; only the interactive content is clipped to its own shape.
ShapeDecoration companionDecoration(
  BuildContext context, {
  required ShapeBorder shape,
  Color? color,
  Color? accent,
  bool raised = false,
  bool quiet = false,
}) {
  final t = Theme.of(context), c = t.colorScheme;
  final light = t.brightness == Brightness.light;
  final contrast = MediaQuery.highContrastOf(context);
  final fill = color ?? c.surfaceContainerLow;
  return ShapeDecoration(
      shape: contrast
          ? shape
          : shape is OutlinedBorder
              ? shape.copyWith(
                  side: BorderSide(
                      color: c.surface.withValues(alpha: light ? .72 : .12),
                      width: .7))
              : shape,
      color: contrast ? fill : null,
      gradient: contrast
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                  Color.lerp(fill, c.surface, quiet ? .025 : .07)!,
                  fill,
                  Color.lerp(fill, accent ?? c.onSurface, quiet ? .012 : .035)!
                ]),
      shadows: contrast
          ? const []
          : [
              BoxShadow(
                  color: c.shadow.withValues(
                      alpha: light
                          ? (quiet
                              ? .025
                              : raised
                                  ? .075
                                  : .045)
                          : (quiet
                              ? .08
                              : raised
                                  ? .20
                                  : .14)),
                  blurRadius: quiet
                      ? 9
                      : raised
                          ? 18
                          : 13,
                  offset: Offset(
                      0,
                      quiet
                          ? 3
                          : raised
                              ? 6
                              : 4)),
              if (raised)
                BoxShadow(
                    color: c.shadow.withValues(alpha: light ? .025 : .08),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
            ]);
}

class CompanionSurface extends StatelessWidget {
  const CompanionSurface(
      {super.key,
      required this.child,
      this.color,
      this.contour = CompanionContour.soft,
      this.padding = const EdgeInsets.all(20),
      this.onTap,
      this.onLongPress,
      this.raised = false,
      this.quiet = false});
  final Widget child;
  final Color? color;
  final CompanionContour contour;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap, onLongPress;
  final bool raised, quiet;
  @override
  Widget build(BuildContext context) {
    Widget surface(BuildContext context) {
      final c = Theme.of(context).colorScheme;
      final shape = CompanionShape(
          contour: contour,
          morph: MediaQuery.disableAnimationsOf(context)
              ? 0
              : CompanionMotionScope.of(context));
      return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: AppMotion.standard,
          decoration: companionDecoration(context,
              shape: shape,
              color: color ?? c.surfaceContainerLow,
              raised: raised,
              quiet: quiet),
          child: Material(
              color: Colors.transparent,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: Padding(padding: padding, child: child)));
    }

    final content = Builder(builder: surface);
    return ExpressiveHoldSurface(
        enabled: onTap != null || onLongPress != null,
        onTap: onTap,
        onHold: onLongPress,
        child: content);
  }
}

/// Glass is reserved for navigation, with an opaque high-contrast fallback.
class CompanionNavigationGlass extends StatelessWidget {
  const CompanionNavigationGlass({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final opaque = MediaQuery.highContrastOf(context);
    final panel = DecoratedBox(
        decoration: BoxDecoration(
            color: opaque
                ? c.secondaryContainer
                : c.secondaryContainer.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(AppRadii.xlPlus),
            border:
                Border.all(color: c.surface.withValues(alpha: .6), width: .7)),
        child: child);
    return RepaintBoundary(
        child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xlPlus),
            child: opaque
                ? panel
                : BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: panel)));
  }
}

class CompanionReserve extends StatelessWidget {
  const CompanionReserve(
      {super.key,
      required this.current,
      required this.maximum,
      this.large = false});
  final int current, maximum;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final style = (large ? t.textTheme.headlineMedium : t.textTheme.titleMedium)
        ?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            color: current > maximum ? c.tertiary : c.onSurface);
    return Semantics(
      label: '$current / $maximum',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        RollingNumber(current, style: style),
        Text(' / $maximum', style: style),
      ]),
    );
  }
}

/// Marks are supplementary. A manual excess or a large reserve stays numeric.
/// A spent mark shrinks into a hollow ring; marks added later grow from a
/// point instead of popping in.
class CompanionReserveMarks extends StatefulWidget {
  const CompanionReserveMarks(
      {super.key,
      required this.current,
      required this.maximum,
      this.contour = CompanionContour.cadence});
  final int current, maximum;
  final CompanionContour contour;
  @override
  State<CompanionReserveMarks> createState() => _CompanionReserveMarksState();
}

class _CompanionReserveMarksState extends State<CompanionReserveMarks> {
  // Marks at or above this index arrived after the first build and grow in.
  int _grownFrom = 1 << 30;
  @override
  void didUpdateWidget(covariant CompanionReserveMarks old) {
    super.didUpdateWidget(old);
    if (widget.maximum > old.maximum) {
      _grownFrom = math.min(_grownFrom, old.maximum);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maximum <= 0 || widget.maximum > 10) {
      return const SizedBox.shrink();
    }
    final c = Theme.of(context).colorScheme;
    final d = AppMotion.of(context, AppMotion.snappySettle);
    return ExcludeSemantics(
        child: Wrap(spacing: 7, runSpacing: 7, children: [
      for (var i = 0; i < widget.maximum; i++)
        _Mark(
            key: ValueKey(i),
            spent: i >= widget.current,
            grow: i >= _grownFrom,
            duration: d,
            color: c.secondary,
            contour: widget.contour),
    ]));
  }
}

class _Mark extends StatelessWidget {
  const _Mark(
      {super.key,
      required this.spent,
      required this.grow,
      required this.duration,
      required this.color,
      required this.contour});
  final bool spent, grow;
  final Duration duration;
  final Color color;
  final CompanionContour contour;
  @override
  Widget build(BuildContext context) {
    final mark = AnimatedScale(
      scale: spent ? .62 : 1,
      duration: duration,
      curve: AppMotion.snappyCurve,
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.standard,
        width: 13,
        height: 13,
        decoration: ShapeDecoration(
            color: spent ? color.withValues(alpha: 0) : color,
            shape: CompanionShape(
                contour: contour,
                side: BorderSide(
                    color: color.withValues(alpha: spent ? .8 : .45),
                    width: spent ? 2.4 : 1))),
      ),
    );
    if (!grow || duration == Duration.zero) return mark;
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: AppMotion.snappyCurve,
        builder: (context, v, child) =>
            Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
        child: mark);
  }
}

class CompanionDieFace extends StatelessWidget {
  const CompanionDieFace(
      {super.key, required this.sides, this.accent, this.size = 88});
  final int sides;
  final Color? accent;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return Container(
        width: size,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: companionDecoration(context,
            shape: const CircleBorder(),
            color: c.surface,
            accent: accent,
            raised: true),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
              child: CustomPaint(
                  size: Size(size * .38, size * .43),
                  painter: _DieFacetPainter(accent ?? c.secondary))),
          const SizedBox(height: 5),
          Text(
              '${Localizations.localeOf(context).languageCode == 'ru' ? 'к' : 'd'}$sides',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ]));
  }
}

class CompanionDiceControl extends StatelessWidget {
  const CompanionDiceControl(
      {super.key, required this.sides, this.onPressed, this.label});
  final int sides;
  final VoidCallback? onPressed;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final die =
        '${Localizations.localeOf(context).languageCode == 'ru' ? 'к' : 'd'}$sides';
    return Semantics(
        button: true,
        enabled: onPressed != null,
        label: label ?? die,
        child: DecoratedBox(
          decoration: companionDecoration(context,
              shape: const StadiumBorder(), color: c.surface, raised: true),
          child: Material(
              color: Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: onPressed,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 17, vertical: 13),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ExcludeSemantics(
                            child: CustomPaint(
                                size: const Size(32, 38),
                                painter: _DieFacetPainter(c.secondary))),
                        const SizedBox(height: 4),
                        Text(die,
                            style: t.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: onPressed != null
                                    ? c.onSurface
                                    : c.onSurfaceVariant)),
                      ])))),
        ));
  }
}

class _DieFacetPainter extends CustomPainter {
  const _DieFacetPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 1)
      ..lineTo(w - 1, h * .48)
      ..lineTo(w / 2, h - 1)
      ..lineTo(1, h * .48)
      ..close()
      ..moveTo(w / 2, 1)
      ..lineTo(w / 2, h - 1)
      ..moveTo(1, h * .48)
      ..lineTo(w - 1, h * .48);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DieFacetPainter oldDelegate) =>
      color != oldDelegate.color;
}
