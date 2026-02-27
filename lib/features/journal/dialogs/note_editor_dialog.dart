import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/journal_note.dart';

class NoteEditorDialog extends StatefulWidget {
  final JournalNote? note;

  const NoteEditorDialog({super.key, this.note});

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late NoteCategory _selectedCategory;
  late bool _isPinned;
  String? _imagePath;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _tagController = TextEditingController();
    _selectedCategory = widget.note?.category ?? NoteCategory.general;
    _isPinned = widget.note?.isPinned ?? false;
    _imagePath = widget.note?.imagePath;
    _tags = List.from(widget.note?.tags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _imagePath = result.files.first.path;
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    final note = JournalNote(
      id: widget.note?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _selectedCategory,
      isPinned: _isPinned,
      imagePath: _imagePath,
      tags: _tags,
      createdAt:
          widget.note?.createdAt, // Preserve original creation date if editing
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.note == null
              ? (locale == 'ru' ? 'Новая заметка' : 'New Note')
              : (locale == 'ru' ? 'Редактировать' : 'Edit Note')),
          actions: [
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              color: _isPinned ? theme.colorScheme.primary : null,
              onPressed: () => setState(() => _isPinned = !_isPinned),
              tooltip: locale == 'ru' ? 'Закрепить' : 'Pin Note',
            ),
            TextButton(
              onPressed: _save,
              child: Text(
                locale == 'ru' ? 'Сохранить' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextField(
                controller: _titleController,
                style: theme.textTheme.headlineMedium,
                decoration: InputDecoration(
                  hintText: locale == 'ru' ? 'Заголовок' : 'Title',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<NoteCategory>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: locale == 'ru' ? 'Категория' : 'Category',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: NoteCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(cat.icon,
                            size: 18, color: cat.getColor(theme.colorScheme)),
                        const SizedBox(width: 8),
                        Text(locale == 'ru'
                            ? cat.displayNameRu
                            : cat.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),

              const SizedBox(height: 16),

              // Image Preview / Add Button
              if (_imagePath != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_imagePath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _imagePath = null),
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(locale == 'ru' ? 'Добавить фото' : 'Add Image'),
                ),

              const SizedBox(height: 24),

              // Content
              TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 10,
                decoration: InputDecoration(
                  hintText: locale == 'ru'
                      ? 'Напишите что-нибудь...'
                      : 'Write something...',
                  border: InputBorder.none,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                ),
              ),

              const SizedBox(height: 24),

              // Tags
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: locale == 'ru' ? 'Добавить тег' : 'Add Tag',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return InputChip(
                    label: Text('#$tag'),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
