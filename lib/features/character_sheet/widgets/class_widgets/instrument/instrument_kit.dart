import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/progression/character_class_context.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

/// Class instruments of the accepted wave 2 prototype
/// (`docs/prototypes/wave2/index.html`, `.inst` and friends). Each ability
/// is an object of its class: a label and a large number at rest, details
/// behind a held peek or the block title, results shown in place, every
/// changing number rolling like the HP drum of Overview.

bool instrumentRu(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ru';

/// The prototype's accents `--a0`…`--a5`.
Color accentOf(BuildContext context, int index) =>
    AppAccents.of(context).at(index);

/// `color-mix(in srgb, a p%, b)`.
Color mixColor(Color a, double p, Color b) => Color.lerp(b, a, p)!;

/// A number with a trailing unit (`90 ОЗ`): the unit in the text face, as
/// in the display face the Cyrillic «ОЗ» reads like the digits «03».
TextSpan unitSpan(String value, TextStyle style) {
  final m = RegExp(r'^(.*?)\s+(ОЗ|HP|фт\.?|ft\.?)$').firstMatch(value);
  if (m == null) return TextSpan(text: value, style: style);
  return TextSpan(style: style, children: [
    TextSpan(text: '${m.group(1)} '),
    TextSpan(
        text: m.group(2),
        style: TextStyle(
            fontFamily: AppType.body,
            fontSize: (style.fontSize ?? 16) * .72,
            fontWeight: FontWeight.w600)),
  ]);
}

/// The prototype accent of each built-in class; other classes take a5.
Color classAccent(BuildContext context, String classId) => accentOf(
    context,
    const {
          'barbarian': 0,
          'bard': 0,
          'cleric': 2,
          'druid': 3,
          'fighter': 4,
          'monk': 2,
          'paladin': 2,
          'ranger': 3,
          'rogue': 4,
          'sorcerer': 1,
          'warlock': 5,
          'wizard': 4,
        }[classId] ??
        5);

/// The sigil of a class for lobby avatars and watermarks; a class that
/// arrives as data takes a neutral spark.
String classSigil(String classId) {
  final id = classId.toLowerCase();
  const sigils = {
    'barbarian': 'axe',
    'bard': 'note',
    'cleric': 'sun',
    'druid': 'tree',
    'fighter': 'sword',
    'monk': 'lotus',
    'paladin': 'shield',
    'ranger': 'target',
    'rogue': 'hood',
    'sorcerer': 'flame',
    'warlock': 'eye',
    'wizard': 'wand',
  };
  for (final e in sigils.entries) {
    if (id.contains(e.key)) return e.value;
  }
  return 'spark';
}

/// Russian noun agreement: 1 заклинание, 2 заклинания, 5 заклинаний.
String ruPlural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

/// Text on an accent fill: the surface pushed towards black.
Color onAccent(BuildContext context) =>
    mixColor(Theme.of(context).colorScheme.surface, .88, Colors.black);

TextStyle capStyle(BuildContext context, Color accent) {
  final c = Theme.of(context).colorScheme;
  return TextStyle(
      fontFamily: AppType.body,
      fontSize: 11.5,
      height: 1.1,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.03,
      color: mixColor(accent, .72, c.onSurface));
}

TextStyle hugeStyle(BuildContext context) => TextStyle(
    fontFamily: AppType.display,
    fontSize: 60,
    height: .92,
    fontWeight: FontWeight.w600,
    letterSpacing: -2.4,
    color: Theme.of(context).colorScheme.onSurface,
    fontFeatures: AppType.tabular);

TextStyle bigStyle(BuildContext context) => TextStyle(
    fontFamily: AppType.display,
    fontSize: 34,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: -.7,
    color: Theme.of(context).colorScheme.onSurface,
    fontFeatures: AppType.tabular);

TextStyle ofStyle(BuildContext context) => TextStyle(
    fontFamily: AppType.display,
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurfaceVariant);

TextStyle hintStyle(BuildContext context) => TextStyle(
    fontFamily: AppType.body,
    fontSize: 12.5,
    height: 1.3,
    color: Theme.of(context).colorScheme.onSurfaceVariant);

TextStyle labelStyle(BuildContext context,
        {double size = 14.5, FontWeight weight = FontWeight.w600}) =>
    TextStyle(
        fontFamily: AppType.body,
        fontSize: size,
        height: 1.2,
        fontWeight: weight,
        color: Theme.of(context).colorScheme.onSurface);

/// What an ability is and how to use it: the block title opens it.
class InstrumentAbout {
  const InstrumentAbout(
      {required this.title, this.kicker, this.paragraphs = const [], this.how});
  final String title;
  final String? kicker;
  final List<String> paragraphs;
  final String? how;
}

Future<void> showInstrumentAbout(
    BuildContext context, InstrumentAbout about, Color accent) {
  HapticFeedback.selectionClick();
  final t = Theme.of(context), c = t.colorScheme;
  return showCompanionSheet(context,
      builder: (context) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (about.kicker != null) ...[
              Text(about.kicker!,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent)),
              const SizedBox(height: 8),
            ],
            SheetHeading(about.title),
            const SizedBox(height: 14),
            for (final p in about.paragraphs)
              if (p.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(p.trim(),
                      style: t.textTheme.bodyLarge
                          ?.copyWith(fontSize: 15, height: 1.5)),
                ),
            if (about.how != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                    color: mixColor(accent, .14, c.surfaceContainerLow),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: InstrumentGlyph('spark',
                              size: 18, color: accent)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(about.how!,
                              style: t.textTheme.bodyMedium
                                  ?.copyWith(fontSize: 14, height: 1.4))),
                    ]),
              ),
            ],
          ]));
}

/// The cap of a block: an uppercase label; with an [about] it carries an
/// info mark and opens the ability's full text.
/// A label that never breaks inside a word: a single word scales down to
/// the width instead of wrapping mid-word (Контрочарование, Преимущество).
class WordSafeText extends StatelessWidget {
  const WordSafeText(this.text,
      {super.key, required this.style, this.maxLines = 2, this.textAlign});
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) {
    if (text.trim().contains(' ')) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : AlignmentDirectional.centerStart,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}

