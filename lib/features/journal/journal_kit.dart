import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_links.dart';
import '../../core/models/journal_note.dart';
import '../../core/models/quest.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import 'journal_strings.dart';

/// The journal's look from the accepted wave 4 prototype
/// (`docs/prototypes/wave4/index.html`): each kind of name, note category
/// and quest state has an accent of the palette family and a line glyph.
abstract final class JournalLook {
  static int kindAccent(JournalEntityKind kind) => switch (kind) {
        JournalEntityKind.person => 0,
        JournalEntityKind.place => 4,
        JournalEntityKind.item => 2,
        JournalEntityKind.event => 1,
        JournalEntityKind.story => 5,
      };
  static String kindIcon(JournalEntityKind kind) => switch (kind) {
        JournalEntityKind.person => 'person',
        JournalEntityKind.place => 'pin',
        JournalEntityKind.item => 'gem',
        JournalEntityKind.event => 'bolt',
        JournalEntityKind.story => 'book',
      };
  static String kindPlural(JournalStrings s, JournalEntityKind kind) =>
      switch (kind) {
        JournalEntityKind.person => s.t('Люди', 'People'),
        JournalEntityKind.place => s.t('Места', 'Places'),
        JournalEntityKind.item => s.t('Предметы', 'Items'),
        JournalEntityKind.event => s.t('События', 'Events'),
        JournalEntityKind.story => s.t('Сюжеты', 'Stories'),
      };
  static int categoryAccent(NoteCategory category) => switch (category) {
        NoteCategory.general => 3,
        NoteCategory.location => 4,
        NoteCategory.npc => 0,
        NoteCategory.artifact => 2,
        NoteCategory.story => 5,
        NoteCategory.session => 1,
      };
  static String categoryIcon(NoteCategory category) => switch (category) {
        NoteCategory.general => 'note',
        NoteCategory.location => 'pin',
        NoteCategory.npc => 'person',
        NoteCategory.artifact => 'gem',
        NoteCategory.story => 'book',
        NoteCategory.session => 'feather',
      };
  static String categoryLabel(JournalStrings s, NoteCategory category) =>
      switch (category) {
        NoteCategory.general => s.t('Общее', 'General'),
        NoteCategory.location => s.t('Место', 'Place'),
        NoteCategory.npc => s.t('Персонаж', 'Person'),
        NoteCategory.artifact => s.t('Артефакт', 'Artifact'),
        NoteCategory.story => s.t('Сюжет', 'Story'),
        NoteCategory.session => s.t('Сессия', 'Session'),
      };
  static int statusAccent(QuestStatus status) => switch (status) {
        QuestStatus.active => 1,
        QuestStatus.completed => 3,
        QuestStatus.failed => 0,
      };
  static String statusIcon(QuestStatus status) => switch (status) {
        QuestStatus.active => 'flag',
        QuestStatus.completed => 'check',
        QuestStatus.failed => 'x',
      };
  static String statusLabel(JournalStrings s, QuestStatus status) =>
      switch (status) {
        QuestStatus.active => s.t('Активно', 'Active'),
        QuestStatus.completed => s.t('Выполнено', 'Completed'),
        QuestStatus.failed => s.t('Провалено', 'Failed'),
      };

  static Color accent(BuildContext context, int index) =>
      AppAccents.of(context).at(index);

  /// `color-mix(in srgb, accent N%, base)` of the prototype.
  static Color mix(Color accent, double amount, Color base) =>
      Color.alphaBlend(accent.withValues(alpha: amount), base);

  /// Text drawn on a filled accent: the surface, darkened a little.
  static Color onAccent(BuildContext context) => Color.alphaBlend(
      Colors.black.withValues(alpha: .12),
      Theme.of(context).colorScheme.surface);

  static const quotesRu = [
    'Опасно идти одному!',
    'Карта — не территория, но лучше, чем ничего.',
    'Каждая история начинается с таверны.',
    'Запиши имя, пока его не забыли.',
    'Проверь ловушки. Всегда проверяй ловушки.',
    'Дорога вдаль и вдаль ведёт...',
  ];
  static const quotesEn = [
    'It’s dangerous to go alone!',
    'The map is not the territory, but it beats nothing.',
    'Every story starts in a tavern.',
    'Write the name down before it is forgotten.',
    'Check for traps. Always check for traps.',
    'The road goes ever on and on...',
  ];
}

