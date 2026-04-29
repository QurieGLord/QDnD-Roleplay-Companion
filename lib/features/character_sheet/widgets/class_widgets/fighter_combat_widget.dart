import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';

class FighterCombatWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? secondWindFeature;
  final CharacterFeature? actionSurgeFeature;
  final CharacterFeature? indomitableFeature;
  final VoidCallback? onChanged;

  const FighterCombatWidget({
    super.key,
    required this.character,
    this.secondWindFeature,
    this.actionSurgeFeature,
    this.indomitableFeature,
    this.onChanged,
  });

  @override
  State<FighterCombatWidget> createState() => _FighterCombatWidgetState();
}

class _FighterCombatWidgetState extends State<FighterCombatWidget> {
  void _useResource(CharacterFeature feature, {String? customMessage}) {
    final pool = feature.resourcePool!;
    if (pool.currentUses > 0) {
      HapticFeedback.mediumImpact();
      setState(() {
        pool.use(1);
        widget.character.save();
        widget.onChanged?.call();
      });

      final cleanName = feature
          .getName(Localizations.localeOf(context).languageCode)
          .replaceAll(RegExp(r'\s*\(.*?\)'), '');

      AppSnackBar.success(
        context,
        customMessage ??
            '$cleanName ${Localizations.localeOf(context).languageCode == 'ru' ? 'использовано!' : 'used!'}',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _useSecondWind() {
    final feature = widget.secondWindFeature!;
    final pool = feature.resourcePool!;
    if (pool.currentUses > 0) {
      HapticFeedback.mediumImpact();
      final roll = Random().nextInt(10) + 1; // 1d10
      final amount = roll + widget.character.level;

      setState(() {
        pool.use(1);
        widget.character.heal(amount);
        widget.character.save();
        widget.onChanged?.call();
      });

      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.success(context, l10n.secondWindHeal(amount));
    }
  }

  void _restoreResource(CharacterFeature feature) {
    final pool = feature.resourcePool!;
    if (!pool.isFull) {
      HapticFeedback.selectionClick();
      setState(() {
        pool.restore(1);
        widget.character.save();
        widget.onChanged?.call();
      });
    }
  }

  void _showDetails(CharacterFeature feature, [IconData? overrideIcon]) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
        overrideIcon: overrideIcon,
      ),
    );
  }

  List<CharacterFeature> _getFightingStyles() {
    // Generic container IDs and names to exclude
    const containerIds = {
      'fighting-style',
      'fighting_style',
      'additional-fighting-style',
      'additional_fighting_style',
    };
    const containerNames = {
      'fighting style',
      'additional fighting style',
    };

    return widget.character.features.where((f) {
      final id = f.id.toLowerCase();
      if (containerIds.contains(id)) return false;
      // Exclude by English name to catch containers with compound IDs
      if (containerNames.contains(f.nameEn.toLowerCase())) return false;
      return id.contains('fighting-style') ||
          id.contains('fighting_style') ||
          id.startsWith('fs-') ||
          id.startsWith('fs_');
    }).toList();
  }

