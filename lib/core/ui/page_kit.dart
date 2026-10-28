import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palettes.dart';
import '../theme/app_tokens.dart';
import 'companion_kit.dart';
import 'expressive_kit.dart';

/// Shared pieces of the wave 5 pages (settings, libraries, transfer, the
/// hero's card), after the accepted prototype
/// (`docs/prototypes/wave5/index.html`).

/// Russian or English text picked in place, as the journal does.
class Tr {
  Tr(BuildContext context)
      : ru = Localizations.localeOf(context).languageCode == 'ru';
  final bool ru;
  String t(String russian, String english) => ru ? russian : english;

  /// «3 записи», «1 entry»: Russian takes one, few, many; English one, many.
  String plural(int n, List<String> ru, List<String> en, {bool number = true}) {
    final head = number ? '${group(n)} ' : '';
    if (!this.ru) return '$head${n == 1 ? en[0] : en[1]}';
    final last = n % 10, teen = n % 100;
    final form = teen >= 11 && teen <= 14
        ? 2
        : last == 1
            ? 0
            : last >= 2 && last <= 4
                ? 1
                : 2;
    return '$head${ru[form]}';
  }

  /// Thousands grouped with a thin space in Russian, a comma in English.
  String group(int n) {
    final s = n.abs().toString();
    final out = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(ru ? ' ' : ',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

/// `color-mix(in srgb, accent N%, base)` of the prototype.
Color pageMix(Color accent, double amount, Color base) =>
    Color.alphaBlend(accent.withValues(alpha: amount), base);

/// Text on a filled accent: the surface, darkened a little.
Color pageOnAccent(ColorScheme c) =>
    Color.alphaBlend(Colors.black.withValues(alpha: .12), c.surface);

/// A small caps label in the accent, softened towards the text colour.
class PageCap extends StatelessWidget {
  const PageCap(this.text, {super.key, required this.accent});
  final String text;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Text(text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 11.5,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.03,
            color: Color.lerp(c.onSurface, accent, .72)));
  }
}

/// The page's own big title with its caps line and an optional subtitle.
class PageMasthead extends StatelessWidget {
  const PageMasthead(
      {super.key, required this.cap, required this.title, this.subtitle});
  final String cap, title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageCap(cap, accent: AppAccents.of(context).at(1)),
        const SizedBox(height: 6),
        Text(title,
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 46,
                height: .95,
                fontWeight: FontWeight.w600,
                letterSpacing: -2.07,
                color: c.onSurface)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!,
              style: TextStyle(
                  fontSize: 14.5, height: 1.45, color: c.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// A section title between blocks of a page.
class PageSection extends StatelessWidget {
  const PageSection(this.title, {super.key, this.note});
  final String title;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 0),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.42,
                      color: c.onSurface)),
            ),
            if (note != null)
              Text(note!,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: c.onSurfaceVariant)),
          ]),
    );
  }
}

enum PageSealSize { sm, md, lg }

/// A square seal with a line glyph in the accent; the large one is filled.
class PageSeal extends StatelessWidget {
  const PageSeal(this.icon,
      {super.key, required this.accent, this.size = PageSealSize.md});
  final String icon;
  final Color accent;
  final PageSealSize size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (side, radius, glyph) = switch (size) {
      PageSealSize.sm => (30.0, 10.0, 16.0),
      PageSealSize.md => (40.0, 14.0, 21.0),
      PageSealSize.lg => (52.0, 18.0, 26.0),
    };
    final large = size == PageSealSize.lg;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.standard,
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: large ? accent : pageMix(accent, .2, c.surfaceContainer),
        borderRadius: BorderRadius.circular(radius),
      ),
      child:
          LineIcon(icon, size: glyph, color: large ? pageOnAccent(c) : accent),
    );
  }
}

