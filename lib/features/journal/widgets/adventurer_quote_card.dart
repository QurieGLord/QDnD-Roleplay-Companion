import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/companion_surface.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdventurerQuoteCard extends StatefulWidget {
  final String characterName;

  const AdventurerQuoteCard({
    super.key,
    required this.characterName,
  });

  @override
  State<AdventurerQuoteCard> createState() => _AdventurerQuoteCardState();
}

class _AdventurerQuoteCardState extends State<AdventurerQuoteCard> {
  late final int _quoteIndex = Random().nextInt(_quotes.length);

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
    "Пусть броски будут удачными, а добыча — легендарной.",
    "Героев создают пути, которые они выбирают.",
    "Огонь дракона жжёт, но отвага сияет ярче.",
    "Проверь ловушки. Всегда проверяй ловушки.",
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final quotes = locale == 'ru' ? _quotesRu : _quotes;

    final quote = quotes[_quoteIndex];

    final card = CompanionSurface(
      padding: EdgeInsets.zero,
      raised: true,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      contour: CompanionContour.cadence,
      child: Padding(
        padding: const EdgeInsets.all(22),
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
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.35,
                letterSpacing: -.25,
              ),
            ),
          ],
        ),
      ),
    );
    return MediaQuery.disableAnimationsOf(context)
        ? card
        : card.animate().fadeIn(duration: 600.ms);
  }
}
