import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'sheet_drag_region.dart' show KeyboardPadding, SheetScrollDismiss;
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
    'swap': 'M7 7h11l-3-3M17 17H6l3 3',
    'key':
        'M10.5 12a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM10.5 12H20.5M17 12v3.5M20.5 12v2.5',
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
    // The journal (wave 4).
    'person':
        'M12 4a3.2 3.2 0 1 1 0 6.4A3.2 3.2 0 0 1 12 4zM5.5 20c0-3.6 2.9-6.3 6.5-6.3s6.5 2.7 6.5 6.3',
    'pin':
        'M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0 1 13 0c0 4.8-6.5 11-6.5 11zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
    'gem': 'M7 4h10l4 5-9 11L3 9zM3 9h18M12 20 8.5 9 12 4l3.5 5z',
    'link':
        'M10 14a4.5 4.5 0 0 0 6.4 0l3.2-3.2a4.5 4.5 0 0 0-6.4-6.4L12 5.6M14 10a4.5 4.5 0 0 0-6.4 0l-3.2 3.2a4.5 4.5 0 0 0 6.4 6.4l1.2-1.2',
    'flag': 'M5 21V4M5 4h11l-2.5 4L16 12H5',
    'tag': 'M3.5 12.5V4.5a1 1 0 0 1 1-1h8l8 8-9 9zM8.5 8.5h.01',
    'image':
        'M4 5.5h16v13H4zM4 15l4.5-4.5 4 4 2.5-2.5L20 17M15.5 9.5h.01',
    'edit': 'M15.5 4.5 19.5 8.5 9 19H5v-4zM13 7l4 4',
    'more': 'M12 5.5h.01M12 12h.01M12 18.5h.01',
    'quote':
        'M5 17c2.5-1 4-3 4-6V7H4.5v5H9M15 17c2.5-1 4-3 4-6V7h-4.5v5H19',
    'feather': 'M19 5c-7 0-12 5-13 13M6 18l3-3M19 5c0 6-4 10-10 10M19 5l-6 6',
    'bookmark': 'M7 4h10v16l-5-3.5L7 20z',
    'search': 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4',
    'grid': 'M5 5h5v5H5zM14 5h5v5h-5zM5 14h5v5H5zM14 14h5v5h-5z',
    'target':
        'M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM12 2v3M12 19v3M2 12h3M19 12h3',
    'minus': 'M5 12h14',
    'spark':
        'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6',
    'settings':
        'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z',
    'sun':
        'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8',
    'heart':
        'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
    'flame':
        'M12 3c.6 3.6 5 5.6 5 10.2a5 5 0 0 1-10 0c0-2.5 1.3-4.1 2.6-5.1.2 1.8 1 3 2.4 3.4C11.5 9.2 11 6 12 3z',
    'drop': 'M12 3.5s6 6.4 6 10.7a6 6 0 0 1-12 0C6 9.9 12 3.5 12 3.5z',
    'globe':
        'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z',
    'palette':
        'M12 3a9 9 0 0 0 0 18c1.3 0 2-.8 2-1.8 0-1.2-1-1.6-1-2.7 0-1 .8-1.5 1.8-1.5H17a4 4 0 0 0 4-4C21 6.6 17 3 12 3zM7.5 11.5h.01M10 7.5h.01M14.5 7.5h.01M17 11h.01',
    'upload':
        'M12 15V4M7.5 8.5 12 4l4.5 4.5M5 15v4a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-4',
    'download':
        'M12 4v11M7.5 10.5 12 15l4.5-4.5M5 15v4a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-4',
    'zip': 'M6 3h8l4 4v14H6zM14 3v4h4M10 5h1M10 8h1M10 11h1M9.5 14h2v3h-2z',
    'file': 'M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6',
    'trash': 'M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13M10 11v5.5M14 11v5.5',
    'code': 'M8.5 7 3.5 12l5 5M15.5 7l5 5-5 5M13.5 4.5l-3 15',
    'send': 'M20.5 3.5 3.5 10.5l7 2.5 2.5 7zM10.5 13l4-4',
    'camera':
        'M4 7.5h3.5L9 5h6l1.5 2.5H20V19H4zM12 16a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
    'ruler':
        'M4 16.5 16.5 4 20 7.5 7.5 20zM8 12.5l1.5 1.5M10.5 10l2 2M13 7.5l1.5 1.5',
    'scale': 'M6 8h12l2 12H4zM9.5 8a2.5 2.5 0 1 1 5 0M12 13l2-2',
    'hourglass':
        'M7 3.5h10M7 20.5h10M8 3.5c0 4.5 4 5.5 4 8.5s-4 4-4 8.5M16 3.5c0 4.5-4 5.5-4 8.5s4 4 4 8.5',
    'layers':
        'm12 4 8.5 4.5L12 13 3.5 8.5zM3.5 12.5 12 17l8.5-4.5M3.5 16.5 12 21l8.5-4.5',
    'auto':
        'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 3v18M12 7.5a4.5 4.5 0 0 1 0 9',
    'share':
        'M17.5 8a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM6.5 14.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM17.5 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM8.7 10.8l6.6-3.6M8.7 13.2l6.6 3.6',
    'swatch':
        'M4 4h6v13a3 3 0 0 1-6 0zM10 8.5l4.2-2.4 3 5.2L10 15.5M14 20H7M17.2 11.3 20 13.5V20h-6',
    'calm':
        'M3.5 9c2-2 4-2 6 0s4 2 6 0 4-2 5 0M3.5 15c2-2 4-2 6 0s4 2 6 0 4-2 5 0',
    'warn': 'M12 4 21 19.5H3zM12 10v4.5M12 17.2h.01',
    'hero':
        'M12 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM5 20.5c.6-3.8 3.4-6.5 7-6.5s6.4 2.7 7 6.5',
    'info': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v5.5M12 7.6h.01',
    'sliders': 'M4 7h10M18 7h2M4 17h4M12 17h8M14 4v6M8 14v6',
    'calendar': 'M4.5 6.5h15v13h-15zM4.5 10.5h15M8.5 4v4M15.5 4v4',
    'lock': 'M7 11V8a5 5 0 0 1 10 0v3M6 11h12v9H6z',
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
                            // A single long word never breaks inside
                            // itself; it narrows to fit instead.
                            ? widget.labels[i].trim().contains(' ')
                                ? Text(widget.labels[i],
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(widget.labels[i],
                                        maxLines: 1, softWrap: false))
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
    {required WidgetBuilder builder, bool bleed = false}) {
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
    // Rises with the keyboard so a field stays in view while typing; only
    // the lift depends on the keyboard, the content is never rebuilt by it.
    builder: (context) => KeyboardPadding(
      // The handle floats over the content: no band of sheet colour cuts
      // what scrolls up beneath it. The sheet keeps its full width however
      // little the content says.
      child: Stack(children: [
        const SizedBox(width: double.infinity),
        SheetTopFade(
          // Pulling the content down from its top closes the sheet too.
          child: SheetScrollDismiss(
            child: SingleChildScrollView(
                // A bleeding sheet draws to its edges and pads itself.
                padding: bleed
                    ? EdgeInsets.only(
                        bottom: 20 + MediaQuery.viewPaddingOf(context).bottom)
                    : EdgeInsets.fromLTRB(18, SheetGrab.inset, 18,
                        20 + MediaQuery.viewPaddingOf(context).bottom),
                child: builder(context)),
          ),
        ),
        const Positioned(left: 0, right: 0, top: 0, child: SheetGrab()),
      ]),
    ),
  );
}