/// The prototype's switch: a capsule whose knob slides over and fills the
/// track with the secondary colour.
class PageSwitch extends StatelessWidget {
  const PageSwitch({super.key, required this.value, this.color});
  final bool value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 240)),
      curve: AppMotion.standard,
      width: 46,
      height: 28,
      decoration: BoxDecoration(
          color: value ? (color ?? c.secondary) : c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14)),
      child: AnimatedAlign(
        duration: dur,
        curve: AppMotion.snappyCurve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: AppMotion.of(context, const Duration(milliseconds: 240)),
          margin: const EdgeInsets.all(4),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: value ? c.surface : c.onSurfaceVariant,
              shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// A row of a page: a seal, a title with a quiet line under it and
/// something at the end (a switch, a pill, a chevron).
class PageRow extends StatelessWidget {
  const PageRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      this.trailing,
      this.onTap,
      this.chevron = false,
      this.toggled,
      this.background});
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final bool chevron;

  /// A row that is a switch announces its state to screen readers.
  final bool? toggled;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final row = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
          color: background ?? c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(child: PageTitle(title, subtitle)),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        if (chevron) ...[
          const SizedBox(width: 8),
          LineIcon('forward', size: 18, color: c.onSurfaceVariant),
        ],
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      toggled: toggled,
      button: toggled == null,
      child: Pressable(scale: .98, onTap: onTap, child: row),
    );
  }
}

/// A title and a quiet line under it.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key, this.size = 15});
  final String title;
  final String? subtitle;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: size,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 12.5, height: 1.35, color: c.onSurfaceVariant)),
          ],
        ]);
  }
}

/// A light tick for every choice made on these pages.
void pageTick() => HapticFeedback.selectionClick();

/// A sheet's heading: a small kicker in the secondary colour, a title and
/// a quiet line under it.
class PageSheetHead extends StatelessWidget {
  const PageSheetHead({super.key, this.kicker, required this.title, this.sub});
  final String? kicker;
  final String title;
  final String? sub;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (kicker != null) ...[
        Text(kicker!,
            style: TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w600,
                color: c.secondary)),
        const SizedBox(height: 10),
      ],
      Text(title,
          style: TextStyle(
              fontFamily: AppType.display,
              fontSize: 26,
              height: 1.12,
              fontWeight: FontWeight.w600,
              letterSpacing: -.52,
              color: c.onSurface)),
      if (sub != null) ...[
        const SizedBox(height: 6),
        Text(sub!,
            style: TextStyle(
                fontSize: 13.5, height: 1.4, color: c.onSurfaceVariant)),
      ],
    ]);
  }
}

/// Content that unfolds from nothing and folds away, fading as it goes.
class PageReveal extends StatelessWidget {
  const PageReveal({super.key, required this.open, required this.child});
  final bool open;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dur = AppMotion.of(context, AppMotion.gentleSettle);
    return ClipRect(
      child: AnimatedAlign(
        duration: dur,
        curve: AppMotion.standard,
        alignment: AlignmentDirectional.topStart,
        heightFactor: open ? 1 : 0,
        child: AnimatedOpacity(
          duration: AppMotion.of(context, const Duration(milliseconds: 300)),
          opacity: open ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}

/// A count in a tinted tile: a rolling number over its name. A zero dims.
class PageCount extends StatelessWidget {
  const PageCount(
      {super.key,
      required this.value,
      required this.label,
      required this.accent,
      this.icon,
      this.size = 22,
      this.tint = .1,
      this.base,
      this.dimZero = false,
      this.from});
  final int value;
  final String label;
  final Color accent;
  final String? icon;
  final double size, tint;
  final Color? base;
  final bool dimZero;
  final int? from;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final zero = dimZero && value == 0;
    return AnimatedOpacity(
      duration: AppMotion.of(context, const Duration(milliseconds: 260)),
      opacity: zero ? .42 : 1,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 260)),
        padding: EdgeInsets.symmetric(
            horizontal: size < 20 ? 10 : 12, vertical: size < 20 ? 8 : 10),
        decoration: BoxDecoration(
            color: zero
                ? c.onSurface.withValues(alpha: .04)
                : pageMix(accent, tint, base ?? c.surfaceContainerLow),
            borderRadius: BorderRadius.circular(size < 20 ? 14 : 18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[
            LineIcon(icon!, size: 17, color: accent),
            const SizedBox(height: 4),
          ],
          RollingNumber(value,
              from: from,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: size,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppType.tabular,
                  color: icon != null
                      ? c.onSurface
                      : Color.lerp(c.onSurface, accent, .7))),
          SizedBox(height: size < 20 ? 3 : 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: size < 20 ? 11 : 11.5,
                  height: 1.2,
                  color: c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Lays tiles out three to a row.
class PageGrid3 extends StatelessWidget {
  const PageGrid3({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 3) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var k = i; k < i + 3; k++) ...[
            if (k > i) SizedBox(width: gap),
            Expanded(
                child: k < children.length ? children[k] : const SizedBox()),
          ],
        ]),
      ));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// A quiet note with a glyph: a hint, or a warning in the accent.
class PageNote extends StatelessWidget {
  const PageNote(this.text,
      {super.key, this.icon = 'info', this.accent, this.size = 13});
  final String text, icon;
  final Color? accent;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = accent == null
        ? c.onSurfaceVariant
        : Color.lerp(c.onSurface, accent, .7)!;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: LineIcon(icon, size: size + 3, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: size, height: 1.4, color: color)),
      ),
    ]);
  }
}

