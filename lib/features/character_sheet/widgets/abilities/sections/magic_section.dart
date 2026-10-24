import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../abilities_shell_tokens.dart';
import '../abilities_tap_feedback.dart';

class MagicStatData {
  const MagicStatData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class AbilitiesMagicSection extends StatelessWidget {
  const AbilitiesMagicSection({
    super.key,
    required this.stats,
    required this.onOpenSpellAlmanac,
    this.preparationStatus,
    this.slotsLabel,
    this.slotsWidget,
    this.vipBlocks = const [],
    this.spellGroups = const [],
    this.emptySpellState,
    this.concentration,
    this.footer,
  });

  final List<MagicStatData> stats;
  final VoidCallback onOpenSpellAlmanac;
  final Widget? preparationStatus;
  final String? slotsLabel;
  final Widget? slotsWidget;
  final List<Widget> vipBlocks;
  final List<Widget> spellGroups;
  final Widget? emptySpellState;

  /// The active concentration banner, above the spellcasting facts.
  final Widget? concentration;

  /// A quiet line under the circles (how slot marks work).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final theme = Theme.of(context);
              const titleStyle = TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: -.3);
              final buttonStyle = theme.textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w700,
              );
              double textWidth(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              }

              // Keep the header on one row: the full name on a wide screen,
              // the short one on a phone, an accessible icon when larger
              // text leaves too little room.
              final available =
                  constraints.maxWidth - textWidth(l10n.magic, titleStyle) - 24;
              String? label;
              for (final candidate in [
                if (constraints.maxWidth >= 520) l10n.spellAlmanac,
                ru ? 'Альманах' : 'Almanac',
              ]) {
                if (textWidth(candidate, buttonStyle) + 54 <= available) {
                  label = candidate;
                  break;
                }
              }
              return Row(children: [
                Expanded(
                    child: Text(l10n.magic,
                        style: titleStyle.copyWith(color: colorScheme.onSurface))),
                _AlmanacButton(
                  key: const ValueKey('spell-almanac-button'),
                  onTap: onOpenSpellAlmanac,
                  label: label,
                  semanticLabel: l10n.spellAlmanac,
                ),
              ]);
            },
          ),
          if (concentration != null) ...[
            const SizedBox(height: 12),
            concentration!,
          ],
          if (preparationStatus != null) ...[
            const SizedBox(height: 14),
            preparationStatus!,
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: AbilitiesShellTokens.nestedPadding,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(
                  AbilitiesShellTokens.nestedRadius,
                ),
              ),
              child: Row(
                children: [
                  for (final stat in stats) ...[
                    Expanded(child: _StatTile(stat: stat)),
                    if (stat != stats.last)
                      Container(
                        width: 1,
                        height: 36,
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                  ],
                ],
              ),
            ),
          ],
          if (slotsWidget != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (slotsLabel != null && slotsLabel!.isNotEmpty) ...[
                    Text(
                      slotsLabel!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  slotsWidget!,
                ],
              ),
            ),
          ],
          for (final block in vipBlocks) ...[
            const SizedBox(height: 16),
            block,
          ],
          if (spellGroups.isNotEmpty) ...[
            const SizedBox(height: 16),
              ...spellGroups.expand((group) => [
                  group,
                  if (group != spellGroups.last) const SizedBox(height: 10),
                ]),
          ] else if (emptySpellState != null) ...[
            const SizedBox(height: 16),
            emptySpellState!,
          ],
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _AlmanacButton extends StatelessWidget {
  const _AlmanacButton({
    required this.onTap,
    this.label,
    required this.semanticLabel,
    super.key,
  });

  final VoidCallback onTap;
  final String? label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticLabel,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: AbilitiesTapFeedback(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AbilitiesShellTokens.pillRadius),
          color: colorScheme.secondaryContainer.withValues(alpha: .7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded,
                      size: 18, color: colorScheme.onSecondaryContainer),
                  if (label != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      label!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final MagicStatData stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            stat.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
