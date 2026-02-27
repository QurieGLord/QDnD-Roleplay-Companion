import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';

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

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            customMessage ??
                '${feature.getName(Localizations.localeOf(context).languageCode)} used!',
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final level = widget.character.level;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.fighterTactics.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          letterSpacing: 1.5,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Second Wind (Wide Button Style)
            if (widget.secondWindFeature != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSecondWindCard(context, l10n, colorScheme, level),
              ),

            if (widget.secondWindFeature != null &&
                (widget.actionSurgeFeature != null ||
                    widget.indomitableFeature != null))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1),
              ),

            // Action Surge
            if (widget.actionSurgeFeature != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildActionSurgeRow(context, l10n, colorScheme),
              ),
            ],

            if (widget.indomitableFeature != null) ...[
              if (widget.actionSurgeFeature != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildIndomitableRow(context, l10n, colorScheme),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecondWindCard(BuildContext context, AppLocalizations l10n,
      ColorScheme colorScheme, int level) {
    final feature = widget.secondWindFeature!;
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final isAvailable = pool.currentUses > 0;
    final healingText = '${DiceUtils.formatDice('1d10', context)} + $level';

    return InkWell(
      onTap: isAvailable
          ? () => _useResource(feature)
          : () => _restoreResource(feature),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAvailable
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAvailable
                ? colorScheme.secondary
                : colorScheme.outline.withOpacity(0.5),
            width: isAvailable ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAvailable
                    ? colorScheme.secondary
                    : colorScheme.onSurface.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite,
                  size: 20,
                  color: isAvailable
                      ? colorScheme.onSecondary
                      : colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.secondWind,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isAvailable
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurface),
                  ),
                  Text(
                    '${l10n.healing}: $healingText',
                    style: TextStyle(
                        fontSize: 12,
                        color: isAvailable
                            ? colorScheme.onSecondaryContainer.withOpacity(0.8)
                            : colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!isAvailable) Icon(Icons.refresh, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSurgeRow(
      BuildContext context, AppLocalizations l10n, ColorScheme colorScheme) {
    final feature = widget.actionSurgeFeature!;
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.actionSurge,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              l10n.actionTypeAction,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: List.generate(pool.maxUses, (index) {
            final isAvailable = index < pool.currentUses;
            return GestureDetector(
              onTap: () {
                if (isAvailable) {
                  _useResource(feature, customMessage: l10n.actionSurge);
                } else {
                  _restoreResource(feature);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAvailable
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAvailable
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isAvailable ? Icons.bolt : Icons.bolt_outlined,
                  size: 20,
                  color: isAvailable
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildIndomitableRow(
      BuildContext context, AppLocalizations l10n, ColorScheme colorScheme) {
    final feature = widget.indomitableFeature!;
    final pool = feature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.indomitable,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              l10n.rerollSave, // "Save Reroll" or similar
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: List.generate(pool.maxUses, (index) {
            final isAvailable = index < pool.currentUses;
            return GestureDetector(
              onTap: () {
                if (isAvailable) {
                  _useResource(feature, customMessage: l10n.rerollSave);
                } else {
                  _restoreResource(feature);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAvailable
                      ? colorScheme.tertiary
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAvailable
                        ? colorScheme.tertiary
                        : colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isAvailable ? Icons.shield : Icons.shield_outlined,
                  size: 20,
                  color: isAvailable
                      ? colorScheme.onTertiary
                      : colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
