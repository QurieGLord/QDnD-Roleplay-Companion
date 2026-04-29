import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/compendium_source.dart';
import '../../core/services/locale_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/theme_provider.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/ui/app_snack_bar.dart';
import 'library_manager_screen.dart';

const String _kAppVersionLabel = '0.13.0 (Beta)';
const String _kAppVersionShort = '0.13.0';
const double _kHeaderExpandedHeight = 258;
const double _kHeaderCollapsedHeight = 86;
const Duration _kSettingsFastMotion = Duration(milliseconds: 160);
const Duration _kSettingsRevealMotion = Duration(milliseconds: 240);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: CustomScrollView(
        key: const Key('settings_scroll_view'),
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            collapsedHeight: _kHeaderCollapsedHeight,
            expandedHeight: _kHeaderExpandedHeight,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: themeProvider.isBasicMode ? 0.2 : 0.5,
            flexibleSpace: _SettingsHeaderShell(
              title: l10n.settings,
              subtitle: l10n.settingsHeroSubtitle,
              localeLabel: _localeLabel(localeProvider.locale),
              themeLabel: _themeModeLabel(l10n, themeProvider.themeMode),
              basicModeLabel: l10n.basicMode,
              showBasicMode: themeProvider.isBasicMode,
              onBack: canPop
                  ? () {
                      _playNavigationHaptic();
                      Navigator.of(context).maybePop();
                    }
                  : null,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _SettingsEntrance(
                    delay: const Duration(milliseconds: 40),
                    child: _SettingsSection(
                      icon: Icons.translate_rounded,
                      accent: colorScheme.secondary,
                      title: l10n.language,
                      description: l10n.settingsLanguageSectionDesc,
                      child: _AdaptiveSegmentedControl<String>(
                        segmentedKey: const Key('settings_language_segmented'),
                        verticalBreakpoint: 290,
                        segments: const [
                          ButtonSegment<String>(
                            value: 'en',
                            icon: Icon(Icons.language_rounded),
                            label: Text(
                              'English',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'ru',
                            icon: Icon(Icons.translate_rounded),
                            label: Text(
                              'Русский',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ),
                        ],
                        selected: {localeProvider.locale.languageCode},
                        onSelectionChanged: (selection) {
                          final localeCode = selection.first;
                          if (localeCode ==
                              localeProvider.locale.languageCode) {
                            return;
                          }

                          _playSelectionHaptic();
                          localeProvider.setLocale(Locale(localeCode));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsEntrance(
                    delay: const Duration(milliseconds: 75),
                    child: _SettingsSection(
                      icon: Icons.palette_outlined,
                      accent: colorScheme.primary,
                      title: l10n.appearance,
                      description: l10n.settingsAppearanceSectionDesc,
                      child: Column(
                        children: [
                          _ControlSurface(
                            title: l10n.theme,
                            description: l10n.settingsThemeSectionDesc,
                            contentSpacing: 10,
                            child: _AdaptiveSegmentedControl<ThemeMode>(
                              segmentedKey:
                                  const Key('settings_theme_segmented'),
                              verticalBreakpoint: 430,
                              segments: [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.system,
                                  icon: const Icon(Icons.brightness_auto),
                                  label: Text(
                                    l10n.themeSystem,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  icon: const Icon(Icons.light_mode_rounded),
                                  label: Text(
                                    l10n.themeLight,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  icon: const Icon(Icons.dark_mode_rounded),
                                  label: Text(
                                    l10n.themeDark,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                              ],
                              selected: {themeProvider.themeMode},
                              onSelectionChanged: (selection) {
                                final mode = selection.first;
                                if (mode == themeProvider.themeMode) {
                                  return;
                                }

                                _playSelectionHaptic();
                                themeProvider.setThemeMode(mode);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          _BasicModeCard(
                            key: const Key('settings_basic_mode_card'),
                            isEnabled: themeProvider.isBasicMode,
                            onChanged: (value) {
                              if (value == themeProvider.isBasicMode) {
                                return;
                              }

                              _playSelectionHaptic();
                              themeProvider.setBasicMode(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          _ControlSurface(
                            title: l10n.colorScheme,
                            description: l10n.settingsPaletteSectionDesc,
                            contentSpacing: 6,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount =
                                    constraints.maxWidth >= 720 ? 3 : 2;
                                final aspectRatio = constraints.maxWidth < 380
                                    ? 0.78
                                    : (crossAxisCount == 2 ? 1.02 : 1.12);

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: aspectRatio,
                                  ),
                                  itemCount: AppColorPreset.values.length,
                                  itemBuilder: (context, index) {
                                    final preset = AppColorPreset.values[index];
                                    return _SettingsEntrance(
                                      delay: Duration(
                                        milliseconds: 96 + (index * 18),
                                      ),
                                      offset: const Offset(0, 0.032),
                                      beginScale: 0.985,
                                      child: _ThemePreviewCard(
                                        key: Key(
                                          'settings_palette_${preset.name}',
                                        ),
                                        preset: preset,
                                        isSelected:
                                            themeProvider.colorPreset == preset,
                                        selectedLabel: l10n.settingsCurrent,
                                        onTap: () {
                                          if (themeProvider.colorPreset ==
                                              preset) {
                                            return;
                                          }

                                          _playSelectionHaptic();
                                          themeProvider.setColorPreset(preset);
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsEntrance(
                    delay: const Duration(milliseconds: 110),
                    child: _SettingsSection(
                      icon: Icons.library_books_outlined,
                      accent: colorScheme.tertiary,
                      title: l10n.contentManagement,
                      description: l10n.settingsContentSectionDesc,
                      child: ValueListenableBuilder<Box<CompendiumSource>>(
                        valueListenable: StorageService.getSourcesListenable(),
                        builder: (context, box, _) {
                          return _ContentManagementCard(
                            librarySummary:
                                l10n.settingsImportedLibraries(box.length),
                            onTap: () {
                              _playNavigationHaptic();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      const LibraryManagerScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsEntrance(
                    delay: const Duration(milliseconds: 145),
                    child: _SettingsSection(
                      icon: Icons.info_outline_rounded,
                      accent: colorScheme.secondary,
                      title: l10n.about,
                      description: l10n.settingsAboutSectionDesc,
                      child: _AboutSection(
                        versionLabel: _kAppVersionLabel,
                        onLicenseTap: () {
                          _playSelectionHaptic();
                          showLicensePage(
                            context: context,
                            applicationName: 'QD&D',
                            applicationVersion: _kAppVersionShort,
                            applicationLegalese: '© 2025 Qurie',
                          );
                        },
                        onGitHubTap: () {
                          _playSelectionHaptic();
                          unawaited(
                            _openExternalLink(
                              context,
                              'https://github.com/QurieGLord/QDnD-Roleplay-Companion',
                              failureMessage: l10n.settingsUnableToOpenLink,
                            ),
                          );
                        },
                        onTelegramTap: () {
                          _playSelectionHaptic();
                          unawaited(
                            _openExternalLink(
                              context,
                              'https://t.me/qdnd_companion',
                              failureMessage: l10n.settingsUnableToOpenLink,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsEntrance(
                    delay: const Duration(milliseconds: 175),
                    offset: const Offset(0, 0.02),
                    beginScale: 0.992,
                    child: _SettingsFooter(
                      text: l10n.d20wish,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openExternalLink(
    BuildContext context,
    String url, {
    required String failureMessage,
  }) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!launched && context.mounted) {
      AppSnackBar.error(context, failureMessage);
    }
  }

  static String _localeLabel(Locale locale) {
    return switch (locale.languageCode) {
      'ru' => 'Русский',
      _ => 'English',
    };
  }

  static String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };
  }

  static void _playSelectionHaptic() {
    if (!kIsWeb) {
      HapticFeedback.selectionClick();
    }
  }

  static void _playNavigationHaptic() {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }
}

class _SettingsHeaderShell extends StatelessWidget {
  const _SettingsHeaderShell({
    required this.title,
    required this.subtitle,
    required this.localeLabel,
    required this.themeLabel,
    required this.basicModeLabel,
    required this.showBasicMode,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final String localeLabel;
  final String themeLabel;
  final String basicModeLabel;
  final bool showBasicMode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final topPadding = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = topPadding + _kHeaderCollapsedHeight;
        final maxHeight = topPadding + _kHeaderExpandedHeight;
        final rawProgress =
            ((constraints.maxHeight - minHeight) / (maxHeight - minHeight))
                .clamp(0.0, 1.0);
        final progress = disableAnimations
            ? rawProgress
            : Curves.easeOutCubic.transform(rawProgress);
        final canShowDetails =
            constraints.maxHeight > (topPadding + _kHeaderCollapsedHeight + 56);
        final detailProgress = !canShowDetails
            ? 0.0
            : disableAnimations
                ? progress
                : Curves.easeOutCubic.transform(
                    ((progress - 0.28) / 0.72).clamp(0.0, 1.0),
                  );
        final shellRadius = lerpDouble(24, 32, progress) ?? 24;
        final verticalPadding = lerpDouble(12, 18, progress) ?? 12;
        final paletteBlockWidth = lerpDouble(58, 114, progress) ?? 58;
        final titleStyle = TextStyle.lerp(
          theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          progress,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 10),
          child: _SettingsEntrance(
            delay: const Duration(milliseconds: 12),
            offset: const Offset(0, 0.03),
            beginScale: 0.992,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(shellRadius),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(shellRadius),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.68),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.04),
                      colorScheme.secondary.withValues(alpha: 0.018),
                      colorScheme.surfaceContainerLow,
                    ],
                  ),
                  boxShadow: disableAnimations
                      ? null
                      : [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.045),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, verticalPadding),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (onBack != null) ...[
                                  _HeaderBackButton(onTap: onBack!),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  ),
                                ),
                                SizedBox(width: paletteBlockWidth + 12),
                              ],
                            ),
                            if (detailProgress > 0.01)
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: detailProgress,
                                  child: Opacity(
                                    opacity: detailProgress,
                                    child: Transform.translate(
                                      offset:
                                          Offset(0, (1 - detailProgress) * -8),
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: 10,
                                          right: paletteBlockWidth + 8,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              subtitle,
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                height: 1.3,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _SummaryChip(
                                                  icon: Icons.language_rounded,
                                                  label: localeLabel,
                                                ),
                                                _SummaryChip(
                                                  icon: Icons
                                                      .auto_awesome_rounded,
                                                  label: themeLabel,
                                                ),
                                                if (showBasicMode)
                                                  _SummaryChip(
                                                    icon: Icons.tune_rounded,
                                                    label: basicModeLabel,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _HeaderPaletteToken(
                          progress: progress,
                          detailProgress: detailProgress,
                          primary: colorScheme.primary,
                          secondary: colorScheme.secondary,
                          tertiary: colorScheme.tertiary,
                          outline: colorScheme.outlineVariant,
                          surface: colorScheme.surface,
                          onSurface: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _TactileSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      pressedScale: 0.96,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: colorScheme.primary.withValues(alpha: 0.04),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          Icons.arrow_back_rounded,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _HeaderPaletteToken extends StatelessWidget {
  const _HeaderPaletteToken({
    required this.progress,
    required this.detailProgress,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.outline,
    required this.surface,
    required this.onSurface,
  });

  final double progress;
  final double detailProgress;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color outline;
  final Color surface;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final width = lerpDouble(52, 102, progress) ?? 52;
    final height = lerpDouble(30, 70, progress) ?? 30;
    final radius = lerpDouble(999, 24, progress) ?? 24;
    final padding = EdgeInsets.symmetric(
      horizontal: lerpDouble(9, 11, progress) ?? 9,
      vertical: lerpDouble(7, 10, progress) ?? 7,
    );
    final dotSize = lerpDouble(8, 10, progress) ?? 8;

    return AnimatedContainer(
      duration: disableAnimations ? Duration.zero : _kSettingsFastMotion,
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: outline.withValues(alpha: 0.42),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.045 * progress),
            tertiary.withValues(alpha: 0.03 * progress),
            surface.withValues(alpha: 0.84),
          ],
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.lerp(
                  Alignment.center,
                  Alignment.topLeft,
                  progress,
                ) ??
                Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SwatchDot(color: primary, size: dotSize, shadowAlpha: 0.15),
                SizedBox(width: lerpDouble(4, 6, progress) ?? 4),
                _SwatchDot(color: secondary, size: dotSize, shadowAlpha: 0.13),
                SizedBox(width: lerpDouble(4, 6, progress) ?? 4),
                _SwatchDot(color: tertiary, size: dotSize, shadowAlpha: 0.13),
              ],
            ),
          ),
          if (progress > 0.02)
            Align(
              alignment: Alignment.bottomLeft,
              child: Opacity(
                opacity: detailProgress,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: lerpDouble(0, 30, detailProgress) ?? 0,
                      height: lerpDouble(0, 7, detailProgress) ?? 0,
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    SizedBox(height: lerpDouble(0, 6, detailProgress) ?? 0),
                    Container(
                      width: lerpDouble(0, 48, detailProgress) ?? 0,
                      height: lerpDouble(0, 7, detailProgress) ?? 0,
                      decoration: BoxDecoration(
                        color: onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (progress > 0.04)
            Align(
              alignment: Alignment.bottomRight,
              child: Opacity(
                opacity: detailProgress,
                child: Container(
                  width: lerpDouble(0, 18, detailProgress) ?? 0,
                  height: lerpDouble(0, 18, detailProgress) ?? 0,
                  decoration: BoxDecoration(
                    color: tertiary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: lerpDouble(0, 11, detailProgress) ?? 0,
                    color: tertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.44),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.66),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.028),
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlSurface extends StatelessWidget {
  const _ControlSurface({
    required this.child,
    this.title,
    this.description,
    this.contentSpacing = 12,
  });

  final String? title;
  final String? description;
  final Widget child;
  final double contentSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasHeader = title != null || description != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader) ...[
                if (title != null)
                  Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (description != null) ...[
                  if (title != null) const SizedBox(height: 4),
                  Text(
                    description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.32,
                    ),
                  ),
                ],
                SizedBox(height: contentSpacing),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveSegmentedControl<T> extends StatelessWidget {
  const _AdaptiveSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.segmentedKey,
    this.verticalBreakpoint = 360,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final Key? segmentedKey;
  final double verticalBreakpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < verticalBreakpoint;

        if (vertical) {
          return _SelectionPulse(
            selectionIdentity: Object.hashAllUnordered(selected),
            child: _VerticalSegmentedControl<T>(
              key: segmentedKey,
              segments: segments,
              selected: selected,
              onSelectionChanged: onSelectionChanged,
            ),
          );
        }

        return _SelectionPulse(
          selectionIdentity: Object.hashAllUnordered(selected),
          child: SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.46),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SegmentedButton<T>(
                  key: segmentedKey,
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  direction: Axis.horizontal,
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  segments: segments,
                  selected: selected,
                  onSelectionChanged: onSelectionChanged,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    animationDuration: _kSettingsFastMotion,
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return colorScheme.primary.withValues(alpha: 0.09);
                      }

                      if (states.contains(WidgetState.hovered)) {
                        return colorScheme.primary.withValues(alpha: 0.05);
                      }

                      return null;
                    }),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colorScheme.onPrimaryContainer;
                      }

                      return colorScheme.onSurfaceVariant;
                    }),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colorScheme.primaryContainer;
                      }

                      return Colors.transparent;
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VerticalSegmentedControl<T> extends StatelessWidget {
  const _VerticalSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.46),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < segments.length; index++) ...[
                _VerticalSegmentTile<T>(
                  segment: segments[index],
                  isSelected: selected.contains(segments[index].value),
                  isFirst: index == 0,
                  isLast: index == segments.length - 1,
                  onTap: () => onSelectionChanged({segments[index].value}),
                ),
                if (index != segments.length - 1)
                  Container(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.34),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalSegmentTile<T> extends StatelessWidget {
  const _VerticalSegmentTile({
    required this.segment,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final ButtonSegment<T> segment;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final foregroundColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: segment.enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: segment.enabled ? onTap : null,
          child: AnimatedContainer(
            duration: disableAnimations ? Duration.zero : _kSettingsFastMotion,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isFirst ? 18 : 0),
                topRight: Radius.circular(isFirst ? 18 : 0),
                bottomLeft: Radius.circular(isLast ? 18 : 0),
                bottomRight: Radius.circular(isLast ? 18 : 0),
              ),
            ),
            child: DefaultTextStyle(
              style: theme.textTheme.labelLarge!.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: foregroundColor,
                  size: 18,
                ),
                child: Row(
                  children: [
                    if (segment.icon != null) ...[
                      segment.icon!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: segment.label ?? const SizedBox.shrink(),
                    ),
                    AnimatedOpacity(
                      opacity: isSelected ? 1 : 0,
                      duration: disableAnimations
                          ? Duration.zero
                          : _kSettingsFastMotion,
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: foregroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BasicModeCard extends StatelessWidget {
  const _BasicModeCard({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return MergeSemantics(
      child: _TactileSurface(
        onTap: () => onChanged(!isEnabled),
        borderRadius: BorderRadius.circular(24),
        pressedScale: 0.985,
        decoration: BoxDecoration(
          color: isEnabled
              ? colorScheme.secondaryContainer.withValues(alpha: 0.72)
              : colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isEnabled
                ? colorScheme.secondary.withValues(alpha: 0.6)
                : colorScheme.outlineVariant.withValues(alpha: 0.54),
          ),
        ),
        splashColor: colorScheme.secondary.withValues(alpha: 0.08),
        highlightColor: colorScheme.secondary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? colorScheme.secondary.withValues(alpha: 0.14)
                      : colorScheme.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: isEnabled
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.basicMode,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        AnimatedContainer(
                          duration: _kSettingsFastMotion,
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? colorScheme.secondary
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isEnabled
                                ? l10n.settingsBasicModeOn
                                : l10n.settingsBasicModeOff,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isEnabled
                                  ? colorScheme.onSecondary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.basicModeDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Switch(
                  key: const Key('settings_basic_mode_toggle'),
                  value: isEnabled,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentManagementCard extends StatelessWidget {
  const _ContentManagementCard({
    required this.librarySummary,
    required this.onTap,
  });

  final String librarySummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return _TactileSurface(
      key: const Key('settings_manage_libraries_tile'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      pressedScale: 0.982,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.tertiary.withValues(alpha: 0.03),
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
          ],
        ),
      ),
      splashColor: colorScheme.tertiary.withValues(alpha: 0.08),
      highlightColor: colorScheme.tertiary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.library_books_outlined,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.manageLibraries,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _MetaBadge(
                        label: 'XML',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.manageLibrariesSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    librarySummary,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.versionLabel,
    required this.onLicenseTap,
    required this.onGitHubTap,
    required this.onTelegramTap,
  });

  final String versionLabel;
  final VoidCallback onLicenseTap;
  final VoidCallback onGitHubTap;
  final VoidCallback onTelegramTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 560;
            final tileWidth =
                isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _AboutInfoTile(
                    title: l10n.version,
                    value: versionLabel,
                    icon: Icons.bolt_rounded,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _AboutInfoTile(
                    title: l10n.developedBy,
                    value: 'Qurie',
                    icon: Icons.draw_rounded,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _AboutInfoTile(
                    key: const Key('settings_license_tile'),
                    title: l10n.license,
                    value: 'MIT License',
                    icon: Icons.description_outlined,
                    onTap: onLicenseTap,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          l10n.settingsProjectLinks,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ContactChip(
              label: 'GitHub',
              icon: Icons.code_rounded,
              tooltip: l10n.settingsGitHubTooltip,
              onTap: onGitHubTap,
            ),
            _ContactChip(
              label: 'Telegram',
              icon: Icons.send_rounded,
              tooltip: l10n.settingsTelegramTooltip,
              onTap: onTelegramTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutInfoTile extends StatelessWidget {
  const _AboutInfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 92),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
        child: content,
      );
    }

    return _TactileSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      pressedScale: 0.982,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: colorScheme.primary.withValues(alpha: 0.04),
      child: content,
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: _TactileSurface(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          pressedScale: 0.97,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          splashColor: colorScheme.secondary.withValues(alpha: 0.08),
          highlightColor: colorScheme.secondary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.casino_outlined,
              size: 14,
              color: colorScheme.primary.withValues(alpha: 0.86),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.selectedLabel,
    required this.onTap,
  });

  final AppColorPreset preset;
  final bool isSelected;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = AppPalettes.getScheme(preset, brightness);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 160;
        final previewHeight = compact ? 60.0 : 74.0;
        final cardPadding = compact ? 10.0 : 12.0;
        final titleSpacing = compact ? 8.0 : 10.0;
        final descriptionLines = compact ? 1 : 2;

        return Semantics(
          button: true,
          selected: isSelected,
          label: preset.label,
          child: _TactileSurface(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            pressedScale: 0.98,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isSelected ? scheme.primary : scheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: isSelected ? 0.035 : 0.015),
                  scheme.surface,
                ],
              ),
              boxShadow: disableAnimations
                  ? null
                  : [
                      BoxShadow(
                        color: (isSelected ? scheme.primary : scheme.outline)
                            .withValues(alpha: isSelected ? 0.11 : 0.045),
                        blurRadius: isSelected ? 16 : 9,
                        offset: const Offset(0, 7),
                      ),
                    ],
            ),
            splashColor: scheme.primary.withValues(alpha: 0.08),
            highlightColor: scheme.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: previewHeight,
                    padding: EdgeInsets.all(compact ? 9 : 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.surfaceContainerHighest,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            children: [
                              _SwatchDot(
                                color: scheme.primary,
                                size: compact ? 10 : 12,
                                shadowAlpha: 0.16,
                              ),
                              SizedBox(width: compact ? 5 : 7),
                              _SwatchDot(
                                color: scheme.secondary,
                                size: compact ? 10 : 12,
                                shadowAlpha: 0.14,
                              ),
                              SizedBox(width: compact ? 5 : 7),
                              _SwatchDot(
                                color: scheme.tertiary,
                                size: compact ? 10 : 12,
                                shadowAlpha: 0.14,
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: compact ? 40 : 50,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              SizedBox(height: compact ? 5 : 7),
                              Container(
                                width: compact ? 62 : 78,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: AnimatedContainer(
                            duration: disableAnimations
                                ? Duration.zero
                                : _kSettingsFastMotion,
                            curve: Curves.easeOutCubic,
                            width: compact ? 22 : 26,
                            height: compact ? 22 : 26,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.tertiaryContainer,
                              borderRadius:
                                  BorderRadius.circular(compact ? 9 : 11),
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_rounded
                                  : Icons.auto_awesome_rounded,
                              size: compact ? 12 : 13,
                              color: isSelected
                                  ? scheme.onPrimary
                                  : scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: titleSpacing),
                  Text(
                    preset.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preset.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.24,
                        ),
                    maxLines: descriptionLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  SizedBox(height: compact ? 6 : 7),
                  AnimatedSwitcher(
                    duration: disableAnimations
                        ? Duration.zero
                        : _kSettingsFastMotion,
                    child: isSelected
                        ? Container(
                            key: const ValueKey('selected'),
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: scheme.onPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.onPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('idle'),
                            height: compact ? 20 : 22,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.color,
    required this.size,
    required this.shadowAlpha,
  });

  final Color color;
  final double size;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: shadowAlpha),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}

class _TactileSurface extends StatefulWidget {
  const _TactileSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.decoration,
    this.onTap,
    this.splashColor,
    this.highlightColor,
    this.pressedScale = 0.986,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Decoration decoration;
  final VoidCallback? onTap;
  final Color? splashColor;
  final Color? highlightColor;
  final double pressedScale;

  @override
  State<_TactileSurface> createState() => _TactileSurfaceState();
}

class _TactileSurfaceState extends State<_TactileSurface> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedSlide(
      offset: disableAnimations || widget.onTap == null
          ? Offset.zero
          : (_pressed ? const Offset(0, 0.006) : Offset.zero),
      duration: disableAnimations ? Duration.zero : _kSettingsFastMotion,
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: disableAnimations || widget.onTap == null
            ? 1
            : (_pressed ? widget.pressedScale : 1),
        duration: disableAnimations ? Duration.zero : _kSettingsFastMotion,
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
          child: Ink(
            decoration: widget.decoration,
            child: InkWell(
              onTap: widget.onTap,
              customBorder:
                  RoundedRectangleBorder(borderRadius: widget.borderRadius),
              splashColor: widget.splashColor,
              highlightColor: widget.highlightColor,
              onHighlightChanged: (value) {
                if (_pressed != value && !disableAnimations) {
                  setState(() => _pressed = value);
                }
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionPulse extends StatefulWidget {
  const _SelectionPulse({
    required this.selectionIdentity,
    required this.child,
  });

  final Object selectionIdentity;
  final Widget child;

  @override
  State<_SelectionPulse> createState() => _SelectionPulseState();
}

class _SelectionPulseState extends State<_SelectionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kSettingsFastMotion,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.992),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.992, end: 1),
        weight: 58,
      ),
    ]).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.005)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0, 0.005), end: Offset.zero),
        weight: 58,
      ),
    ]).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant _SelectionPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!disableAnimations &&
        oldWidget.selectionIdentity != widget.selectionIdentity) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return widget.child;
    }

    return SlideTransition(
      position: _offset,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

class _SettingsEntrance extends StatefulWidget {
  const _SettingsEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.036),
    this.beginScale = 0.988,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final double beginScale;

  @override
  State<_SettingsEntrance> createState() => _SettingsEntranceState();
}

class _SettingsEntranceState extends State<_SettingsEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;
  Timer? _timer;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kSettingsRevealMotion,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(
      begin: widget.beginScale,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      _timer?.cancel();
      _controller.value = 1;
      return;
    }

    if (_scheduled || _controller.isCompleted) {
      return;
    }

    _scheduled = true;
    _timer = Timer(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
