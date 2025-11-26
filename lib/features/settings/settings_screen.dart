import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/theme_provider.dart';
import '../../core/theme/app_palettes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'APPEARANCE'),
          const SizedBox(height: 16),
          
          // Theme Mode Selector
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              themeProvider.setThemeMode(newSelection.first);
            },
          ),
          
          const SizedBox(height: 24),
          Text(
            'Color Scheme',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
          _buildSectionHeader(context, 'ABOUT'),
          const SizedBox(height: 16),
          
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: const Text('1.1.0 (Beta)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Developed by'),
                  subtitle: const Text('Qurie'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('License'),
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
              'May your d20 always land on 20!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
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
                    color: scheme.surfaceContainerHighest, // Header bg simulation
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.topLeft,
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: scheme.primary, radius: 8),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withOpacity(0.2),
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
                child: Icon(Icons.edit, size: 12, color: scheme.onTertiaryContainer),
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