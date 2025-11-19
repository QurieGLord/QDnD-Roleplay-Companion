import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../character_creation_state.dart';

class EquipmentStep extends StatelessWidget {
  const EquipmentStep({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          locale == 'ru' ? 'Стартовая экипировка' : 'Starting Equipment',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          locale == 'ru'
              ? 'Выберите стартовое снаряжение для вашего класса'
              : 'Choose your starting equipment for your class',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Equipment Package Selection
        if (state.selectedClass != null) ...[
          Text(
            locale == 'ru' ? 'Выберите набор экипировки' : 'Choose Equipment Package',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Standard Package Card
          _buildPackageCard(
            context,
            packageId: 'standard',
            title: locale == 'ru' ? 'Стандартный набор' : 'Standard Package',
            subtitle: locale == 'ru'
                ? 'Рекомендуемое начальное снаряжение для вашего класса'
                : 'Recommended starting equipment for your class',
            icon: Icons.check_circle_outline,
            isSelected: state.selectedEquipmentPackage == 'standard' ||
                state.selectedEquipmentPackage == null,
            onTap: () {
              context.read<CharacterCreationState>().updateEquipmentPackage('standard');
            },
          ),

          const SizedBox(height: 12),

          // Alternative Package Card
          _buildPackageCard(
            context,
            packageId: 'alternative',
            title: locale == 'ru' ? 'Альтернативный набор' : 'Alternative Package',
            subtitle: locale == 'ru'
                ? 'Другие варианты экипировки'
                : 'Different equipment options',
            icon: Icons.swap_horiz,
            isSelected: state.selectedEquipmentPackage == 'alternative',
            onTap: () {
              context.read<CharacterCreationState>().updateEquipmentPackage('alternative');
            },
          ),

          const SizedBox(height: 24),

          // Equipment Preview
          Text(
            locale == 'ru'
                ? 'Предпросмотр экипировки ${state.selectedClass!.name['ru']}'
                : '${state.selectedClass!.name['en']} Equipment Preview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildEquipmentCategory(
            context,
            locale == 'ru' ? 'Оружие' : 'Weapons',
            Icons.dataset,
            _getDefaultWeapons(state.selectedClass!.id, locale),
            theme.colorScheme.primary,
          ),

          _buildEquipmentCategory(
            context,
            locale == 'ru' ? 'Доспехи' : 'Armor',
            Icons.shield,
            _getDefaultArmor(state.selectedClass!.id, locale),
            theme.colorScheme.secondary,
          ),

          _buildEquipmentCategory(
            context,
            locale == 'ru' ? 'Инструменты и снаряжение' : 'Tools & Gear',
            Icons.handyman,
            _getDefaultTools(state.selectedClass!.id, locale),
            theme.colorScheme.tertiary,
          ),

          const SizedBox(height: 16),

          // Info Card
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      locale == 'ru'
                          ? 'Это предпросмотр типичного стартового снаряжения. После создания персонажа вы сможете настроить инвентарь.'
                          : 'This is a preview of typical starting equipment. You can customize your inventory after character creation.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPackageCard(
    BuildContext context, {
    required String packageId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentCategory(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
    Color accentColor,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  List<String> _getDefaultWeapons(String classId, String locale) {
    final weapons = {
      'paladin': {
        'en': ['Longsword', 'Shield', 'Holy Symbol'],
        'ru': ['Длинный меч', 'Щит', 'Святой символ'],
      },
      'fighter': {
        'en': ['Longsword', 'Shield', 'Light Crossbow with 20 bolts'],
        'ru': ['Длинный меч', 'Щит', 'Лёгкий арбалет и 20 болтов'],
      },
      'wizard': {
        'en': ['Quarterstaff', 'Dagger'],
        'ru': ['Боевой посох', 'Кинжал'],
      },
      'rogue': {
        'en': ['Shortsword', 'Dagger (2)', 'Thieves\' Tools'],
        'ru': ['Короткий меч', 'Кинжал (2)', 'Воровские инструменты'],
      },
      'cleric': {
        'en': ['Mace', 'Shield', 'Holy Symbol'],
        'ru': ['Булава', 'Щит', 'Святой символ'],
      },
      'ranger': {
        'en': ['Longbow with 20 arrows', 'Shortsword (2)'],
        'ru': ['Длинный лук и 20 стрел', 'Короткий меч (2)'],
      },
    };

    return weapons[classId]?[locale] ??
        (locale == 'ru' ? ['Простое оружие', 'Резервное оружие'] : ['Simple weapon', 'Backup weapon']);
  }

  List<String> _getDefaultArmor(String classId, String locale) {
    final armor = {
      'paladin': {
        'en': ['Chain Mail', 'Shield'],
        'ru': ['Кольчужная броня', 'Щит'],
      },
      'fighter': {
        'en': ['Chain Mail', 'Shield'],
        'ru': ['Кольчужная броня', 'Щит'],
      },
      'wizard': {
        'en': ['No armor'],
        'ru': ['Без доспехов'],
      },
      'rogue': {
        'en': ['Leather Armor'],
        'ru': ['Кожаная броня'],
      },
      'cleric': {
        'en': ['Chain Mail', 'Shield'],
        'ru': ['Кольчужная броня', 'Щит'],
      },
      'ranger': {
        'en': ['Leather Armor'],
        'ru': ['Кожаная броня'],
      },
    };

    return armor[classId]?[locale] ??
        (locale == 'ru' ? ['Лёгкая броня или без доспехов'] : ['Light armor or no armor']);
  }

  List<String> _getDefaultTools(String classId, String locale) {
    final tools = {
      'paladin': {
        'en': ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'],
        'ru': ['Набор путешественника', 'Спальный мешок', 'Рационы (10 дней)'],
      },
      'fighter': {
        'en': ['Explorer\'s Pack', 'Bedroll', 'Rations (10 days)'],
        'ru': ['Набор путешественника', 'Спальный мешок', 'Рационы (10 дней)'],
      },
      'wizard': {
        'en': ['Spellbook', 'Component Pouch', 'Scholar\'s Pack'],
        'ru': ['Книга заклинаний', 'Мешочек с компонентами', 'Набор учёного'],
      },
      'rogue': {
        'en': ['Thieves\' Tools', 'Burglar\'s Pack', 'Crowbar'],
        'ru': ['Воровские инструменты', 'Набор взломщика', 'Ломик'],
      },
      'cleric': {
        'en': ['Holy Symbol', 'Priest\'s Pack', 'Prayer Book'],
        'ru': ['Святой символ', 'Набор священника', 'Молитвенник'],
      },
      'ranger': {
        'en': ['Explorer\'s Pack', 'Rope (50 feet)', 'Hunting Trap'],
        'ru': ['Набор путешественника', 'Верёвка (50 футов)', 'Охотничья ловушка'],
      },
    };

    return tools[classId]?[locale] ??
        (locale == 'ru' ? ['Набор приключенца', 'Верёвка', 'Факел (10)'] : ['Adventurer\'s Pack', 'Rope', 'Torch (10)']);
  }
}
