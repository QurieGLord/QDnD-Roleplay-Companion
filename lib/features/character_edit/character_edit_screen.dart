import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/character.dart';
import '../../core/services/storage_service.dart';

class CharacterEditScreen extends StatefulWidget {
  final Character character;

  const CharacterEditScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _backstoryController;
  
  // Traits
  late final TextEditingController _traitsController;
  late final TextEditingController _idealsController;
  late final TextEditingController _bondsController;
  late final TextEditingController _flawsController;

  // State variables for pickers
  String? _avatarPath;
  String? _selectedHeight;
  String? _selectedWeight;
  String? _selectedEyes;
  String? _selectedSkin;
  String? _selectedHair;
  
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _ageController = TextEditingController(text: widget.character.age);
    _backstoryController = TextEditingController(text: widget.character.backstory);
    
    _traitsController = TextEditingController(text: widget.character.personalityTraits);
    _idealsController = TextEditingController(text: widget.character.ideals);
    _bondsController = TextEditingController(text: widget.character.bonds);
    _flawsController = TextEditingController(text: widget.character.flaws);

    _avatarPath = widget.character.avatarPath;
    _selectedHeight = widget.character.height;
    _selectedWeight = widget.character.weight;
    _selectedEyes = widget.character.eyes;
    _selectedSkin = widget.character.skin;
    _selectedHair = widget.character.hair;

    void markDirty() {
      if (!_isDirty) setState(() => _isDirty = true);
    }
    