/// Small caps over a block: 11.5 Inter, wide tracking, in the accent.
TextStyle journalCap(BuildContext context, Color accent, {double size = 11.5}) {
  final c = Theme.of(context).colorScheme;
  return TextStyle(
      fontFamily: AppType.body,
      fontSize: size,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: size * .09,
      color: Color.lerp(c.onSurface, accent, .72));
}

String journalUpper(String text) => text.toUpperCase();

enum JournalSealSize { sm, md, lg }

/// A category stamped into the page. The large seal is filled and turned a
/// little; when its state changes it is stamped again.
class JournalSeal extends StatefulWidget {
  const JournalSeal(
      {super.key,
      required this.icon,
      required this.accent,
      this.size = JournalSealSize.md,
      this.dimension,
      this.round = false});
  final String icon;
  final Color accent;
  final JournalSealSize size;

  /// Overrides the side of a large seal (the Atlas card uses 56).
  final double? dimension;
  final bool round;
  @override
  State<JournalSeal> createState() => _JournalSealState();
}

class _JournalSealState extends State<JournalSeal>
    with SingleTickerProviderStateMixin {
  late final _stamp = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560), value: 1);

  @override
  void didUpdateWidget(JournalSeal old) {
    super.didUpdateWidget(old);
    if ((old.icon != widget.icon || old.accent != widget.accent) &&
        !MediaQuery.disableAnimationsOf(context)) {
      _stamp.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme, a = widget.accent;
    final large = widget.size == JournalSealSize.lg;
    final side = widget.dimension ??
        switch (widget.size) {
          JournalSealSize.sm => 28.0,
          JournalSealSize.md => 40.0,
          JournalSealSize.lg => 64.0,
        };
    final radius = widget.round
        ? side / 2
        : switch (widget.size) {
            JournalSealSize.sm => 10.0,
            JournalSealSize.md => 14.0,
            JournalSealSize.lg => side * .34,
          };
    final seal = Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: large ? a : JournalLook.mix(a, .2, c.surfaceContainer),
        borderRadius: BorderRadius.circular(radius),
        border: widget.size == JournalSealSize.md
            ? Border.all(color: a.withValues(alpha: .4), width: 1.5)
            : null,
        boxShadow: large
            ? [
                BoxShadow(
                    color: a.withValues(alpha: .55),
                    blurRadius: 26,
                    spreadRadius: -12,
                    offset: const Offset(0, 12))
              ]
            : null,
      ),
      child: LineIcon(widget.icon,
          size: side * (large ? .5 : .53),
          color: large ? JournalLook.onAccent(context) : a),
    );
    if (!large) return seal;
    // stampbig: from 1.7 and −20° through 0.88 and −5° to rest at −7°.
    return AnimatedBuilder(
      animation: _stamp,
      builder: (context, child) {
        final t = _stamp.value;
        final (scale, turn, opacity) = t < .55
            ? (
                ui.lerpDouble(1.7, .88, t / .55)!,
                ui.lerpDouble(-20, -5, t / .55)!,
                t / .55
              )
            : (
                ui.lerpDouble(.88, 1, (t - .55) / .45)!,
                ui.lerpDouble(-5, -7, (t - .55) / .45)!,
                1.0
              );
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
              angle: turn * math.pi / 180,
              child: Transform.scale(scale: scale, child: child)),
        );
      },
      child: seal,
    );
  }
}

