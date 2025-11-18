import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final TextEditingController _nameController;
  late final TextEditingController _currentHpController;
  late final TextEditingController _maxHpController;
  late final TextEditingController _tempHpController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _currentHpController = TextEditingController(
      text: widget.character.currentHp.toString(),
    );
    _maxHpController = TextEditingController(
      text: widget.character.maxHp.toString(),
    );
    _tempHpController = TextEditingController(
      text: widget.character.temporaryHp.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentHpController.dispose();
    _maxHpController.dispose();
    _tempHpController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Name cannot be empty'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final currentHp = int.tryParse(_currentHpController.text) ?? widget.character.currentHp;
    final maxHp = int.tryParse(_maxHpController.text) ?? widget.character.maxHp;
    final tempHp = int.tryParse(_tempHpController.text) ?? widget.character.temporaryHp;

    // Update character fields directly (HiveObject is mutable)
    widget.character.name = name;
    widget.character.currentHp = currentHp;
    widget.character.maxHp = maxHp;
    widget.character.temporaryHp = tempHp;
    widget.character.updatedAt = DateTime.now();

    // Save to database
    await StorageService.saveCharacter(widget.character);

    if (mounted) {
      Navigator.of(context).pop(true); // Return true to indicate changes were saved
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Changes saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Character'),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Name Field
          Text(
            'Basic Information',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Character Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 32),

          // HP Section
          Text(
            'Hit Points',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _currentHpController,
                  decoration: const InputDecoration(
                    labelText: 'Current HP',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxHpController,
                  decoration: const InputDecoration(
                    labelText: 'Max HP',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite_border),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _tempHpController,
            decoration: const InputDecoration(
              labelText: 'Temporary HP',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shield),
              helperText: 'Temporary hit points that absorb damage first',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 32),

          // Info Card
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'More advanced editing (ability scores, proficiencies, etc.) will be available in future updates.',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontSize: 13,
                      ),
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
}