  CharacterFeature? _getCriticalFeature() {
    return widget.character.features.where((f) {
      final id = f.id.toLowerCase();
      return id.contains('improved-critical') ||
          id.contains('superior-critical') ||
          id.contains('improved_critical') ||
          id.contains('superior_critical');
    }).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final colorScheme = Theme.of(context).colorScheme;
    final level = widget.character.level;

    final List<Widget> blocks = [];

    // Archetype Block (Data-Driven logic)
    if (widget.character.subclass != null &&
        widget.character.subclass!.isNotEmpty) {
      blocks.add(_buildArchetypeBlock(context, colorScheme, locale, l10n));
    }

    // Fighting Styles Wrap Block
    final fightingStyles = _getFightingStyles();
    if (fightingStyles.isNotEmpty) {
      blocks.add(_buildFightingStylesBlock(
          context, fightingStyles, colorScheme, locale, l10n));
    }

    // Second Wind
    if (widget.secondWindFeature != null) {
      blocks.add(_buildFeatureCard(
        context: context,
        l10n: l10n,
        colorScheme: colorScheme,
        feature: widget.secondWindFeature!,
        icon: Icons.healing,
        colorBase: colorScheme.secondary,
        colorContainer: colorScheme.secondaryContainer,
        onColorContainer: colorScheme.onSecondaryContainer,
        subtitle:
            '${l10n.healing}: ${DiceUtils.formatDice('1d10', context)} + $level',
        isSecondWind: true,
      ));
    }

    // Action Surge
    if (widget.actionSurgeFeature != null) {
      blocks.add(_buildFeatureCard(
        context: context,
        l10n: l10n,
        colorScheme: colorScheme,
        feature: widget.actionSurgeFeature!,
        icon: Icons.bolt,
        colorBase: colorScheme.primary,
        colorContainer: colorScheme.primaryContainer,
        onColorContainer: colorScheme.onPrimaryContainer,
        subtitle: l10n.actionTypeAction,
        isActionSurge: true,
      ));
    }

    // Indomitable
    if (widget.indomitableFeature != null) {
      blocks.add(_buildFeatureCard(
        context: context,
        l10n: l10n,
        colorScheme: colorScheme,
        feature: widget.indomitableFeature!,
        icon: Icons.shield,
        colorBase: colorScheme.tertiary,
        colorContainer: colorScheme.tertiaryContainer,
        onColorContainer: colorScheme.onTertiaryContainer,
        subtitle: l10n.rerollSave,
        isIndomitable: true,
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
      child: ClassToolsLayoutBuilder(
        padding: const EdgeInsets.all(16),
        children: blocks,
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuart);
  }

  Widget _buildArchetypeBlock(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
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

    final fallbackName = widget.character.subclass ?? '';
    final subclassName = subclassData?.getName(locale) ?? fallbackName;

    final criticalFeature = _getCriticalFeature();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                final description = subclassData?.getDescription(locale) ??
                    l10n.noFeaturesAtLevel1;

                showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
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
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
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
                                  Icon(Icons.military_tech,
                                      color: colorScheme.primary, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      subclassName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface),
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
                        ));
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.military_tech,
                        color: colorScheme.primary, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.fighterArchetype,
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
                            subclassName,
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
            ),
            if (criticalFeature != null) ...[
              const Divider(height: 1),
              InkWell(
                onTap: () => _showDetails(criticalFeature, Icons.crisis_alert),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.crisis_alert,
                          size: 20, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          criticalFeature.getName(locale),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          criticalFeature.id.contains('superior') == true
                              ? '18-20'
                              : '19-20',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFightingStylesBlock(
      BuildContext context,
      List<CharacterFeature> styles,
      ColorScheme colorScheme,
      String locale,
      AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_martial_arts,
                  color: colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.fightingStylesTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: styles.map((style) {
              final fullName = style.getName(locale);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showDetails(style, Icons.flash_on),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on,
                            size: 16, color: colorScheme.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required CharacterFeature feature,
    required IconData icon,
    required Color colorBase,
    required Color colorContainer,
    required Color onColorContainer,
    required String subtitle,
    bool isActionSurge = false,
    bool isIndomitable = false,
    bool isSecondWind = false,
  }) {
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final isAvailable = pool.currentUses > 0;
    final isMultiCharge = (isActionSurge || isIndomitable) && pool.maxUses > 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      decoration: BoxDecoration(
        color: isAvailable
            ? colorContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable
              ? colorBase
              : colorScheme.outline.withValues(alpha: 0.3),
          width: isAvailable ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(feature, icon),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? colorBase
                            : colorScheme.onSurface.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon,
                          size: 20,
                          color: isAvailable
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature
                                .getName(Localizations.localeOf(context)
                                    .languageCode)
                                .replaceAll(RegExp(r'\s*\(.*?\)'), ''),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isAvailable
                                  ? onColorContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isAvailable
                                  ? onColorContainer.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildResourceControls(
                    context: context,
                    feature: feature,
                    colorScheme: colorScheme,
                    isAvailable: isAvailable,
                    colorBase: colorBase,
                    icon: icon,
                    isMultiCharge: isMultiCharge,
                    isSecondWind: isSecondWind,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceControls({
    required BuildContext context,
    required CharacterFeature feature,
    required ColorScheme colorScheme,
    required bool isAvailable,
    required Color colorBase,
    required IconData icon,
    required bool isMultiCharge,
    bool isSecondWind = false,
  }) {
    final pool = feature.resourcePool!;
    final l10n = AppLocalizations.of(context)!;

    if (!isMultiCharge) {
      // Single-charge thematic button
      return FilledButton.tonal(
        onPressed: isAvailable
            ? (isSecondWind ? _useSecondWind : () => _useResource(feature))
            : () => _restoreResource(feature),
        style: FilledButton.styleFrom(
          backgroundColor: isAvailable
              ? colorBase.withValues(alpha: 0.15)
              : colorScheme.surface,
          foregroundColor: isAvailable ? colorBase : colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isAvailable ? icon : Icons.refresh, size: 20),
            const SizedBox(width: 8),
            Text(isAvailable ? l10n.useAction : l10n.rest),
          ],
        ),
      );
    } else {
      // Multi-charge thematic icon tokens
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(pool.maxUses, (index) {
          final chargeAvailable = index < pool.currentUses;
          return Padding(
            padding: EdgeInsets.only(left: index > 0 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                if (chargeAvailable) {
                  _useResource(feature);
                } else {
                  _restoreResource(feature);
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInOutCubicEmphasized,
                switchOutCurve: Curves.easeInOutCubicEmphasized.flipped,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Container(
                  key: ValueKey('charge_${index}_$chargeAvailable'),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: chargeAvailable
                        ? colorBase.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: chargeAvailable
                          ? colorBase
                          : colorScheme.outline.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: chargeAvailable
                        ? colorBase
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }
  }
}