class InstrumentCap extends StatelessWidget {
  const InstrumentCap(this.text, {super.key, required this.accent, this.about});
  final String text;
  final Color accent;
  final InstrumentAbout? about;
  @override
  Widget build(BuildContext context) {
    final style = capStyle(context, accent);
    final upper = text.toUpperCase();
    if (about == null) return WordSafeText(upper, style: style);
    // The ⓘ rides in the same text run, so a narrow cell wraps the caption
    // with it instead of pushing the glyph past the edge.
    final single = !upper.trim().contains(' ');
    Widget label = Text.rich(
        TextSpan(children: [
          TextSpan(text: upper),
          WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Opacity(
                      opacity: .7,
                      child: InstrumentGlyph('info',
                          size: 14, color: style.color)))),
        ]),
        maxLines: single ? 1 : 2,
        softWrap: !single,
        overflow: single ? TextOverflow.visible : TextOverflow.ellipsis,
        style: style);
    if (single) {
      label = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: label);
    }
    return Pressable(
      scale: .97,
      semanticLabel: text,
      onTap: () => showInstrumentAbout(context, about!, accent),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4), child: label),
    );
  }
}

/// Glyphs drawn from the prototype's symbol set that the shared [LineIcon]
/// does not carry.
class InstrumentGlyph extends StatelessWidget {
  const InstrumentGlyph(this.name, {super.key, this.size = 22, this.color});
  final String name;
  final double size;
  final Color? color;

  static const paths = <String, String>{
    'info': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v5.5M12 7.6h.01',
    'spark':
        'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6',
    'axe':
        'M14 3.5c3.5 1 6 3.5 6.5 7l-6 .5-1-1zM13.5 10 4 19.5l1.5 1.5 9.5-9.5',
    'skull':
        'M12 3a7 7 0 0 0-7 7c0 2.6 1.3 4.2 2.5 5.2V18h9v-2.8c1.2-1 2.5-2.6 2.5-5.2a7 7 0 0 0-7-7zM9.3 10.8h.01M14.7 10.8h.01M10 18v3M14 18v3',
    'flame':
        'M12 3c.6 3.6 5 5.6 5 10.2a5 5 0 0 1-10 0c0-2.5 1.3-4.1 2.6-5.1.2 1.8 1 3 2.4 3.4C11.5 9.2 11 6 12 3z',
    'hand':
        'M8 13V6.5a1.5 1.5 0 0 1 3 0V11M11 10.5V5a1.5 1.5 0 0 1 3 0v5.5M14 10.5V7a1.5 1.5 0 0 1 3 0v6.5a6.5 6.5 0 0 1-6.5 6.5h-.3a5 5 0 0 1-4.1-2.2L4.3 14a1.5 1.5 0 0 1 2.4-1.8L8 14',
    'drop': 'M12 3.5s6 6.4 6 10.7a6 6 0 0 1-12 0C6 9.9 12 3.5 12 3.5z',
    'quill':
        'M20 4C12 5 7 10 5 19.5M5 19.5c3-1 6-3 8-6-2 0-3.2-.3-4-1 3.5-1 7-3.5 11-8.5',
    'wave': 'M3 9c2-2 4-2 6 0s4 2 6 0 4-2 6 0M3 15c2-2 4-2 6 0s4 2 6 0 4-2 6 0',
    'tree': 'M12 3 6 11h3l-4 6h14l-4-6h3zM12 17v4',
    'track':
        'M8 4.5c1.4 0 2 1.4 2 2.8S9.4 10 8 10 6 8.7 6 7.3s.6-2.8 2-2.8zM7 12.5h2v2H7zM16 9.5c1.4 0 2 1.4 2 2.8S17.4 15 16 15s-2-1.3-2-2.7.6-2.8 2-2.8zM15 17.5h2v2h-2z',
    'peaks': 'M2.5 20 9 8l3.5 6 2.5-4 6.5 10z',
    'hood':
        'M12 3c-4 0-7 4-7 9.5V20h14v-7.5C19 7 16 3 12 3zM8.5 12.5c1.2 2.2 5.8 2.2 7 0',
    'person':
        'M12 4a3.2 3.2 0 1 1 0 6.4A3.2 3.2 0 0 1 12 4zM5.5 20c0-3.6 2.9-6.3 6.5-6.3s6.5 2.7 6.5 6.3',
    'sun':
        'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8',
    'dash': 'M4 6l6 6-6 6M12 6l6 6-6 6',
    'stepback': 'M9 6 4 11l5 5M4 11h10a6 6 0 0 1 6 6v2',
    'twin': 'M7 4v16M17 4v16M3.5 8 7 4.5 10.5 8M13.5 8 17 4.5 20.5 8',
    'lotus':
        'M12 19c-4.5 0-8.5-2.2-9.5-6.5 3.2 0 6.5 1.4 9.5 4.6 3-3.2 6.3-4.6 9.5-4.6-1 4.3-5 6.5-9.5 6.5zM12 17c-2.3-3.2-2.3-7.6 0-12 2.3 4.4 2.3 8.8 0 12z',
    'wind': 'M3 8.5h10.5a3 3 0 1 0-3-3M3 12.5h15a3 3 0 1 1-3 3M3 16.5h7',
    'strikes': 'M5 19 11.5 5M10 19l6.5-14M15 19l4.5-9',
    'mask':
        'M4 6c4 1.6 12 1.6 16 0v5.5c0 5-4 8.5-8 8.5s-8-3.5-8-8.5zM8 11.5h2.5M13.5 11.5H16M10 16c1.2.8 2.8.8 4 0',
    'paw':
        'M12 13c3 0 5 3 5 5.5 0 1.5-1.3 2-2.5 2S13 20 12 20s-1.3.5-2.5.5S7 20 7 18.5C7 16 9 13 12 13zM6 11.5a1.8 2.3 0 1 0 0-.01M18 11.5a1.8 2.3 0 1 0 0-.01M9 7.5a1.8 2.3 0 1 0 0-.01M15 7.5a1.8 2.3 0 1 0 0-.01',
    'heart':
        'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
    'target':
        'M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM12 2v3M12 19v3M2 12h3M19 12h3',
    'timer': 'M12 21a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 9v4l2.5 2M10 2h4',
    'lock': 'M7 11V8a5 5 0 0 1 10 0v3M6 11h12v9H6z',
    'wand':
        'M5 19 15 9M14 4l1 2.5L17.5 7.5 15 8.5 14 11 13 8.5 10.5 7.5 13 6.5zM19 12l.6 1.4 1.4.6-1.4.6L19 16l-.6-1.4-1.4-.6 1.4-.6z',
    'swap': 'M7 7h11l-3-3M17 17H6l3 3',
    'minus': 'M5 12h14',
  };

