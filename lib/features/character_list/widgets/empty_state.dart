import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.onCreate,
    this.onImport,
  });

  final VoidCallback? onCreate;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final horizontalPadding = isWide ? 32.0 : 24.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Material(
              color: colorScheme.surfaceContainerLow,
              elevation: 1,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
              surfaceTintColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isWide ? 28 : 24,
                  horizontalPadding,
                  isWide ? 28 : 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EmptyRosterScene(isWide: isWide),
                    const SizedBox(height: 28),
                    Text(
                      l10n.empty_roster_title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        l10n.empty_roster_subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (onCreate != null || onImport != null) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (onCreate != null)
                            FilledButton.icon(
                              onPressed: onCreate,
                              icon:
                                  const Icon(Icons.add_circle_outline_rounded),
                              label: Text(l10n.createNewCharacter),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          if (onImport != null)
                            OutlinedButton.icon(
                              onPressed: onImport,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(l10n.importFC5),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyRosterScene extends StatelessWidget {
  const _EmptyRosterScene({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final height = isWide ? 248.0 : 212.0;
    final boardWidth = isWide ? 310.0 : 256.0;
    final boardHeight = isWide ? 172.0 : 156.0;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                      colorScheme.primary.withValues(alpha: 0.07),
                      colorScheme.surfaceContainer,
                    ),
                    colorScheme.surfaceContainer,
                    Color.alphaBlend(
                      colorScheme.secondary.withValues(alpha: 0.06),
                      colorScheme.surfaceContainerLow,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: isWide ? 48 : 20,
            child: _SceneGlow(
              size: isWide ? 68 : 56,
              color: colorScheme.secondary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 36,
            right: isWide ? 52 : 22,
            child: _SceneGlow(
              size: isWide ? 82 : 68,
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            left: isWide ? 86 : 32,
            right: isWide ? 86 : 32,
            bottom: 24,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: boardWidth,
            height: boardHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surfaceContainerHighest,
                  Color.alphaBlend(
                    colorScheme.primary.withValues(alpha: 0.06),
                    colorScheme.surfaceContainerHigh,
                  ),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isWide ? 72 : 60),
                bottom: const Radius.circular(28),
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 18,
                  child: Container(
                    width: isWide ? 84 : 72,
                    height: 10,
                    decoration: BoxDecoration(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: 34,
                  child: Container(
                    width: isWide ? 92 : 80,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        colorScheme.primary.withValues(alpha: 0.12),
                        colorScheme.surfaceContainer,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PortraitPlaceholder(
                        accent: colorScheme.tertiary,
                        isCenter: false,
                      ),
                      _PortraitPlaceholder(
                        accent: colorScheme.primary,
                        isCenter: true,
                      ),
                      _PortraitPlaceholder(
                        accent: colorScheme.secondary,
                        isCenter: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitPlaceholder extends StatelessWidget {
  const _PortraitPlaceholder({
    required this.accent,
    required this.isCenter,
  });

  final Color accent;
  final bool isCenter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = isCenter ? 76.0 : 64.0;
    final height = isCenter ? 92.0 : 80.0;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: isCenter ? 0.14 : 0.09),
          colorScheme.surfaceContainer,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(alpha: isCenter ? 0.24 : 0.18),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isCenter ? 34 : 28,
            height: isCenter ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
            ),
            child: Icon(
              Icons.person_rounded,
              size: isCenter ? 18 : 16,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: isCenter ? 26 : 22,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneGlow extends StatelessWidget {
  const _SceneGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size,
              spreadRadius: size / 4,
            ),
          ],
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}
