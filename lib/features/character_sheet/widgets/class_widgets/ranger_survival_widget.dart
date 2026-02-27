import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/constants/ranger_options.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../core/services/spell_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../../../../shared/widgets/spell_details_sheet.dart';

class RangerSurvivalWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? primevalAwareness;
  final VoidCallback? onChanged;

  const RangerSurvivalWidget({
    super.key,
    required this.character,
    this.primevalAwareness,
    this.onChanged,
  });

  @override
  State<RangerSurvivalWidget> createState() => _RangerSurvivalWidgetState();
}

class _RangerSurvivalWidgetState extends State<RangerSurvivalWidget> {
  late TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    _targetController =
        TextEditingController(text: widget.character.huntersMarkTarget ?? '');
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  List<CharacterFeature> _getHunterTactics() {
    final keywords = [
      'colossus',
      'horde',
      'giant',
      'escape the horde',
      'multiattack defense',
      'steel will',
      'volley',
      'whirlwind',
      'evasion',
      'stand against',
      'uncanny dodge',
      'колосс',
      'орд',
      'великанов',
      'побег',
      'защита от мульти',
      'стальная',
      'залп',
      'вихрев',
      'увертлив',
      'стойкость против',
      'невероятное уклонение'
    ];

    return widget.character.features.where((f) {
      final id = f.id?.toLowerCase() ?? '';
      final name = f.nameEn.toLowerCase();
      final nameRu = f.nameRu?.toLowerCase() ?? '';
      return keywords.any((k) =>
          id.contains(k.replaceAll(' ', '-')) ||
          id.contains(k.replaceAll(' ', '_')) ||
          name.contains(k) ||
          nameRu.contains(k));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;
    final blockBg = colorScheme.surfaceContainerHighest;
    final greenAccent = colorScheme.primary;

    final List<Widget> blocks = [];

    // --- БЛОК А: АРХЕТИП ОХОТНИКА (Hunter's Identity) ---
    final isHunter = widget.character.subclass?.toLowerCase() == 'hunter' ||
        widget.character.subclass?.toLowerCase() == 'охотник';
    if (isHunter) {
      blocks
          .add(_buildHunterArchetypeBlock(context, colorScheme, locale, l10n));
    }

    // --- БЛОК Б: ТРЕКЕР "МЕТКИ ОХОТНИКА" ---
    final knowsHuntersMark =
        widget.character.knownSpells.contains('hunters_mark') ||
            widget.character.knownSpells.contains('hunters-mark');
    if (knowsHuntersMark) {
      blocks.add(_buildHuntersMarkBlock(context, colorScheme, locale, l10n));
    }

    // --- БЛОК В: ТУМБЛЕР "МАСКИРОВКА" (Hide in Plain Sight) ---
    final hasHideInPlainSight = widget.character.level >= 10 &&
        widget.character.features.any((f) =>
            f.id == 'hide-in-plain-sight' ||
            f.id == 'hide_in_plain_sight' ||
            (f.nameEn).toLowerCase().contains('hide in plain sight') ||
            (f.nameRu).toLowerCase().contains('маскировка'));
    if (hasHideInPlainSight) {
      blocks
          .add(_buildHideInPlainSightBlock(context, colorScheme, locale, l10n));
    }

    // --- СТАРЫЕ БЛОКИ ---
    if (widget.character.favoredEnemies.isNotEmpty ||
        widget.character.naturalExplorers.isNotEmpty) {
      blocks
          .add(_buildCoreFeaturesBlock(context, colorScheme, blockBg, locale));
    }

    if (widget.primevalAwareness != null) {
      blocks.add(_buildBlockContainer(
        color: blockBg,
        onTap: () => _showDetails(widget.primevalAwareness!),
        padding: const EdgeInsets.all(12),
        child: _buildPrimevalAwarenessContent(
            context, colorScheme, greenAccent, locale),
      ));
    }

    if (widget.character.beastName != null &&
        widget.character.beastName!.isNotEmpty) {
      blocks.add(AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        child: _buildBeastCompanionBlock(
            context, colorScheme, blockBg, greenAccent),
      ));
    }

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < blocks.length; i++) ...[
              blocks[i],
              if (i < blocks.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  // ===========================================================================
  // БЛОК А: АРХЕТИП ОХОТНИКА
  // ===========================================================================
  Widget _buildHunterArchetypeBlock(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    final selectedTactics = _getHunterTactics();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSubclassLore(context, colorScheme, locale, l10n),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.forest, color: colorScheme.primary, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.hunterArchetype,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            locale == 'ru' ? 'Охотник' : 'Hunter',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
              if (selectedTactics.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedTactics.map((tactic) {
                      return ActionChip(
                        avatar: Icon(Icons.military_tech,
                            size: 16, color: colorScheme.onPrimaryContainer),
                        label: Text(
                          tactic.getName(locale).isNotEmpty
                              ? tactic.getName(locale)
                              : tactic.id ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        backgroundColor: colorScheme.primaryContainer,
                        side: BorderSide(
                            color: colorScheme.primary.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showDetails(tactic),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSubclassLore(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
    HapticFeedback.lightImpact();

    final classData =
        CharacterDataService.getClassById(widget.character.characterClass);
    SubclassData? subclassData;

    if (classData != null && widget.character.subclass != null) {
      try {
        subclassData = classData.subclasses.firstWhere((s) {
          return s.name.values.any((val) => val == widget.character.subclass) ||
              s.id ==
                  widget.character.subclass!.toLowerCase().replaceAll(' ', '_');
        });
      } catch (_) {}
    }

    final description =
        subclassData?.getDescription(locale) ?? l10n.noFeaturesAtLevel1;
    final subclassDisplay = locale == 'ru' ? 'Охотник' : 'Hunter';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Icon(Icons.forest, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subclassDisplay,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // БЛОК Б: МЕТКА ОХОТНИКА (Hunter's Mark)
  // ===========================================================================
  Widget _buildHuntersMarkBlock(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
    final isActive = widget.character.isHuntersMarkActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primary.withOpacity(0.1)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.3),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final spell = SpellService.getSpellById('hunters_mark') ??
                SpellService.getSpellById('hunters-mark');
            if (spell != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                builder: (context) => SpellDetailsSheet(
                    spell: spell, character: widget.character),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.spellNotFound),
                backgroundColor: colorScheme.error,
              ));
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.huntersMarkTracker,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            l10n.markBonusDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive
                                  ? colorScheme.primary.withOpacity(0.8)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.info_outline,
                        size: 20,
                        color: isActive
                            ? colorScheme.primary.withOpacity(0.5)
                            : colorScheme.outline.withOpacity(0.5)),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: isActive
                      ? _buildHuntersMarkActiveState(
                          context, colorScheme, locale, l10n)
                      : _buildHuntersMarkInactiveState(
                          context, colorScheme, locale, l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHuntersMarkInactiveState(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.tonalIcon(
        onPressed: () =>
            _showActivateMarkDialog(context, colorScheme, locale, l10n),
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.markActivate),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildHuntersMarkActiveState(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _targetController,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: l10n.markTargetName,
              hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
              icon:
                  Icon(Icons.person_pin, color: colorScheme.primary, size: 20),
            ),
            onChanged: (val) {
              widget.character.huntersMarkTarget = val;
              widget.character.save();
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _targetController.clear();
                  widget.character.huntersMarkTarget = '';
                  widget.character.save();
                  setState(() {});
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.moveMark),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    widget.character.isHuntersMarkActive = false;
                    widget.character.huntersMarkTarget = '';
                    _targetController.clear();
                    widget.character.save();
                    widget.onChanged?.call();
                  });
                },
                icon: const Icon(Icons.close),
                label: Text(l10n.markDrop),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showActivateMarkDialog(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
    HapticFeedback.lightImpact();

    final availableLevels = <int>[];
    for (int i = 0; i < widget.character.spellSlots.length; i++) {
      if (widget.character.spellSlots[i] > 0) {
        availableLevels.add(i + 1);
      }
    }

    if (availableLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(locale == 'ru'
            ? 'Нет доступных ячеек заклинаний!'
            : 'No spell slots available!'),
        backgroundColor: colorScheme.error,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Icon(Icons.gps_fixed, color: colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.huntersMarkTracker)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.markSlotChoose,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.markDurationHint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: availableLevels.map((level) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                          color: colorScheme.tertiary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        widget.character.spellSlots[level - 1]--;
                        widget.character.isHuntersMarkActive = true;
                        widget.character.save();
                        widget.onChanged?.call();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(locale == 'ru'
                            ? 'Метка наложена (уровень $level)'
                            : 'Mark cast (Level $level)'),
                        backgroundColor: colorScheme.tertiaryContainer,
                        duration: const Duration(seconds: 2),
                      ));
                    },
                    child: Text(
                      locale == 'ru' ? 'Уровень $level' : 'Level $level',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // БЛОК В: МАСКИРОВКА (Hide in Plain Sight)
  // ===========================================================================
  Widget _buildHideInPlainSightBlock(BuildContext context,
      ColorScheme colorScheme, String locale, AppLocalizations l10n) {
    final isActive = widget.character.isHiddenInPlainSight;

    final feature = widget.character.features
            .where((f) =>
                f.id == 'hide-in-plain-sight' || f.id == 'hide_in_plain_sight')
            .firstOrNull ??
        FeatureService.getFeatureById('hide-in-plain-sight') ??
        CharacterFeature(
            id: 'hide-in-plain-sight',
            nameEn: 'Hide in Plain Sight',
            nameRu: 'Маскировка',
            descriptionEn: '',
            descriptionRu: '',
            type: FeatureType.action,
            minLevel: 10);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(feature),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.visibility_off : Icons.visibility,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.hideInPlainSight,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      if (isActive)
                        Text(
                          l10n.hideInPlainSightDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                colorScheme.onPrimaryContainer.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      widget.character.isHiddenInPlainSight = val;
                      widget.character.save();
                      widget.onChanged?.call();
                    });
                    if (val) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.hideSpentMinute),
                        backgroundColor: colorScheme.primaryContainer,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  activeColor: colorScheme.onPrimary,
                  activeTrackColor: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // СТАРЫЕ МЕТОДЫ (Оставлены для совместимости)
  // ===========================================================================

  Widget _buildBlockContainer({
    required Color color,
    required Widget child,
    required EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildCoreFeaturesBlock(BuildContext context, ColorScheme colorScheme,
      Color blockBg, String locale) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.character.favoredEnemies.isNotEmpty)
          Expanded(
            child: _buildIdentityCard(
              context,
              colorScheme,
              blockBg,
              locale,
              title: locale == 'ru' ? "Избранный враг" : "Favored Enemy",
              icon: Icons.gps_fixed,
              items: widget.character.favoredEnemies
                  .map((e) => RangerOptions.favoredEnemies[e]?[locale] ?? e)
                  .toList(),
              featureId: 'favored-enemy',
            ),
          ),
        if (widget.character.favoredEnemies.isNotEmpty &&
            widget.character.naturalExplorers.isNotEmpty)
          const SizedBox(width: 12),
        if (widget.character.naturalExplorers.isNotEmpty)
          Expanded(
            child: _buildIdentityCard(
              context,
              colorScheme,
              blockBg,
              locale,
              title: locale == 'ru' ? "Исследователь" : "Explorer",
              icon: Icons.terrain,
              items: widget.character.naturalExplorers
                  .map((e) => RangerOptions.naturalExplorers[e]?[locale] ?? e)
                  .toList(),
              featureId: 'natural-explorer',
            ),
          ),
      ],
    );
  }

  Widget _buildIdentityCard(BuildContext context, ColorScheme colorScheme,
      Color blockBg, String locale,
      {required String title,
      required IconData icon,
      required List<String> items,
      required String featureId}) {
    return Column(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              CharacterFeature feature;
              final found = widget.character.features
                  .where((f) =>
                      f.id != null &&
                      f.id!.contains(featureId.split('-').first))
                  .firstOrNull;
              if (found != null) {
                feature = found;
              } else {
                feature = FeatureService.getFeatureById(featureId) ??
                    CharacterFeature(
                        id: featureId,
                        nameEn: title,
                        nameRu: title,
                        descriptionEn: '',
                        descriptionRu: '',
                        type: FeatureType.passive,
                        minLevel: 1);
              }
              _showDetails(feature);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: colorScheme.onSecondaryContainer, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    items.join(', '),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSecondaryContainer.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimevalAwarenessContent(BuildContext context,
      ColorScheme colorScheme, Color accentColor, String locale) {
    final featureName =
        widget.primevalAwareness?.getName(locale).toUpperCase() ??
            'PRIMEVAL AWARENESS';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.radar, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                featureName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.info_outline,
                size: 16, color: colorScheme.outline.withOpacity(0.5)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _launchRadar(context, locale, colorScheme),
            icon: const Icon(Icons.radar, size: 18),
            label: Text(locale == 'ru' ? 'Запустить радар' : 'Launch Radar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  void _launchRadar(
      BuildContext context, String locale, ColorScheme colorScheme) {
    final availableLevels = <int>[];
    for (int i = 0; i < widget.character.spellSlots.length; i++) {
      if (widget.character.spellSlots[i] > 0) {
        availableLevels.add(i + 1);
      }
    }

    if (availableLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(locale == 'ru'
            ? 'Нет доступных ячеек заклинаний!'
            : 'No spell slots available!'),
        backgroundColor: colorScheme.error,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Icon(Icons.radar, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(locale == 'ru' ? 'Радар' : 'Radar')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              locale == 'ru'
                  ? 'Выберите уровень ячейки для списания (1 минута за уровень):'
                  : 'Choose a spell slot to expend (1 minute per level):',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: availableLevels.map((level) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        widget.character.spellSlots[level - 1]--;
                        widget.character.save();
                        widget.onChanged?.call();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(locale == 'ru'
                            ? 'Радар запущен на $level минут(ы)'
                            : 'Radar active for $level minute(s)'),
                        backgroundColor: colorScheme.primary,
                        duration: const Duration(seconds: 3),
                      ));
                    },
                    child: Text(
                      locale == 'ru' ? 'Уровень $level' : 'Level $level',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale == 'ru' ? 'Отмена' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildBeastCompanionBlock(BuildContext context,
      ColorScheme colorScheme, Color blockBg, Color accentColor) {
    final maxHp = widget.character.beastMaxHp ?? 1;
    final currentHp = widget.character.beastCurrentHp ?? 0;
    final progress = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    final barColor =
        Color.lerp(colorScheme.error, colorScheme.primary, progress) ??
            colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: blockBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.surface,
                child: Text(
                  widget.character.beastIcon ?? '🐺',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.character.beastName ?? 'Beast',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      'Companion HP',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '$currentHp / $maxHp',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 16,
                  backgroundColor: colorScheme.surfaceDim,
                  valueColor: AlwaysStoppedAnimation(barColor),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildHpButton(
                context,
                icon: Icons.remove,
                onTap: () => _modifyBeastHp(-1, maxHp),
                enabled: currentHp > 0,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _buildHpButton(
                context,
                icon: Icons.add,
                onTap: () => _modifyBeastHp(1, maxHp),
                enabled: currentHp < maxHp,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHpButton(BuildContext context,
      {required IconData icon,
      required VoidCallback onTap,
      required bool enabled,
      required ColorScheme colorScheme}) {
    return SizedBox(
      width: 48,
      height: 36,
      child: FilledButton.tonal(
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: colorScheme.surface,
          disabledBackgroundColor: colorScheme.surface.withOpacity(0.5),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  void _modifyBeastHp(int amount, int maxHp) {
    setState(() {
      int current = widget.character.beastCurrentHp ?? 0;
      current = (current + amount).clamp(0, maxHp);
      widget.character.beastCurrentHp = current;
      widget.character.save();
      widget.onChanged?.call();
    });
  }

  void _showDetails(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }
}