/// A name of the story: a coloured glyph and the name. On, its shape firms
/// up from a capsule into a rounded square.
class JournalToken extends StatelessWidget {
  const JournalToken(
      {super.key,
      required this.entity,
      this.on = false,
      this.mini = false,
      this.off = false,
      this.onTap,
      this.onRemove});
  final JournalEntity entity;
  final bool on, mini, off;
  final VoidCallback? onTap, onRemove;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.kindAccent(entity.kind));
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final h = mini ? 32.0 : 38.0, g = mini ? 24.0 : 28.0;
    final s = JournalStrings(context);
    return Pressable(
      onTap: onTap,
      scale: .95,
      semanticLabel: '${s.kind(entity.kind)}: ${entity.name}',
      selected: on,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.standard,
          height: h,
          padding: EdgeInsets.fromLTRB(
              mini ? 4 : 5, 0, onRemove != null ? 4 : (mini ? 11 : 13), 0),
          decoration: BoxDecoration(
            color: off
                ? Colors.transparent
                : on
                    ? JournalLook.mix(a, .26, c.surfaceContainer)
                    : JournalLook.mix(a, .10, c.surfaceContainerLow),
            borderRadius: BorderRadius.circular(on ? 12 : h / 2),
            border: Border.all(
                color: off
                    ? c.outline
                    : on
                        ? a.withValues(alpha: .7)
                        : Colors.transparent,
                width: 1.5),
          ),
          child: Opacity(
            opacity: off ? .5 : 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: dur,
                curve: AppMotion.standard,
                width: g,
                height: g,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? a : a.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(on ? 9 : g / 2),
                ),
                child: LineIcon(JournalLook.kindIcon(entity.kind),
                    size: 15, color: on ? c.surface : a),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(entity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: mini ? 12.5 : 13.5,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface,
                        decoration: off ? TextDecoration.lineThrough : null)),
              ),
              if (onRemove != null)
                Semantics(
                  button: true,
                  label: s.t('Не связывать', 'Unlink'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Center(
                            child: LineIcon('x',
                                size: 15, color: c.onSurfaceVariant))),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Progress ring of a quest: the arc springs, the count rolls.
class JournalRing extends StatelessWidget {
  const JournalRing(
      {super.key,
      required this.done,
      required this.total,
      this.size = 64,
      this.accent,
      this.fontSize});
  final int done, total;
  final double size;
  final Color? accent;
  final double? fontSize;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final a = accent ?? JournalLook.accent(context, 1);
    final p = total == 0 ? 0.0 : done / total;
    final big = fontSize ?? (size >= 70 ? 23.0 : size >= 60 ? 19.0 : 14.0);
    final s = JournalStrings(context);
    return Semantics(
      label: s.t('Шагов отмечено: $done из $total', 'Steps done: $done of $total'),
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: p),
            duration: AppMotion.of(context, const Duration(milliseconds: 700)),
            curve: AppMotion.snappyCurve,
            builder: (context, value, child) => CustomPaint(
                painter: _RingPainter(value, a,
                    c.onSurface.withValues(alpha: .1), size < 50 ? 4.5 : 5),
                child: child),
            child: Padding(
              padding: EdgeInsets.all(size * .16),
              child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RollingNumber(done,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: big,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: c.onSurface)),
                    Text('/$total',
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: big * .63,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            color: c.onSurfaceVariant)),
                  ]),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.color, this.track, this.width);
  final double p, width;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 5;
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, stroke..color = track);
    if (p <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2,
        2 * math.pi * p.clamp(0.0, 1.0), false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.p != p || old.color != color || old.track != track;
}

/// The kinds of names in a record, as overlapping dots.
class JournalDots extends StatelessWidget {
  const JournalDots(this.colors, {super.key, this.ring});
  final List<Color> colors;
  final Color? ring;
  @override
  Widget build(BuildContext context) {
    final edge = ring ?? Theme.of(context).colorScheme.surfaceContainerLow;
    final shown = colors.take(5).toList();
    return SizedBox(
      width: shown.isEmpty ? 0 : 10 + (shown.length - 1) * 7.0 + 4,
      height: 14,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * 7.0,
            top: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: edge),
              alignment: Alignment.center,
              child: Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: shown[i])),
            ),
          ),
      ]),
    );
  }
}

