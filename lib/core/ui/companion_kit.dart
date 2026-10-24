import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// Building blocks of the accepted wave 1 prototype
/// (`docs/prototypes/wave1/index.html`). Sizes, tones and motion follow its
/// CSS one to one; colours come from the theme roles the prototype mirrors
/// (`low` = surfaceContainerLow, `cont` = surfaceContainer, `high` =
/// surfaceContainerHigh, `muted` = onSurfaceVariant).

/// Line icons drawn from the prototype's own symbol set (24 × 24, stroke 2).
class LineIcon extends StatelessWidget {
  const LineIcon(this.name,
      {super.key, this.size = 22, this.color, this.semanticLabel});
  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  static const _paths = <String, String>{
    'home':
        'M4 11.5 12 4l8 7.5V19a1 1 0 0 1-1 1h-4.5v-5.5h-5V20H5a1 1 0 0 1-1-1z',
    'stats': 'M5 20v-7M10 20V5M15 20v-9M20 20v-4',
    'magic':
        'M4 20 14.5 9.5M17 3l.8 2.2L20 6l-2.2.8L17 9l-.8-2.2L14 6l2.2-.8zM9 4.5l.5 1 1 .5-1 .5-.5 1-.5-1-1-.5 1-.5zM19 13l.5 1 1 .5-1 .5-.5 1-.5-1-1-.5 1-.5z',
    'bag':
        'M9 7V5.5a3 3 0 0 1 6 0V7M6 9.5A2.5 2.5 0 0 1 8.5 7h7A2.5 2.5 0 0 1 18 9.5V18a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2zM9.5 13h5',
    'book':
        'M6 4h11a1 1 0 0 1 1 1v15H7.5A2.5 2.5 0 0 1 5 17.5V5a1 1 0 0 1 1-1zM18 16H7.5A2.5 2.5 0 0 0 5 18.5M9.5 4v6.5l2-1.4 2 1.4V4',
    'note':
        'M9 18V5l10-2v13M9 18a3 3 0 1 1-3-3 3 3 0 0 1 3 3zM19 16a3 3 0 1 1-3-3 3 3 0 0 1 3 3z',
    'star':
        'M12 3l2.4 5.8L20.5 9l-4.7 4 1.5 6.1L12 16l-5.3 3.1L8.2 13 3.5 9l6.1-.2z',
    'leaf': 'M5 19c0-8 5-13 15-14-1 10-6 15-14 15M5 19l8-8',
    'shield': 'M12 3.5 19 6v5.2c0 4.5-3 7.8-7 9.3-4-1.5-7-4.8-7-9.3V6z',
    'sword': 'M14.5 4H20v5.5l-9 9-5.5-5.5zM8 16l-3.5 3.5M5.5 13.5l5 5',
    'eye':
        'M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12zM12 9.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z',
    'back': 'M15 5l-7 7 7 7',
    'forward': 'M9 5l7 7-7 7',
    'plus': 'M12 5v14M5 12h14',
    'moon': 'M19 14.5A7.5 7.5 0 1 1 9.5 5a6 6 0 0 0 9.5 9.5z',
    'cup':
        'M5 9h11v5a5 5 0 0 1-5 5H10a5 5 0 0 1-5-5zM16 10h1.5a2.5 2.5 0 0 1 0 5H16M8 3v3M11 3v3',
    'swords':
        'M4 4l9 9M20 4l-9 9M6.5 14.5l3 3M17.5 14.5l-3 3M4 20l3-3M20 20l-3-3',
    'bolt': 'M13 3 5 13.5h6L10 21l8-10.5h-6z',
    'run': 'M14 5.5a1.5 1.5 0 1 0 0-.01M10 21l2-5-3-2 1-5 4 2 3 1M7 12l2-3',
    'medal': 'M8 3h8l-2 6h-4zM12 21a5 5 0 1 0 0-10 5 5 0 0 0 0 10z',
    'down': 'M6 9l6 6 6-6',
    'x': 'M6 6l12 12M18 6 6 18',
    'check': 'm5 12.5 4.5 4.5L19 7.5',
    'del': 'M9 6h11v12H9l-5-6zM12.5 9.5l5 5M17.5 9.5l-5 5',
    'up': 'M12 19V5M6 11l6-6 6 6',
    'dice': 'M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 3v18M4 7.5l16 9M20 7.5l-16 9',
    'user': 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 20a7.5 7.5 0 0 1 15 0',
    'settings':
        'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z',
  };