/// The grab handle of a sheet, floating over its content: a pill with a
/// soft ring in the sheet's colour, so it reads over text scrolling below.
class SheetGrab extends StatelessWidget {
  const SheetGrab({super.key});

  /// Space the content leaves above itself for the handle at rest.
  static const double inset = 30;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    // The strip takes the touch (a transparent fill hit-tests) so the
    // sheet's own drag pulls it down, as before the handle floated.
    return Container(
      color: Colors.transparent,
      child: SizedBox(
        height: inset,
        child: Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: c.onSurface.withValues(alpha: .42),
              shadows: [
                BoxShadow(
                    color: c.surfaceContainer.withValues(alpha: .45),
                    spreadRadius: 3)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom action floating over a scrolling list as a glass island, like
/// the journal's dock: a [GlassSurface] pill holds the action, the list
/// scrolls on beneath it and pads by [room]. No strip, no bare button.
class FloatingFooter extends StatelessWidget {
  const FloatingFooter(
      {super.key,
      required this.child,
      required this.action,
      this.inset = const EdgeInsets.fromLTRB(14, 0, 14, 14)});
  final Widget child, action;
  final EdgeInsets inset;

  /// Bottom padding a list under the island leaves for its last rows.
  static double room(BuildContext context) =>
      56 + 16 + 40 + MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: child),
        Positioned(
          left: inset.left,
          right: inset.right,
          bottom: inset.bottom + MediaQuery.viewPaddingOf(context).bottom,
          child: FloatingIsland(child: action),
        ),
      ]);
}

/// The glass island of floating actions (journal, combat, level-up docks):
/// a frosted pill with its own soft shadow and the actions inside.
class FloatingIsland extends StatelessWidget {
  const FloatingIsland({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
        borderRadius: BorderRadius.circular(36),
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      );
}

/// A sheet's content under a floating [SheetGrab]: the handle has no band
/// of its own, so what scrolls beneath it is never cut by a strip.
class FloatingGrab extends StatelessWidget {
  const FloatingGrab({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(children: [
        Padding(
            padding: const EdgeInsets.only(top: SheetGrab.inset - 6),
            child: child),
        const Positioned(left: 0, right: 0, top: 0, child: SheetGrab()),
      ]);
}

/// Content scrolling up under a floating handle fades out over its last
/// pixels instead of being cut by a hard edge.
class SheetTopFade extends StatelessWidget {
  const SheetTopFade({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0x00000000), Color(0xFF000000)],
          stops: [0, r.height <= 0 ? 0 : (14 / r.height).clamp(0.0, 1.0)],
        ).createShader(r),
        child: child,
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