/// A numbered bead on a thread: a session in a trail.
class JournalBead extends StatelessWidget {
  const JournalBead(this.label, {super.key, this.ring, this.size = 32});
  final String label;
  final Color? ring;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size + 8,
      height: size + 8,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: ring ?? c.surface),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surfaceContainer,
            border: Border.all(
                color: c.onSurface.withValues(alpha: .16), width: 1.5)),
        child: Text(label,
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w600,
                fontFeatures: AppType.tabular,
                color: c.onSurface)),
      ),
    );
  }
}

/// A dashed outline: an empty shelf, a place to add something.
class JournalDashed extends StatelessWidget {
  const JournalDashed(
      {super.key,
      required this.child,
      this.radius = 22,
      this.color,
      this.width = 1.5,
      this.circle = false});
  final Widget child;
  final double radius, width;
  final Color? color;
  final bool circle;
  @override
  Widget build(BuildContext context) => CustomPaint(
      foregroundPainter: _DashPainter(
          color ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: .16),
          radius,
          width,
          circle),
      child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius, this.width, this.circle);
  final Color color;
  final double radius, width;
  final bool circle;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          rect, Radius.circular(circle ? rect.shortestSide / 2 : radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.radius != radius || old.width != width;
}

/// Text with the story's names drawn in their kind's colour. With
/// [onEntity] each name is a link to its card.
class MarkedText extends StatefulWidget {
  const MarkedText(this.text,
      {super.key,
      required this.mentions,
      required this.style,
      this.onEntity,
      this.maxLines,
      this.only});
  final String text;
  final List<JournalMention> mentions;
  final TextStyle style;
  final ValueChanged<JournalEntity>? onEntity;
  final int? maxLines;

  /// Names this record is linked with; others stay plain.
  final Set<String>? only;
  @override
  State<MarkedText> createState() => _MarkedTextState();
}

class _MarkedTextState extends State<MarkedText> {
  final _taps = <TapGestureRecognizer>[];

  void _clear() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final c = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in widget.mentions) {
      if (m.start < at ||
          (widget.only != null && !widget.only!.contains(m.entity.id))) {
        continue;
      }
      if (m.start > at) spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      final a =
          JournalLook.accent(context, JournalLook.kindAccent(m.entity.kind));
      TapGestureRecognizer? tap;
      if (widget.onEntity != null) {
        tap = TapGestureRecognizer()..onTap = () => widget.onEntity!(m.entity);
        _taps.add(tap);
      }
      spans.add(TextSpan(
          text: widget.text.substring(m.start, m.end),
          recognizer: tap,
          style: TextStyle(
            color: Color.lerp(c.onSurface, a, .82),
            backgroundColor: a.withValues(alpha: .14),
            decoration: tap == null ? null : TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: a.withValues(alpha: .6),
            decorationThickness: 1.5,
          )));
      at = m.end;
    }
    if (at < widget.text.length) spans.add(TextSpan(text: widget.text.substring(at)));
    return Text.rich(TextSpan(style: widget.style, children: spans),
        maxLines: widget.maxLines,
        overflow: widget.maxLines == null ? null : TextOverflow.ellipsis);
  }
}

/// A text controller that colours the story's names while the player types.
class MarkedTextController extends TextEditingController {
  MarkedTextController({super.text});
  JournalMatcher? matcher;
  Set<String> excluded = const {};
  Color Function(JournalEntity)? accentOf;
  Color? ink;

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final m = matcher, accent = accentOf;
    if (m == null || accent == null || text.isEmpty) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final spans = <InlineSpan>[];
    var at = 0;
    for (final hit in m.mentions(text)) {
      if (hit.start < at || excluded.contains(hit.entity.id)) continue;
      if (hit.start > at) spans.add(TextSpan(text: text.substring(at, hit.start)));
      final a = accent(hit.entity);
      spans.add(TextSpan(
          text: text.substring(hit.start, hit.end),
          style: TextStyle(
              color: Color.lerp(ink ?? style?.color, a, .82),
              backgroundColor: a.withValues(alpha: .14))));
      at = hit.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

/// A round icon button of the prototype (`.round`): 40, a faint fill.
class JournalRound extends StatelessWidget {
  const JournalRound(
      {super.key,
      required this.icon,
      required this.label,
      this.onTap,
      this.size = 40,
      this.color,
      this.fill,
      this.iconSize});
  final String icon, label;
  final VoidCallback? onTap;
  final double size;
  final Color? color, fill;
  final double? iconSize;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        scale: .92,
        haptic: true,
        semanticLabel: label,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill ?? c.onSurface.withValues(alpha: .08)),
          child: LineIcon(icon,
              size: iconSize ?? (size < 40 ? 18 : 22),
              color: color ?? c.onSurface),
        ),
      ),
    );
  }
}

