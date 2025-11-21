import 'package:flutter/material.dart';
import '../../../core/models/combat_state.dart';

class CombatSummaryCard extends StatelessWidget {
  final CombatState combatState;

  const CombatSummaryCard({
    super.key,
    required this.combatState,
  });

  String _formatDuration(DateTime? startTime) {
    if (startTime == null) return '0:00';

    final duration = DateTime.now().difference(startTime);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Combat Summary',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Statistics grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Damage Dealt',
                    combatState.totalDamageDealt.toString(),
                    Icons.flash_on,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Damage Taken',
                    combatState.totalDamageTaken.toString(),
                    Icons.shield,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Healing',
                    combatState.totalHealing.toString(),
                    Icons.favorite,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    'Duration',
                    _formatDuration(combatState.combatStartTime),
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