  static final _cache = <String, String>{};

  /// The prototype's glyph for a class: abstract, never an object emblem
  /// beyond these shared line icons.
  static String forClass(String classId) {
    final id = classId.toLowerCase();
    if (id.contains('paladin')) return 'shield';
    if (id.contains('bard')) return 'note';
    if (id.contains('wizard') || id.contains('sorcerer')) return 'star';
    if (id.contains('cleric') ||
        id.contains('druid') ||
        id.contains('ranger')) {
      return 'leaf';
    }
    if (id.contains('fighter') ||
        id.contains('barbarian') ||
        id.contains('monk') ||
        id.contains('rogue')) {
      return 'sword';
    }
    if (id.contains('warlock')) return 'eye';
    return 'user';
  }

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Colors.white;
    final svg = _cache.putIfAbsent(
        name,
        () =>
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
            'stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="${_paths[name] ?? _paths['plus']}"/></svg>');
    return SvgPicture.string(svg,
        width: size,
        height: size,
        semanticsLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn));
  }
}

/// Glass for layers floating over live content: surface tone at 70 %,
/// blur 18, a hairline of light on top and a soft shadow. High contrast
/// falls back to an opaque surface. While its screen is moving (a route
/// transition) the blur pauses and the fill stands in for it, so the
/// transition never pays for a moving blur.
class GlassSurface extends StatefulWidget {
  const GlassSurface(
      {super.key, required this.child, this.borderRadius = BorderRadius.zero});
  final Widget child;
  final BorderRadius borderRadius;
  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  Animation<double>? _route, _cover;

  bool get _moving =>
      (_route != null && !_route!.isCompleted) ||
      (_cover != null && _cover!.status != AnimationStatus.dismissed);

  void _changed(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route?.animation, _route)) {
      _route?.removeStatusListener(_changed);
      _route = route?.animation?..addStatusListener(_changed);
    }
    if (!identical(route?.secondaryAnimation, _cover)) {
      _cover?.removeStatusListener(_changed);
      _cover = route?.secondaryAnimation?..addStatusListener(_changed);
    }
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_changed);
    _cover?.removeStatusListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final opaque = MediaQuery.highContrastOf(context);
    final borderRadius = widget.borderRadius;
    final blur = !opaque && !_moving;
    // Fill plus a hairline of light along the top edge (an inset border
    // on one side cannot follow rounded corners, so it is painted).
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: opaque ? c.surface : c.surface.withValues(alpha: blur ? .7 : .9),
        borderRadius: borderRadius,
      ),
      child: CustomPaint(
        foregroundPainter:
            _TopLight(borderRadius, c.onSurface.withValues(alpha: .14)),
        child: widget.child,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .55),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 10)),
      ]),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blur
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: fill)
            : fill,
      ),
    );
  }
}

/// The glass's inner light: a hairline along the top edge that follows the
/// rounded corners and fades out down the sides.
class _TopLight extends CustomPainter {
  const _TopLight(this.radius, this.color);
  final BorderRadius radius;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(.35);
    final fade = math.min(1.0, (radius.topLeft.y + 2) / size.height);
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0)],
              stops: [0, fade]).createShader(rect));
  }

  @override
  bool shouldRepaint(_TopLight old) =>
      old.color != color || old.radius != radius;
}

