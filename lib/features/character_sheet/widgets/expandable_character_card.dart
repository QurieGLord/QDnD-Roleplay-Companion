import '../../../core/ui/expressive_hold_surface.dart';
import '../../../shared/widgets/advancement_history_sheet.dart';
import '../../../core/progression/character_class_context.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/services/character_data_service.dart';
import '../../character_level_up/level_up_screen.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../core/ui/companion_kit.dart';

/// The hero's header on the sheet, as in the prototype: class light behind
/// the hero, avatar and name, the class story, then the level with its next
/// step and the dice. Tapping the hero opens what is known about them.
class ExpandableCharacterCard extends StatefulWidget {
  final Character character;
  final VoidCallback onDicePressed;
  final VoidCallback? onCharacterUpdated;

  const ExpandableCharacterCard({
    super.key,
    required this.character,
    required this.onDicePressed,
    this.onCharacterUpdated,
  });

  @override
  State<ExpandableCharacterCard> createState() =>
      _ExpandableCharacterCardState();
}

class _ExpandableCharacterCardState extends State<ExpandableCharacterCard> {
  void _openLevelUpWizard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LevelUpScreen(character: widget.character),
      ),
    );

    if (result == true && mounted) {
      _refreshCharacter();
    }
  }

  String _getLocalizedValue(AppLocalizations l10n, String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'male':
        return l10n.genderMale;
      case 'female':
        return l10n.genderFemale;
      case 'other':
        return l10n.genderOther;
      case 'amber':
        return l10n.colorAmber;
      case 'blue':
        return l10n.colorBlue;
      case 'brown':
        return l10n.colorBrown;
      case 'gray':
        return l10n.colorGray;
      case 'green':
        return l10n.colorGreen;
      case 'hazel':
        return l10n.colorHazel;
      case 'red':
        return l10n.colorRed;
      case 'violet':
        return l10n.colorViolet;
      case 'auburn':
        return l10n.colorAuburn;
      case 'black':
        return l10n.colorBlack;
      case 'blonde':
        return l10n.colorBlonde;
      case 'white':
        return l10n.colorWhite;
      case 'bald':
        return l10n.colorBald;
      case 'pale':
        return l10n.skinPale;
      case 'fair':
        return l10n.skinFair;
      case 'light':
        return l10n.skinLight;
      case 'medium':
        return l10n.skinMedium;
      case 'tan':
        return l10n.skinTan;
      case 'dark':
        return l10n.skinDark;
      case 'ebony':
        return l10n.skinEbony;
      default:
        return value;
    }
  }

  String _formatValue(AppLocalizations l10n, String? value) {
    if (value == null) return '';
    var result = value.trim();
    if (result.endsWith('cm')) {
      result = result.replaceAll('cm', ' ${l10n.unitCm}');
    } else if (result.endsWith('kg')) {
      result = result.replaceAll('kg', ' ${l10n.unitKg}');
    } else if (result.endsWith('years')) {
      result = result.replaceAll('years', ' ${l10n.ageYears}');
    } else if (result.endsWith('lb') || result.endsWith('lbs')) {
      result = result.replaceAll(RegExp(r'lbs?'), ' ${l10n.weightUnit}');
    } else if (result.endsWith('ft')) {
      result = result.replaceAll('ft', ' ${l10n.unitCm}');
    }
    return result;
  }

  bool get _hasPersonality =>
      widget.character.personalityTraits != null ||
      widget.character.ideals != null ||
      widget.character.bonds != null ||
      widget.character.flaws != null ||
      widget.character.backstory != null ||
      widget.character.age != null;

  void _openAbout() {
    final l10n = AppLocalizations.of(context)!;
    showCompanionSheet<void>(context,
        builder: (context) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SheetHeading(widget.character.name, subtitle: l10n.heroAbout),
              const SizedBox(height: 14),
              _details(context),
            ]));
  }

  Widget _details(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.character.age != null ||
            widget.character.gender != null ||
            widget.character.height != null ||
            widget.character.weight != null ||
            widget.character.eyes != null ||
            widget.character.hair != null ||
            widget.character.skin != null) ...[
          _buildSectionTitle(l10n.physicalAppearance, Icons.face),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.character.age != null)
                _buildInfoChip(
                    '${l10n.age}: ${_formatValue(l10n, widget.character.age)}'),
              if (widget.character.gender != null)
                _buildInfoChip(
                    '${l10n.gender}: ${_getLocalizedValue(l10n, widget.character.gender!)}'),
              if (widget.character.height != null)
                _buildInfoChip(
                    '${l10n.height}: ${_formatValue(l10n, widget.character.height)}'),
              if (widget.character.weight != null)
                _buildInfoChip(
                    '${l10n.weight}: ${_formatValue(l10n, widget.character.weight)}'),
              if (widget.character.eyes != null)
                _buildInfoChip(
                    '${l10n.eyes}: ${_getLocalizedValue(l10n, widget.character.eyes!)}'),
              if (widget.character.hair != null)
                _buildInfoChip(
                    '${l10n.hair}: ${_getLocalizedValue(l10n, widget.character.hair!)}'),
              if (widget.character.skin != null)
                _buildInfoChip(
                    '${l10n.skin}: ${_getLocalizedValue(l10n, widget.character.skin!)}'),
            ],
          ),
          if (widget.character.appearanceDescription != null) ...[
            const SizedBox(height: 8),
            Text(widget.character.appearanceDescription!,
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                    fontSize: 13)),
          ],
          const SizedBox(height: 16),
        ],
        if (widget.character.personalityTraits != null) ...[
          _buildSectionTitle(l10n.traits, Icons.psychology),
          const SizedBox(height: 4),
          Text(widget.character.personalityTraits!,
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.9),
                  fontSize: 13)),
          const SizedBox(height: 12)
        ],
        if (widget.character.ideals != null) ...[
          _buildSectionTitle(l10n.ideals, Icons.star_outline),
          const SizedBox(height: 4),
          Text(widget.character.ideals!,
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.9),
                  fontSize: 13)),
          const SizedBox(height: 12)
        ],
        if (widget.character.bonds != null) ...[
          _buildSectionTitle(l10n.bonds, Icons.favorite_outline),
          const SizedBox(height: 4),
          Text(widget.character.bonds!,
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.9),
                  fontSize: 13)),
          const SizedBox(height: 12)
        ],
        if (widget.character.flaws != null) ...[
          _buildSectionTitle(l10n.flaws, Icons.warning_amber_outlined),
          const SizedBox(height: 4),
          Text(widget.character.flaws!,
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.9),
                  fontSize: 13)),
          const SizedBox(height: 12)
        ],
        if (widget.character.backstory != null) ...[
          _buildSectionTitle(l10n.backstory, Icons.auto_stories),
          const SizedBox(height: 4),
          Text(widget.character.backstory!,
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.9),
                  fontSize: 13))
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accents = AppAccents.of(context);
    final classes = widget.character.classes;
    final first = accents.forClass(
        classes.isEmpty ? widget.character.characterClass : classes.first.id);
    final second = classes.length > 1 ? accents.forClass(classes[1].id) : null;
    final identity = Row(children: [
      Hero(
          tag: 'character-avatar-${widget.character.id}',
          child: _avatar(Theme.of(context).colorScheme, first)),
      const SizedBox(width: 16),
      Expanded(child: _identity(context, accents)),
    ]);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Class light behind the hero; it may spill upwards under the
        // compact bar, as the prototype's header reaches the screen top.
        Positioned(
          left: 0,
          right: 0,
          top: -64,
          bottom: 0,
          child: IgnorePointer(
            child:
                CustomPaint(painter: _ClassLight(first, second, topSpill: 64)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasPersonality)
                  Semantics(
                    button: true,
                    hint: l10n.heroAbout,
                    child: GestureDetector(
                      key: const ValueKey('character-about'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _openAbout,
                      child: identity,
                    ),
                  )
                else
                  identity,
                const SizedBox(height: 16),
                _actions(context, l10n, first),
              ]),
        ),
      ],
    );
  }

  Widget _avatar(ColorScheme c, Color accent) {
    final glyph = Center(
        child: LineIcon(LineIcon.forClass(widget.character.characterClass),
            size: 34, color: accent));
    return Container(
        width: 72,
        height: 72,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: Color.alphaBlend(
                accent.withValues(alpha: .18), c.surfaceContainer),
            borderRadius: BorderRadius.circular(22)),
        child: widget.character.avatarPath != null
            ? Image.file(File(widget.character.avatarPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => glyph)
            : glyph);
  }

  /// Name, then the class story: one class reads as a line, a multiclass
  /// hero gets a chip per class with its own colour and level.
  Widget _identity(BuildContext context, AppAccents accents) {
    final t = Theme.of(context), c = t.colorScheme;
    final hero = widget.character;
    final locale = Localizations.localeOf(context).languageCode;
    final raceName =
        CharacterDataService.getRaceById(hero.race)?.getName(locale) ??
            hero.race;
    final subclasses = hero.classes
        .map((entry) =>
            CharacterClassContext(hero, entry.id).subclassName(locale))
        .whereType<String>()
        .toList();
    final muted = t.textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hero.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.headlineMedium?.copyWith(
                  fontFamily: AppType.display,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  height: 1.08,
                  letterSpacing: -.75,
                  color: c.onSurface)),
          const SizedBox(height: 6),
          if (hero.classes.length > 1) ...[
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final entry in hero.classes)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      color: c.onSurface.withValues(alpha: .07)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accents.forClass(entry.id))),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text:
                                    '${CharacterClassContext(hero, entry.id).name(locale)} '),
                            TextSpan(
                                text: '${entry.level}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                          ]),
                          style: t.textTheme.labelLarge),
                    ),
                  ]),
                ),
            ]),
            if (subclasses.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subclasses.join(' · '),
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
            ],
          ] else
            Text(
                [
                  raceName,
                  for (final entry in hero.classes)
                    CharacterClassContext(hero, entry.id).name(locale),
                  ...subclasses,
                ].join(' · '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: muted),
        ]);
  }

  /// Level with its next step under the thumb, and the dice beside it.
  Widget _actions(BuildContext context, AppLocalizations l10n, Color accent) {
    final t = Theme.of(context), c = t.colorScheme;
    final hero = widget.character;
    final canRise = hero.level < 20;
    final note = !canRise
        ? l10n.heroLevelHistory
        : hero.classes.length > 1
            ? l10n.heroLevelSum
            : l10n.heroLevelRaise;
    final level = Material(
      color: Color.alphaBlend(
          accent.withValues(alpha: .15), c.onSurface.withValues(alpha: .04)),
      borderRadius: BorderRadius.circular(22),
      child: ExpressiveHoldSurface(
        key: const ValueKey('character-level-control'),
        semanticLabel: '${l10n.levelShort} ${hero.level}',
        hint: l10n.heroHoldHistory,
        onTap: canRise ? _openLevelUpWizard : _openAdvancementHistory,
        onHold: _openAdvancementHistory,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: .26),
                  borderRadius: BorderRadius.circular(14)),
              child: Text('${hero.level}',
                  style: AppType.numeric(t.textTheme.titleLarge)
                      .copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.heroLevelTitle(hero.level),
                        style: t.textTheme.titleSmall?.copyWith(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    Text(note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall?.copyWith(
                            fontSize: 12, color: c.onSurfaceVariant)),
                  ]),
            ),
            canRise
                ? LineIcon('up', size: 20, color: accent)
                : Icon(Icons.history_rounded, size: 20, color: accent),
          ]),
        ),
      ),
    );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: level),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: IconButton(
            tooltip: l10n.diceRoller,
            onPressed: widget.onDicePressed,
            icon: LineIcon('dice', size: 22, color: c.onSurface),
            style: IconButton.styleFrom(
                backgroundColor: c.onSurface.withValues(alpha: .07),
                foregroundColor: c.onSurface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22))),
          ),
        ),
      ]),
    );
  }

  Future<void> _openAdvancementHistory() async {
    final changed = await showAdvancementHistory(context, widget.character);
    if (changed == true && mounted) _refreshCharacter();
  }

  void _refreshCharacter() {
    setState(() {});
    widget.onCharacterUpdated?.call();
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurface),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildInfoChip(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500)),
    );
  }
}

/// The prototype's `.flow` light: a soft ellipse of the class colour at the
/// top right, and for a multiclass hero a second one at the bottom left.
class _ClassLight extends CustomPainter {
  const _ClassLight(this.first, this.second, {required this.topSpill});
  final Color first;
  final Color? second;
  final double topSpill;

  void _glow(Canvas canvas, Offset center, double rx, double ry, Color color,
      double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(rx, ry);
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: .3 * .6),
        color.withValues(alpha: 0),
      ], stops: const [
        0,
        .7
      ]).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height - topSpill;
    const tilt = -12 * 3.14159265 / 180;
    _glow(canvas, Offset(.75 * w, topSpill + .2 * h), .45 * w, .8 * h, first,
        tilt);
    if (second != null) {
      _glow(canvas, Offset(.1 * w, topSpill + .95 * h), .4 * w, .75 * h,
          second!, tilt);
    }
  }

  @override
  bool shouldRepaint(_ClassLight old) =>
      old.first != first || old.second != second;
}
