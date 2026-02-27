import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/models/quest.dart';

class QuestCard extends StatelessWidget {
  final Quest quest;
  final VoidCallback onTap;
  final Function(QuestStatus) onStatusChange;
  final VoidCallback onDelete;

  const QuestCard({
    super.key,
    required this.quest,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final statusColor = quest.status.color;
    final progress = quest.progress;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status Icon
                  Icon(
                    quest.status.icon,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),

                  // Title
                  Expanded(
                    child: Text(
                      quest.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: quest.status != QuestStatus.active
                            ? TextDecoration.lineThrough
                            : null,
                        color: quest.status != QuestStatus.active
                            ? theme.colorScheme.onSurface.withOpacity(0.6)
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Status Menu (Small)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: PopupMenuButton<QuestStatus>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_horiz,
                          size: 16, color: theme.colorScheme.outline),
                      onSelected: onStatusChange,
                      itemBuilder: (context) =>
                          QuestStatus.values.map((status) {
                        return PopupMenuItem(
                          value: status,
                          height: 32,
                          child: Row(
                            children: [
                              Icon(status.icon, size: 16, color: status.color),
                              const SizedBox(width: 8),
                              Text(
                                locale == 'ru'
                                    ? status.displayNameRu
                                    : status.displayName,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              // Progress Bar (if active)
              if (quest.status == QuestStatus.active &&
                  quest.objectives.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: statusColor,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quest.completedObjectivesCount}/${quest.objectives.length} ${locale == 'ru' ? 'задач' : 'tasks'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }
}