    _nameController.addListener(markDirty);
    _ageController.addListener(markDirty);
    _backstoryController.addListener(markDirty);
    _traitsController.addListener(markDirty);
    _idealsController.addListener(markDirty);
    _bondsController.addListener(markDirty);
    _flawsController.addListener(markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _backstoryController.dispose();
    _traitsController.dispose();
    _idealsController.dispose();
    _bondsController.dispose();
    _flawsController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _avatarPath = result.files.first.path;
          _isDirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Update character fields
      widget.character.name = _nameController.text.trim();
      widget.character.avatarPath = _avatarPath;
      
      // Appearance
      widget.character.age = _ageController.text.trim();
      widget.character.height = _selectedHeight;
      widget.character.weight = _selectedWeight;
      widget.character.eyes = _selectedEyes;
      widget.character.skin = _selectedSkin;
      widget.character.hair = _selectedHair;
      
      // Story & Traits
      widget.character.backstory = _backstoryController.text.trim();
      widget.character.personalityTraits = _traitsController.text.trim();
      widget.character.ideals = _idealsController.text.trim();
      widget.character.bonds = _bondsController.text.trim();
      widget.character.flaws = _flawsController.text.trim();
      
      widget.character.updatedAt = DateTime.now();

      // Persist
      await StorageService.saveCharacter(widget.character);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Character updated successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving character: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Character'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= AVATAR SECTION =================
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
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
                          child: _avatarPath != null
                              ? ClipOval(
                                  child: Image.file(
                                    File(_avatarPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 60,
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 60,
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                              color: theme.colorScheme.primary.withOpacity(0.3),
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
            ),
            const SizedBox(height: 24),

            // ================= IDENTITY SECTION =================
            _buildSectionHeader(context, 'Identity', Icons.badge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Character Name',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              style: theme.textTheme.titleMedium,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ================= APPEARANCE SECTION =================
            _buildSectionHeader(context, 'Appearance', Icons.face),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildAgePicker(context, theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildHeightPicker(context, theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildWeightPicker(context, theme)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildEyesPicker(context, theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSkinPicker(context, theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildHairPicker(context, theme)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ================= PERSONALITY SECTION =================
            _buildSectionHeader(context, 'Personality', Icons.psychology),
            const SizedBox(height: 16),
            _buildTextArea('Personality Traits', _traitsController, minLines: 2),
            const SizedBox(height: 12),
            _buildTextArea('Ideals', _idealsController, minLines: 2),
            const SizedBox(height: 12),
            _buildTextArea('Bonds', _bondsController, minLines: 2),
            const SizedBox(height: 12),
            _buildTextArea('Flaws', _flawsController, minLines: 2),
            const SizedBox(height: 24),

            // ================= BACKSTORY SECTION =================
            _buildSectionHeader(context, 'History', Icons.history_edu),
            const SizedBox(height: 16),
            TextFormField(
              controller: _backstoryController,
              decoration: const InputDecoration(
                labelText: 'Backstory',
                hintText: 'Write your legend here...',
                border: OutlineInputBorder(),
                filled: true,
                alignLabelWithHint: true,
              ),
              maxLines: null,
              minLines: 6,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: theme.colorScheme.primaryContainer,
            thickness: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, {int minLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        alignLabelWithHint: true,
      ),
      maxLines: null,
      minLines: minLines,
      keyboardType: TextInputType.multiline,
    );
  }

  // ================= PICKERS COPIED FROM BASIC INFO STEP =================

  Widget _buildAgePicker(BuildContext context, ThemeData theme) {
    return TextField(
      controller: _ageController,
      decoration: InputDecoration(
        labelText: 'Age',
        hintText: '25',
        suffixText: 'yrs',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildHeightPicker(BuildContext context, ThemeData theme) {
    final currentHeight = int.tryParse((_selectedHeight ?? '').replaceAll(RegExp(r'[^\d]'), '')) ?? 170;

    return InkWell(
      onTap: () async {
        int selectedHeight = currentHeight.clamp(50, 250);
        final FixedExtentScrollController scrollController = FixedExtentScrollController(
          initialItem: selectedHeight - 50,
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
                              childCount: 201,
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
                        this.setState(() {
                          _selectedHeight = '$selectedHeight cm';
                          _isDirty = true;
                        });
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
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surface,
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
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    (_selectedHeight?.isEmpty ?? true) ? '—' : _selectedHeight!,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightPicker(BuildContext context, ThemeData theme) {
    final currentWeight = int.tryParse((_selectedWeight ?? '').replaceAll(RegExp(r'[^\d]'), '')) ?? 70;

    return InkWell(
      onTap: () async {
        int selectedWeight = currentWeight.clamp(10, 300);
        final FixedExtentScrollController scrollController = FixedExtentScrollController(
          initialItem: selectedWeight - 10,
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
                              childCount: 291,
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
                        this.setState(() {
                          _selectedWeight = '$selectedWeight kg';
                          _isDirty = true;
                        });
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
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surface,
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
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    (_selectedWeight?.isEmpty ?? true) ? '—' : _selectedWeight!,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildEyesPicker(BuildContext context, ThemeData theme) {
    return _buildColorPicker(
      context, 
      theme, 
      'Eyes', 
      _selectedEyes, 
      ['Amber', 'Blue', 'Brown', 'Gray', 'Green', 'Hazel', 'Red', 'Violet', 'Custom'],
      {
        'Amber': const Color(0xFFFFBF00),
        'Blue': const Color(0xFF4169E1),
        'Brown': const Color(0xFF8B4513),
        'Gray': const Color(0xFF808080),
        'Green': const Color(0xFF228B22),
        'Hazel': const Color(0xFFA0785A),
        'Red': const Color(0xFFDC143C),
        'Violet': const Color(0xFF8B00FF),
        'Custom': Colors.grey,
      },
      (val) => setState(() { _selectedEyes = val; _isDirty = true; }),
    );
  }

  Widget _buildSkinPicker(BuildContext context, ThemeData theme) {
    return _buildColorPicker(
      context, 
      theme, 
      'Skin', 
      _selectedSkin, 
      ['Pale', 'Fair', 'Light', 'Medium', 'Tan', 'Brown', 'Dark', 'Ebony', 'Custom'],
      {
        'Pale': const Color(0xFFFFF0E1),
        'Fair': const Color(0xFFFFE4C4),
        'Light': const Color(0xFFFFDDB3),
        'Medium': const Color(0xFFE8B98A),
        'Tan': const Color(0xFFD2A574),
        'Brown': const Color(0xFFA67C52),
        'Dark': const Color(0xFF8B6F47),
        'Ebony': const Color(0xFF4A3728),
        'Custom': Colors.grey,
      },
      (val) => setState(() { _selectedSkin = val; _isDirty = true; }),
    );
  }

  Widget _buildHairPicker(BuildContext context, ThemeData theme) {
    return _buildColorPicker(
      context, 
      theme, 
      'Hair', 
      _selectedHair, 
      ['Auburn', 'Black', 'Blonde', 'Brown', 'Gray', 'Red', 'White', 'Bald', 'Custom'],
      {
        'Auburn': const Color(0xFFA52A2A),
        'Black': const Color(0xFF000000),
        'Blonde': const Color(0xFFFAF0BE),
        'Brown': const Color(0xFF654321),
        'Gray': const Color(0xFF808080),
        'Red': const Color(0xFFFF0000),
        'White': const Color(0xFFF5F5F5),
        'Bald': Colors.transparent,
        'Custom': Colors.grey,
      },
      (val) => setState(() { _selectedHair = val; _isDirty = true; }),
    );
  }

  Widget _buildColorPicker(
    BuildContext context, 
    ThemeData theme, 
    String label, 
    String? currentValue, 
    List<String> options, 
    Map<String, Color> colors,
    Function(String) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text('Select $label Color'),
              children: options.map((color) {
                return SimpleDialogOption(
                  onPressed: () async {
                    if (color == 'Custom') {
                      Navigator.pop(context);
                      final customValue = await _showCustomInputDialog(
                        context,
                        'Custom $label Color',
                        'Enter custom color',
                      );
                      if (customValue != null) {
                        onChanged(customValue);
                      }
                    } else {
                      Navigator.pop(context, color);
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colors[color],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        child: color == 'Bald' 
                            ? Icon(Icons.block, size: 16, color: theme.colorScheme.error) 
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(color)),
                      if (currentValue == color)
                        Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    (currentValue?.isEmpty ?? true) ? '—' : currentValue!,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

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