  @override
  Widget build(BuildContext context) {
    final path = paths[name];
    if (path == null) return LineIcon(name, size: size, color: color);
    return _PathGlyph(path, size: size, color: color);
  }
}

class _PathGlyph extends StatelessWidget {
  const _PathGlyph(this.path, {required this.size, this.color});
  final String path;
  final double size;
  final Color? color;
  static final _svgs = <String, String>{};
  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Colors.white;
    final svg = _svgs.putIfAbsent(
        path,
        () =>
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
            'stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="$path"/></svg>');
    return SizedBox.square(
        dimension: size, child: _SvgString(svg, size: size, color: tint));
  }
}

class _SvgString extends StatelessWidget {
  const _SvgString(this.svg, {required this.size, required this.color});
  final String svg;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(svg,
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
}

/// The instrument surface (`.inst`): radius 30, padding 18, a gradient of
/// the accent into `low`, a hairline of light on top and a soft shadow.
/// Its height follows its content smoothly when the state changes shape.
class Instrument extends StatelessWidget {
  const Instrument({
    super.key,
    required this.accent,
    required this.title,
    required this.child,
    this.about,
    this.trailing,
    this.background,
    this.border,
    this.glow,
    this.chamfer = false,
    this.padding = const EdgeInsets.all(18),
  });
  final Color accent;
  final String title;
  final InstrumentAbout? about;
  final Widget? trailing;
  final Widget child;

  /// Layers painted under the content (heat, planes, a blob).
  final Widget? background;
  final Color? border, glow;
  final bool chamfer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final low = c.surfaceContainerLow;
    final OutlinedBorder shape = chamfer
        ? const BeveledRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18), bottomRight: Radius.circular(18)))
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
    final body = Padding(
      padding: padding,
      child: AnimatedSize(
        duration: AppMotion.of(context, const Duration(milliseconds: 520)),
        curve: AppMotion.gentleCurve,
        alignment: Alignment.topCenter,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: InstrumentCap(title, accent: accent, about: about))),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              _HeaderTrailing(child: trailing!)
            ],
          ]),
          child,
        ]),
      ),
    );
    return AnimatedContainer(
      duration: AppMotion.of(context, const Duration(milliseconds: 500)),
      curve: AppMotion.standard,
      decoration: ShapeDecoration(
        shape: border == null
            ? shape
            : shape.copyWith(side: BorderSide(color: border!, width: 2)),
        gradient: LinearGradient(
          begin: const Alignment(-.35, -1),
          end: const Alignment(.35, 1),
          stops: const [0, .72],
          colors: [mixColor(accent, .15, low), low],
        ),
        shadows: [
          BoxShadow(
              color: (glow ?? Colors.black)
                  .withValues(alpha: glow == null ? .75 : .55),
              blurRadius: 40,
              spreadRadius: -28,
              offset: const Offset(0, 20)),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Stack(children: [
          if (background != null) Positioned.fill(child: background!),
          Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: ColoredBox(color: c.onSurface.withValues(alpha: .08))),
          body,
        ]),
      ),
    );
  }
}

/// A lighter block (`.lite`) for secondary abilities.
class LiteBlock extends StatelessWidget {
  const LiteBlock(
      {super.key,
      required this.accent,
      required this.title,
      required this.child,
      this.about,
      this.trailing});
  final Color accent;
  final String title;
  final InstrumentAbout? about;
  final Widget? trailing;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24)),
      child: AnimatedSize(
        duration: AppMotion.of(context, const Duration(milliseconds: 520)),
        curve: AppMotion.gentleCurve,
        alignment: Alignment.topCenter,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: InstrumentCap(title, accent: accent, about: about))),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              _HeaderTrailing(child: trailing!)
            ],
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

/// The trailing chips of a block header sit flush right and wrap rather
/// than overflow, never taking more than ~60% of the header.
class _HeaderTrailing extends StatelessWidget {
  const _HeaderTrailing({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .5),
      child: child);
}

/// A block that changes its form (a hero becomes a beast, crystals fold
/// away): the height flows on a gentle spring while the old form fades and
/// the new one rises into place. Give each form its own [key].
class MorphSwitcher extends StatelessWidget {
  const MorphSwitcher({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, const Duration(milliseconds: 520));
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.gentleCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: AppMotion.of(context, const Duration(milliseconds: 220)),
        switchInCurve: AppMotion.standard,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            // The leaving form never sets the height, so nothing jumps.
            for (final p in previous) Positioned(left: 0, right: 0, top: 0, child: p),
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .97, end: 1.0).animate(animation),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A quiet capsule beside a title (`.used`, `.rest`).
class InstrumentChip extends StatelessWidget {
  const InstrumentChip(this.label,
      {super.key, this.glyph, this.onTap, this.color, this.peek});
  final String label;
  final String? glyph;
  final VoidCallback? onTap;
  final Color? color;
  final (String, String)? peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = color ?? c.onSurfaceVariant;
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: c.onSurface.withValues(alpha: onTap == null ? .08 : .06)),
      // One text run, so a long label wraps inside its width instead of
      // overflowing a row (large text, long data names).
      child: Text.rich(
          TextSpan(children: [
            if (glyph != null)
              WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: InstrumentGlyph(glyph!, size: 14, color: fg))),
            TextSpan(text: label),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: fg)),
    );
    if (onTap != null) {
      chip = Pressable(
          onTap: onTap, scale: .92, semanticLabel: label, child: chip);
    }
    if (peek != null) chip = Peek(title: peek!.$1, text: peek!.$2, child: chip);
    return chip;
  }
}

/// The rest chip names the rest that restores this resource. A touch
/// restores it now (the rest just happened at the table), a hold edits the
/// value by hand.
class RestChip extends StatelessWidget {
  const RestChip({super.key, required this.short, this.onRestore, this.onEdit});
  final bool short;
  final Future<void> Function()? onRestore;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final label =
        short ? (ru ? 'Короткий' : 'Short') : (ru ? 'Длительный' : 'Long');
    final chip = InstrumentChip(label, glyph: short ? 'cup' : 'moon');
    if (onRestore == null && onEdit == null) return chip;
    return Pressable(
      onTap: onRestore == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onRestore!();
            },
      onLongPress: onEdit == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onEdit!();
            },
      scale: .92,
      semanticLabel: short
          ? (ru ? 'Короткий отдых: восстановить' : 'Short rest: restore')
          : (ru ? 'Длительный отдых: восстановить' : 'Long rest: restore'),
      child: chip,
    );
  }
}