/// The page bar: transparent over the page's own big title, glass with the
/// title once that title has scrolled away.
class JournalTopBar extends StatelessWidget {
  const JournalTopBar(
      {super.key,
      required this.titled,
      this.title = '',
      this.leading,
      this.actions = const []});
  final bool titled;
  final String title;
  final Widget? leading;
  final List<Widget> actions;

  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final dur = AppMotion.of(context, AppMotion.medium);
    final bar = Padding(
      padding: EdgeInsets.fromLTRB(14, top + 10, 14, 10),
      child: Row(children: [
        if (leading != null) leading!,
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedOpacity(
            opacity: titled ? 1 : 0,
            duration: dur,
            child: AnimatedSlide(
              offset: titled ? Offset.zero : const Offset(0, .25),
              duration: AppMotion.of(context, AppMotion.snappySettle),
              curve: AppMotion.snappyCurve,
              child: Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.17,
                      color: c.onSurface)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ...actions,
        if (leading != null && actions.isEmpty) const SizedBox(width: 40),
      ]),
    );
    return AnimatedSwitcher(
      duration: dur,
      child: titled
          ? GlassSurface(key: const ValueKey('glass'), child: bar)
          : KeyedSubtree(key: const ValueKey('clear'), child: bar),
    );
  }
}

/// The Atlas can turn the journal towards one name and bring the player
/// back to it.
abstract final class JournalFocus {
  static final request = ValueNotifier<String?>(null);
  static Route<dynamic>? home;
}

/// Settles a controller on a spring towards [target].
void springTo(AnimationController controller, double target,
    {SpringDescription spring = AppMotion.snappy, double velocity = 0}) {
  controller.animateWith(
      SpringSimulation(spring, controller.value, target, velocity));
}

/// A record's photo, from the device or the web, with a quiet fallback.
Widget journalImage(BuildContext context, String path,
    {double height = 160, double? width}) {
  final s = JournalStrings(context), c = Theme.of(context).colorScheme;
  Widget error(BuildContext context, Object error, StackTrace? stack) =>
      Container(
          height: height,
          width: width,
          color: c.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LineIcon('image', color: c.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(s.t('Фото недоступно', 'Image unavailable'),
                style: TextStyle(color: c.onSurfaceVariant)),
          ]));
  return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: path.startsWith('http')
          ? Image.network(path,
              height: height, width: width, fit: BoxFit.cover, errorBuilder: error)
          : Image.file(File(path),
              height: height, width: width, fit: BoxFit.cover, errorBuilder: error));
}

/// A round check that firms into a filled square when ticked.
class JournalCheck extends StatelessWidget {
  const JournalCheck(
      {super.key,
      required this.on,
      required this.onTap,
      required this.label,
      this.ring});
  final bool on;
  final VoidCallback? onTap;
  final String label;
  final Color? ring;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final done = JournalLook.accent(context, 3);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Pressable(
      onTap: onTap,
      scale: .88,
      semanticLabel: label,
      selected: on,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: dur,
            curve: AppMotion.standard,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: on ? done : Colors.transparent,
              borderRadius: BorderRadius.circular(on ? 9 : 14),
              border: on
                  ? null
                  : Border.all(color: ring ?? JournalLook.accent(context, 1), width: 2),
            ),
            child: AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: AppMotion.of(context, AppMotion.short),
              child: Center(child: LineIcon('check', size: 17, color: c.surface)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled field of a sheet (`.fld`): a quiet label over a filled box
/// that lights its edge while focused.
class JournalField extends StatelessWidget {
  const JournalField(
      {super.key,
      required this.controller,
      required this.label,
      this.fieldKey,
      this.onChanged,
      this.maxLines = 1,
      this.hint});
  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final edge = OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent, width: 1.5));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: .48,
              color: c.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(
        key: fieldKey,
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.onSurface),
        decoration: InputDecoration(
          filled: true,
          fillColor: c.surfaceContainerLow,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          enabledBorder: edge,
          border: edge,
          focusedBorder: edge.copyWith(
              borderSide: BorderSide(color: c.secondary, width: 1.5)),
        ),
      ),
    ]);
  }
}

