import '../../../core/ui/expressive_hold_surface.dart';
import '../../../shared/widgets/advancement_history_sheet.dart';
import '../../../core/progression/character_class_context.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/services/character_data_service.dart';
import '../../character_level_up/level_up_screen.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class ExpandableCharacterCard extends StatefulWidget {
  final Character character;
  final bool isExpanded;
  final VoidCallback onDicePressed;
  final ValueChanged<bool>? onDetailsToggled;
  final VoidCallback? onCharacterUpdated;
  final double scrollProgress;

  const ExpandableCharacterCard({
    super.key,
    required this.character,
    required this.isExpanded,
    required this.onDicePressed,
    this.onDetailsToggled,
    this.onCharacterUpdated,
    this.scrollProgress = 0,
  });

  @override
  State<ExpandableCharacterCard> createState() =>
      _ExpandableCharacterCardState();
}

class _ExpandableCharacterCardState extends State<ExpandableCharacterCard>
    with SingleTickerProviderStateMixin {
  bool _scrollChanged = false;
  late final AnimationController _details = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
      value: widget.isExpanded ? 1 : 0);
  late final CurvedAnimation _reveal = CurvedAnimation(
      parent: _details,
      curve: AppMotion.standard,
      reverseCurve: Curves.easeInOutCubic);

  @override
  void didUpdateWidget(covariant ExpandableCharacterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollChanged = oldWidget.scrollProgress != widget.scrollProgress;
    if (oldWidget.isExpanded != widget.isExpanded) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _details.value = widget.isExpanded ? 1 : 0;
      } else if (widget.isExpanded) {
        _details.forward();
      } else {
        _details.reverse();
      }
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _details.dispose();
    super.dispose();
  }

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

  Widget _identityFooter(BuildContext context, String className,
          String? subclass, AppLocalizations l10n) =>
      LayoutBuilder(builder: (context, bounds) {
        final t = Theme.of(context), c = t.colorScheme;
        final identity =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(className,
              style: t.textTheme.titleMedium
                  ?.copyWith(color: c.onSurface, fontWeight: FontWeight.w700)),
          if (subclass != null) ...[
            const SizedBox(height: 3),
            Text(subclass,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    t.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant))
          ],
        ]);
        final level = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bounds.maxWidth),
            child: Material(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                child: ExpressiveHoldSurface(
                    key: const ValueKey('character-level-control'),
                    semanticLabel:
                        '${l10n.levelShort} ${widget.character.level}',
                    hint: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'Удерживай для истории повышений'
                        : 'Hold for level-up history',
                    onTap: widget.character.level < 20
                        ? _openLevelUpWizard
                        : _openAdvancementHistory,
                    onHold: _openAdvancementHistory,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (widget.character.level < 20) ...[
                            Icon(Icons.keyboard_double_arrow_up_rounded,
                                size: 16, color: c.secondary),
                            const SizedBox(width: 4)
                          ],
                          Flexible(
                              child: Text(
                                  '${l10n.levelShort} ${widget.character.level}',
                                  style: t.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: c.secondary))),
                        ])))));
        if (bounds.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.35) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: level)
              ]);
        }
        return Row(children: [
          Expanded(child: identity),
          const SizedBox(width: 12),
          level
        ]);
      });

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasPersonalityData = widget.character.personalityTraits != null ||
        widget.character.ideals != null ||
        widget.character.bonds != null ||
        widget.character.flaws != null ||
        widget.character.backstory != null ||
        widget.character.age != null;

    final identityLocale = Localizations.localeOf(context).languageCode;
    final localizedClassName = widget.character.classes.map((entry) {
      final owner = CharacterClassContext(widget.character, entry.id);
      return '${owner.name(identityLocale)}${widget.character.classes.length > 1 ? ' ${entry.level}' : ''}';
    }).join(' / ');
    final subclasses = widget.character.classes
        .map((entry) => CharacterClassContext(widget.character, entry.id)
            .subclassName(identityLocale))
        .whereType<String>()
        .toList();
    final localizedSubclass =
        subclasses.isEmpty ? null : subclasses.join(' / ');

    final isHC = MediaQuery.highContrastOf(context);
    final scroll = MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : widget.scrollProgress.clamp(0.0, 1.0);
    final locale = Localizations.localeOf(context).languageCode;
    final raceName = CharacterDataService.getRaceById(widget.character.race)
            ?.getName(locale) ??
        widget.character.race;
    final t = Theme.of(context);

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) || _scrollChanged
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: AppMotion.standard,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                  colorScheme.secondaryContainer, colorScheme.surface, .08)!,
              colorScheme.secondaryContainer
            ]),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(36 - scroll * 6),
            topRight: Radius.circular(24 + scroll * 4),
            bottomLeft: Radius.circular(widget.isExpanded ? 28 : 24),
            bottomRight: Radius.circular(36 - scroll * 4)),
        boxShadow: isHC
            ? []
            : [
                BoxShadow(
                  color: colorScheme.secondary
                      .withValues(alpha: 0.15), // Soft glow
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
        border: Border.all(
          color: isHC
              ? colorScheme.primary
              : colorScheme.surface.withValues(
                  alpha: Theme.of(context).brightness == Brightness.light
                      ? .7
                      : .16),
          width: isHC ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Hero(
                          tag: 'character-avatar-${widget.character.id}',
                          child: Transform.scale(
                              scale: 1 - scroll * .035,
                              child: AnimatedContainer(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 280),
                                  curve: AppMotion.standard,
                                  width: widget.isExpanded ? 92 : 84,
                                  height: widget.isExpanded ? 92 : 84,
                                  decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(AppRadii.xl),
                                          topRight: Radius.circular(
                                              widget.isExpanded ? 28 : 18),
                                          bottomLeft: const Radius.circular(AppRadii.lgPlus),
                                          bottomRight:
                                              const Radius.circular(AppRadii.xl)),
                                      border: Border.all(
                                          color: colorScheme.surface
                                              .withValues(alpha: .75),
                                          width: 1),
                                      boxShadow: isHC
                                          ? []
                                          : [
                                              BoxShadow(
                                                  color: colorScheme.shadow
                                                      .withValues(alpha: .07),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4))
                                            ]),
                                  clipBehavior: Clip.antiAlias,
                                  child: widget.character.avatarPath != null
                                      ? Image.file(
                                          File(widget.character.avatarPath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) =>
                                              Icon(_getClassIcon(widget.character.characterClass),
                                                  size: 38,
                                                  color: colorScheme.secondary))
                                      : Icon(
                                          _getClassIcon(widget.character.characterClass),
                                          size: 38,
                                          color: colorScheme.secondary)))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 40),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(raceName,
                                        style: t.textTheme.labelMedium
                                            ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 7),
                                    Text(widget.character.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.textTheme.headlineMedium
                                            ?.copyWith(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -.85,
                                                height: 1.08,
                                                color: colorScheme.onSurface)),
                                  ]))),
                    ])),
            Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                    tooltip: l10n.rollDie(20),
                    onPressed: widget.onDicePressed,
                    icon: const Icon(Icons.casino_outlined, size: 23),
                    style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        foregroundColor: colorScheme.secondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17))))),
          ]),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                  child: _identityFooter(
                      context, localizedClassName, localizedSubclass, l10n))),

          // Expandable Trigger
          if (hasPersonalityData)
            InkWell(
              onTap: () {
                widget.onDetailsToggled?.call(!widget.isExpanded);
              },
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadii.lgPlus),
                bottomRight: Radius.circular(AppRadii.lgPlus),
              ),
              child: Column(
                children: [
                  Divider(
                      height: 1,
                      color: colorScheme.onSecondaryContainer
                          .withValues(alpha: 0.1)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RotationTransition(
                        turns:
                            Tween<double>(begin: 0, end: .5).animate(_reveal),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          semanticLabel:
                              Localizations.localeOf(context).languageCode ==
                                      'ru'
                                  ? (widget.isExpanded
                                      ? 'Свернуть описание'
                                      : 'О персонаже')
                                  : (widget.isExpanded
                                      ? 'Collapse details'
                                      : 'About the character'),
                          size: 20,
                          color: colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.5),
                        )),
                  ),
                ],
              ),
            ),

          // Animated Details Section
          SizeTransition(
            key: const ValueKey('character-details-reveal'),
            alignment: Alignment.topCenter,
            sizeFactor: _reveal,
            child: FadeTransition(
                opacity: _reveal,
                child: hasPersonalityData
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(AppRadii.lgPlus),
                            bottomRight: Radius.circular(AppRadii.lgPlus),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.character.age != null ||
                                widget.character.gender != null ||
                                widget.character.height != null ||
                                widget.character.weight != null ||
                                widget.character.eyes != null ||
                                widget.character.hair != null ||
                                widget.character.skin != null) ...[
                              _buildSectionTitle(
                                  l10n.physicalAppearance, Icons.face),
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
                              if (widget.character.appearanceDescription !=
                                  null) ...[
                                const SizedBox(height: 8),
                                Text(widget.character.appearanceDescription!,
                                    style: TextStyle(
                                        color: colorScheme.onSecondaryContainer
                                            .withValues(alpha: 0.9),
                                        fontSize: 13)),
                              ],
                              const SizedBox(height: 16),
                            ],
                            if (widget.character.personalityTraits != null) ...[
                              _buildSectionTitle(l10n.traits, Icons.psychology),
                              const SizedBox(height: 4),
                              Text(widget.character.personalityTraits!,
                                  style: TextStyle(
                                      color: colorScheme.onSecondaryContainer
                                          .withValues(alpha: 0.9),
                                      fontSize: 13)),
                              const SizedBox(height: 12)
                            ],
                            if (widget.character.ideals != null) ...[
                              _buildSectionTitle(
                                  l10n.ideals, Icons.star_outline),
                              const SizedBox(height: 4),
                              Text(widget.character.ideals!,
                                  style: TextStyle(
                                      color: colorScheme.onSecondaryContainer
                                          .withValues(alpha: 0.9),
                                      fontSize: 13)),
                              const SizedBox(height: 12)
                            ],
                            if (widget.character.bonds != null) ...[
                              _buildSectionTitle(
                                  l10n.bonds, Icons.favorite_outline),
                              const SizedBox(height: 4),
                              Text(widget.character.bonds!,
                                  style: TextStyle(
                                      color: colorScheme.onSecondaryContainer
                                          .withValues(alpha: 0.9),
                                      fontSize: 13)),
                              const SizedBox(height: 12)
                            ],
                            if (widget.character.flaws != null) ...[
                              _buildSectionTitle(
                                  l10n.flaws, Icons.warning_amber_outlined),
                              const SizedBox(height: 4),
                              Text(widget.character.flaws!,
                                  style: TextStyle(
                                      color: colorScheme.onSecondaryContainer
                                          .withValues(alpha: 0.9),
                                      fontSize: 13)),
                              const SizedBox(height: 12)
                            ],
                            if (widget.character.backstory != null) ...[
                              _buildSectionTitle(
                                  l10n.backstory, Icons.auto_stories),
                              const SizedBox(height: 4),
                              Text(widget.character.backstory!,
                                  style: TextStyle(
                                      color: colorScheme.onSecondaryContainer
                                          .withValues(alpha: 0.9),
                                      fontSize: 13))
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink()),
          ),
        ],
      ),
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
        Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colorScheme.onSecondaryContainer)),
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
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500)),
    );
  }

  IconData _getClassIcon(String className) {
    final lowerClass = className.toLowerCase();
    if (lowerClass.contains('paladin')) return Icons.shield;
    if (lowerClass.contains('wizard')) return Icons.auto_fix_high;
    if (lowerClass.contains('fighter')) return Icons.sports_martial_arts;
    if (lowerClass.contains('rogue')) return Icons.visibility_off;
    if (lowerClass.contains('cleric')) return Icons.health_and_safety;
    if (lowerClass.contains('barbarian')) return Icons.fitness_center;
    if (lowerClass.contains('bard')) return Icons.music_note;
    if (lowerClass.contains('druid')) return Icons.pets;
    if (lowerClass.contains('monk')) return Icons.self_improvement;
    if (lowerClass.contains('ranger')) return Icons.terrain;
    if (lowerClass.contains('sorcerer')) return Icons.bolt;
    if (lowerClass.contains('warlock')) return Icons.dark_mode;
    return Icons.person;
  }
}