/// Restores a feature's reserve to its maximum after a rest; an overfilled
/// reserve stays as it is. Reports the result in place of a dialog.
Future<void> restoreFeature(
    BuildContext context, Character hero, CharacterFeature feature,
    {VoidCallback? done}) async {
  final current = GameplayActionsService.resourceCurrent(hero, feature);
  final max = Character.isChannelDivinityResource(feature)
      ? hero.getMaxChannelDivinityCharges()
      : feature.resourcePool?.maxUses ?? 0;
  await restoreValue(context,
      current: current,
      max: max,
      write: (v) => GameplayActionsService.editResource(hero, feature, v),
      done: done);
}

/// The shared tail of every rest chip: write the maximum unless already
/// there, then a short confirmation.
Future<void> restoreValue(BuildContext context,
    {required int current,
    required int max,
    required Future<void> Function(int value) write,
    VoidCallback? done}) async {
  final ru = instrumentRu(context);
  if (current >= max) {
    AppSnackBar.info(
        context, ru ? 'Уже полностью восстановлено' : 'Already full');
    return;
  }
  try {
    await write(max);
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.error(
          context, ru ? 'Не удалось сохранить' : 'Could not save');
    }
    return;
  }
  done?.call();
  if (context.mounted) {
    AppSnackBar.success(context, ru ? 'Восстановлено: $max' : 'Restored: $max');
  }
}

/// A large number with its maximum: `5 / 6`.
class BigCount extends StatelessWidget {
  const BigCount(this.value, {super.key, this.of, this.unit, this.big = false});
  final int value;
  final int? of;
  final String? unit;
  final bool big;
  @override
  Widget build(BuildContext context) {
    // Large text scales the count down rather than overflowing its block.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          RollingNumber(value,
              style: big ? bigStyle(context) : hugeStyle(context)),
          if (of != null || unit != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              // Units in the text face: in the display face «ОЗ» reads «03».
              child: Text.rich(
                  TextSpan(children: [
                    if (of != null) TextSpan(text: '/ $of'),
                    if (unit != null)
                      TextSpan(
                          text: '${of != null ? ' ' : ''}${unit!}',
                          style: const TextStyle(
                              fontFamily: AppType.body,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                  ]),
                  style: ofStyle(context)),
            ),
        ],
      ),
    );
  }
}

class InstrumentHint extends StatelessWidget {
  const InstrumentHint(this.text, {super.key, this.center = false});
  final String text;
  final bool center;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: hintStyle(context));
}

/// The accent action (`.go`, `.go.soft`).
class GoButton extends StatelessWidget {
  const GoButton(
      {super.key,
      required this.label,
      required this.accent,
      this.glyph,
      this.onTap,
      this.soft = false,
      this.subtitle,
      this.height = 52});
  final String label;
  final String? glyph, subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool soft;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = soft ? c.onSurface : onAccent(context);
    final bg = soft ? mixColor(accent, .22, c.surfaceContainer) : accent;
    return Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Pressable(
        onTap: onTap,
        scale: .975,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(height / 2)),
          alignment: Alignment.center,
          child: subtitle == null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (glyph != null) ...[
                    InstrumentGlyph(glyph!, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle(context, size: 15)
                              .copyWith(color: fg))),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      textAlign: TextAlign.center,
                      style: labelStyle(context, size: 14).copyWith(color: fg)),
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      textAlign: TextAlign.center,
                      style: hintStyle(context).copyWith(fontSize: 12)),
                ]),
        ),
      ),
    );
  }
}

/// A quiet action (`.ghost`).
class GhostButton extends StatelessWidget {
  const GhostButton(
      {super.key,
      required this.label,
      this.glyph,
      this.onTap,
      this.height = 52});
  final String label;
  final String? glyph;
  final VoidCallback? onTap;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Pressable(
        onTap: onTap,
        scale: .97,
        semanticLabel: label,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: c.onSurface.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(height / 2)),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (glyph != null) ...[
              InstrumentGlyph(glyph!, size: 18, color: c.onSurface),
              const SizedBox(width: 8),
            ],
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle(context, size: 14))),
          ]),
        ),
      ),
    );
  }
}

/// A secondary tile (`.cell2`).
class CellTile extends StatelessWidget {
  const CellTile(
      {super.key,
      required this.accent,
      required this.children,
      this.onTap,
      this.peek,
      this.chamfer = false,
      this.lit = false});
  final Color accent;
  final List<Widget> children;
  final VoidCallback? onTap;
  final (String, String)? peek;
  final bool chamfer, lit;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final low = c.surfaceContainerLow;
    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        shape: chamfer
            ? const BeveledRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18)))
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        gradient: LinearGradient(
            begin: const Alignment(-.35, -1),
            end: const Alignment(.35, 1),
            stops: const [
              0,
              .8
            ],
            colors: [
              mixColor(accent, lit ? .24 : .12, low),
              lit ? mixColor(accent, .14, low) : low
            ]),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 7),
              children[i],
            ]
          ]),
    );
    if (onTap != null) tile = Pressable(onTap: onTap, scale: .97, child: tile);
    if (peek != null) {
      tile = Peek(title: peek!.$1, text: peek!.$2, accent: accent, child: tile);
    }
    return tile;
  }
}

/// A locked tile: the feature opens at a later level.
class LockedCell extends StatelessWidget {
  const LockedCell(
      {super.key,
      required this.title,
      required this.level,
      required this.accent});
  final String title;
  final int level;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    return Opacity(
      opacity: .55,
      child: CellTile(
        accent: accent,
        peek: (
          title,
          ru ? 'Откроется на $level уровне' : 'Opens at level $level'
        ),
        children: [
          Text(title.toUpperCase(), style: capStyle(context, accent)),
          InstrumentGlyph('lock', size: 18, color: c.onSurfaceVariant),
          InstrumentHint(ru ? 'с $level уровня' : 'from level $level'),
        ],
      ),
    );
  }
}