/// A grid of three of kinds or categories, each a seal and a word; the
/// chosen one firms up and is outlined in its colour.
class JournalKindGrid<T> extends StatelessWidget {
  const JournalKindGrid(
      {super.key,
      required this.values,
      required this.icon,
      required this.accent,
      required this.label,
      required this.onPick,
      this.selected,
      this.keyPrefix = 'journal-kind'});
  final List<T> values;
  final T? selected;
  final String Function(T) icon, label;
  final int Function(T) accent;
  final ValueChanged<T> onPick;
  final String keyPrefix;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 16) / 3;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in values)
          Builder(builder: (context) {
            final a = JournalLook.accent(context, accent(v)), on = v == selected;
            return Pressable(
              key: ValueKey('$keyPrefix-${v is Enum ? v.name : v}'),
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(v);
              },
              scale: .95,
              selected: on,
              semanticLabel: label(v),
              child: AnimatedContainer(
                duration: dur,
                curve: AppMotion.standard,
                width: w,
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
                decoration: BoxDecoration(
                  color: on ? JournalLook.mix(a, .2, c.surfaceContainerLow) : c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(on ? 16 : 22),
                  border: Border.all(
                      color: on ? a.withValues(alpha: .7) : Colors.transparent, width: 1.5),
                ),
                child: Column(children: [
                  JournalSeal(icon: icon(v), accent: a),
                  const SizedBox(height: 8),
                  Text(label(v),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, height: 1.1, fontWeight: FontWeight.w600, color: c.onSurface)),
                ]),
              ),
            );
          }),
      ]);
    });
  }
}

/// A chip that pops in when it first appears (a name just recognised).
class JournalPop extends StatefulWidget {
  const JournalPop({super.key, required this.child});
  final Widget child;
  @override
  State<JournalPop> createState() => _JournalPopState();
}

class _JournalPopState extends State<JournalPop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 0);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
      } else {
        springTo(_c, 1, spring: AppMotion.bouncy);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
            opacity: _c.value.clamp(0.0, 1.0),
            child: Transform.scale(scale: .6 + .4 * _c.value, child: child)),
        child: widget.child,
      );
}

/// The search field of the journal and the Atlas: a capsule that firms
/// into a rounded square with a lit edge while typing.
class JournalSearchField extends StatelessWidget {
  const JournalSearchField(
      {super.key,
      required this.controller,
      required this.focus,
      required this.hint,
      required this.onChanged});
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final on = focus.hasFocus;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.snappySettle),
      curve: AppMotion.standard,
      height: 50,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(on ? 18 : 25),
        border: Border.all(
            color: on ? c.secondary : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        LineIcon('search', size: 19, color: c.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: const ValueKey('journal-search'),
            controller: controller,
            focusNode: focus,
            onChanged: (_) => onChanged(),
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.onSurface),
            decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.onSurfaceVariant)),
          ),
        ),
        if (controller.text.isNotEmpty)
          JournalRound(
              icon: 'x',
              label: s.t('Очистить поиск', 'Clear search'),
              size: 34,
              iconSize: 16,
              onTap: () {
                controller.clear();
                onChanged();
              }),
      ]),
    );
  }
}

/// A section heading with a quiet hint at the end; when both do not fit on
/// one line (large text) the hint moves under the title.
class JournalHeading extends StatelessWidget {
  const JournalHeading(this.title, {super.key, this.count});
  final String title;
  final String? count;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(title,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.42,
                    color: c.onSurface)),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(count!,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: c.onSurfaceVariant)),
              ),
          ]),
    );
  }
}
