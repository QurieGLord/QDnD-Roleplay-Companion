import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../character_creation_state.dart';

class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _genderController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _eyesController;
  late final TextEditingController _hairController;
  late final TextEditingController _skinController;
  late final TextEditingController _traitsController;
  late final TextEditingController _idealsController;
  late final TextEditingController _bondsController;
  late final TextEditingController _flawsController;
  late final TextEditingController _appearanceController;
  late final TextEditingController _backstoryController;

  // D&D 5e alignments in 3x3 grid
  static final Map<String, Map<String, dynamic>> alignments = {
    'Lawful Good': {
      'description': 'Honor, compassion, duty',
      'icon': Icons.account_balance,
    },
    'Neutral Good': {
      'description': 'Kind, helpful, balance',
      'icon': Icons.favorite,
    },
    'Chaotic Good': {
      'description': 'Freedom, kindness, rebellion',
      'icon': Icons.whatshot,
    },
    'Lawful Neutral': {
      'description': 'Order, tradition, law',
      'icon': Icons.gavel,
    },
    'True Neutral': {
      'description': 'Balance, nature, neutrality',
      'icon': Icons.balance,
    },
    'Chaotic Neutral': {
      'description': 'Freedom, unpredictability',
      'icon': Icons.shuffle,
    },
    'Lawful Evil': {
      'description': 'Tyranny, order, domination',
      'icon': Icons.security,
    },
    'Neutral Evil': {
      'description': 'Selfish, cruel, practical',
      'icon': Icons.dangerous,
    },
    'Chaotic Evil': {
      'description': 'Destruction, cruelty, chaos',
      'icon': Icons.local_fire_department,
    },
  };

  @override
  void initState() {
    super.initState();
    final state = context.read<CharacterCreationState>();
    _nameController = TextEditingController(text: state.name);
    _ageController = TextEditingController(text: state.age);
    _genderController = TextEditingController(text: state.gender);
    _heightController = TextEditingController(text: state.height);
    _weightController = TextEditingController(text: state.weight);
    _eyesController = TextEditingController(text: state.eyes);
    _hairController = TextEditingController(text: state.hair);
    _skinController = TextEditingController(text: state.skin);
    _traitsController = TextEditingController(text: state.personalityTraits);
    _idealsController = TextEditingController(text: state.ideals);
    _bondsController = TextEditingController(text: state.bonds);
    _flawsController = TextEditingController(text: state.flaws);
    _appearanceController = TextEditingController(text: state.appearanceDescription);
    _backstoryController = TextEditingController(text: state.backstory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _eyesController.dispose();
    _hairController.dispose();
    _skinController.dispose();
    _traitsController.dispose();
    _idealsController.dispose();
    _bondsController.dispose();
    _flawsController.dispose();
    _appearanceController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && context.mounted) {
        final pickedFile = File(result.files.single.path!);

        // Copy to app's private directory to avoid duplicates in gallery
        final appDir = await getApplicationDocumentsDirectory();
        final avatarsDir = Directory('${appDir.path}/avatars');
        if (!await avatarsDir.exists()) {
          await avatarsDir.create(recursive: true);
        }

        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.${result.files.single.extension ?? 'jpg'}';
        final savedFile = File('${avatarsDir.path}/$fileName');
        await pickedFile.copy(savedFile.path);

        if (context.mounted) {
          context.read<CharacterCreationState>().updateAvatarPath(savedFile.path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick avatar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header with gradient accent
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Character Identity',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Create the foundation of your character',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Portrait Picker
        _buildPortraitPicker(context, state),
        const SizedBox(height: 24),

        // Character Name (Required)
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Character Name *',
            hintText: 'e.g., Gundren Rockseeker',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            context.read<CharacterCreationState>().updateName(value);
          },
        ),
        const SizedBox(height: 24),

        // Alignment Picker
        _buildAlignmentPicker(context, state),
        const SizedBox(height: 16),

        // Expandable: Physical Appearance
        Card(
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
          child: ExpansionTile(
            leading: Icon(Icons.face, color: theme.colorScheme.primary),
            title: const Text('Physical Appearance'),
            subtitle: const Text('Optional details about looks'),
            backgroundColor: theme.colorScheme.surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageController,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              hintText: '25',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateAge(value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _genderController,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              hintText: 'Male',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateGender(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              hintText: '6\'2"',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateHeight(value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              hintText: '180 lbs',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateWeight(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _eyesController,
                            decoration: const InputDecoration(
                              labelText: 'Eyes',
                              hintText: 'Blue',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateEyes(value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _hairController,
                            decoration: const InputDecoration(
                              labelText: 'Hair',
                              hintText: 'Brown',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateHair(value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _skinController,
                            decoration: const InputDecoration(
                              labelText: 'Skin',
                              hintText: 'Fair',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => context.read<CharacterCreationState>().updateSkin(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _appearanceController,
                      decoration: const InputDecoration(
                        labelText: 'Appearance Description',
                        hintText: 'Tall and muscular with a battle scar...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) => context.read<CharacterCreationState>().updateAppearanceDescription(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Expandable: Personality
        Card(
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
          child: ExpansionTile(
            leading: Icon(Icons.psychology, color: theme.colorScheme.secondary),
            title: const Text('Personality'),
            subtitle: const Text('Traits, ideals, bonds, flaws'),
            backgroundColor: theme.colorScheme.surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _traitsController,
                      decoration: const InputDecoration(
                        labelText: 'Personality Traits',
                        hintText: 'I am always polite and respectful...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context.read<CharacterCreationState>().updatePersonalityTraits(value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _idealsController,
                      decoration: const InputDecoration(
                        labelText: 'Ideals',
                        hintText: 'Justice. I believe in fairness...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context.read<CharacterCreationState>().updateIdeals(value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bondsController,
                      decoration: const InputDecoration(
                        labelText: 'Bonds',
                        hintText: 'I owe my life to my mentor...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context.read<CharacterCreationState>().updateBonds(value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _flawsController,
                      decoration: const InputDecoration(
                        labelText: 'Flaws',
                        hintText: 'I have a weakness for vices...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context.read<CharacterCreationState>().updateFlaws(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Expandable: Backstory
        Card(
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
          child: ExpansionTile(
            leading: Icon(Icons.auto_stories, color: theme.colorScheme.tertiary),
            title: const Text('Backstory'),
            subtitle: const Text('Your character\'s story'),
            backgroundColor: theme.colorScheme.surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _backstoryController,
                  decoration: const InputDecoration(
                    labelText: 'Backstory',
                    hintText: 'Born in a small village, I always dreamed of adventure...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (value) => context.read<CharacterCreationState>().updateBackstory(value),
                ),
              ),
            ],
          ),
        ),
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
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${state.name} is ready to choose their path!',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPortraitPicker(BuildContext context, CharacterCreationState state) {
    final theme = Theme.of(context);

    return Center(
      child: GestureDetector(
        onTap: () => _pickAvatar(context),
        child: Stack(
          children: [
            // Gradient border effect
            Container(
              width: 146,
              height: 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: state.avatarPath != null
                      ? ClipOval(
                          child: Image.file(
                            File(state.avatarPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 60,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 60,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentPicker(BuildContext context, CharacterCreationState state) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Alignment',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your moral compass',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildAlignmentGrid(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentGrid(BuildContext context, CharacterCreationState state) {
    final theme = Theme.of(context);
    final gridOrder = [
      'Lawful Good', 'Neutral Good', 'Chaotic Good',
      'Lawful Neutral', 'True Neutral', 'Chaotic Neutral',
      'Lawful Evil', 'Neutral Evil', 'Chaotic Evil',
    ];

    return Column(
      children: [
        // Header labels
        Row(
          children: [
            const SizedBox(width: 50),
            Expanded(
              child: Text(
                'LAW',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'NEUTRAL',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'CHAOS',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Grid
        for (int row = 0; row < 3; row++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Side label
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    row == 0 ? 'GOOD' : row == 1 ? 'NEUTRAL' : 'EVIL',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Alignment cards
              for (int col = 0; col < 3; col++) ...[
                Expanded(
                  child: _buildAlignmentCard(
                    context,
                    gridOrder[row * 3 + col],
                    state,
                  ),
                ),
                if (col < 2) const SizedBox(width: 6),
              ],
            ],
          ),
          if (row < 2) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildAlignmentCard(BuildContext context, String alignment, CharacterCreationState state) {
    final theme = Theme.of(context);
    final data = alignments[alignment]!;
    final isSelected = state.alignment == alignment;

    return GestureDetector(
      onTap: () {
        context.read<CharacterCreationState>().updateAlignment(
          isSelected ? null : alignment,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data['icon'] as IconData,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              alignment.split(' ').last, // Show only "Good", "Neutral", "Evil"
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                size: 14,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
