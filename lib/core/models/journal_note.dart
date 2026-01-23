import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'journal_note.g.dart';

@HiveType(typeId: 20)
class JournalNote extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  NoteCategory category;

  @HiveField(4)
  String? imagePath; // Local image path or URL

  @HiveField(5)
  List<String> tags;

  @HiveField(6)
  bool isPinned;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime updatedAt;

  JournalNote({
    required this.id,
    required this.title,
    this.content = '',
    this.category = NoteCategory.general,
    this.imagePath,
    this.tags = const [],
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category.toString(),
      'imagePath': imagePath,
      'tags': tags,
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JournalNote.fromJson(Map<String, dynamic> json) {
    return JournalNote(
      id: json['id'],
      title: json['title'],
      content: json['content'] ?? '',
      category: NoteCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => NoteCategory.general,
      ),
      imagePath: json['imagePath'],
      tags: List<String>.from(json['tags'] ?? []),
      isPinned: json['isPinned'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

@HiveType(typeId: 21)
enum NoteCategory {
  @HiveField(0)
  general,
  @HiveField(1)
  location,
  @HiveField(2)
  npc,
  @HiveField(3)
  artifact,
  @HiveField(4)
  story,
  @HiveField(5)
  session,
}

extension NoteCategoryExtension on NoteCategory {
  String get displayName {
    switch (this) {
      case NoteCategory.general:
        return 'General';
      case NoteCategory.location:
        return 'Location';
      case NoteCategory.npc:
        return 'NPC';
      case NoteCategory.artifact:
        return 'Artifact';
      case NoteCategory.story:
        return 'Story';
      case NoteCategory.session:
        return 'Session';
    }
  }

  String get displayNameRu {
    switch (this) {
      case NoteCategory.general:
        return 'Общее';
      case NoteCategory.location:
        return 'Локация';
      case NoteCategory.npc:
        return 'NPC';
      case NoteCategory.artifact:
        return 'Артефакт';
      case NoteCategory.story:
        return 'Сюжет';
      case NoteCategory.session:
        return 'Сессия';
    }
  }

  IconData get icon {
    switch (this) {
      case NoteCategory.general:
        return Icons.note;
      case NoteCategory.location:
        return Icons.place;
      case NoteCategory.npc:
        return Icons.person;
      case NoteCategory.artifact:
        return Icons.auto_awesome;
      case NoteCategory.story:
        return Icons.menu_book;
      case NoteCategory.session:
        return Icons.event;
    }
  }

  Color getColor(ColorScheme colorScheme) {
    switch (this) {
      case NoteCategory.general:
        return colorScheme.primary;
      case NoteCategory.location:
        return Colors.green;
      case NoteCategory.npc:
        return Colors.blue;
      case NoteCategory.artifact:
        return Colors.purple;
      case NoteCategory.story:
        return Colors.orange;
      case NoteCategory.session:
        return Colors.teal;
    }
  }
}
