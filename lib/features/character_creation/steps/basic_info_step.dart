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
                          child: _buildAgePicker(context, state, theme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGenderPicker(context, state, theme),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeightPicker(context, state, theme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildWeightPicker(context, state, theme),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEyesPicker(context, state, theme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildHairPicker(context, state, theme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSkinPicker(context, state, theme),
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

  // Age Picker - TextField with keyboard input
  Widget _buildAgePicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    return TextField(
      controller: _ageController,
      decoration: InputDecoration(
        labelText: 'Age',
        hintText: '25',
        suffixText: 'years',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => context.read<CharacterCreationState>().updateAge(value),
    );
  }

  // Gender Picker - uses SegmentedButton
  Widget _buildGenderPicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    final genders = ['M', 'F', 'Other'];
    final genderLabels = {
      'M': 'Male',
      'F': 'Female',
      'Other': 'Other',
    };
    final currentGenderShort = state.gender == 'Male' ? 'M' :
                                state.gender == 'Female' ? 'F' :
                                state.gender == 'Other' ? 'Other' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: genders.map((gender) {
              return ButtonSegment<String>(
                value: gender,
                label: Text(gender, style: const TextStyle(fontSize: 11)),
              );
            }).toList(),
            selected: currentGenderShort != null ? {currentGenderShort} : {},
            onSelectionChanged: (Set<String> selection) {
              if (selection.isNotEmpty) {
                final fullGender = genderLabels[selection.first]!;
                context.read<CharacterCreationState>().updateGender(fullGender);
              }
            },
            emptySelectionAllowed: true,
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }

  // Height Picker - uses ScrollPicker in centimeters (50-250 cm)
  Widget _buildHeightPicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    final currentHeight = int.tryParse((state.height ?? '').replaceAll(RegExp(r'[^\d]'), '')) ?? 170;

    return InkWell(
      onTap: () async {
        int selectedHeight = currentHeight.clamp(50, 250);
        final FixedExtentScrollController scrollController = FixedExtentScrollController(
          initialItem: selectedHeight - 50, // offset by min value
        );

        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (builderContext, setState) {
                return AlertDialog(
                  title: const Text('Select Height'),
                  content: SizedBox(
                    height: 250,
                    width: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Number picker wheel
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: scrollController,
                            itemExtent: 50,
                            perspective: 0.005,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedHeight = index + 50;
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 201, // 50-250
                              builder: (builderContext, index) {
                                final value = index + 50;
                                final isSelected = value == selectedHeight;
                                return Center(
                                  child: Text(
                                    '$value',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'cm',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        context.read<CharacterCreationState>().updateHeight('$selectedHeight cm');
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Height',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (state.height?.isEmpty ?? true) ? '—' : state.height!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Weight Picker - uses ScrollPicker in kilograms (10-300 kg)
  Widget _buildWeightPicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    final currentWeight = int.tryParse((state.weight ?? '').replaceAll(RegExp(r'[^\d]'), '')) ?? 70;

    return InkWell(
      onTap: () async {
        int selectedWeight = currentWeight.clamp(10, 300);
        final FixedExtentScrollController scrollController = FixedExtentScrollController(
          initialItem: selectedWeight - 10, // offset by min value
        );

        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (builderContext, setState) {
                return AlertDialog(
                  title: const Text('Select Weight'),
                  content: SizedBox(
                    height: 250,
                    width: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Number picker wheel
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: scrollController,
                            itemExtent: 50,
                            perspective: 0.005,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedWeight = index + 10;
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 291, // 10-300
                              builder: (builderContext, index) {
                                final value = index + 10;
                                final isSelected = value == selectedWeight;
                                return Center(
                                  child: Text(
                                    '$value',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'kg',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        context.read<CharacterCreationState>().updateWeight('$selectedWeight kg');
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Weight',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (state.weight?.isEmpty ?? true) ? '—' : state.weight!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Eyes Picker - dropdown with presets + Custom option
  Widget _buildEyesPicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    final eyeColors = ['Amber', 'Blue', 'Brown', 'Gray', 'Green', 'Hazel', 'Red', 'Violet', 'Custom'];
    final eyeColorValues = {
      'Amber': const Color(0xFFFFBF00),
      'Blue': const Color(0xFF4169E1),
      'Brown': const Color(0xFF8B4513),
      'Gray': const Color(0xFF808080),
      'Green': const Color(0xFF228B22),
      'Hazel': const Color(0xFFA0785A),
      'Red': const Color(0xFFDC143C),
      'Violet': const Color(0xFF8B00FF),
      'Custom': Colors.grey,
    };
    final currentEyes = (state.eyes?.isNotEmpty ?? false) ? state.eyes : null;

    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text('Select Eye Color'),
              children: eyeColors.map((color) {
                return SimpleDialogOption(
                  onPressed: () async {
                    if (color == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(
                        context,
                        'Custom Eye Color',
                        'Enter custom eye color',
                      );
                      if (customValue != null && context.mounted) {
                        context.read<CharacterCreationState>().updateEyes(customValue);
                      }
                    } else {
                      Navigator.pop(context, color);
                    }
                  },
                  child: Row(
                    children: [
                      // Color circle indicator
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: eyeColorValues[color],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(color)),
                      if (currentEyes == color)
                        Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
        if (selected != null && context.mounted) {
          context.read<CharacterCreationState>().updateEyes(selected);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Eyes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (state.eyes?.isEmpty ?? true) ? '—' : state.eyes!,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Hair Picker - dropdown with presets + Custom option
  Widget _buildHairPicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    final hairColors = ['Auburn', 'Black', 'Blonde', 'Brown', 'Gray', 'Red', 'White', 'Bald', 'Custom'];
    final hairColorValues = {
      'Auburn': const Color(0xFFA52A2A),
      'Black': const Color(0xFF000000),
      'Blonde': const Color(0xFFFAF0BE),
      'Brown': const Color(0xFF654321),
      'Gray': const Color(0xFF808080),
      'Red': const Color(0xFFFF0000),
      'White': const Color(0xFFF5F5F5),
      'Bald': Colors.transparent,
      'Custom': Colors.grey,
    };
    final currentHair = (state.hair?.isNotEmpty ?? false) ? state.hair : null;

    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text('Select Hair Color'),
              children: hairColors.map((color) {
                return SimpleDialogOption(
                  onPressed: () async {
                    if (color == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(
                        context,
                        'Custom Hair Color',
                        'Enter custom hair color',
                      );
                      if (customValue != null && context.mounted) {
                        context.read<CharacterCreationState>().updateHair(customValue);
                      }
                    } else {
                      Navigator.pop(context, color);
                    }
                  },
                  child: Row(
                    children: [
                      // Color circle indicator
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: hairColorValues[color],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: color == 'White' || color == 'Blonde' ? 1.5 : 1,
                          ),
                        ),
                        child: color == 'Bald'
                            ? Icon(Icons.block, size: 16, color: theme.colorScheme.error)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(color)),
                      if (currentHair == color)
                        Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
        if (selected != null && context.mounted) {
          context.read<CharacterCreationState>().updateHair(selected);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hair',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (state.hair?.isEmpty ?? true) ? '—' : state.hair!,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Skin Picker - dropdown with presets + Custom option
  Widget _buildSkinPicker(BuildContext context, CharacterCreationState state, ThemeData theme) {
    final skinTones = ['Pale', 'Fair', 'Light', 'Medium', 'Tan', 'Brown', 'Dark', 'Ebony', 'Custom'];
    final skinToneValues = {
      'Pale': const Color(0xFFFFF0E1),
      'Fair': const Color(0xFFFFE4C4),
      'Light': const Color(0xFFFFDDB3),
      'Medium': const Color(0xFFE8B98A),
      'Tan': const Color(0xFFD2A574),
      'Brown': const Color(0xFFA67C52),
      'Dark': const Color(0xFF8B6F47),
      'Ebony': const Color(0xFF4A3728),
      'Custom': Colors.grey,
    };
    final currentSkin = (state.skin?.isNotEmpty ?? false) ? state.skin : null;

    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text('Select Skin Tone'),
              children: skinTones.map((tone) {
                return SimpleDialogOption(
                  onPressed: () async {
                    if (tone == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(
                        context,
                        'Custom Skin Tone',
                        'Enter custom skin tone',
                      );
                      if (customValue != null && context.mounted) {
                        context.read<CharacterCreationState>().updateSkin(customValue);
                      }
                    } else {
                      Navigator.pop(context, tone);
                    }
                  },
                  child: Row(
                    children: [
                      // Color circle indicator
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: skinToneValues[tone],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: tone == 'Pale' || tone == 'Fair' ? 1.5 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tone)),
                      if (currentSkin == tone)
                        Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
        if (selected != null && context.mounted) {
          context.read<CharacterCreationState>().updateSkin(selected);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Skin',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (state.skin?.isEmpty ?? true) ? '—' : state.skin!,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Helper method for custom input dialog
  Future<String?> _showCustomInputDialog(BuildContext context, String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