/// A whole instrument that opens later.
class LockedInstrument extends StatelessWidget {
  const LockedInstrument(
      {super.key,
      required this.title,
      required this.level,
      required this.what,
      required this.accent});
  final String title, what;
  final int level;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    return Instrument(
      accent: accent,
      title: title,
      trailing:
          InstrumentChip(ru ? '$level уровень' : 'Level $level', glyph: 'lock'),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.onSurface.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            InstrumentGlyph('lock', size: 22, color: c.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
                child: Text(what,
                    style: hintStyle(context).copyWith(fontSize: 13.5))),
          ]),
        ),
      ),
    );
  }
}

/// Ten (or n) pips of a duration; the current one glows.
class Fuse extends StatelessWidget {
  const Fuse(
      {super.key,
      required this.length,
      required this.at,
      required this.accent});
  final int length, at;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: AnimatedContainer(
            duration: AppMotion.of(context, const Duration(milliseconds: 400)),
            curve: AppMotion.snappyCurve,
            height: i == at - 1 ? 12 : 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i < at - 1
                  ? accent.withValues(alpha: .3)
                  : i == at - 1
                      ? accent
                      : c.onSurface.withValues(alpha: .1),
              boxShadow: i == at - 1
                  ? [
                      BoxShadow(
                          color: accent.withValues(alpha: .6), blurRadius: 12)
                    ]
                  : null,
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Round counter with back/forward: `Конец · раунд 3 / 10 · ›`.
class RoundControl extends StatelessWidget {
  const RoundControl(
      {super.key,
      required this.round,
      required this.of,
      required this.accent,
      required this.label,
      required this.onNext,
      required this.onEnd,
      required this.endLabel});
  final int round, of;
  final Color accent;
  final String label, endLabel;
  final VoidCallback? onNext, onEnd;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      GhostButton(label: endLabel, onTap: onEnd),
      Expanded(
        child: Column(children: [
          Text(label.toUpperCase(),
              style: hintStyle(context).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .6)),
          const SizedBox(height: 4),
          BigCount(round, of: of, big: true),
        ]),
      ),
      Pressable(
        onTap: onNext,
        scale: .88,
        semanticLabel: label,
        child: Container(
          width: 58,
          height: 58,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: accent, boxShadow: [
            BoxShadow(
                color: accent.withValues(alpha: .5),
                blurRadius: 22,
                spreadRadius: -8,
                offset: const Offset(0, 8))
          ]),
          alignment: Alignment.center,
          child: LineIcon('forward', size: 22, color: onAccent(context)),
        ),
      ),
    ]);
  }
}

/// Peek: hold an element to read its details in a glass bubble beside it.
class Peek extends StatefulWidget {
  const Peek(
      {super.key,
      required this.title,
      required this.text,
      required this.child,
      this.accent,
      this.tap = false});
  final String title, text;
  final Widget child;

  /// An information token opens on a tap as well as on a hold.
  final bool tap;

  /// The block's accent for the title chip; Monokai pink when unset.
  final Color? accent;
  @override
  State<Peek> createState() => _PeekState();
}

class _PeekState extends State<Peek> {
  static OverlayEntry? _open;
  static Timer? _timer;

  static void dismiss() {
    _timer?.cancel();
    _open?.remove();
    _open = null;
  }

  void _show() {
    dismiss();
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (box == null || overlay == null) return;
    HapticFeedback.selectionClick();
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final entry = OverlayEntry(
        builder: (context) => _PeekBubble(
            anchor: rect,
            title: widget.title,
            text: widget.text,
            accent: widget.accent ?? accentOf(this.context, 0),
            onDismiss: dismiss));
    _open = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 4600), dismiss);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: _show,
        onTap: widget.tap ? _show : null,
        child: widget.child,
      );
}

class _PeekBubble extends StatefulWidget {
  const _PeekBubble(
      {required this.anchor,
      required this.title,
      required this.text,
      required this.accent,
      required this.onDismiss});
  final Rect anchor;
  final String title, text;
  final Color accent;
  final VoidCallback onDismiss;
  @override
  State<_PeekBubble> createState() => _PeekBubbleState();
}

