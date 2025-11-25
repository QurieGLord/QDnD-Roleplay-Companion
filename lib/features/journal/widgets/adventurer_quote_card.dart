import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdventurerQuoteCard extends StatelessWidget {
  final String characterName;

  const AdventurerQuoteCard({
    super.key,
    required this.characterName,
  });

  static final List<String> _quotes = [
    "Adventure awaits those who dare to dream.",
    "Every scar tells a story, every victory a legend.",
    "The road goes ever on and on...",
    "Not all those who wander are lost.",
    "It's dangerous to go alone!",
    "Roll for initiative!",
    "May your hits be crits and your loot be legendary.",
    "Heroes are made by the paths they choose.",
    "Dragon fire burns, but courage burns brighter.",
    "Check for traps. Always check for traps.",
  ];

  static final List<String> _quotesRu = [
    "Приключения ждут тех, кто смеет мечтать.",
    "Каждый шрам — это история, каждая победа — легенда.",
    "Дорога вдаль и вдаль ведёт...",
    "Не все, кто блуждают — потеряны.",
    "Опасно идти одному!",
    "Кидай инициативу!",
    "Пусть хиты будут критами, а лут — легендарным.",
    "Героев создают пути, которые они выбирают.",
    "Огонь дракона жжёт, но отвага сияет ярче.",
    "Проверь ловушки. Всегда проверяй ловушки.",
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quotes = locale == 'ru' ? _quotesRu : _quotes;
    
    final quote = quotes[Random().nextInt(quotes.length)];

    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  locale == 'ru' ? 'Совет дня' : 'Daily Insight',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '"$quote"',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}