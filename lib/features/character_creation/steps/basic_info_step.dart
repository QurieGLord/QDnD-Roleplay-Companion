import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../character_creation_state.dart';

class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late final TextEditingController _nameController;

  // D&D 5e alignments
  static const List<String> _alignments = [
    'Lawful Good',
    'Neutral Good',
    'Chaotic Good',
    'Lawful Neutral',
    'True Neutral',
    'Chaotic Neutral',
    'Lawful Evil',
    'Neutral Evil',
    'Chaotic Evil',
  ];

  // Avatar icons (использую Material Icons как placeholder)
  static const List<IconData> _avatarIcons = [
    Icons.person,
    Icons.shield,
    Icons.auto_awesome,
    Icons.pets,
    Icons.park,
    Icons.visibility,
    Icons.psychology,
    Icons.favorite,
    Icons.bolt,
    Icons.nightlight,
    Icons.wb_sunny,
    Icons.ac_unit,
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<CharacterCreationState>();
    _nameController = TextEditingController(text: state.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header
        Text(
          'Basic Information',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Let\'s start by creating the foundation of your character.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Avatar Picker Section
        _buildSectionHeader(context, 'Avatar', 'Choose an icon for your character'),
        const SizedBox(height: 16),
        _buildAvatarPicker(context, state),
        const SizedBox(height: 32),

        // Character Name Section
        _buildSectionHeader(context, 'Character Name', 'What shall we call you?', required: true),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g., Gundren Rockseeker',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.edit),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            context.read<CharacterCreationState>().updateName(value);
          },
        ),
        const SizedBox(height: 32),

        // Alignment Section
        _buildSectionHeader(context, 'Alignment', 'Choose your character\'s moral compass'),
        const SizedBox(height: 16),
        _buildAlignmentGrid(context, state),
        const SizedBox(height: 24),

        // Success indicator
        if (state.name.isNotEmpty)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Looking good!',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${state.name}" is ready to choose their path.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle, {bool required = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPicker(BuildContext context, CharacterCreationState state) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _avatarIcons.length,
        itemBuilder: (context, index) {
          final iconData = _avatarIcons[index];
          final avatarPath = 'icon_$index'; // Simple identifier
          final isSelected = state.avatarPath == avatarPath;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                context.read<CharacterCreationState>().updateAvatarPath(avatarPath);
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData,
                      size: 32,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlignmentGrid(BuildContext context, CharacterCreationState state) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _alignments.map((alignment) {
        final isSelected = state.alignment == alignment;

        return FilterChip(
          label: Text(alignment),
          selected: isSelected,
          onSelected: (selected) {
            context.read<CharacterCreationState>().updateAlignment(
              selected ? alignment : null,
            );
          },
          selectedColor: theme.colorScheme.primaryContainer,
          checkmarkColor: theme.colorScheme.onPrimaryContainer,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        );
      }).toList(),
    );
  }
}