class _PeekBubbleState extends State<_PeekBubble>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380))
    ..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final t = Theme.of(context);
    const width = 280.0;
    final left = (widget.anchor.center.dx - width / 2)
        .clamp(12.0, size.width - width - 12);
    final above = widget.anchor.top > 160;
    return Stack(children: [
      Positioned.fill(
          child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => widget.onDismiss())),
      Positioned(
        left: left,
        width: width,
        top: above ? null : widget.anchor.bottom + 10,
        bottom: above ? size.height - widget.anchor.top + 10 : null,
        child: IgnorePointer(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: AppMotion.snappyCurve)
                .drive(Tween(begin: .86, end: 1)),
            alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
            child: FadeTransition(
              opacity: _c,
              // An overlay has no Material above it; without one Flutter
              // marks bare text with a yellow double underline.
              child: Material(
                type: MaterialType.transparency,
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The title wears the accent as a framed chip.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: ShapeDecoration(
                              shape: StadiumBorder(
                                  side: BorderSide(
                                      color:
                                          widget.accent.withValues(alpha: .6),
                                      width: 1.2)),
                              color: widget.accent.withValues(alpha: .14),
                            ),
                            child: Text(widget.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: labelStyle(context, size: 13)
                                    .copyWith(color: widget.accent)),
                          ),
                          if (widget.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(widget.text,
                                style: t.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: t.colorScheme.onSurface
                                        .withValues(alpha: .8))),
                          ],
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Dice shapes of the prototype (`DSHAPE`).
enum DieShape { d4, d6, d8, d10, d12, d20, d100 }

DieShape dieShapeFor(int sides) => switch (sides) {
      4 => DieShape.d4,
      6 => DieShape.d6,
      8 => DieShape.d8,
      10 => DieShape.d10,
      12 => DieShape.d12,
      100 => DieShape.d100,
      _ => DieShape.d20,
    };

/// A die rolled in place, moving like the large die of the dice roller:
/// a low toss on a spring with its shadow tightening on the table, one
/// turn that lands upright, a short squash at touchdown, faces flickering
/// ever slower while the number stays upright, then the result locks in.
/// A natural maximum glows in the block's accent; a natural 1 on a d20
/// sinks and dims. Before the first roll the face shows the die name.
class TumbleDie extends StatefulWidget {
  const TumbleDie({
    super.key,
    required this.shape,
    required this.label,
    required this.accent,
    this.rollKey = 0,
    this.size = 58,
    this.sides,
    this.natural,
    this.dim = false,
  });
  final DieShape shape;
  final String label;
  final Color accent;
  final int rollKey;
  final double size;
  final int? sides;

  /// The die's own result before modifiers, when the caller knows it: a
  /// maximum glows, a 1 on a d20 sinks.
  final int? natural;
  final bool dim;
  @override
  State<TumbleDie> createState() => _TumbleDieState();
}

class _TumbleDieState extends State<TumbleDie> with TickerProviderStateMixin {
  late final _lift = AnimationController.unbounded(vsync: this)..addListener(_touchdown);
  late final _spin = AnimationController.unbounded(vsync: this);
  late final _squash = AnimationController.unbounded(vsync: this);
  late final _lock = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _falling = false, _rolling = false;
  String? _flicker;
  final _timers = <Timer>[];
  final _rnd = math.Random();

  int get _sides =>
      widget.sides ??
      switch (widget.shape) {
        DieShape.d4 => 4,
        DieShape.d6 => 6,
        DieShape.d8 => 8,
        DieShape.d10 => 10,
        DieShape.d12 => 12,
        DieShape.d20 => 20,
        DieShape.d100 => 100,
      };

  bool get _max => !_rolling && widget.natural != null && widget.natural == _sides;
  bool get _fumble => !_rolling && widget.natural == 1 && _sides == 20;

  @override
  void didUpdateWidget(covariant TumbleDie old) {
    super.didUpdateWidget(old);
    if (widget.rollKey != old.rollKey && widget.rollKey != 0) _toss();
  }

  void _later(int ms, VoidCallback f) => _timers.add(Timer(Duration(milliseconds: ms), () {
        if (mounted) f();
      }));

  void _touchdown() {
    if (_falling && _lift.value >= -1) {
      _falling = false;
      _squash.value = 1;
      _squash.animateWith(SpringSimulation(AppMotion.snappy, 1, 0, 0));
      HapticFeedback.lightImpact();
    }
  }

  void _toss() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _glow.reset();
    if (MediaQuery.disableAnimationsOf(context)) return;
    final h = widget.size;
    setState(() => _rolling = true);
    // A low toss with a turn; the height follows the die's size.
    _lift.animateWith(SpringSimulation(AppMotion.snappy, _lift.value, -h * .32, -h * 5.5));
    final turn = 2 * math.pi + _rnd.nextDouble() * math.pi * .6;
    _spin.animateWith(SpringSimulation(AppMotion.gentle, _spin.value, _spin.value + turn, 19));
    // Faces flicker, each a little slower than the last.
    var wait = 38.0;
    void flick() {
      // The faces stop the moment the die lands.
      if (!_rolling) return;
      setState(() => _flicker = '${1 + _rnd.nextInt(_sides)}');
      wait *= 1.24;
      if (wait < 200) _later(wait.round(), flick);
    }

    flick();
    _later(200, () {
      _falling = true;
      _lift.animateWith(SpringSimulation(AppMotion.snappy, _lift.value, 0, _lift.velocity));
    });
    _later(560, () {
      // Lands upright on the nearest full turn, and the result locks in.
      _spin.animateWith(SpringSimulation(
          AppMotion.gentle, _spin.value, (_spin.value / (2 * math.pi)).roundToDouble() * 2 * math.pi, _spin.velocity));
      setState(() {
        _flicker = null;
        _rolling = false;
      });
      _lock.forward(from: 0);
      if (_max) {
        _glow.forward(from: 0);
        HapticFeedback.mediumImpact();
      } else if (_fumble) {
        _lift.animateWith(SpringSimulation(AppMotion.gentle, _lift.value, widget.size * .05, 0));
        _glow.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _lift.dispose();
    _spin.dispose();
    _squash.dispose();
    _lock.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final size = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_lift, _spin, _squash, _lock, _glow]),
      builder: (context, _) {
        final face = _flicker ?? widget.label;
        final up = (-_lift.value / (size * .32)).clamp(0.0, 1.0);
        final sq = _squash.value;
        final lock = AppMotion.snappyCurve.transform(_lock.value);
        final g = _glow.value;
        final glow = g == 0 ? 0.0 : (g < .3 ? g / .3 : 1 - (g - .3) / .7).clamp(0.0, 1.0);
        final fumble = _fumble;
        final accent = fumble ? c.outline : widget.accent;
        return SizedBox.square(
          dimension: size,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (glow > 0 && !fumble)
              IgnorePointer(
                child: Container(
                  width: size * 1.7,
                  height: size * 1.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [accent.withValues(alpha: .45 * glow), Colors.transparent]),
                  ),
                ),
              ),
            // Its shadow on the table, tighter while the die is up.
            Positioned(
              bottom: -size * .06,
              child: Opacity(
                opacity: (1 - .5 * up) * .9,
                child: Container(
                  width: size * .74 * (1 - .3 * up),
                  height: size * .12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(size * .37, size * .06)),
                    gradient: RadialGradient(colors: [Colors.black.withValues(alpha: .34), Colors.transparent]),
                  ),
                ),
              ),
            ),
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0, _lift.value, 0, 1)
                ..scaleByDouble(1 + .03 * sq, 1 - .045 * sq, 1, 1),
              child: Transform.rotate(
                angle: _spin.value,
                child: SizedBox.square(
                  dimension: size,
                  child: CustomPaint(
                    painter: _DiePainter(widget.shape, accent, c.surfaceContainer, widget.dim || fumble, _max ? glow : 0),
                    // The number stays upright while the die turns; on a d4
                    // it sits in the lower, wider part of the triangle.
                    child: Align(
                      alignment: widget.shape == DieShape.d4
                          ? const Alignment(0, .38)
                          : Alignment.center,
                      child: Transform.rotate(
                        angle: -_spin.value,
                        child: Opacity(
                          opacity: .45 + .55 * lock.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: .86 + .14 * lock,
                            child: Text(face,
                                maxLines: 1,
                                style: TextStyle(
                                    fontFamily: AppType.display,
                                    fontSize: size * (face.length > 2 ? .24 : .3),
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: AppType.tabular,
                                    color: fumble
                                        ? c.onSurfaceVariant
                                        : Color.lerp(c.onSurface, accent, _max ? .55 * glow : 0))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// A die silhouette with softened corners, a little volume (light from the
/// top left) and faint facets, so it reads as a die even when small.
class _DiePainter extends CustomPainter {
  _DiePainter(this.shape, this.accent, this.cont, this.dim, this.glow);
  final DieShape shape;
  final Color accent, cont;
  final bool dim;
  final double glow;

  /// A closed polygon whose corners are rounded by [r].
  static Path _soft(List<Offset> pts, double r) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final prev = pts[(i - 1 + pts.length) % pts.length], cur = pts[i], next = pts[(i + 1) % pts.length];
      final a = cur + (prev - cur) / (prev - cur).distance * math.min(r, (prev - cur).distance / 2);
      final b = cur + (next - cur) / (next - cur).distance * math.min(r, (next - cur).distance / 2);
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final r = 10 * s;
    late Path face;
    final facets = Path();
    // Wave 3 silhouettes (`DSH`): each die reads as itself even small —
    // a pyramid, a cube, a diamond, a banded kite, a pentagon, a hexagon,
    // and two kites for the d100.
    List<Offset> kite10(double dx, double dy, double k) => [
          for (final (x, y) in const [(50.0, 4.0), (95.0, 44.0), (95.0, 56.0), (50.0, 96.0), (5.0, 56.0), (5.0, 44.0)])
            p(50 + (x - 50) * k + dx, 50 + (y - 50) * k + dy)
        ];
    Path? back;
    switch (shape) {
      case DieShape.d6:
        face = Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(10 * s, 10 * s, 80 * s, 80 * s), Radius.circular(18 * s)));
        facets.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(24 * s, 24 * s, 52 * s, 52 * s), Radius.circular(9 * s)));
      case DieShape.d8:
        face = _soft([p(50, 4), p(95, 50), p(50, 96), p(5, 50)], r);
        facets
          ..moveTo(9 * s, 50 * s)
          ..lineTo(50 * s, 36 * s)
          ..lineTo(91 * s, 50 * s)
          ..moveTo(50 * s, 8 * s)
          ..lineTo(50 * s, 36 * s);
      case DieShape.d10:
        face = _soft(kite10(0, 0, 1), r * .8);
        facets
          ..moveTo(9 * s, 44 * s)
          ..lineTo(28 * s, 58 * s)
          ..lineTo(50 * s, 44 * s)
          ..lineTo(72 * s, 58 * s)
          ..lineTo(91 * s, 44 * s)
          ..moveTo(28 * s, 58 * s)
          ..lineTo(50 * s, 92 * s)
          ..lineTo(72 * s, 58 * s);
      case DieShape.d12:
        Offset pent(double radius, int i) => Offset(50 * s + radius * s * math.cos(-math.pi / 2 + i * 2 * math.pi / 5),
            53 * s + radius * s * math.sin(-math.pi / 2 + i * 2 * math.pi / 5));
        face = _soft([for (var i = 0; i < 5; i++) pent(47, i)], r);
        facets.addPath(_soft([for (var i = 0; i < 5; i++) pent(22, i)], r * .4), Offset.zero);
        for (var i = 0; i < 5; i++) {
          facets
            ..moveTo(pent(43, i).dx, pent(43, i).dy)
            ..lineTo(pent(22, i).dx, pent(22, i).dy);
        }
      case DieShape.d4:
        face = _soft([p(50, 6), p(95, 88), p(5, 88)], r * 1.1);
        facets
          ..moveTo(10 * s, 86 * s)
          ..lineTo(50 * s, 64 * s)
          ..lineTo(90 * s, 86 * s)
          ..moveTo(50 * s, 12 * s)
          ..lineTo(50 * s, 64 * s);
      case DieShape.d20:
        face = _soft([p(50, 4), p(92, 28), p(92, 72), p(50, 96), p(8, 72), p(8, 28)], r);
        facets.addPath(_soft([p(50, 26), p(74, 66), p(26, 66)], r * .6), Offset.zero);
        facets
          ..moveTo(50 * s, 8 * s)
          ..lineTo(50 * s, 26 * s)
          ..moveTo(88 * s, 30 * s)
          ..lineTo(74 * s, 66 * s)
          ..moveTo(12 * s, 30 * s)
          ..lineTo(26 * s, 66 * s);
      case DieShape.d100:
        back = _soft(kite10(14, -8, .84), r * .7);
        face = _soft(kite10(-4, 6, .9), r * .8);
        facets
          ..moveTo(9 * s, 50 * s)
          ..lineTo(46 * s, 57 * s)
          ..lineTo(88 * s, 50 * s);
    }
    if (back != null) {
      canvas.drawPath(back, Paint()..color = mixColor(accent, dim ? .06 : .12, cont));
      canvas.drawPath(
          back,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, 3 * s)
            ..strokeJoin = StrokeJoin.round
            ..color = accent.withValues(alpha: dim ? .25 : .6));
    }
    final a = dim ? accent.withValues(alpha: .4) : accent;
    final bounds = Offset.zero & size;
    // Under-glow on a natural maximum.
    if (glow > 0) {
      canvas.drawPath(face, Paint()
        ..color = accent.withValues(alpha: .5 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * s));
    }
    canvas.drawPath(
        face,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.45, -.55),
            radius: 1.1,
            colors: [mixColor(accent, dim ? .18 : .4 + .2 * glow, cont), mixColor(accent, dim ? .06 : .14, cont)],
          ).createShader(bounds));
    canvas.drawPath(
        face,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, 3.6 * s)
          ..strokeJoin = StrokeJoin.round
          ..color = a);
    canvas.drawPath(
        facets,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, 2 * s)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = a.withValues(alpha: .32));
  }

  @override
  bool shouldRepaint(_DiePainter old) =>
      old.shape != shape || old.accent != accent || old.dim != dim || old.cont != cont || old.glow != glow;
}

