import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/quest.dart';

class QuestEditorDialog extends StatefulWidget {
  final Quest? quest;

  const QuestEditorDialog({super.key, this.quest});

  @override
  State<QuestEditorDialog> createState() => _QuestEditorDialogState();
}

class _QuestEditorDialogState extends State<QuestEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late QuestStatus _status;
  late List<QuestObjective> _objectives;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quest?.title ?? '');
    _descController =
        TextEditingController(text: widget.quest?.description ?? '');
    _status = widget.quest?.status ?? QuestStatus.active;
    // Deep copy objectives so we don't modify the original object directly until saved
    _objectives = widget.quest?.objectives
            .map((o) => QuestObjective(
                  description: o.description,
                  isCompleted: o.isCompleted,
                ))
            .toList() ??
        [];

    // Add an empty objective if list is empty for better UX
    if (_objectives.isEmpty) {
      _objectives.add(QuestObjective(description: ''));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addObjective() {
    setState(() {
      _objectives.add(QuestObjective(description: ''));
    });
  }

  void _removeObjective(int index) {
    setState(() {
      _objectives.removeAt(index);
    });
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    // Filter out empty objectives
    final validObjectives =
        _objectives.where((o) => o.description.trim().isNotEmpty).toList();

    final quest = Quest(
      id: widget.quest?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      status: _status,
      objectives: validObjectives,
      createdAt: widget.quest?.createdAt,
      completedAt: _status == QuestStatus.completed
          ? DateTime.now()
          : widget.quest?.completedAt,
    );

    Navigator.pop(context, quest);
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
          title: Text(widget.quest == null
              ? (locale == 'ru' ? 'Новый квест' : 'New Quest')
              : (locale == 'ru' ? 'Редактировать' : 'Edit Quest')),
          actions: [
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
                style: theme.textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: locale == 'ru' ? 'Название квеста' : 'Quest Title',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 16),

              // Status Dropdown
              DropdownButtonFormField<QuestStatus>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: locale == 'ru' ? 'Статус' : 'Status',
                  border: const OutlineInputBorder(),
                ),
                items: QuestStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(status.icon, size: 18, color: status.color),
                        const SizedBox(width: 8),
                        Text(locale == 'ru'
                            ? status.displayNameRu
                            : status.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),

              const SizedBox(height: 16),

              // Description
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: locale == 'ru' ? 'Описание' : 'Description',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // Objectives Header
              Row(
                children: [
                  Text(
                    locale == 'ru' ? 'Задачи' : 'Objectives',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addObjective,
                    icon: const Icon(Icons.add),
                    label: Text(locale == 'ru' ? 'Добавить' : 'Add'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Objectives List
              ..._objectives.asMap().entries.map((entry) {
                final index = entry.key;
                final objective = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: objective.isCompleted,
                        onChanged: (val) {
                          setState(() {
                            objective.isCompleted = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: objective.description,
                          decoration: InputDecoration(
                            hintText: locale == 'ru'
                                ? 'Описание задачи...'
                                : 'Objective description...',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onChanged: (val) {
                            objective.description = val;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        onPressed: () => _removeObjective(index),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
