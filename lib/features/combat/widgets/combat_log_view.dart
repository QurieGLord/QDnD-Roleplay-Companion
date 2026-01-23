import 'package:flutter/material.dart';
import '../../../core/models/combat_state.dart';

class CombatLogView extends StatelessWidget {
  final List<CombatLogEntry> combatLog;

  const CombatLogView({
    super.key,
    required this.combatLog,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (combatLog.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Combat Log',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No combat events yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by timestamp (newest first)
    final sortedLog = List<CombatLogEntry>.from(combatLog)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Combat Log',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sortedLog.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = sortedLog[index];
                  return _buildLogEntry(theme, entry);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(ThemeData theme, CombatLogEntry entry) {
    final time = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getLogTypeColor(entry.type),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getLogTypeIcon(entry.type),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.description ?? entry.type.name,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (entry.amount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.amount.toString(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        'Round ${entry.round} • $time',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _getLogTypeColor(CombatLogType type) {
    switch (type) {
      case CombatLogType.damage:
        return Colors.red;
      case CombatLogType.healing:
        return Colors.green;
      case CombatLogType.deathSave:
        return Colors.black;
      case CombatLogType.conditionAdded:
        return Colors.orange;
      case CombatLogType.conditionRemoved:
        return Colors.blue;
      case CombatLogType.concentrationCheck:
        return Colors.purple;
      case CombatLogType.roundStart:
        return Colors.grey;
      case CombatLogType.other:
        return Colors.blueGrey;
    }
  }

  IconData _getLogTypeIcon(CombatLogType type) {
    switch (type) {
      case CombatLogType.damage:
        return Icons.flash_on;
      case CombatLogType.healing:
        return Icons.favorite;
      case CombatLogType.deathSave:
        return Icons.casino;
      case CombatLogType.conditionAdded:
        return Icons.add_circle;
      case CombatLogType.conditionRemoved:
        return Icons.remove_circle;
      case CombatLogType.concentrationCheck:
        return Icons.psychology;
      case CombatLogType.roundStart:
        return Icons.flag;
      case CombatLogType.other:
        return Icons.info;
    }
  }
}
