import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';

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

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            customMessage ??
                '$cleanName ${Localizations.localeOf(context).languageCode == 'ru' ? 'использовано!' : 'used!'}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        ),
      );
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
    return widget.character.features.where((f) {
      final id = f.id.toLowerCase();
      if (id == 'fighting-style' ||
          id == 'fighting_style' ||
          id == 'additional-fighting-style' ||
          id == 'additional_fighting_style') {
        return false;
      }
      return id.contains('fighting-style') || id.contains('fighting_style');
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
        icon: Icons.favorite,
        colorBase: colorScheme.secondary,
        colorContainer: colorScheme.secondaryContainer,
        onColorContainer: colorScheme.onSecondaryContainer,
        subtitle:
            '${l10n.healing}: ${DiceUtils.formatDice('1d10', context)} + $level',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < blocks.length; i++) ...[
              blocks[i],
              if (i < blocks.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
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
                        Text(
                          style.getName(locale),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colorScheme.onSecondaryContainer,
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
  }) {
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final isAvailable = pool.currentUses > 0;

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
          onTap: () {
            IconData? overrideIcon;
            if (icon == Icons.favorite) {
              overrideIcon = Icons.favorite;
            } else if (icon == Icons.bolt) {
              overrideIcon = Icons.bolt;
            } else if (icon == Icons.shield) {
              overrideIcon = Icons.shield;
            }
            _showDetails(feature, overrideIcon);
          },
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
                    context,
                    feature,
                    colorScheme,
                    isAvailable,
                    colorBase,
                    colorContainer,
                    onColorContainer,
                    isActionSurge || isIndomitable,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceControls(
    BuildContext context,
    CharacterFeature feature,
    ColorScheme colorScheme,
    bool isAvailable,
    Color colorBase,
    Color colorContainer,
    Color onColorContainer,
    bool multiCharge,
  ) {
    final pool = feature.resourcePool!;

    if (!multiCharge || pool.maxUses == 1) {
      // Single button approach (like Second Wind)
      return FilledButton.icon(
        onPressed: isAvailable
            ? () => _useResource(feature)
            : () => _restoreResource(feature),
        icon: Icon(isAvailable ? Icons.play_arrow : Icons.refresh),
        label: Text(isAvailable
            ? AppLocalizations.of(context)!.useAction
            : AppLocalizations.of(context)!.rest),
        style: FilledButton.styleFrom(
          backgroundColor: isAvailable ? colorBase : colorScheme.surface,
          foregroundColor:
              isAvailable ? colorScheme.onPrimary : colorScheme.primary,
        ),
      );
    } else {
      // Multiple charges approach
      return Wrap(
        spacing: 8,
        children: List.generate(pool.maxUses, (index) {
          final chargeAvailable = index < pool.currentUses;
          return GestureDetector(
            onTap: () {
              if (chargeAvailable) {
                _useResource(feature);
              } else {
                _restoreResource(feature);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: chargeAvailable ? colorBase : colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: chargeAvailable
                      ? colorBase
                      : colorScheme.outline.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: chargeAvailable
                    ? [
                        BoxShadow(
                          color: colorBase.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                chargeAvailable ? Icons.check : Icons.refresh,
                size: 20,
                color: chargeAvailable
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          );
        }),
      );
    }
  }
}
