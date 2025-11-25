import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'quest.g.dart';

@HiveType(typeId: 22)
class Quest extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  QuestStatus status;

  @HiveField(4)
  List<QuestObjective> objectives;

  @HiveField(5)
  String? imagePath;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? completedAt;

  Quest({
    required this.id,
    required this.title,
    this.description = '',
    this.status = QuestStatus.active,
    this.objectives = const [],
    this.imagePath,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get completedObjectivesCount =>
      objectives.where((obj) => obj.isCompleted).length;

  double get progress =>
      objectives.isEmpty ? 0 : completedObjectivesCount / objectives.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.toString(),
      'objectives': objectives.map((o) => o.toJson()).toList(),
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: QuestStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => QuestStatus.active,
      ),
      objectives: (json['objectives'] as List?)
              ?.map((o) => QuestObjective.fromJson(o))
              .toList() ??
          [],
      imagePath: json['imagePath'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}

@HiveType(typeId: 23)
class QuestObjective extends HiveObject {
  @HiveField(0)
  String description;

  @HiveField(1)
  bool isCompleted;

  QuestObjective({
    required this.description,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'isCompleted': isCompleted,
    };
  }

  factory QuestObjective.fromJson(Map<String, dynamic> json) {
    return QuestObjective(
      description: json['description'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

@HiveType(typeId: 24)
enum QuestStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  completed,
  @HiveField(2)
  failed,
}

extension QuestStatusExtension on QuestStatus {
  String get displayName {
    switch (this) {
      case QuestStatus.active:
        return 'Active';
      case QuestStatus.completed:
        return 'Completed';
      case QuestStatus.failed:
        return 'Failed';
    }
  }

  String get displayNameRu {
    switch (this) {
      case QuestStatus.active:
        return 'Активен';
      case QuestStatus.completed:
        return 'Завершён';
      case QuestStatus.failed:
        return 'Провален';
    }
  }

  Color get color {
    switch (this) {
      case QuestStatus.active:
        return Colors.blue;
      case QuestStatus.completed:
        return Colors.green;
      case QuestStatus.failed:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case QuestStatus.active:
        return Icons.play_circle;
      case QuestStatus.completed:
        return Icons.check_circle;
      case QuestStatus.failed:
        return Icons.cancel;
    }
  }
}