/// A result that lifts off the element it came from: `+6`.
void floatUp(BuildContext context, String text, Color color) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.maybeOf(context);
  if (box == null || overlay == null) return;
  final at = box.localToGlobal(Offset(box.size.width / 2, 0));
  late OverlayEntry entry;
  entry = OverlayEntry(
      builder: (context) => _FloatUp(
          at: at, text: text, color: color, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _FloatUp extends StatefulWidget {
  const _FloatUp(
      {required this.at,
      required this.text,
      required this.color,
      required this.onDone});
  final Offset at;
  final String text;
  final Color color;
  final VoidCallback onDone;
  @override
  State<_FloatUp> createState() => _FloatUpState();
}

class _FloatUpState extends State<_FloatUp>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeOutCubic.transform(_c.value);
          final opacity =
              _c.value < .22 ? _c.value / .22 : 1 - (_c.value - .22) / .78;
          return Positioned(
            left: widget.at.dx - 60,
            width: 120,
            top: widget.at.dy - 64 * v,
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(widget.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                          shadows: const [
                            Shadow(
                                blurRadius: 18,
                                color: Colors.black54,
                                offset: Offset(0, 6))
                          ])),
                ),
              ),
            ),
          );
        },
      );
}

/// A number typed on a keypad, like the HP keypad of Overview.
Future<int?> showNumberKeypad(BuildContext context,
    {required String title, String? kicker, String? action}) {
  return showCompanionSheet<int>(context,
      builder: (_) =>
          _NumberKeypad(title: title, kicker: kicker, action: action));
}