/// A destructive action that asks to be held: the fill runs across while
/// the finger stays and the action fires once it is full.
class PageHold extends StatefulWidget {
  const PageHold(
      {super.key,
      required this.label,
      required this.onDone,
      this.icon = 'trash',
      this.detail});
  final String label, icon;
  final VoidCallback onDone;

  /// A second line under the label; the button then reads from the left,
  /// with its glyph first (the rollback of the advancement history).
  final String? detail;
  @override
  State<PageHold> createState() => _PageHoldState();
}

class _PageHoldState extends State<PageHold>
    with SingleTickerProviderStateMixin {
  late final _fill = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        widget.onDone();
      }
    });

  void _start() {
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fill.value = 1;
      return;
    }
    _fill.forward(from: 0);
  }

  void _stop() {
    if (_fill.isCompleted) return;
    _fill.animateBack(0,
        duration: const Duration(milliseconds: 200), curve: AppMotion.exit);
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = AppAccents.of(context).at(0);
    return Semantics(
      button: true,
      label: widget.label,
      onLongPress: widget.onDone,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: Container(
          height: widget.detail == null ? 50 : null,
          constraints: widget.detail == null
              ? null
              : const BoxConstraints(minHeight: 62),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: a.withValues(alpha: .1),
              borderRadius:
                  BorderRadius.circular(widget.detail == null ? 25 : 24)),
          child: Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _fill,
                builder: (context, _) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: _fill.value,
                    heightFactor: 1,
                    child: ColoredBox(color: a.withValues(alpha: .3)),
                  ),
                ),
              ),
            ),
            if (widget.detail != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  LineIcon(widget.icon, size: 22, color: a),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.label,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: a)),
                          const SizedBox(height: 2),
                          Text(widget.detail!,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                  color: Color.lerp(a,
                                      Theme.of(context).colorScheme.onSurface, .3))),
                        ]),
                  ),
                ]),
              )
            else
              Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  LineIcon(widget.icon, size: 18, color: a),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: a)),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Rises into place a moment after its neighbours above: lists in sheets
/// arrive as a short wave instead of all at once.
class PageEntrance extends StatefulWidget {
  const PageEntrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 360));
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0 || _wait != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    _wait = Timer(
        Duration(milliseconds: 40 + 45 * widget.index.clamp(0, 7)),
        () => mounted ? _c.forward() : null);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final move = AppMotion.snappyCurve.transform(_c.value);
          return Opacity(
            opacity: AppMotion.standard.transform(_c.value),
            child: Transform.translate(
                offset: Offset(0, 14 * (1 - move)), child: child),
          );
        },
        child: widget.child,
      );
}