/// Press feedback of the prototype: the element dips while held and springs
/// back on release; the release never blocks the action.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key,
      required this.child,
      this.onTap,
      this.onLongPress,
      this.scale = .96,
      this.haptic = false,
      this.semanticLabel,
      this.selected});
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;
  final bool? selected;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 0);

  void _down() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _c.animateTo(1,
        duration: const Duration(milliseconds: 160), curve: AppMotion.standard);
  }

  void _up() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0;
      return;
    }
    _c.animateWith(SpringSimulation(AppMotion.snappy, _c.value, 0, 0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _down() : null,
        onTapUp: enabled ? (_) => _up() : null,
        onTapCancel: enabled ? _up : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(
              scale: 1 - (1 - widget.scale) * _c.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}

enum ToneKind { plain, tonal, primary, heal }

/// The prototype's `.btn`: a 46 high capsule that dips to 0.975 and darkens
/// while pressed. Plain buttons never morph their shape.
class ToneButton extends StatelessWidget {
  const ToneButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = ToneKind.plain,
    this.height = 46,
    this.expand = false,
    this.fontSize = 14,
  });
  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final ToneKind kind;
  final double height, fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final heal = AppPaletteRoles.heal(context);
    final (bg, fg) = switch (kind) {
      ToneKind.plain => (c.surfaceContainerHigh, c.onSurface),
      ToneKind.tonal => (
          Color.alphaBlend(
              c.secondary.withValues(alpha: .16), c.surfaceContainerLow),
          c.onSurface
        ),
      ToneKind.primary => (c.primary, c.onPrimary),
      ToneKind.heal => (
          Color.alphaBlend(heal.withValues(alpha: .3), c.surfaceContainerLow),
          c.onSurface
        ),
    };
    final enabled = onPressed != null;
    final body = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: ShapeDecoration(shape: const StadiumBorder(), color: bg),
      child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              IconTheme(data: IconThemeData(color: fg, size: 20), child: icon!),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.labelLarge?.copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: fg)),
            ),
          ]),
    );
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Pressable(
        onTap: onPressed,
        scale: .975,
        semanticLabel: label,
        child: ExcludeSemantics(child: body),
      ),
    );
  }
}

/// Colours the prototype names that are not plain scheme roles.
abstract final class AppPaletteRoles {
  /// The prototype's `heal`: the green family member of the class accents.
  static Color heal(BuildContext context) => AppAccents.of(context).at(3);
}

/// The prototype's outlined capsule chip (`.chip`) for quick choices.
class OutlineChip extends StatelessWidget {
  const OutlineChip(
      {super.key,
      required this.label,
      this.onTap,
      this.leading,
      this.strong = false});
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final fg = strong ? c.onSurface : c.onSurfaceVariant;
    return Pressable(
      onTap: onTap,
      scale: .97,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: EdgeInsets.fromLTRB(leading == null ? 14 : 10, 6, 14, 6),
          decoration: ShapeDecoration(
              shape: StadiumBorder(
                  side: BorderSide(
                      color: strong
                          ? c.onSurface.withValues(alpha: .22)
                          : c.outline,
                      width: 1.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[
              IconTheme(
                  data: IconThemeData(color: fg, size: 18), child: leading!),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  style: t.textTheme.labelLarge?.copyWith(
                      fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A segmented choice whose indicator flows: the leading edge moves first on
/// the snappy spring, the trailing edge follows 90 ms later on the bouncy
/// one. Labels firm up when selected.
class FlowSegment<T> extends StatefulWidget {
  const FlowSegment({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.keyPrefix,
    this.itemKeys,
    this.dots,
    this.trailing,
  });
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? keyPrefix;

  /// Keys of the items themselves, when callers address them by identity.
  final List<Key>? itemKeys;

  /// A coloured dot before each label (a class in a multiclass switch).
  final List<Color>? dots;

  /// A quiet suffix after each label (the class level).
  final List<String>? trailing;
  @override
  State<FlowSegment<T>> createState() => _FlowSegmentState<T>();
}

class _FlowSegmentState<T> extends State<FlowSegment<T>>
    with TickerProviderStateMixin {
  late final _left = AnimationController.unbounded(vsync: this);
  late final _right = AnimationController.unbounded(vsync: this);
  int _index = 0;
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.values.indexOf(widget.selected).clamp(0, 99);
    _left.value = _index.toDouble();
    _right.value = _index + 1.0;
  }

  @override
  void didUpdateWidget(covariant FlowSegment<T> old) {
    super.didUpdateWidget(old);
    final next = widget.values.indexOf(widget.selected).clamp(0, 99);
    if (next != _index) _move(next);
  }

  void _move(int next) {
    final forward = next > _index;
    _index = next;
    if (MediaQuery.disableAnimationsOf(context) || !_placed) {
      _left.value = next.toDouble();
      _right.value = next + 1.0;
      return;
    }
    final lead = forward ? _right : _left, lag = forward ? _left : _right;
    final leadTo = forward ? next + 1.0 : next.toDouble();
    final lagTo = forward ? next.toDouble() : next + 1.0;
    lead.animateWith(
        SpringSimulation(AppMotion.snappy, lead.value, leadTo, lead.velocity));
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (mounted && _index == next) {
        lag.animateWith(
            SpringSimulation(AppMotion.bouncy, lag.value, lagTo, lag.velocity));
      }
    });
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _placed = true;
    final t = Theme.of(context), c = t.colorScheme;
    final n = widget.values.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
          shape: const StadiumBorder(), color: c.surfaceContainerLow),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / n;
        return Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_left, _right]),
              builder: (context, _) {
                final l = _left.value * w, r = _right.value * w;
                return Stack(children: [
                  Positioned(
                    left: l,
                    width: (r - l).clamp(0.0, box.maxWidth),
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                        decoration: ShapeDecoration(
                            shape: const StadiumBorder(),
                            color: c.secondaryContainer)),
                  ),
                ]);
              },
            ),
          ),
          Row(children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _index,
                  label: widget.labels[i],
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: widget.itemKeys?[i] ??
                        (widget.keyPrefix == null
                            ? null
                            : ValueKey('${widget.keyPrefix}-$i')),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i == _index) return;
                      HapticFeedback.selectionClick();
                      widget.onChanged(widget.values[i]);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 240),
                        curve: AppMotion.standard,
                        style: (t.textTheme.labelLarge ?? const TextStyle())
                            .copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: i == _index
                                    ? c.onSurface
                                    : c.onSurfaceVariant),
                        child: widget.dots == null && widget.trailing == null
                            ? Text(widget.labels[i],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    if (widget.dots != null) ...[
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: widget.dots![i])),
                                      const SizedBox(width: 7),
                                    ],
                                    Flexible(
                                        child: Text(widget.labels[i],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    if (widget.trailing != null) ...[
                                      const SizedBox(width: 6),
                                      Opacity(
                                          opacity: .8,
                                          child: Text(widget.trailing![i],
                                              style: const TextStyle(
                                                  fontFamily: AppType.display,
                                                  fontSize: 12))),
                                    ],
                                  ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Section heading of a sheet page: Rubik 20 with a quiet count at the end.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.count, this.trailing});
  final String title;
  final String? count;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Text(title,
              style: t.textTheme.titleLarge?.copyWith(
                  fontFamily: AppType.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3,
                  height: 1.2)),
        ),
        if (count != null)
          Text(count!,
              style: t.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.onSurfaceVariant)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// A bottom sheet in the prototype's style: `cont` background, 28 corners,
