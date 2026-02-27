import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
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
    'Lawful Good': {'icon': Icons.account_balance},
    'Neutral Good': {'icon': Icons.favorite},
    'Chaotic Good': {'icon': Icons.whatshot},
    'Lawful Neutral': {'icon': Icons.gavel},
    'True Neutral': {'icon': Icons.balance},
    'Chaotic Neutral': {'icon': Icons.shuffle},
    'Lawful Evil': {'icon': Icons.security},
    'Neutral Evil': {'icon': Icons.dangerous},
    'Chaotic Evil': {'icon': Icons.local_fire_department},
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
    _appearanceController =
        TextEditingController(text: state.appearanceDescription);
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

  String _getAlignmentName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'Lawful Good':
        return l10n.lg;
      case 'Neutral Good':
        return l10n.ng;
      case 'Chaotic Good':
        return l10n.cg;
      case 'Lawful Neutral':
        return l10n.ln;
      case 'True Neutral':
        return l10n.tn;
      case 'Chaotic Neutral':
        return l10n.cn;
      case 'Lawful Evil':
        return l10n.le;
      case 'Neutral Evil':
        return l10n.ne;
      case 'Chaotic Evil':
        return l10n.ce;
      default:
        return key;
    }
  }

  String _getLocalizedColor(AppLocalizations l10n, String color) {
    switch (color) {
      case 'Amber':
        return l10n.colorAmber;
      case 'Blue':
        return l10n.colorBlue;
      case 'Brown':
        return l10n.colorBrown;
      case 'Gray':
        return l10n.colorGray;
      case 'Green':
        return l10n.colorGreen;
      case 'Hazel':
        return l10n.colorHazel;
      case 'Red':
        return l10n.colorRed;
      case 'Violet':
        return l10n.colorViolet;
      case 'Auburn':
        return l10n.colorAuburn;
      case 'Black':
        return l10n.colorBlack;
      case 'Blonde':
        return l10n.colorBlonde;
      case 'White':
        return l10n.colorWhite;
      case 'Bald':
        return l10n.colorBald;
      case 'Pale':
        return l10n.skinPale;
      case 'Fair':
        return l10n.skinFair;
      case 'Light':
        return l10n.skinLight;
      case 'Medium':
        return l10n.skinMedium;
      case 'Tan':
        return l10n.skinTan;
      case 'Dark':
        return l10n.skinDark;
      case 'Ebony':
        return l10n.skinEbony;
      case 'Custom':
        return l10n.custom;
      default:
        return color;
    }
  }

  Future<void> _pickAvatar(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null &&
          result.files.single.path != null &&
          context.mounted) {
        final pickedFile = File(result.files.single.path!);

        // Copy to app's private directory to avoid duplicates in gallery
        final appDir = await getApplicationDocumentsDirectory();
        final avatarsDir = Directory('${appDir.path}/avatars');
        if (!await avatarsDir.exists()) {
          await avatarsDir.create(recursive: true);
        }

        final fileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.${result.files.single.extension ?? 'jpg'}';
        final savedFile = File('${avatarsDir.path}/$fileName');
        await pickedFile.copy(savedFile.path);

        if (context.mounted) {
          context
              .read<CharacterCreationState>()
              .updateAvatarPath(savedFile.path);
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
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ... (Header)
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
                    l10n.identity,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.identitySubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        _buildPortraitPicker(context, state),
        const SizedBox(height: 24),

        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.charName,
            hintText: l10n.charNameHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            context.read<CharacterCreationState>().updateName(value);
          },
        ),
        const SizedBox(height: 24),

        _buildAlignmentPicker(context, state, l10n),
        const SizedBox(height: 16),

        // Physical Appearance
        Card(
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
          child: ExpansionTile(
            leading: Icon(Icons.face, color: theme.colorScheme.primary),
            title: Text(l10n.physicalAppearance),
            subtitle: Text(l10n.physicalSubtitle),
            backgroundColor: theme.colorScheme.surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 4,
                            child:
                                _buildAgePicker(context, state, theme, l10n)),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 6,
                            child: _buildGenderPicker(
                                context, state, theme, l10n)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildHeightPicker(
                                context, state, theme, l10n)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildWeightPicker(
                                context, state, theme, l10n)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child:
                                _buildEyesPicker(context, state, theme, l10n)),
                        const SizedBox(width: 12),
                        Expanded(
                            child:
                                _buildHairPicker(context, state, theme, l10n)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child:
                                _buildSkinPicker(context, state, theme, l10n)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _appearanceController,
                      decoration: InputDecoration(
                        labelText: l10n.appearanceDesc,
                        hintText: l10n.appearanceHint,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) => context
                          .read<CharacterCreationState>()
                          .updateAppearanceDescription(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Personality
        Card(
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
          child: ExpansionTile(
            leading: Icon(Icons.psychology, color: theme.colorScheme.secondary),
            title: Text(l10n.personality),
            subtitle: Text(l10n.personalitySubtitle),
            backgroundColor: theme.colorScheme.surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _traitsController,
                      decoration: InputDecoration(
                        labelText: l10n.traits,
                        hintText: l10n.traitsHint,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context
                          .read<CharacterCreationState>()
                          .updatePersonalityTraits(value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _idealsController,
                      decoration: InputDecoration(
                        labelText: l10n.ideals,
                        hintText: l10n.idealsHint,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context
                          .read<CharacterCreationState>()
                          .updateIdeals(value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bondsController,
                      decoration: InputDecoration(
                        labelText: l10n.bonds,
                        hintText: l10n.bondsHint,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context
                          .read<CharacterCreationState>()
                          .updateBonds(value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _flawsController,
                      decoration: InputDecoration(
                        labelText: l10n.flaws,
                        hintText: l10n.flawsHint,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) => context
                          .read<CharacterCreationState>()
                          .updateFlaws(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Backstory
        Card(
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
          child: ExpansionTile(
            leading:
                Icon(Icons.auto_stories, color: theme.colorScheme.tertiary),
            title: Text(l10n.backstory),
            subtitle: Text(l10n.backstorySubtitle),
            backgroundColor: theme.colorScheme.surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _backstoryController,
                  decoration: InputDecoration(
                    labelText: l10n.backstory,
                    hintText: l10n.backstoryHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (value) => context
                      .read<CharacterCreationState>()
                      .updateBackstory(value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

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
                      l10n.readyMessage(state.name),
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

  // ... (Other build methods - _buildPortraitPicker, _buildAlignmentPicker, etc. - include them here from previous thought)
  // I will define them to ensure file is complete.

  Widget _buildPortraitPicker(
      BuildContext context, CharacterCreationState state) {
    final theme = Theme.of(context);
    return Center(
      child: GestureDetector(
        onTap: () => _pickAvatar(context),
        child: Stack(
          children: [
            Container(
              width: 146,
              height: 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary
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
                          child: Image.file(File(state.avatarPath!),
                              fit: BoxFit.cover))
                      : Icon(Icons.person,
                          size: 60,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5)),
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
                  gradient: LinearGradient(colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary
                  ]),
                ),
                child: Icon(Icons.camera_alt,
                    size: 20, color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentPicker(BuildContext context,
      CharacterCreationState state, AppLocalizations l10n) {
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
                Text(l10n.alignment,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.alignmentSubtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _buildAlignmentGrid(context, state, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentGrid(BuildContext context, CharacterCreationState state,
      AppLocalizations l10n) {
    final theme = Theme.of(context);
    final gridOrder = [
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

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 50),
            Expanded(
                child: Text(l10n.law,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold))),
            Expanded(
                child: Text(l10n.neutral,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold))),
            Expanded(
                child: Text(l10n.chaos,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 8),
        for (int row = 0; row < 3; row++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                      row == 0
                          ? l10n.good
                          : row == 1
                              ? l10n.neutral
                              : l10n.evil,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              for (int col = 0; col < 3; col++) ...[
                Expanded(
                    child: _buildAlignmentCard(
                        context, gridOrder[row * 3 + col], state, l10n)),
                if (col < 2) const SizedBox(width: 6),
              ],
            ],
          ),
          if (row < 2) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildAlignmentCard(BuildContext context, String alignment,
      CharacterCreationState state, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final data = alignments[alignment]!;
    final isSelected = state.alignment == alignment;
    final localizedName = _getAlignmentName(l10n, alignment);

    return GestureDetector(
      onTap: () => context
          .read<CharacterCreationState>()
          .updateAlignment(isSelected ? null : alignment),
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
              width: isSelected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data['icon'] as IconData,
                size: 24,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              localizedName,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 9,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle,
                  size: 14, color: theme.colorScheme.onPrimaryContainer)
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgePicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    return TextField(
      controller: _ageController,
      decoration: InputDecoration(
        labelText: l10n.age,
        hintText: '25',
        suffixText: l10n.ageYears,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) =>
          context.read<CharacterCreationState>().updateAge(value),
    );
  }

  Widget _buildGenderPicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    // Map internal state keys to localized UI data (Short labels)
    final genderOptions = {
      'Male': l10n.genderMaleShort,
      'Female': l10n.genderFemaleShort,
      'Other': l10n.genderOtherShort,
    };

    final gender = state.gender ?? '';
    final currentSelection =
        gender.isNotEmpty && genderOptions.containsKey(gender)
            ? {gender}
            : <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(l10n.gender,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: genderOptions.entries.map((entry) {
              return ButtonSegment<String>(
                value: entry.key,
                label: Text(entry.value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              );
            }).toList(),
            selected: currentSelection,
            onSelectionChanged: (Set<String> selection) {
              if (selection.isNotEmpty) {
                context
                    .read<CharacterCreationState>()
                    .updateGender(selection.first);
              }
            },
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeightPicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    final currentHeight =
        int.tryParse((state.height ?? '').replaceAll(RegExp(r'[^\d]'), '')) ??
            170;
    return InkWell(
      onTap: () async {
        int selectedHeight = currentHeight.clamp(50, 250);
        final FixedExtentScrollController scrollController =
            FixedExtentScrollController(initialItem: selectedHeight - 50);
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (builderContext, setState) {
                return AlertDialog(
                  title: Text(l10n.selectHeight),
                  content: SizedBox(
                      height: 250,
                      width: 200,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                                child: ListWheelScrollView.useDelegate(
                                    controller: scrollController,
                                    itemExtent: 50,
                                    perspective: 0.005,
                                    diameterRatio: 1.2,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (index) => setState(
                                        () => selectedHeight = index + 50),
                                    childDelegate: ListWheelChildBuilderDelegate(
                                        childCount: 201,
                                        builder: (builderContext, index) => Center(
                                            child: Text('${index + 50}',
                                                style: theme.textTheme.headlineSmall?.copyWith(
                                                    color: (index + 50) ==
                                                            selectedHeight
                                                        ? theme
                                                            .colorScheme.primary
                                                        : theme.colorScheme
                                                            .onSurfaceVariant,
                                                    fontWeight: (index + 50) == selectedHeight ? FontWeight.bold : FontWeight.normal)))))),
                            const SizedBox(width: 8),
                            Text(l10n.unitCm,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.cancel)),
                    FilledButton(
                        onPressed: () {
                          context
                              .read<CharacterCreationState>()
                              .updateHeight('$selectedHeight ${l10n.unitCm}');
                          Navigator.pop(dialogContext);
                        },
                        child: Text(l10n.confirm))
                  ],
                );
              },
            );
          },
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.height,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text((state.height?.isEmpty ?? true) ? '—' : state.height!,
                      style: theme.textTheme.bodyLarge)
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }

  Widget _buildWeightPicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    final currentWeight =
        int.tryParse((state.weight ?? '').replaceAll(RegExp(r'[^\d]'), '')) ??
            70;
    return InkWell(
      onTap: () async {
        int selectedWeight = currentWeight.clamp(10, 300);
        final FixedExtentScrollController scrollController =
            FixedExtentScrollController(initialItem: selectedWeight - 10);
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (builderContext, setState) {
                return AlertDialog(
                  title: Text(l10n.selectWeight),
                  content: SizedBox(
                      height: 250,
                      width: 200,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                                child: ListWheelScrollView.useDelegate(
                                    controller: scrollController,
                                    itemExtent: 50,
                                    perspective: 0.005,
                                    diameterRatio: 1.2,
                                    physics: const FixedExtentScrollPhysics(),
                                    onSelectedItemChanged: (index) => setState(
                                        () => selectedWeight = index + 10),
                                    childDelegate: ListWheelChildBuilderDelegate(
                                        childCount: 291,
                                        builder: (builderContext, index) => Center(
                                            child: Text('${index + 10}',
                                                style: theme.textTheme.headlineSmall?.copyWith(
                                                    color: (index + 10) ==
                                                            selectedWeight
                                                        ? theme
                                                            .colorScheme.primary
                                                        : theme.colorScheme
                                                            .onSurfaceVariant,
                                                    fontWeight: (index + 10) == selectedWeight ? FontWeight.bold : FontWeight.normal)))))),
                            const SizedBox(width: 8),
                            Text(l10n.unitKg,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.cancel)),
                    FilledButton(
                        onPressed: () {
                          context
                              .read<CharacterCreationState>()
                              .updateWeight('$selectedWeight ${l10n.unitKg}');
                          Navigator.pop(dialogContext);
                        },
                        child: Text(l10n.confirm))
                  ],
                );
              },
            );
          },
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.weight,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text((state.weight?.isEmpty ?? true) ? '—' : state.weight!,
                      style: theme.textTheme.bodyLarge)
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }

  Widget _buildEyesPicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    final eyeColors = [
      'Amber',
      'Blue',
      'Brown',
      'Gray',
      'Green',
      'Hazel',
      'Red',
      'Violet',
      'Custom'
    ];
    final eyeColorValues = {
      'Amber': const Color(0xFFFFBF00),
      'Blue': const Color(0xFF4169E1),
      'Brown': const Color(0xFF8B4513),
      'Gray': const Color(0xFF808080),
      'Green': const Color(0xFF228B22),
      'Hazel': const Color(0xFFA0785A),
      'Red': const Color(0xFFDC143C),
      'Violet': const Color(0xFF8B00FF),
      'Custom': Colors.grey
    };
    final currentEyes = (state.eyes?.isNotEmpty ?? false) ? state.eyes : null;

    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text(l10n.selectEyeColor),
              children: eyeColors.map((color) {
                final label = _getLocalizedColor(l10n, color);
                return SimpleDialogOption(
                  onPressed: () async {
                    if (color == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(
                          context, l10n.customEyeColor, l10n.enterCustom, l10n);
                      if (customValue != null && context.mounted) {
                        context
                            .read<CharacterCreationState>()
                            .updateEyes(customValue);
                      }
                    } else {
                      Navigator.pop(context, color);
                    }
                  },
                  child: Row(children: [
                    Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            color: eyeColorValues[color],
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: theme.colorScheme.outline, width: 1))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                    if (currentEyes == color)
                      Icon(Icons.check,
                          color: theme.colorScheme.primary, size: 20)
                  ]),
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.eyes,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                      (state.eyes?.isEmpty ?? true)
                          ? '—'
                          : _getLocalizedColor(l10n, state.eyes!),
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }

  Widget _buildHairPicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    final hairColors = [
      'Auburn',
      'Black',
      'Blonde',
      'Brown',
      'Gray',
      'Red',
      'White',
      'Bald',
      'Custom'
    ];
    final hairColorValues = {
      'Auburn': const Color(0xFFA52A2A),
      'Black': const Color(0xFF000000),
      'Blonde': const Color(0xFFFAF0BE),
      'Brown': const Color(0xFF654321),
      'Gray': const Color(0xFF808080),
      'Red': const Color(0xFFFF0000),
      'White': const Color(0xFFF5F5F5),
      'Bald': Colors.transparent,
      'Custom': Colors.grey
    };
    final currentHair = (state.hair?.isNotEmpty ?? false) ? state.hair : null;

    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text(l10n.selectHairColor),
              children: hairColors.map((color) {
                final label = _getLocalizedColor(l10n, color);
                return SimpleDialogOption(
                  onPressed: () async {
                    if (color == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(context,
                          l10n.customHairColor, l10n.enterCustom, l10n);
                      if (customValue != null && context.mounted) {
                        context
                            .read<CharacterCreationState>()
                            .updateHair(customValue);
                      }
                    } else {
                      Navigator.pop(context, color);
                    }
                  },
                  child: Row(children: [
                    Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            color: hairColorValues[color],
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: theme.colorScheme.outline,
                                width: color == 'White' || color == 'Blonde'
                                    ? 1.5
                                    : 1)),
                        child: color == 'Bald'
                            ? Icon(Icons.block,
                                size: 16, color: theme.colorScheme.error)
                            : null),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                    if (currentHair == color)
                      Icon(Icons.check,
                          color: theme.colorScheme.primary, size: 20)
                  ]),
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.hair,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                      (state.hair?.isEmpty ?? true)
                          ? '—'
                          : _getLocalizedColor(l10n, state.hair!),
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }

  Widget _buildSkinPicker(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    final skinTones = [
      'Pale',
      'Fair',
      'Light',
      'Medium',
      'Tan',
      'Brown',
      'Dark',
      'Ebony',
      'Custom'
    ];
    final skinToneValues = {
      'Pale': const Color(0xFFFFF0E1),
      'Fair': const Color(0xFFFFE4C4),
      'Light': const Color(0xFFFFDDB3),
      'Medium': const Color(0xFFE8B98A),
      'Tan': const Color(0xFFD2A574),
      'Brown': const Color(0xFFA67C52),
      'Dark': const Color(0xFF8B6F47),
      'Ebony': const Color(0xFF4A3728),
      'Custom': Colors.grey
    };
    final currentSkin = (state.skin?.isNotEmpty ?? false) ? state.skin : null;

    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text(l10n.selectSkinTone),
              children: skinTones.map((tone) {
                final label = _getLocalizedColor(l10n, tone);
                return SimpleDialogOption(
                  onPressed: () async {
                    if (tone == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(
                          context, l10n.customSkinTone, l10n.enterCustom, l10n);
                      if (customValue != null && context.mounted) {
                        context
                            .read<CharacterCreationState>()
                            .updateSkin(customValue);
                      }
                    } else {
                      Navigator.pop(context, tone);
                    }
                  },
                  child: Row(children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color: skinToneValues[tone],
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.outline,
                              width:
                                  tone == 'Pale' || tone == 'Fair' ? 1.5 : 1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                    if (currentSkin == tone)
                      Icon(Icons.check,
                          color: theme.colorScheme.primary, size: 20)
                  ]),
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.skin,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                      (state.skin?.isEmpty ?? true)
                          ? '—'
                          : _getLocalizedColor(l10n, state.skin!),
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant)
          ],
        ),
      ),
    );
  }

  Future<String?> _showCustomInputDialog(BuildContext context, String title,
      String hint, AppLocalizations l10n) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
              controller: controller,
              decoration: InputDecoration(
                  hintText: hint, border: const OutlineInputBorder()),
              autofocus: true,
              textCapitalization: TextCapitalization.words),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Navigator.pop(context, controller.text);
                  }
                },
                child: Text(l10n.confirm))
          ],
        );
      },
    );
  }
}