class _NumberKeypad extends StatefulWidget {
  const _NumberKeypad({required this.title, this.kicker, this.action});
  final String title;
  final String? kicker, action;
  @override
  State<_NumberKeypad> createState() => _NumberKeypadState();
}

class _NumberKeypadState extends State<_NumberKeypad> {
  int _value = 0;
  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == 'del') {
        _value ~/= 10;
      } else {
        _value = math.min(999, int.parse('$_value$k'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final ru = instrumentRu(context);
    Widget key(String k) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Pressable(
              onTap: () => _key(k),
              scale: .94,
              semanticLabel: k == 'del' ? (ru ? 'Стереть' : 'Erase') : k,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                child: k == 'del'
                    ? LineIcon('del', size: 24, color: c.onSurface)
                    : Text(k,
                        style: AppType.numeric(t.textTheme.titleLarge).copyWith(
                            fontSize: 22, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.kicker != null) ...[
        Text(widget.kicker!,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.secondary)),
        const SizedBox(height: 8),
      ],
      SheetHeading(widget.title),
      const SizedBox(height: 10),
      Center(
          child: RollingNumber(_value,
              style: hugeStyle(context).copyWith(fontSize: 64))),
      const SizedBox(height: 14),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', 'del'],
      ])
        Row(children: [
          for (final k in row)
            k.isEmpty ? const Expanded(child: SizedBox()) : key(k)
        ]),
      const SizedBox(height: 10),
      ToneButton(
        kind: ToneKind.primary,
        height: 54,
        expand: true,
        fontSize: 15,
        label: widget.action ?? (ru ? 'Готово' : 'Done'),
        onPressed: _value == 0
            ? null
            : () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, _value);
              },
      ),
    ]);
  }
}

/// A row of tiles with equal widths and gaps (`.two`, `.three`).
class TileRow extends StatelessWidget {
  const TileRow({super.key, required this.children, this.gap = 10});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ]
        ]),
      );
}

/// A badge of a state or a passive (`.rb`): glyph over a word; lights up.
class StateBadge extends StatelessWidget {
  const StateBadge(
      {super.key,
      required this.glyph,
      required this.label,
      required this.accent,
      this.on = false,
      this.pressed,
      this.onTap,
      this.peek,
      this.locked = false});
  final String glyph, label;
  final Color accent;
  final bool on, locked;
  final bool? pressed;
  final VoidCallback? onTap;
  final (String, String)? peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final active = pressed == true;
    final fg = active || on ? c.onSurface : c.onSurfaceVariant;
    Widget badge = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: active
            ? mixColor(accent, .26, c.surfaceContainer)
            : on
                ? accent.withValues(alpha: .18)
                : c.onSurface.withValues(alpha: .05),
        border: active
            ? Border.all(color: accent.withValues(alpha: .7), width: 1.5)
            : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InstrumentGlyph(locked ? 'lock' : glyph, size: 24, color: fg),
        const SizedBox(height: 6),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle(context, size: 12).copyWith(color: fg)),
      ]),
    );
    if (locked) badge = Opacity(opacity: .55, child: badge);
    if (onTap != null) {
      badge =
          Pressable(onTap: onTap, scale: .94, selected: pressed, child: badge);
    }
    if (peek != null) {
      badge =
          Peek(title: peek!.$1, text: peek!.$2, accent: accent, child: badge);
    }
    return badge;
  }
}

/// A switch row (`.swrow`, `.reck-t`).
class SwitchRow extends StatelessWidget {
  const SwitchRow(
      {super.key,
      required this.label,
      required this.value,
      required this.accent,
      this.glyph,
      this.onChanged,
      this.peek});
  final String label;
  final String? glyph;
  final bool value;
  final Color accent;
  final ValueChanged<bool>? onChanged;
  final (String, String)? peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget row = Pressable(
      scale: .98,
      selected: value,
      semanticLabel: label,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
            color: value
                ? accent.withValues(alpha: .14)
                : c.onSurface.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          if (glyph != null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(12)),
              child: InstrumentGlyph(glyph!, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(label, style: labelStyle(context))),
          _Switch(value: value, accent: accent),
        ]),
      ),
    );
    if (peek != null) {
      row = Peek(title: peek!.$1, text: peek!.$2, accent: accent, child: row);
    }
    return row;
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.accent});
  final bool value;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: value ? accent : c.surfaceContainerHigh),
      child: AnimatedAlign(
        duration: AppMotion.of(context, AppMotion.snappySettle),
        curve: AppMotion.snappyCurve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? c.surface : c.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Plays a one-shot pulse (`.ev`, `.flare`) when [trigger] changes.
class Pulse extends StatefulWidget {
  const Pulse(
      {super.key,
      required this.trigger,
      required this.child,
      this.scale = 1.025});
  final Object? trigger;
  final double scale;
  final Widget child;
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 640));
  @override
  void didUpdateWidget(covariant Pulse old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final v = _c.value;
          final s = v == 0
              ? 1.0
              : 1 +
                  (widget.scale - 1) * math.sin(math.min(1, v * 1.4) * math.pi);
          return Transform.scale(scale: s, child: child);
        },
        child: widget.child,
      );
}

/// The localized subclass of a class the hero has, if any.
String? subclassDisplayName(Character hero, String classId, String locale) {
  final owner = CharacterClassContext(hero, classId);
  final raw = owner.subclass;
  if (raw == null || raw.trim().isEmpty) return null;
  final data = owner.definition;
  if (data == null) return raw;
  final nid = raw.toLowerCase().trim();
  final match = data.subclasses
      .where((s) =>
          s.id == nid || s.name.values.any((v) => v.toLowerCase() == nid))
      .firstOrNull;
  return match?.getName(locale) ?? raw;
}
