import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/services/theme_provider.dart';
import '../../core/services/locale_provider.dart';
import '../../core/theme/app_palettes.dart';
import 'library_manager_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, l10n.language.toUpperCase()),
          const SizedBox(height: 16),

          // Language Selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'en',
                label: Text('English'),
                icon: Icon(Icons.language),
              ),
              ButtonSegment(
                value: 'ru',
                label: Text('Русский'),
                icon: Icon(Icons.translate),
              ),
            ],
            selected: {localeProvider.locale.languageCode},
            onSelectionChanged: (Set<String> newSelection) {
              localeProvider.setLocale(Locale(newSelection.first));
            },
          ),

          const SizedBox(height: 32),

          _buildSectionHeader(context, l10n.appearance.toUpperCase()),
          const SizedBox(height: 16),

          // Theme Mode Selector
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
                icon: const Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeDark),
                icon: const Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              themeProvider.setThemeMode(newSelection.first);
            },
          ),

          const SizedBox(height: 16),

          // High Contrast Switch
          SwitchListTile(
            title: Text(l10n.highContrast),
            subtitle: Text(l10n.highContrastDesc),
            secondary: const Icon(Icons.contrast),
            value: themeProvider.isHighContrast,
            onChanged: (value) => themeProvider.setHighContrast(value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),

          const SizedBox(height: 24),
          Text(
            l10n.colorScheme,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Color Presets Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: AppColorPreset.values.length,
            itemBuilder: (context, index) {
              final preset = AppColorPreset.values[index];
              return _ThemePreviewCard(
                preset: preset,
                isSelected: themeProvider.colorPreset == preset,
                onTap: () => themeProvider.setColorPreset(preset),
              );
            },
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(context, l10n.contentManagement.toUpperCase()),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(l10n.manageLibraries),
                  subtitle: Text(l10n.manageLibrariesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LibraryManagerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(context, l10n.about.toUpperCase()),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.version),
                  subtitle: const Text('0.13.0 (Beta)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(l10n.developedBy),
                  subtitle: const Text('Qurie'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.license),
                  subtitle: const Text('MIT License'),
                  onTap: () {
                    // Show license dialog
                    showLicensePage(
                      context: context,
                      applicationName: 'QD&D',
                      applicationVersion: '1.1.0',
                      applicationLegalese: '© 2025 Qurie',
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.d20wish,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final AppColorPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = AppPalettes.getScheme(preset, brightness);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Preview Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color:
                        scheme.surfaceContainerHighest, // Header bg simulation
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.topLeft,
                    child: Row(
                      children: [
                        CircleAvatar(
                            backgroundColor: scheme.primary, radius: 8),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.label,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating action button simulation
            Positioned(
              right: 8,
              top: 28, // Halfway between header and body
              child: CircleAvatar(
                backgroundColor: scheme.tertiaryContainer,
                radius: 12,
                child: Icon(Icons.edit,
                    size: 12, color: scheme.onTertiaryContainer),
              ),
            ),

            // Selection Checkmark
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 12, color: scheme.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
