import 'package:flutter/material.dart';
import '../../../core/models/character_feature.dart';

class FeaturesStep extends StatelessWidget {
  final List<CharacterFeature> newFeatures;
  final List<int> newSpellSlots;
  final List<int> oldSpellSlots;
  final VoidCallback onNext;

  const FeaturesStep({
    Key? key,
    required this.newFeatures,
    required this.newSpellSlots,
    required this.oldSpellSlots,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasSpellChanges = newSpellSlots.isNotEmpty && 
        (newSpellSlots.length > oldSpellSlots.length || 
         newSpellSlots.asMap().entries.any((e) => e.value > (oldSpellSlots.length > e.key ? oldSpellSlots[e.key] : 0)));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'New Abilities Unlocked!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Here is what you gained at this level.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                if (newFeatures.isEmpty && !hasSpellChanges)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No new features at this level. But your stats improved!'),
                    ),
                  ),

                if (hasSpellChanges) ...[
                  _buildSectionHeader(context, 'Magic'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Spell Slots Increased',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildSpellSlotGrid(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (newFeatures.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Class Features'),
                  ...newFeatures.map((feature) => _buildFeatureCard(context, feature)).toList(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature) {
    IconData icon = Icons.star;
    if (feature.iconName != null) {
       // Simple mapping for now
       switch(feature.iconName) {
         case 'healing': icon = Icons.favorite; break;
         case 'visibility': icon = Icons.visibility; break;
         case 'flash_on': icon = Icons.flash_on; break;
         case 'swords': icon = Icons.shield; break; // Using shield for fighting style
         case 'auto_fix_high': icon = Icons.auto_fix_high; break;
         case 'health_and_safety': icon = Icons.health_and_safety; break;
         case 'auto_awesome': icon = Icons.auto_awesome; break;
       }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.nameEn, // TODO: Locale support
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        feature.type.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(feature.descriptionEn), // TODO: Locale support
          ],
        ),
      ),
    );
  }

  Widget _buildSpellSlotGrid(BuildContext context) {
    List<Widget> levelRows = [];
    
    for (int i = 0; i < newSpellSlots.length; i++) {
      int level = i + 1;
      int newCount = newSpellSlots[i];
      int oldCount = i < oldSpellSlots.length ? oldSpellSlots[i] : 0;
      
      if (newCount > oldCount) {
        levelRows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text('Lvl $level', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                // Old slots
                ...List.generate(oldCount, (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(Icons.circle, size: 16, color: Colors.grey),
                )),
                if (oldCount > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  ),
                // New slots
                ...List.generate(newCount, (index) {
                   bool isNew = index >= oldCount;
                   return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Icon(
                      Icons.circle, 
                      size: 16, 
                      color: isNew ? Theme.of(context).colorScheme.primary : Colors.grey
                    ),
                  );
                }),
              ],
            ),
          )
        );
      }
    }
    
    return Column(children: levelRows);
  }
}
