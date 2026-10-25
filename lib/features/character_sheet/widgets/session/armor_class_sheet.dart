import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/models/armor_class_parts.dart';
import '../../../../core/models/character.dart';
import '../class_widgets/instrument/instrument_kit.dart' show InstrumentGlyph;
import 'value_editors.dart';

/// Shows what the armour class is made of; a pinned value keeps the
/// calculation visible beside it. Returns true when the value was changed.
Future<bool> showArmorClassBreakdown(
    BuildContext context, Character character) async {
  final edit = await showCompanionSheet<bool>(context,
      builder: (_) => _ArmorClassBreakdown(character: character));
  if (edit != true || !context.mounted) return false;
  return showArmorValueEditor(context, character);
}

class _ArmorClassBreakdown extends StatelessWidget {
  const _ArmorClassBreakdown({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final parts = armorClassParts(character);
    final calculated = character.calculatedArmorClass;
    final pinned = !character.usesAutomaticArmorClass;

    (String, String, String?) describe(ArmorClassPart part) =>
        switch (part.source) {
          ArmorClassSource.unarmored => (
              'person',
              l10n.acSourceUnarmored,
              null
            ),
          ArmorClassSource.armor => (
              'shield',
              part.item!.getName(locale),
              null
            ),
          ArmorClassSource.dexterity => (
              'run',
              l10n.abilityDex,
              part.cap == null ? null : l10n.acDexCap(part.cap!)
            ),
          ArmorClassSource.constitution => ('heart', l10n.abilityCon, null),
          ArmorClassSource.wisdom => ('lotus', l10n.abilityWis, null),
          ArmorClassSource.draconic => ('flame', l10n.acSourceDraconic, null),
          ArmorClassSource.shield => (
              'shield',
              part.item!.getName(locale),
              null
            ),
          ArmorClassSource.defense => ('sword', l10n.acSourceDefense, null),
        };
    final still = MediaQuery.disableAnimationsOf(context);
    final ru = locale == 'ru';
    const tones = [4, 3, 2, 1, 5, 0];
    // Layers lie from the bottom up and narrow towards the shield; each
    // rises in turn, then the shield is stamped with the total.
    Widget rise(int order, Widget child) => still
        ? child
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 460 + order * 110),
            curve: Interval(order * 110 / (460 + order * 110), 1,
                curve: AppMotion.snappyCurve),
            builder: (context, p, child) => Opacity(
                opacity: p.clamp(0.0, 1.0),
                child: Transform.translate(
                    offset: Offset(0, 18 * (1 - p)),
                    child:
                        Transform.scale(scaleX: .94 + .06 * p, child: child))),
            child: child);
    final plates = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final (icon, label, note) = describe(parts[i]);
      final v = parts[i].value;
      final accent = AppAccents.of(context).at(tones[i % tones.length]);
      plates.add(rise(
        i,
        FractionallySizedBox(
          widthFactor: (1 - i * .09).clamp(.55, 1.0),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  accent.withValues(alpha: .12), c.surfaceContainerLow),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: .30)),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(12)),
                child: InstrumentGlyph(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: AppType.body,
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w600)),
                      if (note != null)
                        Text(note,
                            style: TextStyle(
                                fontFamily: AppType.body,
                                fontSize: 11.5,
                                color: c.onSurfaceVariant)),
                    ]),
              ),
              Text(i > 0 && v >= 0 ? '+$v' : '$v',
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppType.tabular,
                      color: accent)),
            ]),
          ),
        ),
      ));
    }
    final a4 = AppAccents.of(context).at(4);
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final shield =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 112">'
        '<path d="M50 4 92 18v34c0 28-18 48-42 56C26 100 8 80 8 52V18z" '
        'fill="${hex(Color.alphaBlend(a4.withValues(alpha: .22), c.surfaceContainer))}" '
        'stroke="${hex(a4)}" stroke-width="3.5" stroke-linejoin="round"/></svg>';
    final stamp = TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: Duration(milliseconds: 520 + parts.length * 110),
      curve: Interval(parts.length * 110 / (520 + parts.length * 110), 1),
      builder: (context, p, child) {
        final scale =
            p < .6 ? 1.5 - .56 * (p / .6) : .94 + .06 * ((p - .6) / .4);
        return Opacity(
            opacity: (p / .3).clamp(0.0, 1.0),
            child: Transform.rotate(
                angle: (p < .6 ? -8 * (1 - p / .6) : 0) * 3.14159 / 180,
                child: Transform.scale(scale: scale, child: child)));
      },
      child: SizedBox(
        width: 112,
        height: 124,
        child: Stack(alignment: Alignment.center, children: [
          SvgPicture.string(shield, width: 112, height: 124),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${character.armorClass}',
                key: const ValueKey('ac-breakdown-total'),
                style: const TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.8,
                    fontFeatures: AppType.tabular)),
          ),
          Positioned(
            bottom: 26,
            child: Text(ru ? 'КД' : 'AC',
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: c.onSurfaceVariant)),
          ),
        ]),
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeading(l10n.armorClass,
          subtitle: ru
              ? 'Слои ложатся снизу вверх и сходятся в щит.'
              : 'Layers rest from the bottom up and meet in the shield.'),
      const SizedBox(height: 10),
      Center(child: stamp),
      const SizedBox(height: 6),
      ...plates.reversed,
      if (pinned) ...[
        const SizedBox(height: 10),
        Text(
            ru
                ? 'Расчёт по снаряжению: $calculated'
                : 'From equipment: $calculated',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: 12.5,
                color: c.onSurfaceVariant)),
      ],
      const SizedBox(height: 14),
      Text(
          pinned
              ? l10n.acPinned(character.armorClass, calculated)
              : l10n.acAutomaticNote,
          style: t.textTheme.bodyMedium
              ?.copyWith(fontSize: 13.5, color: c.onSurfaceVariant)),
      const SizedBox(height: 14),
      ToneButton(
        key: const ValueKey('ac-breakdown-edit'),
        height: 50,
        expand: true,
        label: pinned ? l10n.acEditPinned : l10n.acEditManual,
        onPressed: () => Navigator.pop(context, true),
      ),
    ]);
  }
}
