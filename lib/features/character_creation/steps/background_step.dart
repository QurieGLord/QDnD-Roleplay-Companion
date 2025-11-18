import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/character_data_service.dart';
import '../character_creation_state.dart';

class BackgroundStep extends StatelessWidget {
  const BackgroundStep({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final locale = Localizations.localeOf(context).languageCode;
    final backgrounds = CharacterDataService.getAllBackgrounds();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Choose Background',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Your background represents your character\'s past and grants additional skills.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        if (backgrounds.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No backgrounds available'),
            ),
          )
        else
          ...backgrounds.map((background) {
            final isSelected = state.selectedBackground?.id == background.id;
            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => state.updateBackground(background),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              background.getName(locale),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        background.getDescription(locale),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (background.skillProficiencies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: background.skillProficiencies.map((skill) {
                            return Chip(
                              label: Text(skill),
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