/// a 36 × 4 grab handle, content padded 18 with 14 between blocks.
Future<T?> showCompanionSheet<T>(BuildContext context,
    {required WidgetBuilder builder}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final c = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surfaceContainer,
    barrierColor: const Color(0x730A0806),
    showDragHandle: false,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 420),
            reverseDuration: Duration(milliseconds: 220)),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (context) => AnimatedPadding(
      // Rises with the keyboard so a field stays in view while typing.
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 28,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: ShapeDecoration(
                  shape: const StadiumBorder(), color: c.outline),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                18, 0, 18, 20 + MediaQuery.viewPaddingOf(context).bottom),
            child: builder(context),
          ),
        ),
      ]),
    ),
  );
}

/// Title and optional subtitle at the top of a companion sheet.
class SheetHeading extends StatelessWidget {
  const SheetHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: t.textTheme.headlineSmall?.copyWith(
              fontFamily: AppType.display,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
              height: 1.15)),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!,
            style: t.textTheme.bodyMedium
                ?.copyWith(fontSize: 13.5, color: c.onSurfaceVariant)),
      ],
    ]);
  }
}

/// A proficiency mark: hollow ring, filled dot, or a ring around a dot for
/// expertise. Filled marks use the secondary tone.
class ProficiencyDot extends StatelessWidget {
  const ProficiencyDot({super.key, required this.on, this.expert = false});
  final bool on, expert;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? c.secondary : null,
          border: on ? null : Border.all(color: c.outline, width: 1.6)),
    );
    if (!expert) return dot;
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.secondary, width: 1.4)),
      child: dot,
    );
  }
}

/// Space a sheet page leaves at its top for the floating island; pages that
/// scroll under the glass pad their list by it instead of being clipped.
class SheetPageInset extends InheritedWidget {
  const SheetPageInset({super.key, required this.top, required super.child});
  final double top;
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetPageInset>()?.top ?? 0;
  @override
  bool updateShouldNotify(SheetPageInset old) => old.top != top;
}
